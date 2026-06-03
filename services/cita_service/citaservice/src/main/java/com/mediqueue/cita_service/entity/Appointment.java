package com.mediqueue.cita_service.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import jakarta.persistence.Version;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(
        name = "appointments",
        uniqueConstraints = {
                @UniqueConstraint(name = "ux_appointments_idempotency_key_jpa", columnNames = "idempotency_key"),
                @UniqueConstraint(name = "ux_appointments_doctor_datetime_jpa", columnNames = {"doctor_id", "appointment_date"}),
                @UniqueConstraint(name = "ux_appointments_patient_datetime_jpa", columnNames = {"patient_id", "appointment_date"})
        }
)
public class Appointment {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "patient_id", nullable = false, length = 80)
    private String patientId;

    @Column(name = "patient_name", length = 120)
    private String patientName;

    @Column(name = "doctor_id", nullable = false, length = 80)
    private String doctorId;

    @Column(name = "doctor_name", length = 120)
    private String doctorName;

    @Column(name = "appointment_date", nullable = false)
    private LocalDateTime appointmentDate;

    @Column(name = "duration_minutes", nullable = false)
    private Integer durationMinutes;

    @Column(name = "consultation_price", nullable = false, precision = 12, scale = 2)
    private BigDecimal consultationPrice;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private AppointmentStatus status;

    @Column(name = "idempotency_key", length = 120)
    private String idempotencyKey;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @Version
    private Long version;

    @PrePersist
    void prePersist() {
        if (status == null) {
            status = AppointmentStatus.PENDING;
        }
        if (durationMinutes == null) {
            durationMinutes = 30;
        }
        if (consultationPrice == null) {
            consultationPrice = BigDecimal.ZERO;
        }
        LocalDateTime now = LocalDateTime.now();
        if (createdAt == null) {
            createdAt = now;
        }
        if (updatedAt == null) {
            updatedAt = now;
        }
    }

    @PreUpdate
    void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
