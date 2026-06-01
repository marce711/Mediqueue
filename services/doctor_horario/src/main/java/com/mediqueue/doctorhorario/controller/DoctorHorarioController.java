package com.mediqueue.doctorhorario.controller;

import com.mediqueue.doctorhorario.dto.DisponibilidadRequest;
import com.mediqueue.doctorhorario.dto.DoctorHorarioRequest;
import com.mediqueue.doctorhorario.dto.DoctorHorarioResponse;
import com.mediqueue.doctorhorario.dto.DoctorRequest;
import com.mediqueue.doctorhorario.dto.DoctorResponse;
import com.mediqueue.doctorhorario.entity.Specialty;
import com.mediqueue.doctorhorario.service.DoctorService;
import com.mediqueue.doctorhorario.service.DoctorHorarioService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Positive;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Validated
@RestController
@RequestMapping("/api/horarios")
public class DoctorHorarioController {

    private static final Logger logger = LoggerFactory.getLogger(DoctorHorarioController.class);

    private final DoctorHorarioService service;
    private final DoctorService doctorService;

    public DoctorHorarioController(DoctorHorarioService service, DoctorService doctorService) {
        this.service = service;
        this.doctorService = doctorService;
    }

    @PostMapping("/doctores")
    public ResponseEntity<DoctorResponse> crearDoctor(@Valid @RequestBody DoctorRequest request) {
        logger.info("POST /api/horarios/doctores recibido. nombre={}, specialtyId={}",
                request.nombre(), request.specialtyId());
        return ResponseEntity.status(HttpStatus.CREATED).body(doctorService.crear(request));
    }

    @GetMapping("/doctores")
    public ResponseEntity<List<DoctorResponse>> listarDoctores() {
        logger.info("GET /api/horarios/doctores recibido");
        return ResponseEntity.ok(doctorService.listar());
    }

    @GetMapping("/especialidades")
    public ResponseEntity<List<Specialty>> listarEspecialidades() {
        logger.info("GET /api/horarios/especialidades recibido");
        return ResponseEntity.ok(doctorService.listarEspecialidades());
    }

    @PostMapping
    public ResponseEntity<DoctorHorarioResponse> crear(@Valid @RequestBody DoctorHorarioRequest request) {
        logger.info("POST /api/horarios recibido. doctorId={}, diaSemana={}, horaInicio={}, horaFin={}, disponible={}",
                request.doctorId(), request.diaSemana(), request.horaInicio(), request.horaFin(), request.disponible());
        DoctorHorarioResponse response = service.crear(request);
        logger.info("POST /api/horarios completado. horarioId={}, doctorId={}", response.id(), response.doctorId());
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @GetMapping
    public ResponseEntity<List<DoctorHorarioResponse>> listar(@RequestParam(required = false) Boolean disponible) {
        logger.info("GET /api/horarios recibido. filtroDisponible={}", disponible);
        List<DoctorHorarioResponse> response = service.listar(disponible);
        logger.info("GET /api/horarios completado. total={}", response.size());
        return ResponseEntity.ok(response);
    }

    @GetMapping("/{id}")
    public ResponseEntity<DoctorHorarioResponse> obtenerPorId(@PathVariable @Positive Long id) {
        logger.info("GET /api/horarios/{} recibido", id);
        DoctorHorarioResponse response = service.obtenerPorId(id);
        logger.info("GET /api/horarios/{} completado. doctorId={}, disponible={}",
                id, response.doctorId(), response.disponible());
        return ResponseEntity.ok(response);
    }

    @GetMapping("/doctor/{doctorId}")
    public ResponseEntity<List<DoctorHorarioResponse>> obtenerPorDoctor(
            @PathVariable @Positive Long doctorId,
            @RequestParam(required = false) Boolean disponible
    ) {
        logger.info("GET /api/horarios/doctor/{} recibido. filtroDisponible={}", doctorId, disponible);
        List<DoctorHorarioResponse> response = service.obtenerPorDoctor(doctorId, disponible);
        logger.info("GET /api/horarios/doctor/{} completado. total={}", doctorId, response.size());
        return ResponseEntity.ok(response);
    }

    @GetMapping("/disponibles")
    public ResponseEntity<List<DoctorHorarioResponse>> obtenerDisponibles() {
        logger.info("GET /api/horarios/disponibles recibido");
        List<DoctorHorarioResponse> response = service.obtenerDisponibles();
        logger.info("GET /api/horarios/disponibles completado. total={}", response.size());
        return ResponseEntity.ok(response);
    }

    @PutMapping("/{id}")
    public ResponseEntity<DoctorHorarioResponse> actualizar(
            @PathVariable @Positive Long id,
            @Valid @RequestBody DoctorHorarioRequest request
    ) {
        logger.info("PUT /api/horarios/{} recibido. doctorId={}, diaSemana={}, horaInicio={}, horaFin={}, disponible={}",
                id, request.doctorId(), request.diaSemana(), request.horaInicio(), request.horaFin(), request.disponible());
        DoctorHorarioResponse response = service.actualizar(id, request);
        logger.info("PUT /api/horarios/{} completado. doctorId={}, disponible={}",
                id, response.doctorId(), response.disponible());
        return ResponseEntity.ok(response);
    }

    @PatchMapping("/{id}/disponibilidad")
    public ResponseEntity<DoctorHorarioResponse> cambiarDisponibilidad(
            @PathVariable @Positive Long id,
            @Valid @RequestBody DisponibilidadRequest request
    ) {
        logger.info("PATCH /api/horarios/{}/disponibilidad recibido. disponible={}", id, request.disponible());
        DoctorHorarioResponse response = service.cambiarDisponibilidad(id, request);
        logger.info("PATCH /api/horarios/{}/disponibilidad completado. disponible={}", id, response.disponible());
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable @Positive Long id) {
        logger.info("DELETE /api/horarios/{} recibido", id);
        service.eliminar(id);
        logger.info("DELETE /api/horarios/{} completado", id);
        return ResponseEntity.noContent().build();
    }
}
