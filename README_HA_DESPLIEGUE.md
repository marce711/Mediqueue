# GUÍA DE DESPLIEGUE EN ALTA DISPONIBILIDAD (HA) - MEDIQUEUE

Esta arquitectura está diseñada para sobrevivir a la caída de una computadora completa de las 3 disponibles.

## 1. Preparación de Red (Tailscale)
Asegurarse de que las 3 computadoras tengan Tailscale instalado y se vean entre sí.
En este ejemplo usamos las siguientes IPs (DEBES REEMPLAZARLAS EN LOS ARCHIVOS .yml):
- **Nodo 1 (Computadora A):** 100.76.170.62
- **Nodo 2 (Computadora B):** 100.115.210.113
- **Nodo 3 (Computadora C):** 100.99.158.111

## 2. Archivos de Despliegue
He creado 3 archivos Docker Compose específicos:
- `docker-compose-node1.yml` -> Ejecutar en Computadora A
- `docker-compose-node2.yml` -> Ejecutar en Computadora B
- `docker-compose-node3.yml` -> Ejecutar en Computadora C

Cada archivo levanta el plano de aplicacion completo: frontend, api-gateway,
paciente-service, cita-service, doctor-horario, pago-service,
notificacion-service, RabbitMQ, Redis/Sentinel, PostgreSQL/Patroni, HAProxy y
pgAdmin. Esto permite entrar por cualquier nodo disponible.

## 3. Pasos para iniciar el Clúster
1. **Paso 1: Levantar etcd (El cerebro)**
   En las 3 máquinas, ejecutar primero solo el servicio etcd:
   `docker compose -f docker-compose-nodeX.yml up -d etcd`
   Verificar que se vean: `docker exec etcd etcdctl member list`

2. **Paso 2: Levantar Infraestructura Crítica**
   Levantar RabbitMQ, Redis y Postgres en todas:
   `docker compose -f docker-compose-nodeX.yml up -d rabbitmq redis redis-sentinel postgresX haproxy`

3. **Paso 3: Levantar Microservicios**
   `docker compose -f docker-compose-nodeX.yml up -d`

URLs principales:
- Frontend nodo A: `http://100.76.170.62/`
- Frontend nodo B: `http://100.115.210.113/`
- Frontend nodo C: `http://100.99.158.111/`
- Gateway de cada nodo: `http://<IP_NODO>:8080`
- Estado Patroni: `http://<IP_NODO>:8008/cluster`
- Estado HAProxy: `http://<IP_NODO>:7000`
- pgAdmin: `http://<IP_NODO>:5050`

## 4. Pruebas de Resiliencia (Demo)
- **Cierre de una PC:** Apaga la Computadora A. Entra por `http://100.115.210.113/` o `http://100.99.158.111/`. El gateway de esos nodos tiene listas de fallback hacia los servicios locales y remotos, y la base escribe por HAProxy al líder Patroni disponible.
- **Matar Postgres Master:** Patroni promoverá una réplica en < 10 segundos. HAProxy detectará el cambio automáticamente.
- **Corte de RabbitMQ:** Spring Boot tiene configuradas las 3 IPs, por lo que se reconectará al siguiente nodo disponible.

## 5. pgAdmin
pgAdmin se levanta por defecto en los tres compose:

- URL: `http://<IP_NODO>:5050`
- Login: `admin@mediqueue.com`
- Password: `admin123`

Al agregar el servidor dentro de pgAdmin:

- Name: `Mediqueue HA`
- Host name/address: `haproxy`
- Port: `5432`
- Maintenance database: `mediqueueadmin`
- Username: `mediqueue`
- Password: `mediqueue123`

Si usa un pgAdmin externo al compose, use como host la IP Tailscale de
cualquier nodo y el puerto `5000`, por ejemplo `100.115.210.113:5000`.

## 6. Reglas de Negocio Implementadas
- Pacientes: el DPI es único; un segundo registro con el mismo DPI devuelve conflicto.
- Doctores: se registran con especialidad y horarios.
- Especialidades: el dropdown se alimenta de `especialidades` y cada una tiene `precio_consulta`.
- Citas: solo admiten duraciones de 20 a 30 minutos.
- Disponibilidad: se valida que el doctor atienda el día/hora solicitados y que no exista traslape con otra cita activa.
- Flujo de pago: la cita se crea como `PENDING`; al pagar el monto exacto del precio de la especialidad, el pago queda `SUCCESS` y la cita pasa a `CONFIRMED`.
- Cancelación: una cita solo puede cancelarse con al menos 48 horas de anticipación.

## 7. Backups y Pruebas de Restauración

