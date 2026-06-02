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

## Reglas de negocio

- Paciente unico por DPI.
- Especialidades con precio de consulta: Medicina General Q150, Pediatria Q180, Ginecologia Q220, Cardiologia Q300 y Dermatologia Q200.
- Citas con duracion valida de 20 a 30 minutos.
- Disponibilidad por agenda real del doctor y por traslape con citas activas.
- La cita se crea `PENDING`; el pago exacto confirma la cita como `CONFIRMED`.
- Cancelacion permitida solo con 48 horas o mas de anticipacion.
