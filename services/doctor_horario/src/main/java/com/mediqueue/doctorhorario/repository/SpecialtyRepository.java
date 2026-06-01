package com.mediqueue.doctorhorario.repository;

import com.mediqueue.doctorhorario.entity.Specialty;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.UUID;

@Repository
public interface SpecialtyRepository extends JpaRepository<Specialty, UUID> {
    java.util.Optional<Specialty> findByNombre(String nombre);
}
