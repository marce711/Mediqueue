package payment_service.controller;

import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import payment_service.model.Payment;
import payment_service.service.PaymentService;

@RestController
@RequestMapping("/payments")
public class PaymentController {

    private static final Logger logger = LoggerFactory.getLogger(PaymentController.class);

    @Autowired
    private PaymentService paymentService;

    @PostMapping
    public Payment processPayment(@Valid @RequestBody Payment payment) {

        logger.info("Solicitud recibida para procesar pago: {}", payment);

        try {
            Payment result = paymentService.processPayment(payment);

            logger.info("Pago procesado exitosamente. ID o referencia: {}", result);

            return result;

        } catch (Exception e) {
            logger.error("Error al procesar el pago: {}", payment, e);
            throw e;
        }
    }
}