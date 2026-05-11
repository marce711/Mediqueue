package com.mediqueue.cita_service.dto;

import jakarta.validation.constraints.Future;
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
        LocalDateTime appointmentDate
) {
}
