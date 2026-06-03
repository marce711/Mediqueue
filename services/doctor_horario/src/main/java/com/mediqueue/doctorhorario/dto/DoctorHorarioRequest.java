package com.mediqueue.doctorhorario.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.LocalTime;
import java.util.UUID;

public record DoctorHorarioRequest(
        @NotNull(message = "doctorId es obligatorio")
        UUID doctorId,

        @NotBlank(message = "diaSemana es obligatorio")
        String diaSemana,

        @NotNull(message = "horaInicio es obligatoria")
        LocalTime horaInicio,

        @NotNull(message = "horaFin es obligatoria")
        LocalTime horaFin,

        Boolean disponible
) {
}
