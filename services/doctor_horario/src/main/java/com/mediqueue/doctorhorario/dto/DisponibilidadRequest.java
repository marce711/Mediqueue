package com.mediqueue.doctorhorario.dto;

import jakarta.validation.constraints.NotNull;

public record DisponibilidadRequest(
        @NotNull(message = "disponible es obligatorio")
        Boolean disponible
) {
}
