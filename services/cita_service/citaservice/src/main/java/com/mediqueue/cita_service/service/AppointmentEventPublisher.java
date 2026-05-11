package com.mediqueue.cita_service.service;

import com.mediqueue.cita_service.dto.AppointmentEvent;
import com.mediqueue.cita_service.entity.Appointment;
import com.mediqueue.cita_service.entity.AppointmentStatus;
import lombok.RequiredArgsConstructor;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
public class AppointmentEventPublisher {

    private final RabbitTemplate rabbitTemplate;

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
        rabbitTemplate.convertAndSend(exchangeName, routingKey, event);
    }
}
