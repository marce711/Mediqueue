package com.mediqueue.doctorhorario.consumer;

import com.mediqueue.doctorhorario.dto.DoctorValidationRequest;
import com.mediqueue.doctorhorario.dto.DoctorValidationResponse;
import com.mediqueue.doctorhorario.repository.DoctorHorarioRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

import java.util.UUID;

@Component
public class DoctorRpcConsumer {

    private static final Logger logger = LoggerFactory.getLogger(DoctorRpcConsumer.class);
    private final DoctorHorarioRepository repository;

    public DoctorRpcConsumer(DoctorHorarioRepository repository) {
        this.repository = repository;
    }

    @RabbitListener(queues = "${app.rabbitmq.doctor-validation-queue}")
    public DoctorValidationResponse handleDoctorValidation(DoctorValidationRequest request) {
        logger.info("Recibida peticion RPC de validacion de horario de doctor. doctorId={}", request.doctorId());
        try {
            UUID doctorId = UUID.fromString(request.doctorId().trim());
            boolean hasAvailableSchedule = !repository.findByDoctorIdAndDisponibleTrue(doctorId).isEmpty();
            logger.info("Resultado de validacion para doctorId={}: {}", doctorId, hasAvailableSchedule);
            return new DoctorValidationResponse(hasAvailableSchedule);
        } catch (IllegalArgumentException e) {
            logger.error("Formato de doctorId invalido: {}", request.doctorId());
            return new DoctorValidationResponse(false);
        }
    }
}
