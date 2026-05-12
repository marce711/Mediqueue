package com.mediqueue.cita_service.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.mediqueue.cita_service.dto.AppointmentEvent;
import com.mediqueue.cita_service.entity.Appointment;
import com.mediqueue.cita_service.entity.AppointmentStatus;
import com.mediqueue.cita_service.entity.OutboxEvent;
import com.mediqueue.cita_service.repository.OutboxEventRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.core.MessageDeliveryMode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
public class AppointmentEventPublisher {

    private final RabbitTemplate rabbitTemplate;
    private final ObjectMapper objectMapper;
    private final OutboxEventRepository outboxEventRepository;

    @Value("${app.rabbitmq.exchange}")
    private String exchangeName;

    @Value("${app.rabbitmq.appointment-created-routing-key}")
    private String appointmentCreatedRoutingKey;

    @Value("${app.rabbitmq.appointment-cancelled-routing-key}")
    private String appointmentCancelledRoutingKey;

    public void publishCreated(Appointment appointment) {
        publish(appointment, "APPOINTMENT_CREATED", appointmentCreatedRoutingKey);
    }

    public void publishCancelled(Appointment appointment) {
        publish(appointment, "APPOINTMENT_CANCELLED", appointmentCancelledRoutingKey);
    }

    @Transactional
    public void publishPendingOutboxEvents() {
        outboxEventRepository.findTop25ByStatusOrderByCreatedAtAsc("PENDING")
                .forEach(this::sendOutboxEvent);
    }

    @Scheduled(fixedDelayString = "${app.outbox.fixed-delay-ms:5000}")
    @Transactional
    void publishPendingOutboxEventsScheduled() {
        publishPendingOutboxEvents();
    }

    private void publish(Appointment appointment, String eventType, String routingKey) {
        AppointmentEvent event = new AppointmentEvent(
                appointment.getId(),
                appointment.getPatientId(),
                appointment.getDoctorId(),
                appointment.getAppointmentDate(),
                AppointmentStatus.valueOf(appointment.getStatus().name()),
                eventType,
                LocalDateTime.now()
        );

        OutboxEvent outboxEvent = new OutboxEvent();
        outboxEvent.setAggregateId(appointment.getId().toString());
        outboxEvent.setAggregateType("APPOINTMENT");
        outboxEvent.setEventType(eventType);
        outboxEvent.setExchangeName(exchangeName);
        outboxEvent.setRoutingKey(routingKey);
        outboxEvent.setPayload(toJson(event));
        outboxEventRepository.save(outboxEvent);
    }

    private void sendOutboxEvent(OutboxEvent event) {
        try {
            rabbitTemplate.convertAndSend(event.getExchangeName(), event.getRoutingKey(), event.getPayload(), message -> {
                message.getMessageProperties().setDeliveryMode(MessageDeliveryMode.PERSISTENT);
                message.getMessageProperties().setContentType("application/json");
                message.getMessageProperties().setMessageId(event.getId().toString());
                return message;
            });
            event.setStatus("SENT");
            event.setProcessedAt(LocalDateTime.now());
        } catch (RuntimeException exception) {
            event.setAttempts(event.getAttempts() + 1);
            if (event.getAttempts() >= 10) {
                event.setStatus("FAILED");
            }
        }
    }

    private String toJson(AppointmentEvent event) {
        try {
            return objectMapper.writeValueAsString(event);
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Could not serialize appointment event", exception);
        }
    }
}
