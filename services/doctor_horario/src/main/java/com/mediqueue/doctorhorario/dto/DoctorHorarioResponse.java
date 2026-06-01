package com.mediqueue.doctorhorario.dto;

import java.time.LocalTime;
import java.util.UUID;

public record DoctorHorarioResponse(
        UUID id,
        UUID doctorId,
        String diaSemana,
        LocalTime horaInicio,
        LocalTime horaFin,
        boolean disponible
) {
}
