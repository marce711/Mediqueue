package com.mediqueue.doctorhorario.repository;

import com.mediqueue.doctorhorario.entity.DoctorHorario;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface DoctorHorarioRepository extends JpaRepository<DoctorHorario, Long> {

    List<DoctorHorario> findByDoctorId(Long doctorId);

    List<DoctorHorario> findByDisponibleTrue();

    List<DoctorHorario> findByDisponibleFalse();

    List<DoctorHorario> findByDoctorIdAndDisponibleTrue(Long doctorId);
}
