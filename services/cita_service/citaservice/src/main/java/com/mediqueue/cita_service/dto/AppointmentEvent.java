package com.mediqueue.cita_service.dto;

import com.mediqueue.cita_service.entity.AppointmentStatus;

import java.time.LocalDateTime;
import java.util.UUID;

public record AppointmentEvent(
        UUID appointmentId,
        String patientId,
        String doctorId,
        LocalDateTime appointmentDate,
        AppointmentStatus status,
        String eventType,
        LocalDateTime occurredAt
) {
}
