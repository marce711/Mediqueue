# GUÍA DE DESPLIEGUE EN ALTA DISPONIBILIDAD (HA) - MEDIQUEUE

Esta arquitectura está diseñada para sobrevivir a la caída de una computadora completa de las 3 disponibles.

## 1. Preparación de Red (Tailscale)
Asegurarse de que las 3 computadoras tengan Tailscale instalado y se vean entre sí.
En este ejemplo usamos las siguientes IPs (DEBES REEMPLAZARLAS EN LOS ARCHIVOS .yml):
- **Nodo 1 (Computadora A):** 100.76.170.62
- **Nodo 2 (Computadora B):** 100.113.35.88
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
- Frontend nodo B: `http://100.113.35.88/`
- Frontend nodo C: `http://100.99.158.111/`
- Gateway de cada nodo: `http://<IP_NODO>:8080`
- Estado Patroni: `http://<IP_NODO>:8008/cluster`
- Estado HAProxy: `http://<IP_NODO>:7000`
- pgAdmin: `http://<IP_NODO>:5050`

## 4. Pruebas de Resiliencia (Demo)
- **Cierre de una PC:** Apaga la Computadora A. Entra por `http://100.113.35.88/` o `http://100.99.158.111/`. El gateway de esos nodos tiene listas de fallback hacia los servicios locales y remotos, y la base escribe por HAProxy al líder Patroni disponible.
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
cualquier nodo y el puerto `5000`, por ejemplo `100.113.35.88:5000`.

## 6. Reglas de Negocio Implementadas
- Pacientes: el DPI es único; un segundo registro con el mismo DPI devuelve conflicto.
- Doctores: se registran con especialidad y horarios.
- Especialidades: el dropdown se alimenta de `especialidades` y cada una tiene `precio_consulta`.
- Citas: solo admiten duraciones de 20 a 30 minutos.
- Disponibilidad: se valida que el doctor atienda el día/hora solicitados y que no exista traslape con otra cita activa.
- Flujo de pago: la cita se crea como `PENDING`; al pagar el monto exacto del precio de la especialidad, el pago queda `SUCCESS` y la cita pasa a `CONFIRMED`.
- Cancelación: una cita solo puede cancelarse con al menos 48 horas de anticipación.

## 7. Notas Importantes
- **Quorum Queues:** Las colas de RabbitMQ deben definirse como tipo 'quorum' en el código Java para que se repliquen.
- **Resilience4j:** Los microservicios ahora tienen Circuit Breakers para evitar que fallos en cascada tumben el sistema.
- **HAProxy Local:** Cada nodo tiene su HAProxy local apuntando a los 3 nodos de DB. Los microservicios se conectan a `haproxy:5432` dentro de Docker; desde el host use `localhost:5000` para escritura.

