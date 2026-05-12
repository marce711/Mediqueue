package com.mediqueue.paciente.dto;

public record PacienteResponse(
        Long id,
        String dpi,
        String correo,
        String nombre,
        String telefono
) {
}
