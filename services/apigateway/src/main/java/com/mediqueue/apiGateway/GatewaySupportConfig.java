package com.mediqueue.apiGateway;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;

import java.util.List;
import java.util.Map;

@Configuration
public class GatewaySupportConfig {

    @Bean
    public CorsFilter corsFilter() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(List.of("*"));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(false);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return new CorsFilter(source);
    }
}

@RestController
class FallbackController {

    @RequestMapping("/fallback/paciente")
    ResponseEntity<Map<String, String>> pacienteFallback() {
        return unavailable("paciente-service no disponible temporalmente");
    }

    @RequestMapping("/fallback/cita")
    ResponseEntity<Map<String, String>> citaFallback() {
        return unavailable("cita-service no disponible temporalmente");
    }

    @RequestMapping("/fallback/doctor")
    ResponseEntity<Map<String, String>> doctorFallback() {
        return unavailable("doctor-horario no disponible temporalmente");
    }

    @RequestMapping("/fallback/pago")
    ResponseEntity<Map<String, String>> pagoFallback() {
        return unavailable("pago-service no disponible temporalmente");
    }

    @RequestMapping("/fallback/notificacion")
    ResponseEntity<Map<String, String>> notificacionFallback() {
        return unavailable("notificacion-service no disponible temporalmente");
    }

    private ResponseEntity<Map<String, String>> unavailable(String message) {
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(Map.of("error", message));
    }
}
