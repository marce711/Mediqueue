package payment_service.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.math.BigDecimal;

public record PaymentRequest(
        @NotNull(message = "appointmentId es obligatorio")
        String appointmentId,

        @NotNull(message = "patientId es obligatorio")
        String patientId,

        @NotNull(message = "amount es obligatorio")
        @Positive(message = "El monto debe ser mayor a 0")
        BigDecimal amount
) {
}
