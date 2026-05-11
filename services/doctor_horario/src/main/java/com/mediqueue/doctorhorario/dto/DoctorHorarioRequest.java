package com.mediqueue.doctorhorario.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.time.DayOfWeek;
import java.time.LocalTime;

public record DoctorHorarioRequest(
        @NotNull(message = "doctorId es obligatorio")
        @Positive(message = "doctorId debe ser mayor que cero")
        Long doctorId,

        @NotNull(message = "diaSemana es obligatorio")
        DayOfWeek diaSemana,

        @NotNull(message = "horaInicio es obligatoria")
        LocalTime horaInicio,

        @NotNull(message = "horaFin es obligatoria")
        LocalTime horaFin,

        Boolean disponible
) {
}
