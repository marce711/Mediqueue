#!/bin/bash
set -e
envsubst < /home/postgres/patroni.yml.template > /home/postgres/patroni.yml
mkdir -p /var/lib/postgresql/data
chmod 700 /var/lib/postgresql/data
exec patroni /home/postgres/patroni.yml
