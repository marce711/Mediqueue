package notification_service.notificacionservice.config;

import org.springframework.amqp.core.*;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitMQConfig {

    public static final String EXCHANGE = "mediqueue.exchange";
    public static final String PAGO_CONFIRMADO_QUEUE = "pago.confirmado.queue";
    public static final String PAGO_FALLIDO_QUEUE = "pago.fallido.queue";

    @Bean
    public TopicExchange exchange() {
        return new TopicExchange(EXCHANGE);
    }

    @Bean
    public Queue pagoConfirmadoQueue() {
        return new Queue(PAGO_CONFIRMADO_QUEUE);
    }

    @Bean
    public Queue pagoFallidoQueue() {
        return new Queue(PAGO_FALLIDO_QUEUE);
    }

    @Bean
    public Binding bindingConfirmado() {
        return BindingBuilder
                .bind(pagoConfirmadoQueue())
                .to(exchange())
                .with("pago.confirmado");
    }

    @Bean
    public Binding bindingFallido() {
        return BindingBuilder
                .bind(pagoFallidoQueue())
                .to(exchange())
                .with("pago.fallido");
    }
}