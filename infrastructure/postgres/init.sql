CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS estados_paciente (
    id_estado_paciente SERIAL PRIMARY KEY,
    nombre_estado VARCHAR(50) NOT NULL UNIQUE,
    descripcion VARCHAR(255),
    activo BOOLEAN NOT NULL DEFAULT TRUE
    );

CREATE TABLE IF NOT EXISTS pacientes (
    id_paciente BIGSERIAL PRIMARY KEY,
    dpi  VARCHAR(20)  NOT NULL UNIQUE,
    nombre_paciente   VARCHAR(150) NOT NULL,
    apellido_paciente VARCHAR(150) NOT NULL,
    correo_paciente  VARCHAR(150) NOT NULL,
    telefono_paciente VARCHAR(20)  NOT NULL,
    fecha_nacimiento DATE,
    direccion VARCHAR(255),
    registro_paciente TIMESTAMP NOT NULL DEFAULT NOW(),
    id_estado_paciente INT NOT NULL,

    CONSTRAINT fk_estado_paciente
    FOREIGN KEY (id_estado_paciente)
    REFERENCES estados_paciente(id_estado_paciente)
    );

CREATE INDEX IF NOT EXISTS idx_pacientes_dpi ON pacientes (dpi);

CREATE TABLE IF NOT EXISTS especialidades (
    id_especialidades SERIAL PRIMARY KEY,
    nombre_especialidad VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS doctores (
    id_doctor BIGSERIAL PRIMARY KEY,
    nombreDoctor VARCHAR(150) NOT NULL,
    apellidoDoctor VARCHAR(150) NOT NULL,
    correoDoctor VARCHAR(150) NOT NULL,
    telefonoDoctor VARCHAR(20),
    activo   BOOLEAN  NOT NULL DEFAULT TRUE,
    creado_en    TIMESTAMP    NOT NULL DEFAULT NOW(),
    id_especialidad INT NOT NULL,

    CONSTRAINT fk_especialidad
    FOREIGN KEY (id_especialidad)
    REFERENCES especialidades(id_especialidades)
    );

CREATE INDEX IF NOT EXISTS idx_doctores_activo ON doctores (activo);

CREATE TABLE IF NOT EXISTS doctor_horarios (
    id_horario BIGSERIAL PRIMARY KEY,
    id_doctor   BIGINT NOT NULL REFERENCES doctores(id_doctor) ON DELETE CASCADE,
    dia_semana  VARCHAR(20) NOT NULL,
    hora_inicio TIME  NOT NULL,
    hora_fin    TIME  NOT NULL,
    disponible  BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_horario_horas CHECK (hora_fin > hora_inicio),
    CONSTRAINT fk_doctor FOREIGN KEY (id_doctor) REFERENCES doctores(id_doctor)
    );

CREATE INDEX IF NOT EXISTS idx_doctor_horarios_doctor_id  ON doctor_horarios (id_doctor);
CREATE INDEX IF NOT EXISTS idx_doctor_horarios_disponible ON doctor_horarios (disponible);
CREATE INDEX IF NOT EXISTS idx_doctor_horarios_dia ON doctor_horarios (dia_semana);

CREATE TABLE IF NOT EXISTS citas (
    id_cita UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_paciente VARCHAR(80) NOT NULL,
    id_doctor VARCHAR(80) NOT NULL,
    cita_fecha TIMESTAMP NOT NULL,
    estado_cita VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE',
    descripcion_citas VARCHAR(170),
    creada_en TIMESTAMP NOT NULL DEFAULT NOW(),
    actualizada_en TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_appointment_status CHECK (status IN ('PENDIENTE','CONFIRMADO','CANCELADO','COMPLETADO','SIN_RESULTADO'))
    );

CREATE INDEX IF NOT EXISTS idx_citas_patient_id ON citas (id_paciente);
CREATE INDEX IF NOT EXISTS idx_citas_doctor_id ON citas (id_doctor);
CREATE INDEX IF NOT EXISTS idx_citas_appointment_date ON citas (cita_fecha);
CREATE INDEX IF NOT EXISTS idx_citas_status ON citas (estado_cita);

CREATE TABLE IF NOT EXISTS pagos (
    id_pagos BIGSERIAL PRIMARY KEY,
    id_cita VARCHAR(80) NOT NULL,
    id_paciente BIGINT NOT NULL,
    monto NUMERIC(12,2) NOT NULL CHECK (monto > 0),
    moneda VARCHAR(5) NOT NULL DEFAULT 'GTQ',
    estado_pago VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
    metodo_pago VARCHAR(50),
    referencia VARCHAR(100),
    creado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_payment_status CHECK (status IN ('PENDIENTE','COMPLETADO','FALLIDO','DEVUELTO','CANCELADO'))
    );

CREATE INDEX IF NOT EXISTS idx_payments_appointment_id ON pagos (id_cita);
CREATE INDEX IF NOT EXISTS idx_payments_patient_id ON pagos (id_paciente);
CREATE INDEX IF NOT EXISTS idx_payments_status ON pagos (estado_pago);

