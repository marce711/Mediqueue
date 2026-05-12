package payment_service.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.amqp.core.MessageDeliveryMode;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import payment_service.dto.PaymentEvent;
import payment_service.model.Payment;
import payment_service.model.OutboxEvent;
import payment_service.repository.OutboxEventRepository;

import java.time.LocalDateTime;

@Service
public class PaymentEventPublisher {

    private final RabbitTemplate rabbitTemplate;
    private final ObjectMapper objectMapper;
    private final OutboxEventRepository outboxEventRepository;

    @Value("${app.rabbitmq.payments-exchange}")
    private String paymentsExchangeName;

    @Value("${app.rabbitmq.payment-success-routing-key}")
    private String paymentSuccessRoutingKey;

    @Value("${app.rabbitmq.payment-failed-routing-key}")
    private String paymentFailedRoutingKey;

    public PaymentEventPublisher(RabbitTemplate rabbitTemplate, ObjectMapper objectMapper, OutboxEventRepository outboxEventRepository) {
        this.rabbitTemplate = rabbitTemplate;
        this.objectMapper = objectMapper;
        this.outboxEventRepository = outboxEventRepository;
    }

    public void publishPaymentResult(Payment payment) {
        String eventType = "SUCCESS".equals(payment.getStatus()) ? "PAYMENT_SUCCESS" : "PAYMENT_FAILED";
        String routingKey = "SUCCESS".equals(payment.getStatus()) ? paymentSuccessRoutingKey : paymentFailedRoutingKey;

        PaymentEvent event = new PaymentEvent(
                payment.getId(),
                payment.getAppointmentId(),
                payment.getPatientId(),
                payment.getAmount(),
                payment.getStatus(),
                eventType,
                LocalDateTime.now()
        );

        OutboxEvent outboxEvent = new OutboxEvent();
        outboxEvent.setAggregateId(String.valueOf(payment.getId()));
        outboxEvent.setAggregateType("PAYMENT");
        outboxEvent.setEventType(eventType);
        outboxEvent.setExchangeName(paymentsExchangeName);
        outboxEvent.setRoutingKey(routingKey);
        outboxEvent.setPayload(toJson(event));
        outboxEventRepository.save(outboxEvent);
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

    private String toJson(PaymentEvent event) {
        try {
            return objectMapper.writeValueAsString(event);
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Could not serialize payment event", exception);
        }
    }
}
