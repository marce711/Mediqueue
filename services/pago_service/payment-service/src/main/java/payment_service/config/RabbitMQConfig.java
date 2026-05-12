package payment_service.config;

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
    DirectExchange paymentsExchange() {
        return new DirectExchange(paymentsExchangeName, true, false);
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
    DirectExchange paymentsDeadLetterExchange() {
        return new DirectExchange(paymentsExchangeName + ".dlx", true, false);
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
    Binding paymentSuccessBinding(
            @Qualifier("paymentSuccessQueue") Queue queue,
            DirectExchange paymentsExchange
    ) {
        return BindingBuilder.bind(queue).to(paymentsExchange).with(paymentSuccessRoutingKey);
    }

    @Bean
    Binding paymentFailedBinding(
            @Qualifier("paymentFailedQueue") Queue queue,
            DirectExchange paymentsExchange
    ) {
        return BindingBuilder.bind(queue).to(paymentsExchange).with(paymentFailedRoutingKey);
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

    @Bean
    RabbitTemplate rabbitTemplate(ConnectionFactory connectionFactory, MessageConverter jsonMessageConverter) {
        RabbitTemplate rabbitTemplate = new RabbitTemplate(connectionFactory);
        rabbitTemplate.setMessageConverter(jsonMessageConverter);
        return rabbitTemplate;
    }
}
