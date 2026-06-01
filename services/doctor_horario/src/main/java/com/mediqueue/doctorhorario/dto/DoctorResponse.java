package com.mediqueue.doctorhorario.dto;

import java.util.List;

public record DoctorResponse(
        Long id,
        String nombre,
        Integer specialtyId,
        String specialtyName,
        String telefono,
        String correo,
        boolean activo,
        List<DoctorHorarioResponse> horarios
) {
}
