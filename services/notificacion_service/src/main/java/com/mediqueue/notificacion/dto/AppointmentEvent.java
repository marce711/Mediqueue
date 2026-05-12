package com.mediqueue.notificacion.dto;

import java.time.LocalDateTime;
import java.util.UUID;

public record AppointmentEvent(
        UUID appointmentId,
        String patientId,
        String doctorId,
        LocalDateTime appointmentDate,
        String status,
        String eventType,
        LocalDateTime occurredAt
) {
}
