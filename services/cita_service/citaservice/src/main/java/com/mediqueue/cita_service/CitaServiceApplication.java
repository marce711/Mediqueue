package com.mediqueue.cita_service;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@EnableScheduling
@SpringBootApplication
public class CitaServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(CitaServiceApplication.class, args);
    }
}
