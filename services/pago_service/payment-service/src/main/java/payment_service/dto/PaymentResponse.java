package payment_service.dto;

import java.math.BigDecimal;

public record PaymentResponse(
        Long id,
        Long appointmentId,
        Long patientId,
        BigDecimal amount,
        String status
) {
}
