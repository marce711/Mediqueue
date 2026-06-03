# Pruebas de estres k6 - Mediqueue

Estos scripts generan carga contra el API Gateway de Mediqueue. Cada iteracion
ejecuta una solicitud HTTP, por lo que `stress-5000.js` ejecuta 5000
solicitudes, `stress-10000.js` ejecuta 10000, etc.

## Archivos

- `stress-5000.js`: 5000 solicitudes, 100 VUs por defecto.
- `stress-10000.js`: 10000 solicitudes, 200 VUs por defecto.
- `stress-15000.js`: 15000 solicitudes, 300 VUs por defecto.
- `stress-20000.js`: 20000 solicitudes, 400 VUs por defecto.
- `mediqueue-scenario.js`: escenario comun reutilizado por los perfiles.
- `results/`: salida JSON resumida por ejecucion.

## Variables utiles

- `BASE_URL`: gateway objetivo. Default: `http://localhost:8080`.
- `TARGET_REQUESTS`: sobrescribe la cantidad de solicitudes del perfil.
- `VUS`: sobrescribe usuarios virtuales.
- `MAX_DURATION`: tiempo maximo de prueba. Default: `20m`.
- `WRITE_RATIO`: porcentaje decimal de escrituras `POST /api/pacientes`.
  Default: `0.05` (5%).
- `THINK_TIME_SECONDS`: pausa opcional entre iteraciones. Default: `0`.
- `RUN_ID`: identificador usado para datos unicos de pacientes.
- `TEST_ID`: etiqueta para filtrar la corrida en Prometheus/Grafana.
- `P95_THRESHOLD_MS`: umbral p95 para `http_req_duration`. Default: `3000`.
- `P99_THRESHOLD_MS`: umbral p99 para `http_req_duration`. Default: `6000`.
- `DISABLE_LATENCY_THRESHOLDS`: use `true` para no fallar la corrida por
  latencia durante pruebas exploratorias.
- `ENDPOINT_SET`: filtra endpoints para aislar cuellos. Valores utiles:
  `all`, `no-doctor`, `doctor-only`, `paciente-only`, `cita-only`,
  `pago-only`, `notificacion-only`.
- `REQUEST_TIMEOUT`: timeout por solicitud, por ejemplo `10s` o `30s`.

## Ejecucion local sin Prometheus

```powershell
k6 run -e BASE_URL=http://100.115.210.113:8080 tests/k6/stress-5000.js
```

## Ejecucion con Prometheus remote write

Prometheus debe estar levantado con `--web.enable-remote-write-receiver`.

```powershell
$env:K6_PROMETHEUS_RW_SERVER_URL="http://100.76.170.62:9090/api/v1/write"
$env:K6_PROMETHEUS_RW_TREND_STATS="p(95),p(99),avg,min,max"

k6 run -o experimental-prometheus-rw `
  --tag testid=stress-5000-$(Get-Date -Format yyyyMMddHHmmss) `
  -e BASE_URL=http://100.115.210.113:8080 `
  tests/k6/stress-5000.js
```

## Escalamiento recomendado

Ejecute una prueba a la vez y deje 2 a 5 minutos entre corridas para observar
recuperacion de latencias, CPU, memoria y errores.

```powershell
k6 run -o experimental-prometheus-rw --tag testid=stress-5000  -e BASE_URL=http://100.115.210.113:8080 tests/k6/stress-5000.js
k6 run -o experimental-prometheus-rw --tag testid=stress-10000 -e BASE_URL=http://100.115.210.113:8080 tests/k6/stress-10000.js
k6 run -o experimental-prometheus-rw --tag testid=stress-15000 -e BASE_URL=http://100.115.210.113:8080 tests/k6/stress-15000.js
k6 run -o experimental-prometheus-rw --tag testid=stress-20000 -e BASE_URL=http://100.115.210.113:8080 tests/k6/stress-20000.js
```

Para una prueba solo lectura:

```powershell
k6 run -e WRITE_RATIO=0 -e BASE_URL=http://100.115.210.113:8080 tests/k6/stress-20000.js
```

## Diagnosticar timeouts en /api/horarios

Si aparecen timeouts como:

```text
Get "http://100.76.170.62:8080/api/horarios": request timeout
Get "http://100.76.170.62:8080/api/horarios/doctores": request timeout
Get "http://100.76.170.62:8080/api/horarios/especialidades": request timeout
```

primero aisle si el cuello esta en `doctor-horario`.

Prueba sin endpoints de doctor:

```powershell
docker compose -f $compose --profile tools run --rm k6 `
  run -o experimental-prometheus-rw `
  --tag testid=stress-10000-no-doctor `
  -e BASE_URL=$baseUrl `
  -e ENDPOINT_SET=no-doctor `
  -e DISABLE_LATENCY_THRESHOLDS=true `
  tests/k6/stress-10000.js
```

Prueba solo endpoints de doctor por el gateway:

```powershell
docker compose -f $compose --profile tools run --rm k6 `
  run -o experimental-prometheus-rw `
  --tag testid=stress-10000-doctor-gateway `
  -e BASE_URL=$baseUrl `
  -e ENDPOINT_SET=doctor-only `
  -e DISABLE_LATENCY_THRESHOLDS=true `
  tests/k6/stress-10000.js
```

Prueba solo endpoints de doctor directo al microservicio del Nodo A:

```powershell
docker compose -f $compose --profile tools run --rm k6 `
  run -o experimental-prometheus-rw `
  --tag testid=stress-10000-doctor-direct `
  -e BASE_URL=http://100.76.170.62:8082 `
  -e ENDPOINT_SET=doctor-only `
  -e DISABLE_LATENCY_THRESHOLDS=true `
  tests/k6/stress-10000.js
```

Interpretacion rapida:

- Si `no-doctor` pasa y `doctor-only` falla, el cuello esta en
  `doctor-horario` o sus consultas a PostgreSQL.
- Si `doctor-direct` pasa pero `doctor-gateway` falla, revise el API Gateway.
- Si `doctor-direct` tambien falla, revise `doctor-horario`, pool JDBC,
  consultas SQL y PostgreSQL.

## Interpretar "thresholds crossed"

Si k6 termina con algo como:

```text
Requests: 5000
Failures: 0.00%
Duration p95: 4623.63 ms
thresholds on metrics 'http_req_duration' have been crossed
```

La prueba si ejecuto todas las solicitudes. El error significa que la latencia
p95 supero el umbral configurado, no que Docker o k6 fallaran. Para continuar
la prueba exploratoria sin cortar por latencia:

```powershell
docker compose -f $compose --profile tools run --rm k6 `
  run -o experimental-prometheus-rw `
  --tag testid=stress-5000-exploratory `
  -e BASE_URL=$baseUrl `
  -e DISABLE_LATENCY_THRESHOLDS=true `
  tests/k6/stress-5000.js
```

Para mantener umbrales pero ajustarlos a esta infraestructura:

```powershell
docker compose -f $compose --profile tools run --rm k6 `
  run -o experimental-prometheus-rw `
  --tag testid=stress-5000-p95-5s `
  -e BASE_URL=$baseUrl `
  -e P95_THRESHOLD_MS=5000 `
  -e P99_THRESHOLD_MS=9000 `
  tests/k6/stress-5000.js
```
