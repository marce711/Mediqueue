package com.mediqueue.doctorhorario.service;

import com.mediqueue.doctorhorario.dto.DisponibilidadRequest;
import com.mediqueue.doctorhorario.dto.DoctorHorarioRequest;
import com.mediqueue.doctorhorario.dto.DoctorHorarioResponse;
import com.mediqueue.doctorhorario.entity.DoctorHorario;
import com.mediqueue.doctorhorario.exception.DoctorHorarioNotFoundException;
import com.mediqueue.doctorhorario.exception.InvalidHorarioException;
import com.mediqueue.doctorhorario.repository.DoctorHorarioRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalTime;
import java.util.List;

@Service
public class DoctorHorarioService {

    private static final Logger logger = LoggerFactory.getLogger(DoctorHorarioService.class);

    private final DoctorHorarioRepository repository;

    public DoctorHorarioService(DoctorHorarioRepository repository) {
        this.repository = repository;
    }

    @Transactional
    public DoctorHorarioResponse crear(DoctorHorarioRequest request) {
        logger.info("Iniciando transaccion de creacion de horario. doctorId={}", request.doctorId());
        try {
            validarRangoHorario(request.horaInicio(), request.horaFin());
            logger.debug("Rango horario validado para creacion. horaInicio={}, horaFin={}",
                    request.horaInicio(), request.horaFin());

            DoctorHorario horario = new DoctorHorario();
            horario.setDoctorId(request.doctorId());
            horario.setDiaSemana(request.diaSemana());
            horario.setHoraInicio(request.horaInicio());
            horario.setHoraFin(request.horaFin());
            horario.setDisponible(request.disponible() == null || request.disponible());
            logger.debug("Entidad DoctorHorario construida. doctorId={}, diaSemana={}, disponible={}",
                    horario.getDoctorId(), horario.getDiaSemana(), horario.isDisponible());

            DoctorHorario horarioGuardado = repository.save(horario);
            logger.info("Horario creado correctamente. horarioId={}, doctorId={}, disponible={}",
                    horarioGuardado.getId(), horarioGuardado.getDoctorId(), horarioGuardado.isDisponible());
            return toResponse(horarioGuardado);
        } catch (RuntimeException exception) {
            logger.error("Error en transaccion de creacion de horario. doctorId={}", request.doctorId(), exception);
            throw exception;
        }
    }

    @Transactional(readOnly = true)
    public List<DoctorHorarioResponse> listar(Boolean disponible) {
        logger.info("Iniciando consulta de horarios. filtroDisponible={}", disponible);
        try {
            List<DoctorHorario> horarios;
            if (disponible == null) {
                logger.debug("Consultando todos los horarios");
                horarios = repository.findAll();
            } else if (disponible) {
                logger.debug("Consultando horarios disponibles");
                horarios = repository.findByDisponibleTrue();
            } else {
                logger.debug("Consultando horarios no disponibles");
                horarios = repository.findByDisponibleFalse();
            }

            logger.info("Consulta de horarios completada. total={}", horarios.size());
            return horarios.stream().map(this::toResponse).toList();
        } catch (RuntimeException exception) {
            logger.error("Error al consultar horarios. filtroDisponible={}", disponible, exception);
            throw exception;
        }
    }

    @Transactional(readOnly = true)
    public DoctorHorarioResponse obtenerPorId(Long id) {
        logger.info("Iniciando consulta de horario por id. horarioId={}", id);
        try {
            DoctorHorario horario = buscarEntidad(id);
            logger.info("Horario encontrado. horarioId={}, doctorId={}, disponible={}",
                    horario.getId(), horario.getDoctorId(), horario.isDisponible());
            return toResponse(horario);
        } catch (RuntimeException exception) {
            logger.error("Error al consultar horario por id. horarioId={}", id, exception);
            throw exception;
        }
    }

    @Transactional(readOnly = true)
    public List<DoctorHorarioResponse> obtenerPorDoctor(Long doctorId, Boolean soloDisponibles) {
        logger.info("Iniciando consulta de horarios por doctor. doctorId={}, soloDisponibles={}",
                doctorId, soloDisponibles);
        try {
            List<DoctorHorario> horarios = Boolean.TRUE.equals(soloDisponibles)
                    ? repository.findByDoctorIdAndDisponibleTrue(doctorId)
                    : repository.findByDoctorId(doctorId);

            logger.info("Consulta de horarios por doctor completada. doctorId={}, total={}", doctorId, horarios.size());
            return horarios.stream().map(this::toResponse).toList();
        } catch (RuntimeException exception) {
            logger.error("Error al consultar horarios por doctor. doctorId={}, soloDisponibles={}",
                    doctorId, soloDisponibles, exception);
            throw exception;
        }
    }

