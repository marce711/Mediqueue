package com.mediqueue.doctorhorario.dto;

import jakarta.validation.constraints.NotNull;

import java.time.DayOfWeek;
import java.time.LocalTime;

public record DoctorScheduleRequest(
        @NotNull(message = "diaSemana es obligatorio")
        DayOfWeek diaSemana,

        @NotNull(message = "horaInicio es obligatoria")
        LocalTime horaInicio,

        @NotNull(message = "horaFin es obligatoria")
        LocalTime horaFin,

        Boolean disponible
) {
}
