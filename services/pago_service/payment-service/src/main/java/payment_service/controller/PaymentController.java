package payment_service.controller;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Positive;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;
import payment_service.dto.PaymentRequest;
import payment_service.dto.PaymentResponse;
import payment_service.service.PaymentService;

import java.util.List;

@Validated
@RestController
@RequestMapping({"/api/payments", "/payments"})
public class PaymentController {

    private static final Logger logger = LoggerFactory.getLogger(PaymentController.class);

    private final PaymentService paymentService;

    public PaymentController(PaymentService paymentService) {
        this.paymentService = paymentService;
    }

    @PostMapping
    public ResponseEntity<PaymentResponse> processPayment(
            @Valid @RequestBody PaymentRequest payment,
            @RequestHeader(name = "Idempotency-Key", required = false) String idempotencyKey
    ) {
        logger.info("Solicitud recibida para procesar pago. appointmentId={}, patientId={}",
                payment.appointmentId(), payment.patientId());
        PaymentResponse result = paymentService.processPayment(payment, idempotencyKey);
        logger.info("Pago procesado exitosamente. paymentId={}, status={}", result.id(), result.status());
        return ResponseEntity.status(HttpStatus.CREATED).body(result);
    }

    @GetMapping
    public ResponseEntity<List<PaymentResponse>> findAll() {
        return ResponseEntity.ok(paymentService.findAll());
    }

    @GetMapping("/{id}")
    public ResponseEntity<PaymentResponse> findById(@PathVariable @Positive Long id) {
        return ResponseEntity.ok(paymentService.findById(id));
    }

    @GetMapping("/appointment/{appointmentId}")
    public ResponseEntity<List<PaymentResponse>> findByAppointmentId(@PathVariable String appointmentId) {
        return ResponseEntity.ok(paymentService.findByAppointmentId(appointmentId));
    }
}
