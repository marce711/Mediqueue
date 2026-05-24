FROM postgres:15

RUN apt-get update && apt-get install -y \
    python3-pip \
    python3-dev \
    libpq-dev \
    gcc \
    curl \
    pgbackrest \
    gettext-base \
    python3-psycopg2 \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install patroni[etcd] psutil --break-system-packages


# Create directories for Patroni and pgBackRest
RUN mkdir -p /home/postgres /var/lib/postgresql/data /var/log/patroni /var/lib/pgbackrest
RUN chown -R postgres:postgres /home/postgres /var/lib/postgresql /var/log/patroni /var/lib/pgbackrest

USER postgres

WORKDIR /home/postgres

# Default configuration will be overwritten by environment variables or volume mounts
CMD ["patroni", "/home/postgres/patroni.yml"]
