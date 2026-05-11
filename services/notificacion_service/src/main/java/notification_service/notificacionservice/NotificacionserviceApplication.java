package notification_service.notificacionservice;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.ComponentScan; // Añade esto

@SpringBootApplication
@ComponentScan(basePackages = "com.mediqueue.notificacionservice") // Fuerza el escaneo
public class NotificacionserviceApplication {

	public static void main(String[] args) {
		SpringApplication.run(NotificacionserviceApplication.class, args);
	}
}