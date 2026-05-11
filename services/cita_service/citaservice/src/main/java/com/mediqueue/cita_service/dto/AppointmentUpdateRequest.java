package com.mediqueue.cita_service.dto;

import com.mediqueue.cita_service.entity.AppointmentStatus;
import jakarta.validation.constraints.NotNull;

public record AppointmentUpdateRequest(
        @NotNull(message = "status is required")
        AppointmentStatus status
) {
}
