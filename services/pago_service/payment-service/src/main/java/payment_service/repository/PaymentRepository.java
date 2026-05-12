package payment_service.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import payment_service.model.Payment;

import java.util.List;
import java.util.Optional;

public interface PaymentRepository extends JpaRepository<Payment, Long> {

    // Validar si ya existe un pago exitoso para esa cita
    boolean existsByAppointmentIdAndStatus(String appointmentId, String status);

    List<Payment> findByAppointmentId(String appointmentId);

    Optional<Payment> findByIdempotencyKey(String idempotencyKey);
}
