package com.mediqueue.doctorhorario.dto;

import java.time.LocalDateTime;

public record DoctorValidationRequest(
        String doctorId,
        LocalDateTime appointmentDate,
        Integer durationMinutes
) {}