    @Transactional(readOnly = true)
    public List<DoctorHorarioResponse> obtenerDisponibles() {
        logger.info("Iniciando consulta de horarios disponibles");
        try {
            List<DoctorHorario> horarios = repository.findByDisponibleTrue();
            logger.info("Consulta de horarios disponibles completada. total={}", horarios.size());
            return horarios.stream().map(this::toResponse).toList();
        } catch (RuntimeException exception) {
            logger.error("Error al consultar horarios disponibles", exception);
            throw exception;
        }
    }

    @Transactional
    public DoctorHorarioResponse actualizar(Long id, DoctorHorarioRequest request) {
        logger.info("Iniciando transaccion de actualizacion de horario. horarioId={}", id);
        try {
            validarRangoHorario(request.horaInicio(), request.horaFin());
            logger.debug("Rango horario validado para actualizacion. horarioId={}, horaInicio={}, horaFin={}",
                    id, request.horaInicio(), request.horaFin());

            DoctorHorario horario = buscarEntidad(id);
            logger.debug("Horario cargado para actualizacion. horarioId={}, doctorIdAnterior={}, disponibleAnterior={}",
                    horario.getId(), horario.getDoctorId(), horario.isDisponible());

            horario.setDoctorId(request.doctorId());
            horario.setDiaSemana(request.diaSemana());
            horario.setHoraInicio(request.horaInicio());
            horario.setHoraFin(request.horaFin());
            if (request.disponible() != null) {
                horario.setDisponible(request.disponible());
            }

            DoctorHorario horarioActualizado = repository.save(horario);
            logger.info("Horario actualizado correctamente. horarioId={}, doctorId={}, disponible={}",
                    horarioActualizado.getId(), horarioActualizado.getDoctorId(), horarioActualizado.isDisponible());
            return toResponse(horarioActualizado);
        } catch (RuntimeException exception) {
            logger.error("Error en transaccion de actualizacion de horario. horarioId={}", id, exception);
            throw exception;
        }
    }

    @Transactional
    public void eliminar(Long id) {
        logger.info("Iniciando transaccion de eliminacion de horario. horarioId={}", id);
        try {
            DoctorHorario horario = buscarEntidad(id);
            logger.debug("Horario cargado para eliminacion. horarioId={}, doctorId={}, disponible={}",
                    horario.getId(), horario.getDoctorId(), horario.isDisponible());
            repository.delete(horario);
            logger.info("Horario eliminado correctamente. horarioId={}", id);
        } catch (RuntimeException exception) {
            logger.error("Error en transaccion de eliminacion de horario. horarioId={}", id, exception);
            throw exception;
        }
    }

    @Transactional
    public DoctorHorarioResponse cambiarDisponibilidad(Long id, DisponibilidadRequest request) {
        logger.info("Iniciando transaccion de cambio de disponibilidad. horarioId={}, disponibleSolicitado={}",
                id, request.disponible());
        try {
            DoctorHorario horario = buscarEntidad(id);
            boolean disponibleAnterior = horario.isDisponible();
            horario.setDisponible(request.disponible());
            DoctorHorario horarioActualizado = repository.save(horario);
            logger.info("Disponibilidad actualizada correctamente. horarioId={}, disponibleAnterior={}, disponibleActual={}",
                    id, disponibleAnterior, horarioActualizado.isDisponible());
            return toResponse(horarioActualizado);
        } catch (RuntimeException exception) {
            logger.error("Error en transaccion de cambio de disponibilidad. horarioId={}, disponibleSolicitado={}",
                    id, request.disponible(), exception);
            throw exception;
        }
    }

    private DoctorHorario buscarEntidad(Long id) {
        logger.debug("Buscando horario en base de datos. horarioId={}", id);
        return repository.findById(id)
                .orElseThrow(() -> new DoctorHorarioNotFoundException("Horario no encontrado con id: " + id));
    }

    private void validarRangoHorario(LocalTime horaInicio, LocalTime horaFin) {
        logger.debug("Validando rango horario. horaInicio={}, horaFin={}", horaInicio, horaFin);
        if (!horaInicio.isBefore(horaFin)) {
            logger.warn("Rango horario invalido. horaInicio={}, horaFin={}", horaInicio, horaFin);
            throw new InvalidHorarioException("horaInicio debe ser anterior a horaFin");
        }
    }

    private DoctorHorarioResponse toResponse(DoctorHorario horario) {
        return new DoctorHorarioResponse(
                horario.getId(),
                horario.getDoctorId(),
                horario.getDiaSemana(),
                horario.getHoraInicio(),
                horario.getHoraFin(),
                horario.isDisponible()
        );
    }
}
