package com.mediqueue.cita_service.dto;

public record ExternalPacienteResponse(
        Long id,
        String dpi,
        String correo,
        String nombre,
        String telefono
) {
}
