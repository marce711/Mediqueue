package payment_service.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.Data;

@Entity
@Table(name = "payments")
@Data
public class Payment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotNull(message = "appointmentId es obligatorio")
    @Column(name = "appointment_id")
    private Long appointmentId;

    @NotNull(message = "patientId es obligatorio")
    @Column(name = "patient_id")
    private Long patientId;

    @NotNull(message = "amount es obligatorio")
    @Positive(message = "El monto debe ser mayor a 0")
    private Double amount;

    private String status;
}