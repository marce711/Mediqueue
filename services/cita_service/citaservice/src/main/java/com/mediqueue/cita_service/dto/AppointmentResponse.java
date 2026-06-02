package com.mediqueue.cita_service.dto;

import com.mediqueue.cita_service.entity.AppointmentStatus;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

public record AppointmentResponse(
        UUID id,
        String patientId,
        String patientName,
        String doctorId,
        String doctorName,
        LocalDateTime appointmentDate,
        Integer durationMinutes,
        BigDecimal consultationPrice,
        AppointmentStatus status,
        LocalDateTime createdAt
) {
}
