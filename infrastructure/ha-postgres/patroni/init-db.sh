#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username postgres <<SQL
DO
\$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'mediqueue') THEN
      CREATE ROLE mediqueue LOGIN PASSWORD '${POSTGRES_APP_PASSWORD}';
   ELSE
      ALTER ROLE mediqueue WITH LOGIN PASSWORD '${POSTGRES_APP_PASSWORD}';
   END IF;
END
\$\$;

SELECT 'CREATE DATABASE mediqueueadmin OWNER mediqueue'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'mediqueueadmin')\gexec
GRANT ALL PRIVILEGES ON DATABASE mediqueueadmin TO mediqueue;
SQL

psql -v ON_ERROR_STOP=1 --username postgres --dbname mediqueueadmin <<SQL
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
GRANT ALL ON SCHEMA public TO mediqueue;
ALTER SCHEMA public OWNER TO mediqueue;
SQL
