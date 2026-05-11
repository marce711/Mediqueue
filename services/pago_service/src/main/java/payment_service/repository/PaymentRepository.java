package payment_service.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import payment_service.model.Payment;

public interface PaymentRepository extends JpaRepository<Payment, Long> {

    // Validar si ya existe un pago exitoso para esa cita
    boolean existsByAppointmentIdAndStatus(Long appointmentId, String status);
}