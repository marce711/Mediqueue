# Guia de alta disponibilidad - Mediqueue

El despliegue objetivo usa Docker Compose en 3 maquinas independientes. No usa orquestador externo.

## Nodos

- Nodo 1: `100.76.170.62`, plano de aplicacion completo, PostgreSQL/Patroni, HAProxy, RabbitMQ, Redis Sentinel y pgAdmin.
- Nodo 2: `100.115.210.113`, plano de aplicacion completo, PostgreSQL/Patroni, HAProxy, RabbitMQ, Redis Sentinel y pgAdmin.
- Nodo 3: `100.99.158.111`, plano de aplicacion completo, PostgreSQL/Patroni, HAProxy, RabbitMQ, Redis Sentinel y pgAdmin.

## Base de datos HA

PostgreSQL se administra con Patroni y etcd. Cada maquina levanta un nodo Postgres y un HAProxy local:

- Escritura desde contenedores: `jdbc:postgresql://haproxy:5432/mediqueueadmin`
- Escritura desde la maquina host: `localhost:5000`
- Lectura desde la maquina host: `localhost:5001`
- Estado HAProxy: `http://localhost:7000`
- Estado Patroni del nodo: `http://localhost:8008/cluster`

El primer lider de Patroni crea automaticamente:

- Base: `mediqueueadmin`
- Usuario: `mediqueue`
- Password: `mediqueue123`
- Extension: `pgcrypto`

Si los volumenes ya existian antes de este cambio, esa inicializacion no se vuelve a ejecutar. En ese caso cree la base y el usuario manualmente o reinicialice el cluster de forma controlada.

## Ejecucion

Ejecute en cada maquina el compose correspondiente:

```bash
docker compose -f docker-compose-node1.yml up -d --build
docker compose -f docker-compose-node2.yml up -d --build
docker compose -f docker-compose-node3.yml up -d --build
```

## Estado de la base de datos

Ver lider y replicas:

```bash
curl http://localhost:8008/cluster
```

Ver salud de HAProxy:

```bash
curl http://localhost:7000
```

Probar conexion por HAProxy:

```bash
docker compose -f docker-compose-node1.yml exec postgres1 psql -U postgres -d mediqueueadmin -c "select current_database(), current_user, now();"
```

Listar tablas principales:

```bash
docker compose -f docker-compose-node1.yml exec postgres1 psql -U postgres -d mediqueueadmin -c "\dt"
```

## Acceso a la aplicacion

Use cualquier frontend disponible:

- Nodo 1: `http://100.76.170.62/`
- Nodo 2: `http://100.115.210.113/`
- Nodo 3: `http://100.99.158.111/`

Cada gateway (`http://<IP_NODO>:8080`) tiene URLs de fallback hacia servicios
locales y remotos. Si el nodo A se apaga, entre por el frontend del nodo B o C.

## pgAdmin

pgAdmin se levanta por defecto en cada compose:

- URL: `http://<IP_NODO>:5050`
- Login: `admin@mediqueue.com`
- Password: `admin123`

En pgAdmin agregue un servidor:

- Name: `Mediqueue HA`
- Host name/address: `haproxy`
- Port: `5432`
- Maintenance database: `mediqueueadmin`
- Username: `mediqueue`
- Password: `mediqueue123`

Si usa un pgAdmin externo al compose, use como host la IP de cualquier maquina
con HAProxy, por ejemplo `100.115.210.113`, y puerto `5000`.

Para ver registros: `Servers > Mediqueue HA > Databases > mediqueueadmin > Schemas > public > Tables`, clic derecho sobre una tabla y `View/Edit Data`.

## Resiliencia sin orquestador

Docker Compose no reubica automaticamente contenedores entre maquinas cuando una computadora se apaga. La disponibilidad ante caida de una maquina se consigue con estos puntos:

- La base de datos sigue disponible si queda quorum de etcd/Patroni y al menos un nodo Postgres sano.
- Los tres compose levantan frontend, gateway y microservicios principales, por lo que puede entrar por otro nodo sin esperar a reubicar contenedores.
- El gateway intenta primero el servicio local y despues las IPs remotas definidas en `*_SERVICE_URLS`.
- RabbitMQ debe conservar el cluster y las colas durables para no perder eventos publicados.

Para cumplir la prueba de apagar una computadora sin orquestador externo, mantenga los tres compose arriba antes de la demo y use la URL del nodo que siga disponible.

