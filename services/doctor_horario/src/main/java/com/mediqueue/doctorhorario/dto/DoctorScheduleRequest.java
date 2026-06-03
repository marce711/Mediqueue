package com.mediqueue.doctorhorario.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.LocalTime;

public record DoctorScheduleRequest(
        @NotBlank(message = "diaSemana es obligatorio")
        String diaSemana,

        @NotNull(message = "horaInicio es obligatoria")
        LocalTime horaInicio,

        @NotNull(message = "horaFin es obligatoria")
        LocalTime horaFin,

        Boolean disponible
) {
}
