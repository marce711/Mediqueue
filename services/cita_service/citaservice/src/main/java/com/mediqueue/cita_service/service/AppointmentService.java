package com.mediqueue.cita_service.service;

import com.mediqueue.cita_service.dto.AppointmentRequest;
import com.mediqueue.cita_service.dto.AppointmentResponse;
import com.mediqueue.cita_service.dto.AppointmentUpdateRequest;
import com.mediqueue.cita_service.dto.AvailabilityResponse;
import com.mediqueue.cita_service.dto.DoctorValidationRequest;
import com.mediqueue.cita_service.dto.DoctorValidationResponse;
import com.mediqueue.cita_service.dto.PatientValidationRequest;
import com.mediqueue.cita_service.dto.PatientValidationResponse;
import com.mediqueue.cita_service.entity.Appointment;
import com.mediqueue.cita_service.entity.AppointmentStatus;
import com.mediqueue.cita_service.exception.AppointmentConflictException;
import com.mediqueue.cita_service.exception.AppointmentNotFoundException;
import com.mediqueue.cita_service.exception.InvalidAppointmentException;
import com.mediqueue.cita_service.repository.AppointmentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AppointmentService {

    private static final int DEFAULT_DURATION_MINUTES = 30;
    private static final int MIN_DURATION_MINUTES = 20;
    private static final int MAX_DURATION_MINUTES = 30;
    private static final int CANCELLATION_NOTICE_HOURS = 48;

    private static final Set<AppointmentStatus> ACTIVE_STATUSES = EnumSet.of(
            AppointmentStatus.PENDING,
            AppointmentStatus.CONFIRMED
    );

    private final AppointmentRepository appointmentRepository;
    private final AppointmentEventPublisher eventPublisher;
    private final RabbitTemplate rabbitTemplate;
    private final RestTemplate restTemplate;

    @Value("${app.services.patient-url}")
    private String patientServiceUrl;

    @Value("${app.services.doctor-url}")
    private String doctorServiceUrl;

    @Value("${app.rabbitmq.rpc-exchange}")
    private String rpcExchange;

    @Value("${app.rabbitmq.patient-validation-routing-key}")
    private String patientValidationRoutingKey;

    @Value("${app.rabbitmq.doctor-validation-routing-key}")
    private String doctorValidationRoutingKey;

    @Transactional
    @CacheEvict(value = "appointmentAvailability", allEntries = true)
    public AppointmentResponse create(AppointmentRequest request, String idempotencyKey) {
        String normalizedIdempotencyKey = normalizeIdempotencyKey(idempotencyKey);
        if (normalizedIdempotencyKey != null) {
            var existing = appointmentRepository.findByIdempotencyKey(normalizedIdempotencyKey);
            if (existing.isPresent()) {
                return toResponse(existing.get());
            }
        }

        int durationMinutes = normalizeDuration(request.durationMinutes());
        validateFutureDate(request.appointmentDate());
        PatientValidationResponse patientValidation = validatePatientExists(request.patientId());
        DoctorValidationResponse doctorValidation = validateDoctorHasAvailableSchedule(
                request.doctorId(),
                request.appointmentDate(),
                durationMinutes
        );
        validateDoctorDailyLimit(request.doctorId(), request.appointmentDate(), doctorValidation.maxAppointmentsPerDay());
        BigDecimal consultationPrice = resolveConsultationPrice(doctorValidation);
        validateAvailability(request.doctorId(), request.patientId(), request.appointmentDate(), durationMinutes);

        Appointment appointment = Appointment.builder()
                .patientId(request.patientId().trim())
                .patientName(patientValidation.name())
                .doctorId(request.doctorId().trim())
                .doctorName(doctorValidation.name())
                .appointmentDate(request.appointmentDate())
                .durationMinutes(durationMinutes)
                .consultationPrice(consultationPrice)
                .status(AppointmentStatus.PENDING)
                .idempotencyKey(normalizedIdempotencyKey)
                .build();

        try {
            Appointment savedAppointment = appointmentRepository.save(appointment);
            eventPublisher.publishCreated(savedAppointment);
            return toResponse(savedAppointment);
        } catch (DataIntegrityViolationException exception) {
            throw new AppointmentConflictException("Appointment slot is already reserved");
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
    @Cacheable(value = "appointmentAvailability", key = "#doctorId.trim() + ':' + #appointmentDate.toString() + ':' + #durationMinutes")
    public AvailabilityResponse checkAvailability(String doctorId, LocalDateTime appointmentDate, Integer durationMinutes) {
        validateFutureDate(appointmentDate);
        int normalizedDuration = normalizeDuration(durationMinutes);
        DoctorValidationResponse doctorValidation = requestDoctorValidation(doctorId, appointmentDate, normalizedDuration);
        boolean hasDoctorSchedule = doctorValidation != null && doctorValidation.hasAvailableSchedule();
        boolean hasAppointmentOverlap = hasOverlap(
                appointmentRepository.findByDoctorIdAndStatusIn(doctorId.trim(), ACTIVE_STATUSES),
                appointmentDate,
                normalizedDuration
        );
        boolean unavailable = !hasDoctorSchedule || hasAppointmentOverlap;
        return new AvailabilityResponse(doctorId.trim(), appointmentDate, normalizedDuration, !unavailable);
    }

    @Transactional
    @CacheEvict(value = "appointmentAvailability", allEntries = true)
    public AppointmentResponse updateStatus(UUID id, AppointmentUpdateRequest request) {
        Appointment appointment = getAppointment(id);
        if (request.status() == AppointmentStatus.CANCELLED && appointment.getStatus() != AppointmentStatus.CANCELLED) {
            validateCancellationNotice(appointment);
        }
        appointment.setStatus(request.status());
        Appointment updatedAppointment = appointmentRepository.save(appointment);
        if (request.status() == AppointmentStatus.CANCELLED) {
            eventPublisher.publishCancelled(updatedAppointment);
        }
        return toResponse(updatedAppointment);
    }

    @Transactional
    @CacheEvict(value = "appointmentAvailability", allEntries = true)
    public AppointmentResponse cancel(UUID id) {
        Appointment appointment = getAppointment(id);
        if (appointment.getStatus() == AppointmentStatus.CANCELLED) {
            return toResponse(appointment);
        }
        validateCancellationNotice(appointment);
        appointment.setStatus(AppointmentStatus.CANCELLED);
        Appointment cancelledAppointment = appointmentRepository.save(appointment);
        eventPublisher.publishCancelled(cancelledAppointment);
        return toResponse(cancelledAppointment);
    }

    private Appointment getAppointment(UUID id) {
        return appointmentRepository.findById(id)
                .orElseThrow(() -> new AppointmentNotFoundException(id));
    }

    private void validateDoctorDailyLimit(String doctorId, LocalDateTime date, int maxDaily) {
        LocalDateTime startOfDay = date.toLocalDate().atStartOfDay();
        LocalDateTime endOfDay = date.toLocalDate().atTime(23, 59, 59);
        long count = appointmentRepository.countByDoctorIdAndAppointmentDateBetweenAndStatusIn(
                doctorId.trim(),
                startOfDay,
                endOfDay,
                ACTIVE_STATUSES
        );
        if (count >= maxDaily) {
            throw new AppointmentConflictException("El doctor ya ha alcanzado su limite diario de citas (" + maxDaily + ")");
        }
    }

    private void validateAvailability(String doctorId, String patientId, LocalDateTime appointmentDate, int durationMinutes) {
        boolean doctorUnavailable = hasOverlap(
                appointmentRepository.findByDoctorIdAndStatusIn(doctorId.trim(), ACTIVE_STATUSES),
                appointmentDate,
                durationMinutes
        );
        if (doctorUnavailable) {
            throw new AppointmentConflictException("Doctor already has an active appointment in the requested time range");
        }

        boolean patientUnavailable = hasOverlap(
                appointmentRepository.findByPatientIdAndStatusIn(patientId.trim(), ACTIVE_STATUSES),
                appointmentDate,
                durationMinutes
        );
        if (patientUnavailable) {
            throw new AppointmentConflictException("Patient already has an active appointment in the requested time range");
        }
    }

    private PatientValidationResponse validatePatientExists(String patientId) {
        PatientValidationRequest request = new PatientValidationRequest(patientId);
        PatientValidationResponse response = (PatientValidationResponse) rabbitTemplate.convertSendAndReceive(
                rpcExchange,
                patientValidationRoutingKey,
                request
        );
        if (response == null || !response.exists()) {
            throw new InvalidAppointmentException("Patient does not exist: " + patientId);
        }
        return response;
    }

    private DoctorValidationResponse validateDoctorHasAvailableSchedule(String doctorId, LocalDateTime appointmentDate, int durationMinutes) {
        DoctorValidationResponse response = requestDoctorValidation(doctorId, appointmentDate, durationMinutes);
        if (response == null || !response.hasAvailableSchedule()) {
            throw new InvalidAppointmentException("Doctor does not have available schedules: " + doctorId);
        }
        return response;
    }

    private DoctorValidationResponse requestDoctorValidation(String doctorId, LocalDateTime appointmentDate, int durationMinutes) {
        DoctorValidationRequest request = new DoctorValidationRequest(doctorId, appointmentDate, durationMinutes);
        return (DoctorValidationResponse) rabbitTemplate.convertSendAndReceive(
                rpcExchange,
                doctorValidationRoutingKey,
                request
        );
    }

    private void validateFutureDate(LocalDateTime appointmentDate) {
        if (appointmentDate == null || !appointmentDate.isAfter(LocalDateTime.now())) {
            throw new InvalidAppointmentException("Appointment date must be in the future");
        }
    }

    private int normalizeDuration(Integer durationMinutes) {
        int normalized = durationMinutes == null ? DEFAULT_DURATION_MINUTES : durationMinutes;
        if (normalized < MIN_DURATION_MINUTES || normalized > MAX_DURATION_MINUTES) {
            throw new InvalidAppointmentException("Appointment duration must be between 20 and 30 minutes");
        }
        return normalized;
    }

    private BigDecimal resolveConsultationPrice(DoctorValidationResponse doctorValidation) {
        if (doctorValidation.consultationPrice() == null || doctorValidation.consultationPrice().signum() <= 0) {
            throw new InvalidAppointmentException("Doctor does not have a valid consultation price");
        }
        return doctorValidation.consultationPrice();
    }

    private boolean hasOverlap(List<Appointment> appointments, LocalDateTime requestedStart, int requestedDurationMinutes) {
        LocalDateTime requestedEnd = requestedStart.plusMinutes(requestedDurationMinutes);
        return appointments.stream().anyMatch(existing -> {
            int existingDuration = existing.getDurationMinutes() == null
                    ? DEFAULT_DURATION_MINUTES
                    : existing.getDurationMinutes();
            LocalDateTime existingStart = existing.getAppointmentDate();
            LocalDateTime existingEnd = existingStart.plusMinutes(existingDuration);
            return existingStart.isBefore(requestedEnd) && existingEnd.isAfter(requestedStart);
        });
    }

    private void validateCancellationNotice(Appointment appointment) {
        LocalDateTime cancellationLimit = appointment.getAppointmentDate().minusHours(CANCELLATION_NOTICE_HOURS);
        if (LocalDateTime.now().isAfter(cancellationLimit)) {
            throw new InvalidAppointmentException("Appointments can only be cancelled with at least 48 hours notice");
        }
    }

    private String normalizeIdempotencyKey(String idempotencyKey) {
        if (idempotencyKey == null || idempotencyKey.isBlank()) {
            return null;
        }
        String normalized = idempotencyKey.trim();
        if (normalized.length() > 120) {
            throw new InvalidAppointmentException("Idempotency-Key must be 120 characters or less");
        }
        return normalized;
    }

    private AppointmentResponse toResponse(Appointment appointment) {
        return new AppointmentResponse(
                appointment.getId(),
                appointment.getPatientId(),
                appointment.getPatientName(),
                appointment.getDoctorId(),
                appointment.getDoctorName(),
                appointment.getAppointmentDate(),
                appointment.getDurationMinutes(),
                appointment.getConsultationPrice(),
                appointment.getStatus(),
                appointment.getCreatedAt()
        );
    }
}
