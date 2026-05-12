package com.mediqueue.paciente.exception;

public class PacienteNotFoundException extends RuntimeException {

    public PacienteNotFoundException(String message) {
        super(message);
    }
}
