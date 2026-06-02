package com.mediqueue.cita_service.dto;

import java.time.LocalDateTime;

public record DoctorValidationRequest(
        String doctorId,
        LocalDateTime appointmentDate,
        Integer durationMinutes
) {}
