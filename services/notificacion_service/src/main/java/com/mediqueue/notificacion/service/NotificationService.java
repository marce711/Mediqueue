package com.mediqueue.notificacion.service;

import com.mediqueue.notificacion.dto.AppointmentEvent;
import com.mediqueue.notificacion.dto.NotificationResponse;
import com.mediqueue.notificacion.dto.PaymentEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedList;
import java.util.List;

@Service
public class NotificationService {

    private static final Logger logger = LoggerFactory.getLogger(NotificationService.class);
    private static final int MAX_RECENT_NOTIFICATIONS = 100;

    private final List<NotificationResponse> recentNotifications = Collections.synchronizedList(new LinkedList<>());

    public NotificationResponse notifyAppointment(AppointmentEvent event) {
        String message = switch (event.eventType()) {
            case "APPOINTMENT_CREATED" -> "Su cita fue creada exitosamente";
            case "APPOINTMENT_CANCELLED" -> "Su cita fue cancelada";
            default -> "Actualizacion de cita recibida";
        };

        NotificationResponse notification = new NotificationResponse(
                event.eventType(),
                event.patientId(),
                message,
                LocalDateTime.now()
        );
        store(notification);
        logger.info("Notificacion de cita generada. appointmentId={}, patientId={}, type={}",
                event.appointmentId(), event.patientId(), event.eventType());
        return notification;
    }

    public NotificationResponse notifyPayment(PaymentEvent event) {
        String message = switch (event.eventType()) {
            case "PAYMENT_SUCCESS" -> "Su pago fue confirmado exitosamente";
            case "PAYMENT_FAILED" -> "Su pago no pudo ser procesado";
            default -> "Actualizacion de pago recibida";
        };

        NotificationResponse notification = new NotificationResponse(
                event.eventType(),
                String.valueOf(event.patientId()),
                message,
                LocalDateTime.now()
        );
        store(notification);
        logger.info("Notificacion de pago generada. paymentId={}, appointmentId={}, patientId={}, type={}",
                event.paymentId(), event.appointmentId(), event.patientId(), event.eventType());
        return notification;
    }

    public List<NotificationResponse> findRecent() {
        synchronized (recentNotifications) {
            return new ArrayList<>(recentNotifications);
        }
    }

    private void store(NotificationResponse notification) {
        synchronized (recentNotifications) {
            recentNotifications.add(0, notification);
            if (recentNotifications.size() > MAX_RECENT_NOTIFICATIONS) {
                recentNotifications.remove(recentNotifications.size() - 1);
            }
        }
    }
}
