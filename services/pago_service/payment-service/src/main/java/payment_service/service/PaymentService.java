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

import java.util.List;

@Service
public class PaymentService {

    private static final Logger logger = LoggerFactory.getLogger(PaymentService.class);

    private final PaymentRepository paymentRepository;
    private final PaymentEventPublisher eventPublisher;
    private final RestTemplate restTemplate;

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

        String patientId = resolvePatientIdFromAppointment(request.appointmentId());

        Payment payment = new Payment();
        payment.setAppointmentId(request.appointmentId());
        payment.setPatientId(patientId);
        payment.setAmount(request.amount());
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

    private String resolvePatientIdFromAppointment(String appointmentId) {
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
            return appointment.patientId();
        } catch (RestClientException ex) {
            logger.warn("No fue posible consultar la cita para procesar pago. appointmentId={}", appointmentId, ex);
            throw new RuntimeException("No se pudo validar la cita indicada");
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
