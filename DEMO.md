# MediQueue demo operativa

Esta guia muestra que el proyecto cumple la demo academica: servicios activos, endpoints, PostgreSQL, Redis, RabbitMQ, Docker, Prometheus/Grafana y pendientes.

## 1. Levantar plataforma

Si ya existian volumenes antiguos, reinicia limpio para crear `pacientedb`, `doctordb`, `citadb` y `pagodb`.

```powershell
docker compose down -v
docker compose up --build
```

Para simular varias replicas con Docker Compose normal:

```powershell
docker compose up --build --scale paciente_service=2 --scale doctor_horario=2 --scale cita_service=2
```

Ver contenedores:

```powershell
docker compose ps
```

## 2. Healthchecks y endpoints que responden

```powershell
curl http://localhost:8080/actuator/health
curl http://localhost:8080/api/pacientes
curl http://localhost:8080/api/horarios
curl http://localhost:8080/api/v1/appointments
curl http://localhost:8080/api/payments
curl http://localhost:8080/api/notificaciones
```

## 3. Crear datos por el API Gateway

Crear paciente:

```powershell
curl -X POST http://localhost:8080/api/pacientes `
  -H "Content-Type: application/json" `
  -d '{"dpi":"1234567890101","correo":"ana.demo@mediqueue.com","nombre":"Ana Demo","telefono":"55550000"}'
```

Crear horario de doctor:

```powershell
curl -X POST http://localhost:8080/api/horarios `
  -H "Content-Type: application/json" `
  -d '{"doctorId":1,"diaSemana":"MONDAY","horaInicio":"08:00:00","horaFin":"12:00:00","disponible":true}'
```

Consultar disponibilidad, usando Redis:

```powershell
curl "http://localhost:8080/api/v1/appointments/availability?doctorId=1&appointmentDate=2030-05-13T09:00:00"
docker compose exec redis redis-cli KEYS "*appointmentAvailability*"
```

Crear cita idempotente:

```powershell
curl -X POST http://localhost:8080/api/v1/appointments `
  -H "Content-Type: application/json" `
  -H "Idempotency-Key: cita-demo-001" `
  -d '{"patientId":"1","doctorId":"1","appointmentDate":"2030-05-13T09:00:00"}'
```

Repetir el mismo comando debe devolver la misma cita, no crear otra.

Procesar pago idempotente, reemplazando `appointmentId` por el UUID devuelto al crear cita:

```powershell
curl -X POST http://localhost:8080/api/payments `
  -H "Content-Type: application/json" `
  -H "Idempotency-Key: pago-demo-001" `
  -d '{"appointmentId":"PEGAR_UUID_CITA","patientId":"1","amount":125.50}'
```

Repetir el mismo pago con la misma clave debe devolver el mismo pago, no duplicarlo.

## 4. Evidencia PostgreSQL

```powershell
docker compose exec postgres psql -U mediqueue -d pacientedb -c "select * from pacientes;"
docker compose exec postgres psql -U mediqueue -d doctordb -c "select * from doctor_horarios;"
docker compose exec postgres psql -U mediqueue -d citadb -c "select id, patient_id, doctor_id, status, idempotency_key from appointments;"
docker compose exec postgres psql -U mediqueue -d pagodb -c "select id, appointment_id, patient_id, status, idempotency_key from payments;"
docker compose exec postgres psql -U mediqueue -d citadb -c "select event_type, status, attempts from outbox_events;"
docker compose exec postgres psql -U mediqueue -d pagodb -c "select event_type, status, attempts from outbox_events;"
```

## 5. Evidencia RabbitMQ

Abrir:

```text
http://localhost:15672
usuario: mediqueue
password: mediqueue123
```

Colas esperadas:

```text
mediqueue.appointments.created
mediqueue.appointments.cancelled
mediqueue.payments.success
mediqueue.payments.failed
*.dlq
```

Consultar notificaciones generadas por consumidores RabbitMQ:

```powershell
curl http://localhost:8080/api/notificaciones
```

## 6. Evidencia Redis

```powershell
docker compose exec redis redis-cli PING
docker compose exec redis redis-cli KEYS "*appointmentAvailability*"
```

Prueba de degradacion:

```powershell
docker compose restart redis
curl "http://localhost:8080/api/v1/appointments/availability?doctorId=1&appointmentDate=2030-05-13T10:00:00"
```

La consulta debe seguir respondiendo aunque Redis se reinicie; solo se pierde el cache temporal.

## 7. Evidencia Prometheus y Grafana

Prometheus:

```text
http://localhost:9090/targets
```

Targets esperados: `api_gateway`, `paciente_service`, `doctor_horario`, `cita_service`, `pago_service`, `notificacion_service`.

Grafana:

```text
http://localhost:3000
usuario: admin
password: admin123
```

Si no hay dashboards provisionados, usar Explore con Prometheus y consultar:

```text
up
http_server_requests_seconds_count
jvm_memory_used_bytes
```

## 8. Caos controlado

Matar un servicio:

```powershell
docker compose kill cita_service
docker compose ps
```

Con `restart: unless-stopped`, Docker lo levanta si el proceso termina por fallo/reinicio. Si se usa `kill`, puede requerir:

```powershell
docker compose up -d cita_service
```

Simular consumidor caido:

```powershell
docker compose stop notificacion_service
```

Crear cita o pago. El evento queda en outbox y/o cola durable. Luego:

```powershell
docker compose start notificacion_service
curl http://localhost:8080/api/notificaciones
```

## 9. Pendientes tecnicos para entrega final

- Reemplazar `ddl-auto=update` por migraciones Flyway/Liquibase.
- Agregar dashboards Grafana versionados.
- Agregar circuit breaker formal con Resilience4j para llamadas REST desde `cita_service`.
- Agregar pruebas de concurrencia para idempotencia de citas y pagos.
- Evitar `deploy.replicas` como prueba de HA en Compose normal; documentar recuperacion manual y `--scale` local cuando aplique.
- Persistir notificaciones en base propia si se requiere auditoria, porque hoy son memoria del contenedor.
