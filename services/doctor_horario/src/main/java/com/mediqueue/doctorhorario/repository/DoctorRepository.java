package com.mediqueue.doctorhorario.repository;

import com.mediqueue.doctorhorario.entity.Doctor;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface DoctorRepository extends JpaRepository<Doctor, Long> {

    List<Doctor> findByActivoTrueOrderByNombreAsc();

    Optional<Doctor> findByCorreo(String correo);

    boolean existsByCorreo(String correo);
}
