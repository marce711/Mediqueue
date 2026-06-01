#!/bin/bash
set -e

# 1. Crear usuario y base de datos
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

# 2. Inicializar esquema en mediqueueadmin
psql -v ON_ERROR_STOP=1 --username postgres --dbname mediqueueadmin <<SQL
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
GRANT ALL ON SCHEMA public TO mediqueue;
ALTER SCHEMA public OWNER TO mediqueue;

-- --- ESQUEMA DE TABLAS (Normalizado 3NF) ---

-- 2. Tabla: PACIENTES
CREATE TABLE IF NOT EXISTS pacientes (
    id_paciente UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dpi VARCHAR(30) NOT NULL UNIQUE,
    correo VARCHAR(120) NOT NULL UNIQUE,
    nombre VARCHAR(120) NOT NULL,
    telefono VARCHAR(30) NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    creado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_paciente_estado CHECK (estado IN ('ACTIVO', 'INACTIVO'))
);

-- 3. Tabla: ESPECIALIDADES
CREATE TABLE IF NOT EXISTS especialidades (
    id_especialidad UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion VARCHAR(255),
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Insertar Especialidades Iniciales
INSERT INTO especialidades (nombre, descripcion)
SELECT * FROM (VALUES 
    ('Medicina General', 'Atención médica primaria y preventiva'),
    ('Pediatría', 'Cuidado médico de bebés, niños y adolescentes'),
    ('Ginecología', 'Salud del sistema reproductor femenino'),
    ('Cardiología', 'Tratamiento de trastornos del corazón'),
    ('Dermatología', 'Cuidado de la piel, cabello y uñas')
) AS t(nombre, descripcion)
WHERE NOT EXISTS (SELECT 1 FROM especialidades);

-- 4. Tabla: DOCTORES
CREATE TABLE IF NOT EXISTS doctores (
    id_doctor UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    especialidad_id UUID NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    telefono VARCHAR(30),
    correo VARCHAR(120),
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    creado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT fk_doctor_especialidad FOREIGN KEY (especialidad_id) REFERENCES especialidades(id_especialidad),
    CONSTRAINT chk_doctor_estado CHECK (estado IN ('ACTIVO', 'INACTIVO'))
);

-- 5. Tabla: HORARIOS
CREATE TABLE IF NOT EXISTS horarios (
    id_horario UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    doctor_id UUID NOT NULL,
    dia_semana VARCHAR(20) NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    disponible BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_horario_doctor FOREIGN KEY (doctor_id) REFERENCES doctores(id_doctor) ON DELETE CASCADE
);

-- 6. Tabla: CITAS
CREATE TABLE IF NOT EXISTS citas (
    id_cita UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    paciente_id UUID NOT NULL,
    doctor_id UUID NOT NULL,
    horario_id UUID NOT NULL,
    estado_cita VARCHAR(30) NOT NULL DEFAULT 'CONFIRMADA',
    numero_turno INT,
    motivo_consulta VARCHAR(255),
    observaciones VARCHAR(255),
    creado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT fk_cita_paciente FOREIGN KEY (paciente_id) REFERENCES pacientes(id_paciente),
    CONSTRAINT fk_cita_doctor FOREIGN KEY (doctor_id) REFERENCES doctores(id_doctor),
    CONSTRAINT fk_cita_horario FOREIGN KEY (horario_id) REFERENCES horarios(id_horario),
    CONSTRAINT chk_cita_estado CHECK (estado_cita IN ('CONFIRMADA', 'CANCELADA', 'PENDIENTE', 'FINALIZADA'))
);

-- 7. Tabla: PAGOS
CREATE TABLE IF NOT EXISTS pagos (
    id_pago UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cita_id UUID NOT NULL UNIQUE,
    paciente_id UUID NOT NULL,
    monto NUMERIC(12,2) NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
    metodo_pago VARCHAR(30),
    referencia VARCHAR(120),
    idempotency_key VARCHAR(120),
    creado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT fk_pago_cita FOREIGN KEY (cita_id) REFERENCES citas(id_cita),
    CONSTRAINT fk_pago_paciente FOREIGN KEY (paciente_id) REFERENCES pacientes(id_paciente),
    CONSTRAINT chk_pago_estado CHECK (estado IN ('PENDIENTE', 'PAGADO', 'FALLIDO', 'CANCELADO'))
);

-- 10. Índices
CREATE UNIQUE INDEX IF NOT EXISTS ux_doctor_horario_activo 
ON citas (doctor_id, horario_id) 
WHERE estado_cita = 'CONFIRMADA';

CREATE UNIQUE INDEX IF NOT EXISTS ux_paciente_horario_activo 
ON citas (paciente_id, horario_id) 
WHERE estado_cita = 'CONFIRMADA';

SQL
