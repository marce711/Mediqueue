package com.mediqueue.cita_service.repository;

import com.mediqueue.cita_service.entity.Appointment;
import com.mediqueue.cita_service.entity.AppointmentStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.UUID;

public interface AppointmentRepository extends JpaRepository<Appointment, UUID> {

    boolean existsByDoctorIdAndAppointmentDateAndStatusIn(
            String doctorId,
            LocalDateTime appointmentDate,
            Collection<AppointmentStatus> statuses
    );

    boolean existsByPatientIdAndAppointmentDateAndStatusIn(
            String patientId,
            LocalDateTime appointmentDate,
            Collection<AppointmentStatus> statuses
    );

    List<Appointment> findByDoctorIdOrderByAppointmentDateAsc(String doctorId);

    List<Appointment> findByPatientIdOrderByAppointmentDateAsc(String patientId);
}
