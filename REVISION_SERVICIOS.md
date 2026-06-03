# Revisión General de Microservicios - MediQueue

Este documento proporciona una visión general de los servicios que componen el ecosistema de MediQueue. Todos los servicios están desarrollados con **Java 21** y **Spring Boot**.

## Estructura de Servicios

| Servicio | Puerto | Tecnologías Clave | Descripción |
| :--- | :--- | :--- | :--- |
| `apigateway` | 8080 | Spring Cloud Gateway | Punto de entrada único para las peticiones externas. Enruta el tráfico a los microservicios correspondientes. |
| `cita_service` | 8081 | JPA, PostgreSQL, Redis, RabbitMQ | Gestiona las citas médicas, validando pacientes y doctores. Usa Redis para caché y RabbitMQ para eventos de creación/cancelación. |
| `doctor_horario` | 8082 | JPA, PostgreSQL | Administra la disponibilidad y los horarios de los doctores. |
| `paciente_service` | 8083 | JPA, PostgreSQL | Maneja el registro y la información detallada de los pacientes. |
| `pago_service` | 8084 | JPA, PostgreSQL, RabbitMQ | Procesa los pagos de las citas y notifica el éxito o fallo a través de RabbitMQ. |
| `notificacion_service`| 8085 | RabbitMQ | Consumidor de eventos que se encarga de enviar notificaciones basadas en cambios en citas y pagos. |

---

## Detalles Técnicos por Servicio

### 1. API Gateway (`apigateway`)
- **Rutas configuradas:**
  - `/api/pacientes/**` -> `paciente-service` (8083)
  - `/api/v1/appointments/**` -> `cita-service` (8081)
  - `/api/horarios/**` -> `doctor-horario` (8082)
  - `/api/payments/**` -> `pago-service` (8084)
  - `/api/notificaciones/**` -> `notificacion-service` (8085)

### 2. Cita Service (`cita_service/citaservice`)
- **Persistencia:** PostgreSQL (`mediqueueadmin`).
- **Caché:** Redis (puerto 6379).
- **Comunicación:** Publica eventos en el exchange `mediqueue.appointments.exchange`.
- **Integración:** Consume datos de `paciente-service` y `doctor-horario`.

### 3. Doctor Horario (`doctor_horario`)
- **Persistencia:** PostgreSQL.
- **Responsabilidad:** Gestión de entidades de horarios de médicos.

### 4. Paciente Service (`paciente_service`)
- **Persistencia:** PostgreSQL.
- **Responsabilidad:** Gestión de perfiles de pacientes.

### 5. Pago Service (`pago_service/payment-service`)
- **Persistencia:** PostgreSQL.
- **Comunicación:** Publica eventos en `mediqueue.payments.exchange` (rutas `payments.success` y `payments.failed`).

### 6. Notificación Service (`notificacion_service`)
- **Tipo:** Servicio reactivo a eventos.
- **Colas escuchadas:**
  - `mediqueue.appointments.created`
  - `mediqueue.appointments.cancelled`
  - `mediqueue.payments.success`
  - `mediqueue.payments.failed`

---

## Observaciones Comunes
- **Monitoreo:** Todos los servicios incluyen `Spring Boot Actuator` y Micrometer con exposición de métricas para **Prometheus** en el endpoint `/actuator/prometheus`.
- **Configuración:** La mayoría de los servicios utilizan variables de entorno con valores por defecto para facilitar el despliegue en Docker.
- **Base de Datos:** Se utiliza PostgreSQL de forma generalizada, apuntando a una base de datos central llamada `mediqueueadmin`.
