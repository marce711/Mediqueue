package com.mediqueue.paciente.controller;

import com.mediqueue.paciente.entity.Paciente; // <--- REVISA ESTE CAMINO
import com.mediqueue.paciente.service.PacienteService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/pacientes")
public class PacienteController {

    private static final Logger logger = LoggerFactory.getLogger(PacienteController.class);

    private final PacienteService service;

    public PacienteController(PacienteService service) {
        this.service = service;
    }

    @GetMapping
    public List<Paciente> listar() {
        logger.info("Solicitud recibida para listar pacientes");
        List<Paciente> pacientes = service.listar();
        logger.info("Solicitud de listado de pacientes completada. total={}", pacientes.size());
        return pacientes;
    }

    @PostMapping
    public Paciente guardar(@RequestBody Paciente paciente) {
        logger.info("Solicitud recibida para crear paciente");
        Paciente pacienteGuardado = service.guardar(paciente);
        logger.info("Solicitud de creacion de paciente completada. pacienteId={}", pacienteGuardado.getId());
        return pacienteGuardado;
    }
}
