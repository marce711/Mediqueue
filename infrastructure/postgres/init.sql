-- 1. Configuración Inicial
-- CREATE DATABASE mediqueueadmin;
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. Tabla: PACIENTES
CREATE TABLE pacientes (
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
CREATE TABLE especialidades (
    id_especialidad UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion VARCHAR(255),
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 4. Tabla: DOCTORES
CREATE TABLE doctores (
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
CREATE TABLE horarios (
    id_horario UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    doctor_id UUID NOT NULL,
    dia_semana VARCHAR(20) NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    disponible BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_horario_doctor FOREIGN KEY (doctor_id) REFERENCES doctores(id_doctor) ON DELETE CASCADE
);

-- 6. Tabla: CITAS (Agregada según recomendación)
CREATE TABLE citas (
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

-- 7. Tabla: PAGOS (Relación 1:1 y llaves foráneas corregidas)
CREATE TABLE pagos (
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

-- 8. Tabla: LLAVES_IDEMPOTENCIA (Unificada)
CREATE TABLE llaves_idempotencia (
    client_id UUID PRIMARY KEY,
    servicio_origen VARCHAR(50) NOT NULL, 
    request_hash VARCHAR(255),
    idempotency_key VARCHAR(120) UNIQUE NOT NULL,
    cuerpo_respuesta TEXT,
    creado_en TIMESTAMP DEFAULT NOW(),
    expira_en TIMESTAMP
);

-- 9. Tabla: EVENTOS_SALIENTES (Outbox - Eliminada duplicidad)
CREATE TABLE eventos_salientes (
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

-- 10. Índices de Unicidad
CREATE UNIQUE INDEX ux_doctor_horario_activo 
ON citas (doctor_id, horario_id) 
WHERE estado_cita = 'CONFIRMADA';

CREATE UNIQUE INDEX ux_paciente_horario_activo 
ON citas (paciente_id, horario_id) 
WHERE estado_cita = 'CONFIRMADA';