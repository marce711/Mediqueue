CREATE DATABASE mediqueueadmin;

CREATE TABLE pacientes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dpi VARCHAR(30) NOT NULL UNIQUE,
    correo VARCHAR(120) NOT NULL UNIQUE,
    nombre VARCHAR(120) NOT NULL,
    telefono VARCHAR(30) NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    creado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    version BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT chk_paciente_estado
        CHECK (estado IN ('ACTIVO','INACTIVO'))
);

CREATE TABLE especialidades (
   id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
   nombre VARCHAR(100) NOT NULL UNIQUE,
   descripcion VARCHAR(255),
   activa BOOLEAN NOT NULL DEFAULT TRUE,
   creado_en TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE doctores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    especialidad_id UUID NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    telefono VARCHAR(30),
    correo VARCHAR(120),
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    creado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    version BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT fk_doctor_especialidad
     FOREIGN KEY (especialidad_id)
         REFERENCES especialidades(id),

    CONSTRAINT chk_doctor_estado
     CHECK (estado IN ('ACTIVO','INACTIVO'))
);

CREATE TABLE horarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    doctor_id UUID NOT NULL,
    dia_semana VARCHAR(20) NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    disponible BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_horario_doctor
        FOREIGN KEY (doctor_id)
            REFERENCES doctores(id)
            ON DELETE CASCADE
);

CREATE UNIQUE INDEX ux_doctor_horario_activo
ON citas (doctor_id, fecha_hora)
WHERE estado IN ('PENDIENTE','CONFIRMADA');

CREATE UNIQUE INDEX ux_paciente_horario_activo
ON citas (paciente_id, fecha_hora)
WHERE estado IN ('PENDIENTE','CONFIRMADA');

CREATE UNIQUE INDEX ux_cita_idempotency
ON citas (idempotency_key)
WHERE idempotency_key IS NOT NULL;

CREATE TABLE pagos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cita_id UUID NOT NULL,
    paciente_id UUID NOT NULL,
    monto NUMERIC(12,2) NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
    metodo_pago VARCHAR(30),
    referencia VARCHAR(120),
    idempotency_key VARCHAR(120),
    creado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    version BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT chk_pago_estado CHECK (estado IN ('PENDIENTE','EXITOSO','FALLIDO','DEVUELTO','CANCELADO'))
);

CREATE UNIQUE INDEX ux_pago_cita_exitosa
ON pagos (cita_id)
WHERE estado = 'EXITOSO';

CREATE UNIQUE INDEX ux_pago_idempotency
ON pagos (idempotency_key)
WHERE idempotency_key IS NOT NULL;

CREATE TABLE outbox_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_id VARCHAR(120) NOT NULL,
    aggregate_type VARCHAR(80) NOT NULL,
    event_type VARCHAR(120) NOT NULL,
    exchange_name VARCHAR(160) NOT NULL,
    routing_key VARCHAR(160) NOT NULL,
    payload TEXT NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
    attempts INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMP NULL
);

CREATE TABLE outbox_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_id VARCHAR(120) NOT NULL,
    aggregate_type VARCHAR(80) NOT NULL,
    event_type VARCHAR(120) NOT NULL,
    exchange_name VARCHAR(160) NOT NULL,
    routing_key VARCHAR(160) NOT NULL,
    payload TEXT NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
    attempts INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMP NULL
);

