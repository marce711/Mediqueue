package com.mediqueue.notificacion.consumer;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.mediqueue.notificacion.dto.AppointmentEvent;
import com.mediqueue.notificacion.dto.PaymentEvent;
import com.mediqueue.notificacion.service.NotificationService;
import org.springframework.amqp.core.Message;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

@Component
public class NotificationConsumer {

    private static final Logger logger = LoggerFactory.getLogger(NotificationConsumer.class);

    private final NotificationService notificationService;
    private final ObjectMapper objectMapper;

    public NotificationConsumer(NotificationService notificationService, ObjectMapper objectMapper) {
        this.notificationService = notificationService;
        this.objectMapper = objectMapper;
    }

    @RabbitListener(queues = "${app.rabbitmq.appointment-created-queue}")
    public void consumeAppointmentCreated(Message message) {
        AppointmentEvent event = readMessage(message, AppointmentEvent.class);
        logger.info("Evento de cita creada recibido. appointmentId={}, patientId={}", event.appointmentId(), event.patientId());
        notificationService.notifyAppointment(event);
    }

    @RabbitListener(queues = "${app.rabbitmq.appointment-cancelled-queue}")
    public void consumeAppointmentCancelled(Message message) {
        AppointmentEvent event = readMessage(message, AppointmentEvent.class);
        logger.info("Evento de cita cancelada recibido. appointmentId={}, patientId={}", event.appointmentId(), event.patientId());
        notificationService.notifyAppointment(event);
    }

    @RabbitListener(queues = "${app.rabbitmq.payment-success-queue}")
    public void consumePaymentSuccess(Message message) {
        PaymentEvent event = readMessage(message, PaymentEvent.class);
        logger.info("Evento de pago exitoso recibido. paymentId={}, appointmentId={}, patientId={}",
                event.paymentId(), event.appointmentId(), event.patientId());
        notificationService.notifyPayment(event);
    }

    @RabbitListener(queues = "${app.rabbitmq.payment-failed-queue}")
    public void consumePaymentFailed(Message message) {
        PaymentEvent event = readMessage(message, PaymentEvent.class);
        logger.info("Evento de pago fallido recibido. paymentId={}, appointmentId={}, patientId={}",
                event.paymentId(), event.appointmentId(), event.patientId());
        notificationService.notifyPayment(event);
    }

    private <T> T readMessage(Message message, Class<T> eventType) {
        try {
            return objectMapper.readValue(message.getBody(), eventType);
        } catch (Exception exception) {
            logger.error("No se pudo deserializar evento RabbitMQ. targetType={}", eventType.getSimpleName(), exception);
            throw new IllegalArgumentException("Evento RabbitMQ invalido", exception);
        }
    }
}
