package payment_service.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import payment_service.model.Payment;

import java.util.List;

public interface PaymentRepository extends JpaRepository<Payment, Long> {

    // Validar si ya existe un pago exitoso para esa cita
    boolean existsByAppointmentIdAndStatus(Long appointmentId, String status);

    List<Payment> findByAppointmentId(Long appointmentId);
}
