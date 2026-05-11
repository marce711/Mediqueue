package com.mediqueue.cita_service.service;

import com.mediqueue.cita_service.dto.AppointmentRequest;
import com.mediqueue.cita_service.dto.AppointmentResponse;
import com.mediqueue.cita_service.dto.AppointmentUpdateRequest;
import com.mediqueue.cita_service.dto.AvailabilityResponse;
import com.mediqueue.cita_service.entity.Appointment;
import com.mediqueue.cita_service.entity.AppointmentStatus;
import com.mediqueue.cita_service.exception.AppointmentConflictException;
import com.mediqueue.cita_service.exception.AppointmentNotFoundException;
import com.mediqueue.cita_service.exception.InvalidAppointmentException;
import com.mediqueue.cita_service.repository.AppointmentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AppointmentService {

    private static final Set<AppointmentStatus> ACTIVE_STATUSES = EnumSet.of(
            AppointmentStatus.PENDING,
            AppointmentStatus.CONFIRMED
    );

    private final AppointmentRepository appointmentRepository;
    private final AppointmentEventPublisher eventPublisher;

    @Transactional
    public AppointmentResponse create(AppointmentRequest request) {
        validateFutureDate(request.appointmentDate());
        validateAvailability(request.doctorId(), request.patientId(), request.appointmentDate());

        Appointment appointment = Appointment.builder()
                .patientId(request.patientId().trim())
                .doctorId(request.doctorId().trim())
                .appointmentDate(request.appointmentDate())
                .status(AppointmentStatus.PENDING)
                .build();

        try {
            Appointment savedAppointment = appointmentRepository.save(appointment);
            eventPublisher.publishCreated(savedAppointment);
            return toResponse(savedAppointment);
        } catch (DataIntegrityViolationException exception) {
            throw new AppointmentConflictException("Doctor already has an appointment at the requested time");
        }
    }

    @Transactional(readOnly = true)
    public List<AppointmentResponse> findAll(String doctorId, String patientId) {
        if (doctorId != null && !doctorId.isBlank()) {
            return appointmentRepository.findByDoctorIdOrderByAppointmentDateAsc(doctorId.trim())
                    .stream()
                    .map(this::toResponse)
                    .toList();
        }
        if (patientId != null && !patientId.isBlank()) {
            return appointmentRepository.findByPatientIdOrderByAppointmentDateAsc(patientId.trim())
                    .stream()
                    .map(this::toResponse)
                    .toList();
        }
        return appointmentRepository.findAll()
                .stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public AppointmentResponse findById(UUID id) {
        return appointmentRepository.findById(id)
                .map(this::toResponse)
                .orElseThrow(() -> new AppointmentNotFoundException(id));
    }

    @Transactional(readOnly = true)
    public AvailabilityResponse checkAvailability(String doctorId, LocalDateTime appointmentDate) {
        validateFutureDate(appointmentDate);
        boolean unavailable = appointmentRepository.existsByDoctorIdAndAppointmentDateAndStatusIn(
                doctorId.trim(),
                appointmentDate,
                ACTIVE_STATUSES
        );
        return new AvailabilityResponse(doctorId.trim(), appointmentDate, !unavailable);
    }

    @Transactional
    public AppointmentResponse updateStatus(UUID id, AppointmentUpdateRequest request) {
        Appointment appointment = getAppointment(id);
        appointment.setStatus(request.status());
        Appointment updatedAppointment = appointmentRepository.save(appointment);
        if (request.status() == AppointmentStatus.CANCELLED) {
            eventPublisher.publishCancelled(updatedAppointment);
        }
        return toResponse(updatedAppointment);
    }

    @Transactional
    public AppointmentResponse cancel(UUID id) {
        Appointment appointment = getAppointment(id);
        if (appointment.getStatus() == AppointmentStatus.CANCELLED) {
            return toResponse(appointment);
        }
        appointment.setStatus(AppointmentStatus.CANCELLED);
        Appointment cancelledAppointment = appointmentRepository.save(appointment);
        eventPublisher.publishCancelled(cancelledAppointment);
        return toResponse(cancelledAppointment);
    }

    private Appointment getAppointment(UUID id) {
        return appointmentRepository.findById(id)
                .orElseThrow(() -> new AppointmentNotFoundException(id));
    }

    private void validateAvailability(String doctorId, String patientId, LocalDateTime appointmentDate) {
        boolean doctorUnavailable = appointmentRepository.existsByDoctorIdAndAppointmentDateAndStatusIn(
                doctorId.trim(),
                appointmentDate,
                ACTIVE_STATUSES
        );
        if (doctorUnavailable) {
            throw new AppointmentConflictException("Doctor already has an active appointment at the requested time");
        }

        boolean patientUnavailable = appointmentRepository.existsByPatientIdAndAppointmentDateAndStatusIn(
                patientId.trim(),
                appointmentDate,
                ACTIVE_STATUSES
        );
        if (patientUnavailable) {
            throw new AppointmentConflictException("Patient already has an active appointment at the requested time");
        }
    }

    private void validateFutureDate(LocalDateTime appointmentDate) {
        if (appointmentDate == null || !appointmentDate.isAfter(LocalDateTime.now())) {
            throw new InvalidAppointmentException("Appointment date must be in the future");
        }
    }

    private AppointmentResponse toResponse(Appointment appointment) {
        return new AppointmentResponse(
                appointment.getId(),
                appointment.getPatientId(),
                appointment.getDoctorId(),
                appointment.getAppointmentDate(),
                appointment.getStatus(),
                appointment.getCreatedAt()
        );
    }
}
