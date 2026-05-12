package com.mediqueue.paciente.controller;

import com.mediqueue.paciente.dto.PacienteRequest;
import com.mediqueue.paciente.dto.PacienteResponse;
import com.mediqueue.paciente.service.PacienteService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Positive;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Validated
@RestController
@RequestMapping("/api/pacientes")
public class PacienteController {

    private static final Logger logger = LoggerFactory.getLogger(PacienteController.class);

    private final PacienteService service;

    public PacienteController(PacienteService service) {
        this.service = service;
    }

    @GetMapping
    public ResponseEntity<List<PacienteResponse>> listar() {
        logger.info("Solicitud recibida para listar pacientes");
        List<PacienteResponse> pacientes = service.listar();
        logger.info("Solicitud de listado de pacientes completada. total={}", pacientes.size());
        return ResponseEntity.ok(pacientes);
    }

    @GetMapping("/{id}")
    public ResponseEntity<PacienteResponse> obtenerPorId(@PathVariable @Positive Long id) {
        logger.info("Solicitud recibida para consultar paciente. pacienteId={}", id);
        return ResponseEntity.ok(service.obtenerPorId(id));
    }

    @GetMapping("/dpi/{dpi}")
    public ResponseEntity<PacienteResponse> obtenerPorDpi(@PathVariable String dpi) {
        logger.info("Solicitud recibida para consultar paciente por dpi");
        return ResponseEntity.ok(service.obtenerPorDpi(dpi));
    }

    @PostMapping
    public ResponseEntity<PacienteResponse> guardar(@Valid @RequestBody PacienteRequest paciente) {
        logger.info("Solicitud recibida para crear paciente");
        PacienteResponse pacienteGuardado = service.guardar(paciente);
        logger.info("Solicitud de creacion de paciente completada. pacienteId={}", pacienteGuardado.id());
        return ResponseEntity.status(HttpStatus.CREATED).body(pacienteGuardado);
    }
}