## Recuperacion si alguien ejecuto `down -v`

`down -v` borra volumenes. Si se ejecuta en algun nodo, lo primero es
recuperar quorum de etcd y asegurar que el nodo con datos sea el primero que
toma el liderazgo de Patroni. No intente restaurar datos mientras HAProxy no
tenga un backend de escritura activo.

Estado de falla tipico:

- `curl http://localhost:2379/health` devuelve `RAFT NO LEADER`.
- `curl http://localhost:8008/primary` devuelve `503`.
- HAProxy muestra `postgres_write` sin servidores disponibles.
- Los microservicios fallan con errores JDBC contra `haproxy:5432`.

Recuperacion recomendada si el nodo B conserva datos:

1. En las tres maquinas, detener aplicacion y Postgres. No usar `-v`.

```powershell
# PC A
docker compose -f docker-compose-node1.yml stop frontend api-gateway paciente-service cita-service doctor-horario pago-service notificacion-service postgres1

# PC B
docker compose -f docker-compose-node2.yml stop frontend api-gateway paciente-service cita-service doctor-horario pago-service notificacion-service postgres2

# PC C
docker compose -f docker-compose-node3.yml stop frontend api-gateway paciente-service cita-service doctor-horario pago-service notificacion-service postgres3
```

2. En las tres maquinas, recrear solo etcd para recuperar quorum.

```powershell
# PC A
docker compose -f docker-compose-node1.yml up -d --force-recreate etcd

# PC B
docker compose -f docker-compose-node2.yml up -d --force-recreate etcd

# PC C
docker compose -f docker-compose-node3.yml up -d --force-recreate etcd
```

Verificar en al menos dos maquinas:

```powershell
curl --noproxy "*" http://localhost:2379/health
```

Debe responder `{"health":"true"}`.

3. Si quedo un lock viejo apuntando a un nodo caido, eliminar solo el DCS de
Patroni. Esto no borra datos de Postgres.

```powershell
curl --noproxy "*" -X DELETE "http://localhost:2379/v2/keys/db/mediqueue-cluster?recursive=true"
```

4. Levantar primero Postgres del nodo que conserva los datos. En este proyecto,
si B conserva datos, iniciar B antes que A y C.

```powershell
# PC B
docker compose -f docker-compose-node2.yml up -d postgres2 haproxy
curl --noproxy "*" http://localhost:8008/primary
```

El endpoint `/primary` debe responder `200`. Si responde `503`, no seguir con
microservicios todavia.

5. Cuando B sea primario, levantar A y C para que se unan como replicas.

```powershell
# PC A
docker compose -f docker-compose-node1.yml up -d postgres1 haproxy

# PC C
docker compose -f docker-compose-node3.yml up -d postgres3 haproxy
```

6. Levantar todo en las tres maquinas.

```powershell
docker compose -f docker-compose-node1.yml up -d --build
docker compose -f docker-compose-node2.yml up -d --build
docker compose -f docker-compose-node3.yml up -d --build
```

7. Restaurar datos minimos si las tablas quedaron vacias.

```powershell
Get-Content infrastructure/postgres/restore-minimal-data.sql | docker compose -f docker-compose-node2.yml exec -T -e PGPASSWORD=mediqueue123 postgres2 psql -h haproxy -p 5432 -U postgres -d mediqueueadmin -v ON_ERROR_STOP=1
```

Si ejecuta el script desde el host en vez del contenedor:

```powershell
$env:PGPASSWORD="mediqueue123"
psql -h localhost -p 5000 -U postgres -d mediqueueadmin -f infrastructure/postgres/restore-minimal-data.sql
```

El script es idempotente: puede ejecutarse mas de una vez. Restaura
especialidades con precios, un paciente demo, un doctor demo y horarios.

## Reglas de negocio

- Paciente unico por DPI.
- Especialidades con precio de consulta: Medicina General Q150, Pediatria Q180, Ginecologia Q220, Cardiologia Q300 y Dermatologia Q200.
- Citas con duracion valida de 20 a 30 minutos.
- Disponibilidad por agenda real del doctor y por traslape con citas activas.
- La cita se crea `PENDING`; el pago exacto confirma la cita como `CONFIRMED`.
- Cancelacion permitida solo con 48 horas o mas de anticipacion.
