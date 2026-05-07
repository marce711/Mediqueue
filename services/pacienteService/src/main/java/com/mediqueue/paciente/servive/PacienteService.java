package com.mediqueue.paciente.service;

import com.mediqueue.paciente.entity.Paciente;
import com.mediqueue.paciente.repository.PacienteRepository;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class PacienteService {

    private final PacienteRepository repository;

    public PacienteService(PacienteRepository repository) {
        this.repository = repository;
    }

    public List<Paciente> listar() { // <--- ESTE ES EL MÉTODO QUE BUSCA EL CONTROLLER
        return repository.findAll();
    }

    public Paciente guardar(Paciente paciente) {
        return repository.save(paciente);
    }
}