Aunque una computadora no sea líder de Patroni, puede hacer backup y pruebas de
restauración usando su HAProxy local. No use `localhost:5432` directamente para
restaurar si el nodo local es réplica; use `haproxy:5432` desde Docker o
`localhost:5000` desde el host.

### 7.1 Seleccionar variables por computadora

En cada computadora ejecute solo el bloque que le corresponde:

```powershell
# Computadora A / Nodo 1
$compose = "docker-compose-node1.yml"
$pgService = "postgres1"
```

```powershell
# Computadora B / Nodo 2
$compose = "docker-compose-node2.yml"
$pgService = "postgres2"
```

```powershell
# Computadora C / Nodo 3
$compose = "docker-compose-node3.yml"
$pgService = "postgres3"
```

### 7.2 Verificar rol del nodo y conexión al líder

```powershell
curl.exe --noproxy "*" http://localhost:8008/cluster

docker compose -f $compose exec -T -e PGPASSWORD=mediqueue123 $pgService `
  psql -h localhost -p 5432 -U postgres -d mediqueueadmin `
  -c "select pg_is_in_recovery() as nodo_local_es_replica;"

docker compose -f $compose exec -T -e PGPASSWORD=mediqueue123 $pgService `
  psql -h haproxy -p 5432 -U postgres -d mediqueueadmin `
  -c "select pg_is_in_recovery() as conexion_por_haproxy_es_replica;"
```

El resultado esperado por HAProxy para escritura es `false`, porque HAProxy debe
enviar al líder actual aunque el nodo local sea réplica.

### 7.3 Generar backup lógico

```powershell
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupName = "mediqueue_full_$timestamp.sql"
$backupPath = "backups\$backupName"

New-Item -ItemType Directory -Force backups | Out-Null

docker compose -f $compose exec -T -e PGPASSWORD=mediqueue123 $pgService `
  pg_dump -h haproxy -p 5432 -U postgres -d mediqueueadmin `
  --clean --if-exists -f "/tmp/$backupName"

docker compose -f $compose cp "${pgService}:/tmp/$backupName" $backupPath
docker compose -f $compose exec -T $pgService sh -lc "rm -f /tmp/$backupName"

Get-Item $backupPath
Get-FileHash -Algorithm SHA256 $backupPath
```

### 7.4 Probar restauración sin tocar producción

Esta prueba crea una base temporal, restaura el backup, valida que cargue sin
errores y luego borra la base temporal. No restaure pruebas sobre
`mediqueueadmin`.

```powershell
$testDb = "mediqueue_restore_verify_$timestamp"

docker compose -f $compose exec -T -e PGPASSWORD=mediqueue123 $pgService `
  psql -h haproxy -p 5432 -U postgres -d postgres `
  -v ON_ERROR_STOP=1 -c "CREATE DATABASE $testDb OWNER mediqueue;"

docker compose -f $compose cp $backupPath "${pgService}:/tmp/$backupName"

docker compose -f $compose exec -T -e PGPASSWORD=mediqueue123 $pgService `
  psql -h haproxy -p 5432 -U postgres -d $testDb `
  -v ON_ERROR_STOP=1 -f "/tmp/$backupName"

docker compose -f $compose exec -T -e PGPASSWORD=mediqueue123 $pgService `
  psql -h haproxy -p 5432 -U postgres -d $testDb `
  -c "\dt"

docker compose -f $compose exec -T -e PGPASSWORD=mediqueue123 $pgService `
  psql -h haproxy -p 5432 -U postgres -d $testDb -At -F "|" `
  -c "select 'appointments', count(*) from public.appointments union all select 'doctores', count(*) from public.doctores union all select 'especialidades', count(*) from public.especialidades union all select 'horarios', count(*) from public.horarios union all select 'pacientes', count(*) from public.pacientes union all select 'payments', count(*) from public.payments order by 1;"

docker compose -f $compose exec -T -e PGPASSWORD=mediqueue123 $pgService `
  psql -h haproxy -p 5432 -U postgres -d postgres `
  -v ON_ERROR_STOP=1 -c "DROP DATABASE $testDb WITH (FORCE);"

docker compose -f $compose exec -T $pgService sh -lc "rm -f /tmp/$backupName"
```

La prueba es válida si el comando de restauración termina sin errores, `\dt`
muestra las tablas esperadas (`appointments`, `pacientes`, `doctores`,
`especialidades`, `horarios`, `payments`, entre otras) y los conteos coinciden
con lo esperado para ese backup.

### 7.5 Verificación realizada

El backup `backups/mediqueue_full_20260602_144151.sql` fue verificado el
2026-06-02 desde la Computadora B:

