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

## 4. Pruebas de Resiliencia (Demo)
- **Cierre de una PC:** Apaga la Computadora A. El Gateway del Nodo 1 caerá, pero si tienes un balanceador externo o entras por la IP del Nodo 2, el sistema seguirá funcionando porque etcd elegirá un nuevo master de DB y RabbitMQ seguirá vivo en los otros nodos.
- **Matar Postgres Master:** Patroni promoverá una réplica en < 10 segundos. HAProxy detectará el cambio automáticamente.
- **Corte de RabbitMQ:** Spring Boot tiene configuradas las 3 IPs, por lo que se reconectará al siguiente nodo disponible.

## 5. Notas Importantes
- **Quorum Queues:** Las colas de RabbitMQ deben definirse como tipo 'quorum' en el código Java para que se repliquen.
- **Resilience4j:** Los microservicios ahora tienen Circuit Breakers para evitar que fallos en cascada tumben el sistema.
- **HAProxy Local:** Cada nodo tiene su HAProxy local apuntando a los 3 nodos de DB. Los microservicios se conectan a `127.0.0.1:5000`.
