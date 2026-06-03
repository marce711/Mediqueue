package com.mediqueue.doctorhorario.repository;

import com.mediqueue.doctorhorario.entity.Doctor;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface DoctorRepository extends JpaRepository<Doctor, UUID> {

    List<Doctor> findByEstado(String estado);

    Optional<Doctor> findByCorreo(String correo);

    boolean existsByCorreo(String correo);
}
