package payment_service.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import payment_service.model.Payment;
import payment_service.repository.PaymentRepository;

import java.util.Random;

@Service
public class PaymentService {

    @Autowired
    private PaymentRepository paymentRepository;

    public Payment processPayment(Payment payment) {

        // ❗ Evitar pagos duplicados
        if (paymentRepository.existsByAppointmentIdAndStatus(payment.getAppointmentId(), "SUCCESS")) {
            throw new RuntimeException("Esta cita ya fue pagada");
        }

        // Estado inicial
        payment.setStatus("PENDING");

        // Simulación de proceso de pago
        boolean success = new Random().nextBoolean();

        if (success) {
            payment.setStatus("SUCCESS");
        } else {
            payment.setStatus("FAILED");
        }

        return paymentRepository.save(payment);
    }
}