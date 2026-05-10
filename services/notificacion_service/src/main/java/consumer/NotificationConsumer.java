package com.mediqueue.notificacionservice.consumer;

import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

@Component
public class NotificationConsumer {

    @RabbitListener(queues = "pago.confirmado.queue")
    public void pagoConfirmado(String mensaje) {

        System.out.println("=========== PAGO CONFIRMADO ==========");
        System.out.println(mensaje);

    }

    @RabbitListener(queues = "pago.fallido.queue")
    public void pagoFallido(String mensaje) {

        System.out.println("=========== PAGO FALLIDO ==========");
        System.out.println(mensaje);

    }
}