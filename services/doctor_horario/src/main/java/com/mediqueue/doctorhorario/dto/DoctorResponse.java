package com.mediqueue.doctorhorario.dto;

import java.util.List;

public record DoctorResponse(
        Long id,
        String nombre,
        String especialidad,
        String telefono,
        String correo,
        boolean activo,
        List<DoctorHorarioResponse> horarios
) {
}
