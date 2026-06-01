-- Inicializacion idempotente de la base Mediqueue.
-- Este archivo puede ejecutarse mas de una vez sin fallar por objetos existentes.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

GRANT ALL ON SCHEMA public TO mediqueue;
ALTER SCHEMA public OWNER TO mediqueue;

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

CREATE TABLE IF NOT EXISTS especialidades (
    id_especialidad UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion VARCHAR(255),
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO especialidades (nombre, descripcion) VALUES
('Medicina General', 'Atención médica primaria y preventiva'),
('Pediatría', 'Cuidado médico de bebés, niños y adolescentes'),
('Ginecología', 'Salud del sistema reproductor femenino'),
('Cardiología', 'Tratamiento de trastornos del corazón'),
('Dermatología', 'Cuidado de la piel, cabello y uñas')
ON CONFLICT (nombre) DO NOTHING;

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

CREATE TABLE IF NOT EXISTS llaves_idempotencia (
    client_id UUID PRIMARY KEY,
    servicio_origen VARCHAR(50) NOT NULL,
    request_hash VARCHAR(255),
    idempotency_key VARCHAR(120) UNIQUE NOT NULL,
    cuerpo_respuesta TEXT,
    creado_en TIMESTAMP DEFAULT NOW(),
    expira_en TIMESTAMP
);

CREATE TABLE IF NOT EXISTS eventos_salientes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_id UUID NOT NULL,
    aggregate_type VARCHAR(80) NOT NULL,
    event_type VARCHAR(120) NOT NULL,
    exchange_name VARCHAR(160) NOT NULL,
    routing_key VARCHAR(160) NOT NULL,
    payload TEXT NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
    intentos INT NOT NULL DEFAULT 0,
    creado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    procesado_en TIMESTAMP NULL,
    CONSTRAINT chk_outbox_status CHECK (status IN ('PENDIENTE', 'PROCESADO'))
);

-- Tablas usadas por los servicios JPA actuales de citas y pagos.
CREATE TABLE IF NOT EXISTS appointments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id VARCHAR(80) NOT NULL,
    doctor_id VARCHAR(80) NOT NULL,
    appointment_date TIMESTAMP NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    idempotency_key VARCHAR(120),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    version BIGINT
);

CREATE TABLE IF NOT EXISTS payments (
    id BIGSERIAL PRIMARY KEY,
    appointment_id VARCHAR(80) NOT NULL,
    patient_id VARCHAR(80) NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    status VARCHAR(30) NOT NULL,
    idempotency_key VARCHAR(120),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    version BIGINT
);

CREATE TABLE IF NOT EXISTS outbox_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_id VARCHAR(120) NOT NULL,
    aggregate_type VARCHAR(80) NOT NULL,
    event_type VARCHAR(120) NOT NULL,
    exchange_name VARCHAR(160) NOT NULL,
    routing_key VARCHAR(160) NOT NULL,
    payload TEXT NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    attempts INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMP NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_doctor_horario_activo
ON citas (doctor_id, horario_id)
WHERE estado_cita = 'CONFIRMADA';

CREATE UNIQUE INDEX IF NOT EXISTS ux_paciente_horario_activo
ON citas (paciente_id, horario_id)
WHERE estado_cita = 'CONFIRMADA';

CREATE UNIQUE INDEX IF NOT EXISTS ux_appointments_idempotency_key_jpa
ON appointments (idempotency_key)
WHERE idempotency_key IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_appointments_doctor_datetime_jpa
ON appointments (doctor_id, appointment_date);

CREATE UNIQUE INDEX IF NOT EXISTS ux_appointments_patient_datetime_jpa
ON appointments (patient_id, appointment_date);

CREATE UNIQUE INDEX IF NOT EXISTS ux_payments_idempotency_key_jpa
ON payments (idempotency_key)
WHERE idempotency_key IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_payments_appointment_id_jpa
ON payments (appointment_id);

DO
$$
DECLARE
    object_name text;
BEGIN
    FOR object_name IN
        SELECT tablename
        FROM pg_tables
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('ALTER TABLE public.%I OWNER TO mediqueue', object_name);
    END LOOP;

    FOR object_name IN
        SELECT sequencename
        FROM pg_sequences
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('ALTER SEQUENCE public.%I OWNER TO mediqueue', object_name);
    END LOOP;
END
$$;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO mediqueue;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO mediqueue;
