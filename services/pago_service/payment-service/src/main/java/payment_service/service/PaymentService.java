package payment_service.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;
import payment_service.dto.AppointmentLookupResponse;
import payment_service.dto.PaymentRequest;
import payment_service.dto.PaymentResponse;
import payment_service.exception.PaymentNotFoundException;
import payment_service.model.Payment;
import payment_service.repository.PaymentRepository;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.math.BigDecimal;
import java.time.Duration;
import java.util.List;

@Service
public class PaymentService {

    private static final Logger logger = LoggerFactory.getLogger(PaymentService.class);

    private final PaymentRepository paymentRepository;
    private final PaymentEventPublisher eventPublisher;
    private final RestTemplate restTemplate;
    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(2))
            .build();

    @Value("${app.services.appointment-url}")
    private String appointmentServiceUrl;

    public PaymentService(PaymentRepository paymentRepository, PaymentEventPublisher eventPublisher, RestTemplate restTemplate) {
        this.paymentRepository = paymentRepository;
        this.eventPublisher = eventPublisher;
        this.restTemplate = restTemplate;
    }

    @Transactional
    public PaymentResponse processPayment(PaymentRequest request, String idempotencyKey) {
        logger.info("Iniciando procesamiento de pago. appointmentId={}", request.appointmentId());

        String normalizedIdempotencyKey = normalizeIdempotencyKey(idempotencyKey);
        if (normalizedIdempotencyKey != null) {
            var existing = paymentRepository.findByIdempotencyKey(normalizedIdempotencyKey);
            if (existing.isPresent()) {
                return toResponse(existing.get());
            }
        }

        if (paymentRepository.existsByAppointmentIdAndStatus(request.appointmentId(), "SUCCESS")) {
            throw new RuntimeException("Esta cita ya fue pagada");
        }

        AppointmentLookupResponse appointment = resolveAppointment(request.appointmentId());
        BigDecimal expectedAmount = resolveExpectedAmount(appointment, request.amount());

        Payment payment = new Payment();
        payment.setAppointmentId(request.appointmentId());
        payment.setPatientId(appointment.patientId());
        payment.setAmount(expectedAmount);
        payment.setStatus("PENDING");
        payment.setIdempotencyKey(normalizedIdempotencyKey);

        payment.setStatus("SUCCESS");

        Payment savedPayment;
        try {
            savedPayment = paymentRepository.save(payment);
        } catch (DataIntegrityViolationException exception) {
            throw new RuntimeException("Esta cita ya fue pagada");
        }
        logger.info("Pago procesado. paymentId={}, appointmentId={}, status={}",
                savedPayment.getId(), savedPayment.getAppointmentId(), savedPayment.getStatus());

        confirmAppointment(savedPayment.getAppointmentId());
        eventPublisher.publishPaymentResult(savedPayment);
        logger.info("Evento de pago publicado. paymentId={}, status={}", savedPayment.getId(), savedPayment.getStatus());

        return toResponse(savedPayment);
    }

    @Transactional(readOnly = true)
    public List<PaymentResponse> findAll() {
        return paymentRepository.findAll().stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public PaymentResponse findById(Long id) {
        return paymentRepository.findById(id)
                .map(this::toResponse)
                .orElseThrow(() -> new PaymentNotFoundException(id));
    }

    @Transactional(readOnly = true)
    public List<PaymentResponse> findByAppointmentId(String appointmentId) {
        return paymentRepository.findByAppointmentId(appointmentId).stream().map(this::toResponse).toList();
    }

    private String normalizeIdempotencyKey(String idempotencyKey) {
        if (idempotencyKey == null || idempotencyKey.isBlank()) {
            return null;
        }
        String normalized = idempotencyKey.trim();
        if (normalized.length() > 120) {
            throw new RuntimeException("Idempotency-Key debe tener 120 caracteres o menos");
        }
        return normalized;
    }

    private AppointmentLookupResponse resolveAppointment(String appointmentId) {
        if (appointmentId == null || appointmentId.isBlank()) {
            throw new RuntimeException("appointmentId es obligatorio");
        }

        String baseUrl = appointmentServiceUrl.replaceAll("/+$", "");
        String url = baseUrl + "/api/v1/appointments/" + appointmentId.trim();
        try {
            AppointmentLookupResponse appointment = restTemplate.getForObject(url, AppointmentLookupResponse.class);
            if (appointment == null || appointment.patientId() == null || appointment.patientId().isBlank()) {
                throw new RuntimeException("La cita no tiene paciente asociado");
            }
            return appointment;
        } catch (RestClientException ex) {
            logger.warn("No fue posible consultar la cita para procesar pago. appointmentId={}", appointmentId, ex);
            throw new RuntimeException("No se pudo validar la cita indicada");
        }
    }

    private BigDecimal resolveExpectedAmount(AppointmentLookupResponse appointment, BigDecimal requestedAmount) {
        if (appointment.consultationPrice() == null || appointment.consultationPrice().signum() <= 0) {
            if (requestedAmount == null || requestedAmount.signum() <= 0) {
                throw new RuntimeException("La cita no tiene precio de consulta valido");
            }
            return requestedAmount;
        }
        if (requestedAmount != null && requestedAmount.compareTo(appointment.consultationPrice()) != 0) {
            throw new RuntimeException("El monto del pago debe ser igual al precio de la cita: " + appointment.consultationPrice());
        }
        return appointment.consultationPrice();
    }

    private void confirmAppointment(String appointmentId) {
        String baseUrl = appointmentServiceUrl.replaceAll("/+$", "");
        String url = baseUrl + "/api/v1/appointments/" + appointmentId.trim() + "/status";
        try {
            HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                    .timeout(Duration.ofSeconds(4))
                    .header("Content-Type", "application/json")
                    .method("PATCH", HttpRequest.BodyPublishers.ofString("{\"status\":\"CONFIRMED\"}"))
                    .build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() >= 400) {
                throw new RuntimeException("cita-service respondio " + response.statusCode());
            }
            logger.info("Cita confirmada despues del pago. appointmentId={}", appointmentId);
        } catch (IOException ex) {
            logger.warn("No fue posible confirmar la cita despues del pago. appointmentId={}", appointmentId, ex);
            throw new RuntimeException("El pago no pudo confirmar la cita indicada");
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            logger.warn("Confirmacion de cita interrumpida despues del pago. appointmentId={}", appointmentId, ex);
            throw new RuntimeException("El pago no pudo confirmar la cita indicada");
        }
    }

    private PaymentResponse toResponse(Payment payment) {
        return new PaymentResponse(
                payment.getId(),
                payment.getAppointmentId(),
                payment.getAmount(),
                payment.getStatus()
        );
    }
}
