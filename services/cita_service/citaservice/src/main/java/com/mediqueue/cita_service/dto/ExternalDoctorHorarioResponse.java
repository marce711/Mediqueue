package com.mediqueue.cita_service.dto;

import java.time.DayOfWeek;
import java.time.LocalTime;

public record ExternalDoctorHorarioResponse(
        Long id,
        Long doctorId,
        DayOfWeek diaSemana,
        LocalTime horaInicio,
        LocalTime horaFin,
        boolean disponible
) {
}
