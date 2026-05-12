package com.mediqueue.paciente.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record PacienteRequest(
        @NotBlank(message = "dpi es obligatorio")
        @Size(max = 30, message = "dpi no debe exceder 30 caracteres")
        String dpi,

        @NotBlank(message = "correo es obligatorio")
        @Email(message = "correo debe tener formato valido")
        @Size(max = 120, message = "correo no debe exceder 120 caracteres")
        String correo,

        @NotBlank(message = "nombre es obligatorio")
        @Size(max = 120, message = "nombre no debe exceder 120 caracteres")
        String nombre,

        @NotBlank(message = "telefono es obligatorio")
        @Size(max = 30, message = "telefono no debe exceder 30 caracteres")
        String telefono
) {
}
