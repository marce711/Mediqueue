package com.mediqueue.notificacion.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record PaymentEvent(
        Long paymentId,
        Long appointmentId,
        Long patientId,
        BigDecimal amount,
        String status,
        String eventType,
        LocalDateTime occurredAt
) {
}
