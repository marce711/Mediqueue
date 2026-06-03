-- Limpieza y ampliacion de especialidades
-- Ejecutar en el lider de Patroni (Nodo B usualmente)

DELETE FROM especialidades;

INSERT INTO especialidades (nombre, descripcion, precio_consulta) VALUES
('Medicina General', 'Atención médica primaria y preventiva', 150.00),
('Pediatría', 'Cuidado médico de bebés, niños y adolescentes', 180.00),
('Ginecología', 'Salud del sistema reproductor femenino', 220.00),
('Cardiología', 'Tratamiento de trastornos del corazón', 300.00),
('Dermatología', 'Cuidado de la piel, cabello y uñas', 200.00),
('Oftalmología', 'Salud ocular y cirugía de visión', 250.00),
('Odontología', 'Salud dental y ortodoncia', 175.00),
('Nutrición', 'Asesoría alimenticia y dietética', 130.00),
('Psicología', 'Apoyo emocional y salud mental', 150.00),
('Traumatología', 'Lesiones óseas y musculares', 210.00),
('Neurología', 'Trastornos del sistema nervioso', 350.00),
('Endocrinología', 'Trastornos hormonales y metabólicos', 280.00),
('Urología', 'Salud del sistema urinario', 230.00),
('Gastroenterología', 'Salud del sistema digestivo', 225.00)
ON CONFLICT (nombre) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    precio_consulta = EXCLUDED.precio_consulta,
    activa = TRUE;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO mediqueue;
