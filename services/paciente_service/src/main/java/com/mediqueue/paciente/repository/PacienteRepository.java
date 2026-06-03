package com.mediqueue.paciente.repository;

import com.mediqueue.paciente.entity.Paciente;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PacienteRepository extends JpaRepository<Paciente, UUID> {
    Optional<Paciente> findByDpi(String dpi);
    boolean existsByDpi(String dpi);
    boolean existsByCorreo(String correo);
}
