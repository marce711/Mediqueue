package com.mediqueue.paciente.service;

import com.mediqueue.paciente.dto.PacienteRequest;
import com.mediqueue.paciente.dto.PacienteResponse;
import com.mediqueue.paciente.entity.Paciente;
import com.mediqueue.paciente.exception.PacienteNotFoundException;
import com.mediqueue.paciente.repository.PacienteRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class PacienteService {

    private static final Logger logger = LoggerFactory.getLogger(PacienteService.class);

    private final PacienteRepository repository;

    public PacienteService(PacienteRepository repository) {
        this.repository = repository;
    }

    public List<PacienteResponse> listar() {
        logger.debug("Consultando todos los pacientes en base de datos");
        try {
            List<Paciente> pacientes = repository.findAll();
            logger.debug("Consulta de pacientes finalizada. total={}", pacientes.size());
            return pacientes.stream().map(this::toResponse).toList();
        } catch (RuntimeException ex) {
            logger.error("Error al consultar pacientes", ex);
            throw ex;
        }
    }

    public PacienteResponse obtenerPorId(Long id) {
        logger.debug("Consultando paciente por id. pacienteId={}", id);
        Paciente paciente = repository.findById(id)
                .orElseThrow(() -> new PacienteNotFoundException("Paciente no encontrado con id: " + id));
        return toResponse(paciente);
    }

    public PacienteResponse obtenerPorDpi(String dpi) {
        logger.debug("Consultando paciente por dpi");
        Paciente paciente = repository.findByDpi(dpi)
                .orElseThrow(() -> new PacienteNotFoundException("Paciente no encontrado con dpi solicitado"));
        return toResponse(paciente);
    }

    public PacienteResponse guardar(PacienteRequest request) {
        logger.debug("Persistiendo nuevo paciente");
        try {
            Paciente paciente = new Paciente();
            paciente.setDpi(request.dpi());
            paciente.setCorreo(request.correo());
            paciente.setNombre(request.nombre());
            paciente.setTelefono(request.telefono());

            Paciente pacienteGuardado = repository.save(paciente);
            logger.info("Paciente persistido correctamente. pacienteId={}", pacienteGuardado.getId());
            return toResponse(pacienteGuardado);
        } catch (RuntimeException ex) {
            logger.error("Error al persistir paciente", ex);
            throw ex;
        }
    }

    private PacienteResponse toResponse(Paciente paciente) {
        return new PacienteResponse(
                paciente.getId(),
                paciente.getDpi(),
                paciente.getCorreo(),
                paciente.getNombre(),
                paciente.getTelefono()
        );
    }
}
