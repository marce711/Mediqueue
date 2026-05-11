package com.mediqueue.doctorhorario.dto;

import java.time.DayOfWeek;
import java.time.LocalTime;

public record DoctorHorarioResponse(
        Long id,
        Long doctorId,
        DayOfWeek diaSemana,
        LocalTime horaInicio,
        LocalTime horaFin,
        boolean disponible
) {
}
