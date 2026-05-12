package payment_service.dto;

import java.math.BigDecimal;

public record PaymentResponse(
        Long id,
        String appointmentId,
        String patientId,
        BigDecimal amount,
        String status
) {
}
