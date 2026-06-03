package com.mediqueue.doctorhorario.repository;

import com.mediqueue.doctorhorario.entity.DoctorHorario;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface DoctorHorarioRepository extends JpaRepository<DoctorHorario, UUID> {
    List<DoctorHorario> findByDoctorId(UUID doctorId);

    List<DoctorHorario> findByDoctorIdOrderByDiaSemanaAscHoraInicioAsc(UUID doctorId);

    List<DoctorHorario> findByDisponibleTrue();

    List<DoctorHorario> findByDisponibleFalse();

    List<DoctorHorario> findByDoctorIdAndDisponibleTrue(UUID doctorId);
}
