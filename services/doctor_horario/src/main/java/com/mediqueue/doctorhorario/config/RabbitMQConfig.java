package com.mediqueue.doctorhorario.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.springframework.amqp.core.Binding;
import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.DirectExchange;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.DefaultJackson2JavaTypeMapper;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.HashMap;
import java.util.Map;

@Configuration
public class RabbitMQConfig {

    @Value("${app.rabbitmq.rpc-exchange}")
    private String rpcExchangeName;

    @Value("${app.rabbitmq.doctor-validation-queue}")
    private String doctorValidationQueueName;

    @Value("${app.rabbitmq.doctor-validation-routing-key}")
    private String doctorValidationRoutingKey;

    @Bean
    DirectExchange rpcExchange() {
        return new DirectExchange(rpcExchangeName, true, false);
    }

    @Bean
    Queue doctorValidationQueue() {
        return new Queue(doctorValidationQueueName, true);
    }

    @Bean
    Binding doctorValidationBinding(Queue doctorValidationQueue, DirectExchange rpcExchange) {
        return BindingBuilder.bind(doctorValidationQueue)
                .to(rpcExchange)
                .with(doctorValidationRoutingKey);
    }

    @Bean
    MessageConverter jsonMessageConverter() {
        ObjectMapper objectMapper = new ObjectMapper();
        objectMapper.registerModule(new JavaTimeModule());

        Jackson2JsonMessageConverter converter = new Jackson2JsonMessageConverter(objectMapper);
        DefaultJackson2JavaTypeMapper typeMapper = new DefaultJackson2JavaTypeMapper();
        typeMapper.setTrustedPackages("*");

        Map<String, Class<?>> idClassMapping = new HashMap<>();
        idClassMapping.put("com.mediqueue.cita_service.dto.DoctorValidationRequest", com.mediqueue.doctorhorario.dto.DoctorValidationRequest.class);
        idClassMapping.put("com.mediqueue.cita_service.dto.DoctorValidationResponse", com.mediqueue.doctorhorario.dto.DoctorValidationResponse.class);

        typeMapper.setIdClassMapping(idClassMapping);
        converter.setJavaTypeMapper(typeMapper);
        return converter;
    }

    @Bean
    RabbitTemplate rabbitTemplate(ConnectionFactory connectionFactory, MessageConverter jsonMessageConverter) {
        RabbitTemplate rabbitTemplate = new RabbitTemplate(connectionFactory);
        rabbitTemplate.setMessageConverter(jsonMessageConverter);
        return rabbitTemplate;
    }
}
