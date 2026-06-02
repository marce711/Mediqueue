package com.mediqueue.cita_service.dto;

import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDateTime;

public record AppointmentRequest(
        @NotBlank(message = "patientId is required")
        String patientId,

        @NotBlank(message = "doctorId is required")
        String doctorId,

        @NotNull(message = "appointmentDate is required")
        @Future(message = "appointmentDate must be in the future")
        LocalDateTime appointmentDate,

        @Min(value = 20, message = "durationMinutes must be at least 20")
        @Max(value = 30, message = "durationMinutes must be at most 30")
        Integer durationMinutes
) {
}
