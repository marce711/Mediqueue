-- Restauracion idempotente de datos minimos para Mediqueue.
-- Ejecutar contra el lider por HAProxy cuando Patroni tenga primario:
-- psql -h localhost -p 5000 -U postgres -d mediqueueadmin -f infrastructure/postgres/restore-minimal-data.sql

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

ALTER TABLE especialidades
ADD COLUMN IF NOT EXISTS precio_consulta NUMERIC(12,2) NOT NULL DEFAULT 150.00;

ALTER TABLE appointments
ADD COLUMN IF NOT EXISTS duration_minutes INT NOT NULL DEFAULT 30;

ALTER TABLE appointments
ADD COLUMN IF NOT EXISTS consultation_price NUMERIC(12,2) NOT NULL DEFAULT 0.00;

ALTER TABLE citas
ADD COLUMN IF NOT EXISTS duracion_minutos INT NOT NULL DEFAULT 30;

ALTER TABLE citas
ADD COLUMN IF NOT EXISTS precio_consulta NUMERIC(12,2) NOT NULL DEFAULT 0.00;

DO
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_appointments_duration_minutes'
    ) THEN
        ALTER TABLE appointments
        ADD CONSTRAINT chk_appointments_duration_minutes CHECK (duration_minutes BETWEEN 20 AND 30);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_citas_duracion_minutos'
    ) THEN
        ALTER TABLE citas
        ADD CONSTRAINT chk_citas_duracion_minutos CHECK (duracion_minutos BETWEEN 20 AND 30);
    END IF;
END
$$;

INSERT INTO especialidades (nombre, descripcion, precio_consulta) VALUES
('Medicina General', 'Atención médica primaria y preventiva', 150.00),
('Pediatría', 'Cuidado médico de bebés, niños y adolescentes', 180.00),
('Ginecología', 'Salud del sistema reproductor femenino', 220.00),
('Cardiología', 'Tratamiento de trastornos del corazón', 300.00),
('Dermatología', 'Cuidado de la piel, cabello y uñas', 200.00)
ON CONFLICT (nombre) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    precio_consulta = EXCLUDED.precio_consulta,
    activa = TRUE;

INSERT INTO pacientes (
    id_paciente,
    dpi,
    correo,
    nombre,
    telefono,
    estado
) VALUES (
    '11111111-1111-4111-8111-111111111111',
    '9000000000001',
    'paciente.demo@mediqueue.com',
    'Paciente Demo',
    '55550001',
    'ACTIVO'
)
ON CONFLICT (dpi) DO UPDATE SET
    correo = EXCLUDED.correo,
    nombre = EXCLUDED.nombre,
    telefono = EXCLUDED.telefono,
    estado = 'ACTIVO',
    actualizado_en = NOW();

WITH cardiologia AS (
    SELECT id_especialidad
    FROM especialidades
    WHERE nombre = 'Cardiología'
    ORDER BY nombre
    LIMIT 1
)
INSERT INTO doctores (
    id_doctor,
    especialidad_id,
    nombre,
    telefono,
    correo,
    estado
)
SELECT
    '22222222-2222-4222-8222-222222222222',
    id_especialidad,
    'Doctor Demo Cardiologia',
    '44440001',
    'doctor.demo@mediqueue.com',
    'ACTIVO'
FROM cardiologia
ON CONFLICT (id_doctor) DO UPDATE SET
    especialidad_id = EXCLUDED.especialidad_id,
    nombre = EXCLUDED.nombre,
    telefono = EXCLUDED.telefono,
    correo = EXCLUDED.correo,
    estado = 'ACTIVO',
    actualizado_en = NOW();

INSERT INTO horarios (
    id_horario,
    doctor_id,
    dia_semana,
    hora_inicio,
    hora_fin,
    disponible
) VALUES
(
    '33333333-3333-4333-8333-333333333331',
    '22222222-2222-4222-8222-222222222222',
    'MONDAY',
    '08:00:00',
    '12:00:00',
    TRUE
),
(
    '33333333-3333-4333-8333-333333333332',
    '22222222-2222-4222-8222-222222222222',
    'WEDNESDAY',
    '08:00:00',
    '12:00:00',
    TRUE
),
(
    '33333333-3333-4333-8333-333333333333',
    '22222222-2222-4222-8222-222222222222',
    'FRIDAY',
    '08:00:00',
    '12:00:00',
    TRUE
)
ON CONFLICT (id_horario) DO UPDATE SET
    doctor_id = EXCLUDED.doctor_id,
    dia_semana = EXCLUDED.dia_semana,
    hora_inicio = EXCLUDED.hora_inicio,
    hora_fin = EXCLUDED.hora_fin,
    disponible = TRUE;

UPDATE appointments a
SET consultation_price = e.precio_consulta
FROM doctores d
JOIN especialidades e ON e.id_especialidad = d.especialidad_id
WHERE a.doctor_id = d.id_doctor::text
  AND (a.consultation_price IS NULL OR a.consultation_price = 0);

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO mediqueue;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO mediqueue;