- `postgres2` estaba como réplica.
- El líder Patroni era `postgres1`.
- La conexión por `haproxy:5432` llegó al líder.
- El archivo tiene 101004 bytes y hash SHA256
  `0A1D545F4E68FD360B07EBB36FC9B96BFDD4A0FF66FE3CE477D378E299FDEF43`.
- La restauración en base temporal finalizó sin errores.
- Los conteos restaurados coincidieron con producción: `appointments=12`,
  `doctores=7`, `especialidades=18`, `horarios=26`, `outbox_events=27`,
  `pacientes=7`, `payments=9`, y las tablas vacías esperadas quedaron en 0.

## 8. Pruebas de Estrés con k6, Prometheus y Grafana

Los scripts de k6 están en `tests/k6`. Cada iteración ejecuta una solicitud
HTTP, por lo que los perfiles generan la cantidad indicada:

- `tests/k6/stress-5000.js`: 5000 solicitudes.
- `tests/k6/stress-10000.js`: 10000 solicitudes.
- `tests/k6/stress-15000.js`: 15000 solicitudes.
- `tests/k6/stress-20000.js`: 20000 solicitudes.

Por defecto, la carga es 95% lectura y 5% escritura en `POST /api/pacientes`
con DPI/correo únicos. Para no insertar datos durante la prueba, use
`-e WRITE_RATIO=0`.

### 8.1 Levantar observabilidad

Prometheus y Grafana están definidos en `docker-compose-node1.yml`, por lo que
deben levantarse en la Computadora A / Nodo 1:

```powershell
docker compose -f docker-compose-node1.yml up -d --force-recreate prometheus grafana
```

URLs:

- Prometheus: `http://100.76.170.62:9090`
- Targets de Prometheus: `http://100.76.170.62:9090/targets`
- Grafana: `http://100.76.170.62:3000`
- Grafana login: `admin` / `admin123`
- Dashboard provisionado: `Mediqueue > Mediqueue Performance`

Prometheus scrapea los endpoints `/actuator/prometheus` de los servicios en los
tres nodos. Además queda habilitado para recibir métricas de k6 por remote
write en `http://100.76.170.62:9090/api/v1/write`.

### 8.2 Verificar que Prometheus vea los servicios

Desde cualquier computadora:

```powershell
curl.exe --noproxy "*" http://100.76.170.62:9090/-/ready
curl.exe --noproxy "*" "http://100.76.170.62:9090/api/v1/query?query=up"
```

En `http://100.76.170.62:9090/targets`, los targets de `api_gateway`,
`paciente_service`, `cita_service`, `doctor_horario`, `pago_service` y
`notificacion_service` deben aparecer en estado `UP`.

### 8.3 Instalar k6

Opción recomendada en Windows:

```powershell
winget install k6.k6
k6 version
```

Si no puede instalar k6 en el host, puede usar Docker:

```powershell
docker run --rm -v "${PWD}:/workspace" -w /workspace grafana/k6 version
```

### 8.4 Seleccionar el gateway objetivo

Puede probar contra cualquier gateway disponible:

```powershell
# Nodo 1
$baseUrl = "http://100.76.170.62:8080"

# Nodo 2
$baseUrl = "http://100.115.210.113:8080"

# Nodo 3
$baseUrl = "http://100.99.158.111:8080"
```

Para probar el gateway de la misma computadora también puede usar
`http://localhost:8080`.

### 8.5 Ejecutar la progresión 5000 -> 20000

Ejecute una corrida a la vez y espere 2 a 5 minutos entre corridas para observar
recuperación de latencia, errores, CPU, memoria y throughput.

```powershell
$env:K6_PROMETHEUS_RW_SERVER_URL = "http://100.76.170.62:9090/api/v1/write"
$env:K6_PROMETHEUS_RW_TREND_STATS = "p(95),p(99),avg,min,max"

k6 run -o experimental-prometheus-rw --tag testid=stress-5000 `
  -e PROFILE=stress-5000 -e BASE_URL=$baseUrl `
  tests/k6/stress-5000.js

k6 run -o experimental-prometheus-rw --tag testid=stress-10000 `
  -e PROFILE=stress-10000 -e BASE_URL=$baseUrl `
  tests/k6/stress-10000.js

k6 run -o experimental-prometheus-rw --tag testid=stress-15000 `
  -e PROFILE=stress-15000 -e BASE_URL=$baseUrl `
  tests/k6/stress-15000.js

k6 run -o experimental-prometheus-rw --tag testid=stress-20000 `
  -e PROFILE=stress-20000 -e BASE_URL=$baseUrl `
  tests/k6/stress-20000.js
```

