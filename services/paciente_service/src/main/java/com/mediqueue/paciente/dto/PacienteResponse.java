package com.mediqueue.paciente.dto;

import java.util.UUID;

public record PacienteResponse(
        UUID id,
        String dpi,
        String correo,
        String nombre,
        String telefono
) {
}
