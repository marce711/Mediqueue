# Guia de alta disponibilidad - Mediqueue

El despliegue objetivo usa Docker Compose en 3 maquinas independientes. No usa orquestador externo.

## Nodos

- Nodo 1: `100.76.170.62`, gateway, frontend, paciente-service, PostgreSQL/Patroni, HAProxy, RabbitMQ, Redis Sentinel.
- Nodo 2: `100.115.210.113`, cita-service, doctor-horario, PostgreSQL/Patroni, HAProxy, RabbitMQ, Redis Sentinel.
- Nodo 3: `100.99.158.111`, pago-service, notificacion-service, PostgreSQL/Patroni, HAProxy, RabbitMQ, Redis Sentinel.

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

## pgAdmin

Este despliegue no levanta pgAdmin por defecto. Puede abrirlo como contenedor auxiliar en cualquier maquina:

```bash
docker run -d --name mediqueue-pgadmin -p 5050:80 \
  -e PGADMIN_DEFAULT_EMAIL=admin@mediqueue.local \
  -e PGADMIN_DEFAULT_PASSWORD=admin123 \
  dpage/pgadmin4
```

En pgAdmin agregue un servidor:

- Name: `Mediqueue HA`
- Host name/address: IP de cualquier maquina con HAProxy, por ejemplo `100.76.170.62`
- Port: `5000`
- Maintenance database: `mediqueueadmin`
- Username: `mediqueue`
- Password: `mediqueue123`

Para ver registros: `Servers > Mediqueue HA > Databases > mediqueueadmin > Schemas > public > Tables`, clic derecho sobre una tabla y `View/Edit Data`.

## Resiliencia sin orquestador

Docker Compose no reubica automaticamente contenedores entre maquinas cuando una computadora se apaga. La disponibilidad ante caida de una maquina se consigue con estos puntos:

- La base de datos sigue disponible si queda quorum de etcd/Patroni y al menos un nodo Postgres sano.
- Los microservicios que solo existian en la maquina apagada deben levantarse en otra maquina con su compose alterno o manualmente.
- El gateway debe apuntar a la IP donde se levanto el servicio recuperado.
- RabbitMQ debe conservar el cluster y las colas durables para no perder eventos publicados.

Para cumplir la prueba de apagar una computadora sin orquestador externo, deben preparar perfiles o comandos de recuperacion manual para levantar los servicios criticos de esa maquina en otra antes de la demo.
