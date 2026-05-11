package com.mediqueue.cita_service.dto;

import java.time.LocalDateTime;

public record AvailabilityResponse(
        String doctorId,
        LocalDateTime appointmentDate,
        boolean available
) {
}
