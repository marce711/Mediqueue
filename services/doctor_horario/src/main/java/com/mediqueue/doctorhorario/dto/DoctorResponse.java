package com.mediqueue.doctorhorario.dto;

import java.util.List;
import java.util.UUID;

public record DoctorResponse(
        UUID id,
        String nombre,
        UUID specialtyId,
        String specialtyName,
        String telefono,
        String correo,
        boolean activo,
        List<DoctorHorarioResponse> horarios
) {
}
