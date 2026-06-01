package com.mediqueue.paciente.consumer;

import com.mediqueue.paciente.dto.PatientValidationRequest;
import com.mediqueue.paciente.dto.PatientValidationResponse;
import com.mediqueue.paciente.repository.PacienteRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

import java.util.UUID;

@Component
public class PatientRpcConsumer {

    private static final Logger logger = LoggerFactory.getLogger(PatientRpcConsumer.class);
    private final PacienteRepository repository;

    public PatientRpcConsumer(PacienteRepository repository) {
        this.repository = repository;
    }

    @RabbitListener(queues = "${app.rabbitmq.patient-validation-queue}")
    public PatientValidationResponse handlePatientValidation(PatientValidationRequest request) {
        logger.info("Recibida peticion RPC de validacion de paciente. patientId={}", request.patientId());
        try {
            UUID id = UUID.fromString(request.patientId().trim());
            boolean exists = repository.existsById(id);
            logger.info("Resultado de validacion para patientId={}: {}", id, exists);
            return new PatientValidationResponse(exists);
        } catch (IllegalArgumentException e) {
            logger.error("Formato de patientId invalido: {}", request.patientId());
            return new PatientValidationResponse(false);
        }
    }
}
