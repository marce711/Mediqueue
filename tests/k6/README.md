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
