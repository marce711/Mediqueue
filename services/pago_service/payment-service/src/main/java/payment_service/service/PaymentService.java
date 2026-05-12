package payment_service.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
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

    public PaymentService(PaymentRepository paymentRepository, PaymentEventPublisher eventPublisher) {
        this.paymentRepository = paymentRepository;
        this.eventPublisher = eventPublisher;
    }

    @Transactional
    public PaymentResponse processPayment(PaymentRequest request, String idempotencyKey) {
        logger.info("Iniciando procesamiento de pago. appointmentId={}, patientId={}",
                request.appointmentId(), request.patientId());

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

        Payment payment = new Payment();
        payment.setAppointmentId(request.appointmentId());
        payment.setPatientId(request.patientId());
        payment.setAmount(request.amount());
        payment.setStatus("PENDING");
        payment.setIdempotencyKey(normalizedIdempotencyKey);

        payment.setStatus("SUCCESS");

        Payment savedPayment = paymentRepository.save(payment);
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

    private PaymentResponse toResponse(Payment payment) {
        return new PaymentResponse(
                payment.getId(),
                payment.getAppointmentId(),
                payment.getPatientId(),
                payment.getAmount(),
                payment.getStatus()
        );
    }
}
