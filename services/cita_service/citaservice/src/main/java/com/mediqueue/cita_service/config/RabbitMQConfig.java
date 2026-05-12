package com.mediqueue.cita_service.config;

import org.springframework.amqp.core.Binding;
import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.DirectExchange;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.core.QueueBuilder;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitMQConfig {

    @Value("${app.rabbitmq.exchange}")
    private String exchangeName;

    @Value("${app.rabbitmq.appointment-created-queue}")
    private String appointmentCreatedQueue;

    @Value("${app.rabbitmq.appointment-cancelled-queue}")
    private String appointmentCancelledQueue;

    @Value("${app.rabbitmq.appointment-created-routing-key}")
    private String appointmentCreatedRoutingKey;

    @Value("${app.rabbitmq.appointment-cancelled-routing-key}")
    private String appointmentCancelledRoutingKey;

    @Bean
    DirectExchange appointmentExchange() {
        return new DirectExchange(exchangeName, true, false);
    }

    @Bean
    Queue appointmentCreatedQueue() {
        return QueueBuilder.durable(appointmentCreatedQueue)
                .deadLetterExchange(exchangeName + ".dlx")
                .deadLetterRoutingKey(appointmentCreatedRoutingKey + ".dlq")
                .build();
    }

    @Bean
    Queue appointmentCancelledQueue() {
        return QueueBuilder.durable(appointmentCancelledQueue)
                .deadLetterExchange(exchangeName + ".dlx")
                .deadLetterRoutingKey(appointmentCancelledRoutingKey + ".dlq")
                .build();
    }

    @Bean
    DirectExchange appointmentDeadLetterExchange() {
        return new DirectExchange(exchangeName + ".dlx", true, false);
    }

    @Bean
    Queue appointmentCreatedDeadLetterQueue() {
        return QueueBuilder.durable(appointmentCreatedQueue + ".dlq").build();
    }

    @Bean
    Queue appointmentCancelledDeadLetterQueue() {
        return QueueBuilder.durable(appointmentCancelledQueue + ".dlq").build();
    }

    @Bean
    Binding appointmentCreatedBinding(
            @Qualifier("appointmentCreatedQueue") Queue appointmentCreatedQueue,
            DirectExchange appointmentExchange
    ) {
        return BindingBuilder.bind(appointmentCreatedQueue)
                .to(appointmentExchange)
                .with(appointmentCreatedRoutingKey);
    }

    @Bean
    Binding appointmentCancelledBinding(
            @Qualifier("appointmentCancelledQueue") Queue appointmentCancelledQueue,
            DirectExchange appointmentExchange
    ) {
        return BindingBuilder.bind(appointmentCancelledQueue)
                .to(appointmentExchange)
                .with(appointmentCancelledRoutingKey);
    }

    @Bean
    Binding appointmentCreatedDeadLetterBinding(
            @Qualifier("appointmentCreatedDeadLetterQueue") Queue queue,
            @Qualifier("appointmentDeadLetterExchange") DirectExchange exchange
    ) {
        return BindingBuilder.bind(queue).to(exchange).with(appointmentCreatedRoutingKey + ".dlq");
    }

    @Bean
    Binding appointmentCancelledDeadLetterBinding(
            @Qualifier("appointmentCancelledDeadLetterQueue") Queue queue,
            @Qualifier("appointmentDeadLetterExchange") DirectExchange exchange
    ) {
        return BindingBuilder.bind(queue).to(exchange).with(appointmentCancelledRoutingKey + ".dlq");
    }

    @Bean
    MessageConverter jsonMessageConverter() {
        return new Jackson2JsonMessageConverter();
    }

    @Bean
    RabbitTemplate rabbitTemplate(ConnectionFactory connectionFactory, MessageConverter jsonMessageConverter) {
        RabbitTemplate rabbitTemplate = new RabbitTemplate(connectionFactory);
        rabbitTemplate.setMessageConverter(jsonMessageConverter);
        return rabbitTemplate;
    }
}
