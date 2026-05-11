package payment_service.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.*;

@Entity
@Table(name = "payments")
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

    // Constructor vacío
    public Payment() {
    }

    // GETTERS Y SETTERS

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getAppointmentId() {
        return appointmentId;
    }

    public void setAppointmentId(Long appointmentId) {
        this.appointmentId = appointmentId;
    }

    public Long getPatientId() {
        return patientId;
    }

    public void setPatientId(Long patientId) {
        this.patientId = patientId;
    }

    public Double getAmount() {
        return amount;
    }

    public void setAmount(Double amount) {
        this.amount = amount;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }
}