package com.mediqueue.paciente.repository;

// FIJATE EN ESTA LINEA, DEBE SER EXACTAMENTE ASI:
import com.mediqueue.paciente.entity.Paciente;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface PacienteRepository extends JpaRepository<Paciente, Long> {
    Optional<Paciente> findByDpi(String dpi);
}