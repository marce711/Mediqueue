package com.mediqueue.paciente.service;

import com.mediqueue.paciente.entity.Paciente;
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

    public List<Paciente> listar() { // <--- ESTE ES EL MÉTODO QUE BUSCA EL CONTROLLER
        logger.debug("Consultando todos los pacientes en base de datos");
        try {
            List<Paciente> pacientes = repository.findAll();
            logger.debug("Consulta de pacientes finalizada. total={}", pacientes.size());
            return pacientes;
        } catch (RuntimeException ex) {
            logger.error("Error al consultar pacientes", ex);
            throw ex;
        }
    }

    public Paciente guardar(Paciente paciente) {
        logger.debug("Persistiendo nuevo paciente");
        try {
            Paciente pacienteGuardado = repository.save(paciente);
            logger.info("Paciente persistido correctamente. pacienteId={}", pacienteGuardado.getId());
            return pacienteGuardado;
        } catch (RuntimeException ex) {
            logger.error("Error al persistir paciente", ex);
            throw ex;
        }
    }
}
