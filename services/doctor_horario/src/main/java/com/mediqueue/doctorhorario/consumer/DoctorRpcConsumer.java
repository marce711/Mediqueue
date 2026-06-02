package com.mediqueue.doctorhorario.consumer;

import com.mediqueue.doctorhorario.dto.DoctorValidationRequest;
import com.mediqueue.doctorhorario.dto.DoctorValidationResponse;
import com.mediqueue.doctorhorario.repository.DoctorRepository;
import com.mediqueue.doctorhorario.repository.DoctorHorarioRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

import java.text.Normalizer;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

@Component
public class DoctorRpcConsumer {

    private static final Logger logger = LoggerFactory.getLogger(DoctorRpcConsumer.class);
    private final DoctorHorarioRepository repository;
    private final DoctorRepository doctorRepository;

    public DoctorRpcConsumer(DoctorHorarioRepository repository, DoctorRepository doctorRepository) {
        this.repository = repository;
        this.doctorRepository = doctorRepository;
    }

    @RabbitListener(queues = "${app.rabbitmq.doctor-validation-queue}")
    public DoctorValidationResponse handleDoctorValidation(DoctorValidationRequest request) {
        logger.info("Recibida peticion RPC de validacion de horario de doctor. doctorId={}", request.doctorId());
        try {
            UUID doctorId = UUID.fromString(request.doctorId().trim());
            List<com.mediqueue.doctorhorario.entity.DoctorHorario> schedules = repository.findByDoctorIdAndDisponibleTrue(doctorId);
            boolean hasAvailableSchedule = hasScheduleForRequest(
                    schedules,
                    request.appointmentDate(),
                    request.durationMinutes()
            );
            logger.info("Resultado de validacion para doctorId={}: {}", doctorId, hasAvailableSchedule);
            return doctorRepository.findById(doctorId)
                    .map(doctor -> new DoctorValidationResponse(
                            hasAvailableSchedule && doctor.isActivo(),
                            doctor.getSpecialty().getConsultationPrice(),
                            doctor.getNombre()
                    ))
                    .orElseGet(() -> new DoctorValidationResponse(false, null, null));
        } catch (IllegalArgumentException e) {
            logger.error("Formato de doctorId invalido: {}", request.doctorId());
            return new DoctorValidationResponse(false, null, null);
        }
    }

    private boolean hasScheduleForRequest(
            List<com.mediqueue.doctorhorario.entity.DoctorHorario> schedules,
            LocalDateTime appointmentDate,
            Integer durationMinutes
    ) {
        if (appointmentDate == null) {
            return !schedules.isEmpty();
        }
        int duration = durationMinutes == null ? 30 : durationMinutes;
        LocalTime requestedStart = appointmentDate.toLocalTime();
        LocalTime requestedEnd = requestedStart.plusMinutes(duration);
        String requestedDay = appointmentDate.getDayOfWeek().name();

        return schedules.stream().anyMatch(schedule ->
                requestedDay.equals(normalizeDay(schedule.getDiaSemana()))
                        && !requestedStart.isBefore(schedule.getHoraInicio())
                        && !requestedEnd.isAfter(schedule.getHoraFin())
        );
    }

    private String normalizeDay(String day) {
        if (day == null || day.isBlank()) {
            return "";
        }
        String normalized = Normalizer.normalize(day.trim(), Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "")
                .toUpperCase(Locale.ROOT);
        return switch (normalized) {
            case "LUNES" -> "MONDAY";
            case "MARTES" -> "TUESDAY";
            case "MIERCOLES" -> "WEDNESDAY";
            case "JUEVES" -> "THURSDAY";
            case "VIERNES" -> "FRIDAY";
            case "SABADO" -> "SATURDAY";
            case "DOMINGO" -> "SUNDAY";
            default -> normalized;
        };
    }
}
