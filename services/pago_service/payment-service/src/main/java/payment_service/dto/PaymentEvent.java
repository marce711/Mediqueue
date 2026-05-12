package payment_service.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record PaymentEvent(
        Long paymentId,
        String appointmentId,
        String patientId,
        BigDecimal amount,
        String status,
        String eventType,
        LocalDateTime occurredAt
) {
}
