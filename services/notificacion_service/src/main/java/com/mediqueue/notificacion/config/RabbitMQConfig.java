package com.mediqueue.notificacion.config;

import org.springframework.amqp.core.Binding;
import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.DirectExchange;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.core.QueueBuilder;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitMQConfig {

    @Value("${app.rabbitmq.appointments-exchange}")
    private String appointmentsExchangeName;

    @Value("${app.rabbitmq.appointment-created-queue}")
    private String appointmentCreatedQueueName;

    @Value("${app.rabbitmq.appointment-cancelled-queue}")
    private String appointmentCancelledQueueName;

    @Value("${app.rabbitmq.appointment-created-routing-key}")
    private String appointmentCreatedRoutingKey;

    @Value("${app.rabbitmq.appointment-cancelled-routing-key}")
    private String appointmentCancelledRoutingKey;

    @Value("${app.rabbitmq.payments-exchange}")
    private String paymentsExchangeName;

    @Value("${app.rabbitmq.payment-success-queue}")
    private String paymentSuccessQueueName;

    @Value("${app.rabbitmq.payment-failed-queue}")
    private String paymentFailedQueueName;

    @Value("${app.rabbitmq.payment-success-routing-key}")
    private String paymentSuccessRoutingKey;

    @Value("${app.rabbitmq.payment-failed-routing-key}")
    private String paymentFailedRoutingKey;

    @Bean
    DirectExchange appointmentsExchange() {
        return new DirectExchange(appointmentsExchangeName, true, false);
    }

    @Bean
    DirectExchange paymentsExchange() {
        return new DirectExchange(paymentsExchangeName, true, false);
    }

    @Bean
    Queue appointmentCreatedQueue() {
        return QueueBuilder.durable(appointmentCreatedQueueName)
                .deadLetterExchange(appointmentsExchangeName + ".dlx")
                .deadLetterRoutingKey(appointmentCreatedRoutingKey + ".dlq")
                .build();
    }

    @Bean
    Queue appointmentCancelledQueue() {
        return QueueBuilder.durable(appointmentCancelledQueueName)
                .deadLetterExchange(appointmentsExchangeName + ".dlx")
                .deadLetterRoutingKey(appointmentCancelledRoutingKey + ".dlq")
                .build();
    }

    @Bean
    Queue paymentSuccessQueue() {
        return QueueBuilder.durable(paymentSuccessQueueName)
                .deadLetterExchange(paymentsExchangeName + ".dlx")
                .deadLetterRoutingKey(paymentSuccessRoutingKey + ".dlq")
                .build();
    }

    @Bean
    Queue paymentFailedQueue() {
        return QueueBuilder.durable(paymentFailedQueueName)
                .deadLetterExchange(paymentsExchangeName + ".dlx")
                .deadLetterRoutingKey(paymentFailedRoutingKey + ".dlq")
                .build();
    }

    @Bean
    DirectExchange appointmentsDeadLetterExchange() {
        return new DirectExchange(appointmentsExchangeName + ".dlx", true, false);
    }

    @Bean
    DirectExchange paymentsDeadLetterExchange() {
        return new DirectExchange(paymentsExchangeName + ".dlx", true, false);
    }

    @Bean
    Queue appointmentCreatedDeadLetterQueue() {
        return QueueBuilder.durable(appointmentCreatedQueueName + ".dlq").build();
    }

    @Bean
    Queue appointmentCancelledDeadLetterQueue() {
        return QueueBuilder.durable(appointmentCancelledQueueName + ".dlq").build();
    }

    @Bean
    Queue paymentSuccessDeadLetterQueue() {
        return QueueBuilder.durable(paymentSuccessQueueName + ".dlq").build();
    }

    @Bean
    Queue paymentFailedDeadLetterQueue() {
        return QueueBuilder.durable(paymentFailedQueueName + ".dlq").build();
    }

    @Bean
    Binding appointmentCreatedBinding(
            @Qualifier("appointmentCreatedQueue") Queue queue,
            @Qualifier("appointmentsExchange") DirectExchange exchange
    ) {
        return BindingBuilder.bind(queue).to(exchange).with(appointmentCreatedRoutingKey);
    }

    @Bean
    Binding appointmentCancelledBinding(
            @Qualifier("appointmentCancelledQueue") Queue queue,
            @Qualifier("appointmentsExchange") DirectExchange exchange
    ) {
        return BindingBuilder.bind(queue).to(exchange).with(appointmentCancelledRoutingKey);
    }

    @Bean
    Binding paymentSuccessBinding(
            @Qualifier("paymentSuccessQueue") Queue queue,
            @Qualifier("paymentsExchange") DirectExchange exchange
    ) {
        return BindingBuilder.bind(queue).to(exchange).with(paymentSuccessRoutingKey);
    }

    @Bean
    Binding paymentFailedBinding(
            @Qualifier("paymentFailedQueue") Queue queue,
            @Qualifier("paymentsExchange") DirectExchange exchange
    ) {
        return BindingBuilder.bind(queue).to(exchange).with(paymentFailedRoutingKey);
    }

    @Bean
    Binding appointmentCreatedDeadLetterBinding(
            @Qualifier("appointmentCreatedDeadLetterQueue") Queue queue,
            @Qualifier("appointmentsDeadLetterExchange") DirectExchange exchange
    ) {
        return BindingBuilder.bind(queue).to(exchange).with(appointmentCreatedRoutingKey + ".dlq");
    }

    @Bean
    Binding appointmentCancelledDeadLetterBinding(
            @Qualifier("appointmentCancelledDeadLetterQueue") Queue queue,
            @Qualifier("appointmentsDeadLetterExchange") DirectExchange exchange
    ) {
        return BindingBuilder.bind(queue).to(exchange).with(appointmentCancelledRoutingKey + ".dlq");
    }

    @Bean
    Binding paymentSuccessDeadLetterBinding(
            @Qualifier("paymentSuccessDeadLetterQueue") Queue queue,
            @Qualifier("paymentsDeadLetterExchange") DirectExchange exchange
    ) {
        return BindingBuilder.bind(queue).to(exchange).with(paymentSuccessRoutingKey + ".dlq");
    }

    @Bean
    Binding paymentFailedDeadLetterBinding(
            @Qualifier("paymentFailedDeadLetterQueue") Queue queue,
            @Qualifier("paymentsDeadLetterExchange") DirectExchange exchange
    ) {
        return BindingBuilder.bind(queue).to(exchange).with(paymentFailedRoutingKey + ".dlq");
    }

    @Bean
    MessageConverter jsonMessageConverter() {
        return new Jackson2JsonMessageConverter();
    }

}
