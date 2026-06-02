package com.mediqueue.cita_service.dto;

import java.math.BigDecimal;

public record DoctorValidationResponse(
        boolean hasAvailableSchedule,
        BigDecimal consultationPrice,
        String name
) {
}
