# Guía de Alta Disponibilidad y Backups - Mediqueue

Este proyecto ahora utiliza **Patroni** para gestionar un cluster de PostgreSQL altamente disponible, con **etcd** como DCS (Distributed Configuration Store) y **HAProxy** como balanceador de carga.

## Componentes del Cluster

1.  **etcd**: Almacena el estado del cluster y realiza la elección del líder.
2.  **postgres1, postgres2, postgres3**: Nodos de base de datos gestionados por Patroni.
3.  **HAProxy**: Punto de entrada único para las aplicaciones (Puerto 5433 externamente, 5432 internamente). Siempre redirige al nodo líder actual.
4.  **pgAdmin**: Interfaz web para gestionar las bases de datos (Puerto 5050).
5.  **pgBackRest**: Herramienta para backups incrementales.

## Cómo ejecutar

Para iniciar todo el sistema:

```bash
docker-compose up -d --build
```

## Verificando el Estado del Cluster

Puedes ver el estado del cluster accediendo a las estadísticas de HAProxy en `http://localhost:7000`.

O mediante la API de Patroni en cualquier nodo:

```bash
curl http://localhost:8008/cluster
```

## Estrategia de Backups Incrementales

Los backups se gestionan con **pgBackRest**. Los archivos de backup se guardan en el volumen `backrest_repo`.

### Configuración Inicial

La primera vez que corras el sistema, debes inicializar el "stanza" de pgBackRest en el nodo líder:

1. Identifica al líder (ej. `postgres1`).
2. Ejecuta:
   ```bash
   docker-compose exec postgres1 bash /home/postgres/backup.sh
   ```

### Ejecutar Backup Incremental

Para realizar un backup incremental manualmente:
```bash
docker-compose exec postgres1 pgbackrest --stanza=mediqueue --type=incr backup
```

### Recuperación de Datos

Si la base de datos se corrompe o se borra, puedes restaurar usando:
```bash
docker-compose exec postgres1 pgbackrest --stanza=mediqueue restore
```

## 🌐 Despliegue Distribuido con Docker Swarm

Para la prueba con múltiples máquinas, utilizaremos **Docker Swarm**. Esto permite que las computadoras de tus compañeros se unan en un solo "cluster".

### Pasos para activar el Cluster:

1.  **En tu máquina (Manager):**
    ```bash
    docker swarm init --advertise-addr <TU_IP_LOCAL>
    ```
    *Copia el comando `docker swarm join --token ...` que aparecerá.*

2.  **En las máquinas de tus compañeros (Workers):**
    Pega el comando copiado en el paso anterior.

3.  **Desplegar todo el sistema:**
    ```bash
    docker stack deploy -c docker-compose.yml mediqueue
    ```

4.  **Verificar el estado:**
    ```bash
    docker service ls
    ```

---

## ⚖️ Docker Swarm vs Kubernetes (K8s)

Durante la presentación, podrían preguntarte por qué elegiste Swarm. Aquí tienes la respuesta técnica:

| Característica | Docker Swarm | Kubernetes (K8s) |
| :--- | :--- | :--- |
| **Instalación** | Muy simple (Ya viene en Docker). | Compleja (Requiere muchas herramientas extra). |
| **Curva de Aprendizaje** | Baja. Usa el mismo `docker-compose.yml`. | Alta. Requiere aprender YAMLs de K8s. |
| **Recursos** | Muy ligero. Ideal para vuestra prueba. | Pesado. Consume mucha RAM/CPU. |
| **Escalabilidad** | Rápida y sencilla para clusters pequeños. | Masiva. Diseñado para miles de nodos. |

**Respuesta para los evaluadores:**
> "Elegimos **Docker Swarm** porque ofrece la orquestación necesaria para garantizar la **Alta Disponibilidad** y **Escalabilidad Horizontal** de nuestros microservicios con una sobrecarga mínima de recursos. Mientras que Kubernetes es el estándar de la industria para despliegues masivos, Swarm nos permite cumplir con los mismos objetivos de redundancia y recuperación ante fallos de manera eficiente para esta arquitectura de microservicios."

---

## 🛡️ Prueba de Resiliencia (Puntos Extra)
Si apagas una máquina del cluster, verás cómo Swarm:
1. Detecta la caída.
2. Identifica qué servicios corrían allí.
3. Los **vuelve a levantar automáticamente** en las máquinas que siguen encendidas.

---
**Nota:** El sistema está configurado para que si una máquina se apaga, Patroni detecte la caída y elija un nuevo líder automáticamente en menos de 30 segundos. HAProxy actualizará su ruta al nuevo líder sin intervención manual.
