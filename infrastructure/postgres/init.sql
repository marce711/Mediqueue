CREATE DATABASE pacientedb;
CREATE DATABASE doctordb;
CREATE DATABASE citadb;
CREATE DATABASE pagodb;

\connect citadb

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS outbox_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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

CREATE INDEX IF NOT EXISTS idx_cita_outbox_pending
    ON outbox_events (status, created_at)
    WHERE status = 'PENDIENTE';

CREATE TABLE IF NOT EXISTS citas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_paciente VARCHAR(80) NOT NULL,
    id_doctor VARCHAR(80) NOT NULL,
    cita_fecha TIMESTAMP NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE',
    idempotency_key VARCHAR(120),
    creado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_citas_estado
        CHECK (status IN ('PENDIENTE','CONFIRMADO','CANCELADO','COMPLETADO','NO_DISPONIBLE'))
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_citas_idempotency_key
    ON citas (idempotency_key)
    WHERE idempotency_key IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_citas_espacio_doctor_activo
    ON citas (id_doctor, cita_fecha)
    WHERE estado IN ('PENDIENTE', 'CONFIRMADO');

CREATE UNIQUE INDEX IF NOT EXISTS ux_citas_espacio_paciente_activo
    ON citas (id_paciente, cita_fecha)
    WHERE estado IN ('PENDIENTE', 'CONFIRMADO');

\connect pagodb

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS outbox_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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

CREATE INDEX IF NOT EXISTS idx_pago_outbox_pending
    ON outbox_events (status, created_at)
    WHERE status = 'PENDIENTE';

CREATE TABLE IF NOT EXISTS pagos (
    id BIGSERIAL PRIMARY KEY,
    id_cita VARCHAR(80) NOT NULL,
    id_paciente VARCHAR(80) NOT NULL,
    monto NUMERIC(12,2) NOT NULL CHECK (monto > 0),
    estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
    idempotency_key VARCHAR(120),
    creado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_pago_estado
        CHECK (estado IN ('PENDIENTE','EXITOSO','FALLIDO','DEVUELTO','CANCELADO'))
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_pagos_idempotency_key
    ON pagos (idempotency_key)
    WHERE idempotency_key IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_pagos_cita_exitosa
    ON pagos (id_cita)
    WHERE estado = 'SUCCESS';
