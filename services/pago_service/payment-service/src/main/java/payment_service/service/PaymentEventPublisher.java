package payment_service.service;

import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import payment_service.dto.PaymentEvent;
import payment_service.model.Payment;

import java.time.LocalDateTime;

@Service
public class PaymentEventPublisher {

    private final RabbitTemplate rabbitTemplate;

    @Value("${app.rabbitmq.payments-exchange}")
    private String paymentsExchangeName;

    @Value("${app.rabbitmq.payment-success-routing-key}")
    private String paymentSuccessRoutingKey;

    @Value("${app.rabbitmq.payment-failed-routing-key}")
    private String paymentFailedRoutingKey;

    public PaymentEventPublisher(RabbitTemplate rabbitTemplate) {
        this.rabbitTemplate = rabbitTemplate;
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

        rabbitTemplate.convertAndSend(paymentsExchangeName, routingKey, event);
    }
}
