package com.mediqueue.doctorhorario.dto;

import java.math.BigDecimal;

public record DoctorValidationResponse(
        boolean hasAvailableSchedule,
        BigDecimal consultationPrice,
        String name,
        int maxAppointmentsPerDay
) {
}
