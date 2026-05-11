package com.mediqueue.cita_service.dto;

import com.mediqueue.cita_service.entity.AppointmentStatus;

import java.time.LocalDateTime;
import java.util.UUID;

public record AppointmentResponse(
        UUID id,
        String patientId,
        String doctorId,
        LocalDateTime appointmentDate,
        AppointmentStatus status,
        LocalDateTime createdAt
) {
}
