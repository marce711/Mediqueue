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
import java.util.Random;

@Service
public class PaymentService {

    private static final Logger logger = LoggerFactory.getLogger(PaymentService.class);

    private final PaymentRepository paymentRepository;
    private final PaymentEventPublisher eventPublisher;
    private final Random random = new Random();

    public PaymentService(PaymentRepository paymentRepository, PaymentEventPublisher eventPublisher) {
        this.paymentRepository = paymentRepository;
        this.eventPublisher = eventPublisher;
    }

    @Transactional
    public PaymentResponse processPayment(PaymentRequest request) {
        logger.info("Iniciando procesamiento de pago. appointmentId={}, patientId={}",
                request.appointmentId(), request.patientId());

        if (paymentRepository.existsByAppointmentIdAndStatus(request.appointmentId(), "SUCCESS")) {
            throw new RuntimeException("Esta cita ya fue pagada");
        }

        Payment payment = new Payment();
        payment.setAppointmentId(request.appointmentId());
        payment.setPatientId(request.patientId());
        payment.setAmount(request.amount());
        payment.setStatus("PENDING");

        boolean success = random.nextBoolean();
        payment.setStatus(success ? "SUCCESS" : "FAILED");

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
    public List<PaymentResponse> findByAppointmentId(Long appointmentId) {
        return paymentRepository.findByAppointmentId(appointmentId).stream().map(this::toResponse).toList();
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
