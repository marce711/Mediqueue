package com.mediqueue.notificacion.dto;

import java.time.LocalDateTime;

public record NotificationResponse(
        String type,
        String recipientId,
        String message,
        LocalDateTime createdAt
) {
}