Si usa Docker para ejecutar k6:

```powershell
$env:K6_PROMETHEUS_RW_SERVER_URL = "http://100.76.170.62:9090/api/v1/write"
$env:K6_PROMETHEUS_RW_TREND_STATS = "p(95),p(99),avg,min,max"

docker run --rm -v "${PWD}:/workspace" -w /workspace `
  -e K6_PROMETHEUS_RW_SERVER_URL=$env:K6_PROMETHEUS_RW_SERVER_URL `
  -e K6_PROMETHEUS_RW_TREND_STATS=$env:K6_PROMETHEUS_RW_TREND_STATS `
  grafana/k6 run -o experimental-prometheus-rw `
  --tag testid=stress-5000 `
  -e PROFILE=stress-5000 -e BASE_URL=$baseUrl `
  tests/k6/stress-5000.js
```

Repita el mismo comando cambiando el archivo y `testid` a `stress-10000`,
`stress-15000` y `stress-20000`.

### 8.6 Variables para ajustar la prueba

- `BASE_URL`: gateway objetivo.
- `VUS`: usuarios virtuales. Defaults: 100, 200, 300 y 400 según perfil.
- `TARGET_REQUESTS`: sobrescribe el total de solicitudes del perfil.
- `MAX_DURATION`: duración máxima. Default: `20m`.
- `WRITE_RATIO`: proporción de escrituras. Default: `0.05`.
- `THINK_TIME_SECONDS`: pausa entre iteraciones. Default: `0`.
- `TEST_ID`: etiqueta para filtrar una corrida específica en Grafana.

Ejemplo de 20000 solicitudes solo lectura con menos VUs:

```powershell
k6 run -o experimental-prometheus-rw --tag testid=stress-20000-readonly `
  -e PROFILE=stress-20000-readonly `
  -e BASE_URL=$baseUrl `
  -e WRITE_RATIO=0 `
  -e VUS=250 `
  tests/k6/stress-20000.js
```

### 8.7 Métricas a observar

En Grafana, abra `Mediqueue > Mediqueue Performance` y revise:

- `k6 Throughput`: solicitudes por segundo generadas por k6.
- `k6 Latency`: latencia p95/p99 de k6.
- `k6 Failure Rate`: tasa de errores vista por k6.
- `k6 Requests by Endpoint`: distribución por endpoint.
- `Spring Request Rate by Service`: tráfico recibido por cada microservicio.
- `Spring Avg HTTP Duration`: duración promedio por servicio y nodo.
- `JVM Heap Used`: memoria heap usada por servicio.
- `Prometheus Targets`: targets `UP/DOWN`.

Consultas PromQL útiles:

```promql
sum(rate(k6_http_reqs_total[1m]))
max(k6_http_req_failed_rate)
max(k6_http_req_duration_p95)
sum(rate(http_server_requests_seconds_count[1m])) by (application, node)
sum(rate(http_server_requests_seconds_sum[1m])) by (application, node)
  / sum(rate(http_server_requests_seconds_count[1m])) by (application, node)
sum(jvm_memory_used_bytes{area="heap"}) by (application, node)
```

### 8.8 Criterios prácticos de evaluación

- `http_req_failed` debe mantenerse idealmente por debajo de 1%; arriba de 5%
  ya indica degradación seria.
- p95 menor a 1 segundo es saludable para lecturas; p95 sobre 3 segundos indica
  saturación para esta demo.
- Si k6 muestra errores pero Prometheus targets siguen `UP`, revise logs del
  gateway y circuit breakers.
- Si sube latencia en todos los servicios al mismo tiempo, revise PostgreSQL,
  RabbitMQ y red Tailscale.
- Si solo sube un servicio, revise el endpoint dominante en `k6 Requests by
  Endpoint` y el panel de ese microservicio.

No ejecute los perfiles en las tres computadoras al mismo tiempo salvo que
quiera una prueba distribuida. Si ejecuta `stress-20000.js` simultáneamente en
las tres, la carga total será de 60000 solicitudes.

## 9. Notas Importantes
- **Quorum Queues:** Las colas de RabbitMQ deben definirse como tipo 'quorum' en el código Java para que se repliquen.
- **Resilience4j:** Los microservicios ahora tienen Circuit Breakers para evitar que fallos en cascada tumben el sistema.
- **HAProxy Local:** Cada nodo tiene su HAProxy local apuntando a los 3 nodos de DB. Los microservicios se conectan a `haproxy:5432` dentro de Docker; desde el host use `localhost:5000` para escritura.
