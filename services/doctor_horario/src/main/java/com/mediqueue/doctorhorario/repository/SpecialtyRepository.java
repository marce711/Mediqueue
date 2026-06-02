package com.mediqueue.doctorhorario.repository;

import com.mediqueue.doctorhorario.entity.Specialty;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.UUID;

@Repository
public interface SpecialtyRepository extends JpaRepository<Specialty, UUID> {
    java.util.Optional<Specialty> findByName(String name);

    List<Specialty> findByActivaTrueOrderByNameAsc();
}
