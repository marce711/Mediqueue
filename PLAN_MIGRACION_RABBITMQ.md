# Plan de Migración de Comunicación REST a RabbitMQ

Este documento detalla la estrategia para migrar las consultas síncronas entre microservicios (actualmente vía REST) hacia una arquitectura orientada a eventos utilizando RabbitMQ.

## 1. Estado Actual
Actualmente, el microservicio `cita_service` realiza llamadas REST síncronas a otros servicios para validaciones críticas:
- **`paciente_service`**: Valida la existencia de un paciente (`/api/pacientes/{id}`).
- **`doctor_horario`**: Valida la disponibilidad de horarios del doctor (`/api/horarios/doctor/{doctorId}`).

### Problemas Detectados
- **Acoplamiento Temporal:** Si `paciente_service` está caído, `cita_service` no puede crear citas.
- **Propagación de Fallos:** La latencia en un servicio afecta directamente a los demás.
- **Carga Innecesaria:** Cada validación implica una nueva conexión de red.

---

## 2. Propuesta de Solución

Se recomiendan dos fases para la migración:

### Fase 1: RabbitMQ RPC (Completado)
Se ha reemplazado `RestTemplate` por el patrón **Request-Reply** de RabbitMQ.
- `cita_service` envía mensajes RPC a las colas `mediqueue.paciente.validation` y `mediqueue.doctor.validation`.
- Los servicios correspondientes procesan la validación y responden de forma síncrona a través del broker.
- **Estado:** Implementado en `AppointmentService`, `PatientRpcConsumer` y `DoctorRpcConsumer`.

### Fase 2: Replicación de Datos (Recomendado)
Implementar **Proyecciones de Datos** en `cita_service`.
- `cita_service` mantiene una tabla local (caché) con los IDs de pacientes y horarios.
- Los servicios de origen publican eventos (`PATIENT_CREATED`, `SCHEDULE_UPDATED`).
- `cita_service` consume estos eventos y actualiza su copia local.
- **Ventaja:** Máxima disponibilidad y velocidad. Las validaciones son consultas a la base de datos local.

---

## 3. Ejemplo de Implementación (Fase 1: RPC)

### En el Cliente (`cita_service`):
```java
// Sustitución en AppointmentService
public void validatePatient(String patientId) {
    PatientValidationRequest request = new PatientValidationRequest(patientId);
    Boolean exists = rabbitTemplate.convertSendAndReceive(
        "query.exchange", 
        "patient.validate.key", 
        request
    );
    if (!Boolean.TRUE.equals(exists)) {
        throw new InvalidAppointmentException("Paciente no existe");
    }
}
```

### En el Servidor (`paciente_service`):
```java
@RabbitListener(queues = "patient.validation.queue")
public Boolean handleValidation(PatientValidationRequest request) {
    return pacienteService.exists(request.getPatientId());
}
```

---

## 4. Estado de la Implementación
1. [x] Definir DTOs de validación en todos los servicios.
2. [x] Configurar Exchange RPC (`mediqueue.rpc.exchange`) y colas de validación.
3. [x] Implementar `PatientRpcConsumer` en `paciente_service`.
4. [x] Implementar `DoctorRpcConsumer` en `doctor_horario`.
5. [x] Refactorizar `AppointmentService` para usar `RabbitTemplate.convertSendAndReceive`.

## 5. Recomendación Final
Aunque la Fase 1 soluciona el uso de REST, el sistema sigue teniendo acoplamiento temporal (si el broker falla o el servicio destino está saturado, la cita falla). Se recomienda encarecidamente proceder con la **Fase 2 (Replicación de Datos)** para lograr una arquitectura puramente reactiva y altamente disponible.
