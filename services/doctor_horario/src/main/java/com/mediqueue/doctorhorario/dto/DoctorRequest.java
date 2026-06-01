package com.mediqueue.doctorhorario.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;
import java.util.UUID;

public record DoctorRequest(
        @NotBlank(message = "nombre es obligatorio")
        @Size(max = 120, message = "nombre no debe exceder 120 caracteres")
        String nombre,

        @NotNull(message = "specialtyId es obligatorio")
        UUID specialtyId,

        @Size(max = 30, message = "telefono no debe exceder 30 caracteres")
        String telefono,

        @Email(message = "correo debe tener formato valido")
        @Size(max = 120, message = "correo no debe exceder 120 caracteres")
        String correo,

        Boolean activo,

        @Valid
        @NotEmpty(message = "Debe registrar al menos un horario")
        List<DoctorScheduleRequest> horarios
) {
}
