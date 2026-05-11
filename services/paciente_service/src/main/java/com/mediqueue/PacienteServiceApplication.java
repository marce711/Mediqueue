package com.mediqueue;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class PacienteServiceApplication {

    private static final Logger logger = LoggerFactory.getLogger(PacienteServiceApplication.class);

    public static void main(String[] args) {
        SpringApplication.run(PacienteServiceApplication.class, args);
        logger.info("Paciente service iniciado correctamente");
    }

}
