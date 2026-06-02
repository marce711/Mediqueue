package com.mediqueue.doctorhorario.dto;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record DoctorResponse(
        UUID id,
        String nombre,
        UUID specialtyId,
        String specialtyName,
        BigDecimal consultationPrice,
        String telefono,
        String correo,
        boolean activo,
        int maxAppointmentsPerDay,
        List<DoctorHorarioResponse> horarios
) {
}
