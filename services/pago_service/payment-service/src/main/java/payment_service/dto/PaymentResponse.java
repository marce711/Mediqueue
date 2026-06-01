package payment_service.dto;

import java.math.BigDecimal;

public record PaymentResponse(
        Long id,
        String appointmentId,
        BigDecimal amount,
        String status
) {
}
