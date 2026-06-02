package com.mediqueue.apiGateway;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;
import java.util.Arrays;
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

    @Bean
    public RestTemplate gatewayRestTemplate() {
        return new RestTemplate();
    }
}

@RestController
class ApiProxyController {

    private static final List<String> HOP_BY_HOP_HEADERS = List.of(
            HttpHeaders.CONNECTION,
            HttpHeaders.TRANSFER_ENCODING,
            HttpHeaders.CONTENT_LENGTH,
            "Keep-Alive",
            "Proxy-Authenticate",
            "Proxy-Authorization",
            "TE",
            "Trailer",
            "Upgrade"
    );

    private final RestTemplate restTemplate;
    private final List<String> pacienteServiceUrls;
    private final List<String> citaServiceUrls;
    private final List<String> doctorServiceUrls;
    private final List<String> pagoServiceUrls;
    private final List<String> notificacionServiceUrls;

    ApiProxyController(
            RestTemplate restTemplate,
            @Value("${PACIENTE_SERVICE_URLS:${PACIENTE_SERVICE_URL:http://100.76.170.62:8083}}") String pacienteServiceUrls,
            @Value("${CITA_SERVICE_URLS:${CITA_SERVICE_URL:http://100.113.35.88:8081}}") String citaServiceUrls,
            @Value("${DOCTOR_SERVICE_URLS:${DOCTOR_SERVICE_URL:http://100.113.35.88:8082}}") String doctorServiceUrls,
            @Value("${PAGO_SERVICE_URLS:${PAGO_SERVICE_URL:http://100.99.158.111:8084}}") String pagoServiceUrls,
            @Value("${NOTIFICACION_SERVICE_URLS:${NOTIFICACION_SERVICE_URL:http://100.99.158.111:8085}}") String notificacionServiceUrls
    ) {
        this.restTemplate = restTemplate;
        this.pacienteServiceUrls = parseServiceUrls(pacienteServiceUrls);
        this.citaServiceUrls = parseServiceUrls(citaServiceUrls);
        this.doctorServiceUrls = parseServiceUrls(doctorServiceUrls);
        this.pagoServiceUrls = parseServiceUrls(pagoServiceUrls);
        this.notificacionServiceUrls = parseServiceUrls(notificacionServiceUrls);
    }

    @RequestMapping({
            "/api/pacientes", "/api/pacientes/**",
            "/api/horarios", "/api/horarios/**",
            "/api/v1/appointments", "/api/v1/appointments/**",
            "/api/payments", "/api/payments/**",
            "/api/notificaciones", "/api/notificaciones/**"
    })
    ResponseEntity<byte[]> proxy(HttpServletRequest request, @RequestBody(required = false) byte[] body) {
        List<String> targetBaseUrls = targetBaseUrls(request.getRequestURI());
        HttpHeaders headers = copyRequestHeaders(request);
        HttpEntity<byte[]> entity = new HttpEntity<>(body, headers);
        RestClientException lastException = null;

        for (String targetBaseUrl : targetBaseUrls) {
            URI targetUri = UriComponentsBuilder.fromUriString(targetBaseUrl)
                    .path(request.getRequestURI())
                    .query(request.getQueryString())
                    .build(true)
                    .toUri();
            try {
                ResponseEntity<byte[]> response = restTemplate.exchange(
                        targetUri,
                        HttpMethod.valueOf(request.getMethod()),
                        entity,
                        byte[].class
                );
                return responseWithFilteredHeaders(response);
            } catch (HttpStatusCodeException exception) {
                return ResponseEntity.status(exception.getStatusCode())
                        .headers(copyResponseHeaders(exception.getResponseHeaders()))
                        .body(exception.getResponseBodyAsByteArray());
            } catch (RestClientException exception) {
                lastException = exception;
            }
        }

        String detail = lastException == null ? "No hay rutas configuradas" : lastException.getMessage().replace("\"", "'");
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(("{\"error\":\"Servicio destino no disponible\",\"detail\":\""
                        + detail + "\"}").getBytes());
    }

    private List<String> targetBaseUrls(String requestUri) {
        if (requestUri.startsWith("/api/pacientes")) {
            return pacienteServiceUrls;
        }
        if (requestUri.startsWith("/api/horarios")) {
            return doctorServiceUrls;
        }
        if (requestUri.startsWith("/api/v1/appointments")) {
            return citaServiceUrls;
        }
        if (requestUri.startsWith("/api/payments")) {
            return pagoServiceUrls;
        }
        if (requestUri.startsWith("/api/notificaciones")) {
            return notificacionServiceUrls;
        }
        throw new IllegalArgumentException("Ruta no soportada: " + requestUri);
    }

    private HttpHeaders copyRequestHeaders(HttpServletRequest request) {
        HttpHeaders headers = new HttpHeaders();
        request.getHeaderNames().asIterator().forEachRemaining(headerName -> {
            if (!isHopByHopHeader(headerName) && !HttpHeaders.HOST.equalsIgnoreCase(headerName)) {
                request.getHeaders(headerName).asIterator()
                        .forEachRemaining(value -> headers.add(headerName, value));
            }
        });
        return headers;
    }

    private ResponseEntity<byte[]> responseWithFilteredHeaders(ResponseEntity<byte[]> response) {
        return ResponseEntity.status(response.getStatusCode())
                .headers(copyResponseHeaders(response.getHeaders()))
                .body(response.getBody());
    }

    private HttpHeaders copyResponseHeaders(HttpHeaders source) {
        HttpHeaders headers = new HttpHeaders();
        if (source != null) {
            source.forEach((headerName, values) -> {
                if (!isHopByHopHeader(headerName)) {
                    headers.put(headerName, values);
                }
            });
        }
        return headers;
    }

    private boolean isHopByHopHeader(String headerName) {
        return HOP_BY_HOP_HEADERS.stream().anyMatch(header -> header.equalsIgnoreCase(headerName));
    }

    private String trimTrailingSlash(String value) {
        if (value == null || value.isBlank()) {
            return "";
        }
        return value.endsWith("/") ? value.substring(0, value.length() - 1) : value;
    }

    private List<String> parseServiceUrls(String value) {
        return Arrays.stream(value.split(","))
                .map(String::trim)
                .filter(url -> !url.isBlank())
                .map(this::trimTrailingSlash)
                .toList();
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

