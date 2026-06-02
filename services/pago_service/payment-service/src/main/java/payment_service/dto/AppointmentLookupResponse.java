package payment_service.dto;

import java.math.BigDecimal;

public record AppointmentLookupResponse(
        String id,
        String patientId,
        String doctorId,
        String appointmentDate,
        Integer durationMinutes,
        BigDecimal consultationPrice,
        String status,
        String createdAt
) {
}
