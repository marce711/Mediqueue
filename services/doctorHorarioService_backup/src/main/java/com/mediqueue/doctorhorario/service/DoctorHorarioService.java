package com.mediqueue.doctorhorario.service;

import com.mediqueue.doctorhorario.DoctorHorario;
import com.mediqueue.doctorhorario.repository.DoctorHorarioRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class DoctorHorarioService {

    private final DoctorHorarioRepository repository;

    public DoctorHorarioService(DoctorHorarioRepository repository) {
        this.repository = repository;
    }

    public DoctorHorario guardarHorario(DoctorHorario horario) {
        return repository.save(horario);
    }

    public List<DoctorHorario> obtenerHorarios(Long doctorId) {
        return repository.findByDoctorId(doctorId);
    }
}