--
-- PostgreSQL database dump
--

\restrict ZhVYvdwQLD9NLCiF8Lgppr9Px0sJAShJh6Mc34EW8CUiPozMr3A1nl6YTA7LArN

-- Dumped from database version 15.18 (Debian 15.18-1.pgdg13+1)
-- Dumped by pg_dump version 15.18 (Debian 15.18-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE IF EXISTS ONLY public.pagos DROP CONSTRAINT IF EXISTS fk_pago_paciente;
ALTER TABLE IF EXISTS ONLY public.pagos DROP CONSTRAINT IF EXISTS fk_pago_cita;
ALTER TABLE IF EXISTS ONLY public.horarios DROP CONSTRAINT IF EXISTS fk_horario_doctor;
ALTER TABLE IF EXISTS ONLY public.doctores DROP CONSTRAINT IF EXISTS fk_doctor_especialidad;
ALTER TABLE IF EXISTS ONLY public.citas DROP CONSTRAINT IF EXISTS fk_cita_paciente;
ALTER TABLE IF EXISTS ONLY public.citas DROP CONSTRAINT IF EXISTS fk_cita_horario;
ALTER TABLE IF EXISTS ONLY public.citas DROP CONSTRAINT IF EXISTS fk_cita_doctor;
DROP INDEX IF EXISTS public.ux_payments_idempotency_key_jpa;
DROP INDEX IF EXISTS public.ux_payments_appointment_id_jpa;
DROP INDEX IF EXISTS public.ux_paciente_horario_activo;
DROP INDEX IF EXISTS public.ux_doctor_horario_activo;
DROP INDEX IF EXISTS public.ux_appointments_patient_datetime_jpa;
DROP INDEX IF EXISTS public.ux_appointments_idempotency_key_jpa;
DROP INDEX IF EXISTS public.ux_appointments_doctor_datetime_jpa;
DROP INDEX IF EXISTS public.idx_doctors_activo;
DROP INDEX IF EXISTS public.idx_doctor_horario_doctor_id;
DROP INDEX IF EXISTS public.idx_doctor_horario_disponible;
ALTER TABLE IF EXISTS ONLY public.payments DROP CONSTRAINT IF EXISTS payments_pkey;
ALTER TABLE IF EXISTS ONLY public.pagos DROP CONSTRAINT IF EXISTS pagos_pkey;
ALTER TABLE IF EXISTS ONLY public.pagos DROP CONSTRAINT IF EXISTS pagos_cita_id_key;
ALTER TABLE IF EXISTS ONLY public.pacientes DROP CONSTRAINT IF EXISTS pacientes_pkey;
ALTER TABLE IF EXISTS ONLY public.pacientes DROP CONSTRAINT IF EXISTS pacientes_dpi_key;
ALTER TABLE IF EXISTS ONLY public.pacientes DROP CONSTRAINT IF EXISTS pacientes_correo_key;
ALTER TABLE IF EXISTS ONLY public.outbox_events DROP CONSTRAINT IF EXISTS outbox_events_pkey;
ALTER TABLE IF EXISTS ONLY public.llaves_idempotencia DROP CONSTRAINT IF EXISTS llaves_idempotencia_pkey;
ALTER TABLE IF EXISTS ONLY public.llaves_idempotencia DROP CONSTRAINT IF EXISTS llaves_idempotencia_idempotency_key_key;
ALTER TABLE IF EXISTS ONLY public.pacientes DROP CONSTRAINT IF EXISTS idx_dpi;
ALTER TABLE IF EXISTS ONLY public.doctores DROP CONSTRAINT IF EXISTS idx_doctors_correo;
ALTER TABLE IF EXISTS ONLY public.horarios DROP CONSTRAINT IF EXISTS horarios_pkey;
ALTER TABLE IF EXISTS ONLY public.eventos_salientes DROP CONSTRAINT IF EXISTS eventos_salientes_pkey;
ALTER TABLE IF EXISTS ONLY public.especialidades DROP CONSTRAINT IF EXISTS especialidades_pkey;
ALTER TABLE IF EXISTS ONLY public.doctores DROP CONSTRAINT IF EXISTS doctores_pkey;
ALTER TABLE IF EXISTS ONLY public.citas DROP CONSTRAINT IF EXISTS citas_pkey;
ALTER TABLE IF EXISTS ONLY public.appointments DROP CONSTRAINT IF EXISTS appointments_pkey;
ALTER TABLE IF EXISTS public.payments ALTER COLUMN id DROP DEFAULT;
DROP SEQUENCE IF EXISTS public.payments_id_seq;
DROP TABLE IF EXISTS public.payments;
DROP TABLE IF EXISTS public.pagos;
DROP TABLE IF EXISTS public.pacientes;
DROP TABLE IF EXISTS public.outbox_events;
DROP TABLE IF EXISTS public.llaves_idempotencia;
DROP TABLE IF EXISTS public.horarios;
DROP TABLE IF EXISTS public.eventos_salientes;
DROP TABLE IF EXISTS public.especialidades;
DROP TABLE IF EXISTS public.doctores;
DROP TABLE IF EXISTS public.citas;
DROP TABLE IF EXISTS public.appointments;
DROP EXTENSION IF EXISTS pgcrypto;
-- *not* dropping schema, since initdb creates it
--
-- Name: public; Type: SCHEMA; Schema: -; Owner: mediqueue
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO mediqueue;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: appointments; Type: TABLE; Schema: public; Owner: mediqueue
--

CREATE TABLE public.appointments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    patient_id character varying(80) NOT NULL,
    doctor_id character varying(80) NOT NULL,
    appointment_date timestamp without time zone NOT NULL,
    duration_minutes integer DEFAULT 30 NOT NULL,
    consultation_price numeric(12,2) DEFAULT 0.00 NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    idempotency_key character varying(120),
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    version bigint,
    doctor_name character varying(120),
    patient_name character varying(120),
    CONSTRAINT chk_appointments_duration_minutes CHECK (((duration_minutes >= 20) AND (duration_minutes <= 30)))
);


ALTER TABLE public.appointments OWNER TO mediqueue;

--
-- Name: citas; Type: TABLE; Schema: public; Owner: mediqueue
--

CREATE TABLE public.citas (
    id_cita uuid DEFAULT gen_random_uuid() NOT NULL,
    paciente_id uuid NOT NULL,
    doctor_id uuid NOT NULL,
    horario_id uuid NOT NULL,
    estado_cita character varying(30) DEFAULT 'CONFIRMADA'::character varying NOT NULL,
    duracion_minutos integer DEFAULT 30 NOT NULL,
    precio_consulta numeric(12,2) DEFAULT 0.00 NOT NULL,
    numero_turno integer,
    motivo_consulta character varying(255),
    observaciones character varying(255),
    creado_en timestamp without time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp without time zone DEFAULT now() NOT NULL,
    version bigint DEFAULT 0 NOT NULL,
    CONSTRAINT chk_cita_estado CHECK (((estado_cita)::text = ANY (ARRAY[('CONFIRMADA'::character varying)::text, ('CANCELADA'::character varying)::text, ('PENDIENTE'::character varying)::text, ('FINALIZADA'::character varying)::text]))),
    CONSTRAINT chk_citas_duracion_minutos CHECK (((duracion_minutos >= 20) AND (duracion_minutos <= 30)))
);


ALTER TABLE public.citas OWNER TO mediqueue;

--
-- Name: doctores; Type: TABLE; Schema: public; Owner: mediqueue
--

CREATE TABLE public.doctores (
    id_doctor uuid DEFAULT gen_random_uuid() NOT NULL,
    especialidad_id uuid NOT NULL,
    nombre character varying(120) NOT NULL,
    telefono character varying(30),
    correo character varying(120),
    estado character varying(255) DEFAULT 'ACTIVO'::character varying NOT NULL,
    creado_en timestamp without time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp without time zone DEFAULT now() NOT NULL,
    version bigint DEFAULT 0 NOT NULL,
    max_appointments_per_day integer DEFAULT 10 NOT NULL,
    CONSTRAINT chk_doctor_estado CHECK (((estado)::text = ANY (ARRAY[('ACTIVO'::character varying)::text, ('INACTIVO'::character varying)::text])))
);


ALTER TABLE public.doctores OWNER TO mediqueue;

--
-- Name: especialidades; Type: TABLE; Schema: public; Owner: mediqueue
--

CREATE TABLE public.especialidades (
    id_especialidad uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(255),
    precio_consulta numeric(12,2) DEFAULT 150.00 NOT NULL,
    activa boolean DEFAULT true NOT NULL,
    creado_en timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.especialidades OWNER TO mediqueue;

--
-- Name: eventos_salientes; Type: TABLE; Schema: public; Owner: mediqueue
--

CREATE TABLE public.eventos_salientes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    aggregate_id uuid NOT NULL,
    aggregate_type character varying(80) NOT NULL,
    event_type character varying(120) NOT NULL,
    exchange_name character varying(160) NOT NULL,
    routing_key character varying(160) NOT NULL,
    payload text NOT NULL,
    status character varying(30) DEFAULT 'PENDIENTE'::character varying NOT NULL,
    intentos integer DEFAULT 0 NOT NULL,
    creado_en timestamp without time zone DEFAULT now() NOT NULL,
    procesado_en timestamp without time zone,
    CONSTRAINT chk_outbox_status CHECK (((status)::text = ANY (ARRAY[('PENDIENTE'::character varying)::text, ('PROCESADO'::character varying)::text])))
);


ALTER TABLE public.eventos_salientes OWNER TO mediqueue;

--
-- Name: horarios; Type: TABLE; Schema: public; Owner: mediqueue
--

CREATE TABLE public.horarios (
    id_horario uuid DEFAULT gen_random_uuid() NOT NULL,
    doctor_id uuid NOT NULL,
    dia_semana character varying(20) NOT NULL,
    hora_inicio time without time zone NOT NULL,
    hora_fin time without time zone NOT NULL,
    disponible boolean DEFAULT true NOT NULL,
    creado_en timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.horarios OWNER TO mediqueue;

--
-- Name: llaves_idempotencia; Type: TABLE; Schema: public; Owner: mediqueue
--

CREATE TABLE public.llaves_idempotencia (
    client_id uuid NOT NULL,
    servicio_origen character varying(50) NOT NULL,
    request_hash character varying(255),
    idempotency_key character varying(120) NOT NULL,
    cuerpo_respuesta text,
    creado_en timestamp without time zone DEFAULT now(),
    expira_en timestamp without time zone
);


ALTER TABLE public.llaves_idempotencia OWNER TO mediqueue;

--
-- Name: outbox_events; Type: TABLE; Schema: public; Owner: mediqueue
--

CREATE TABLE public.outbox_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    aggregate_id character varying(120) NOT NULL,
    aggregate_type character varying(80) NOT NULL,
    event_type character varying(120) NOT NULL,
    exchange_name character varying(160) NOT NULL,
    routing_key character varying(160) NOT NULL,
    payload text NOT NULL,
    status character varying(30) DEFAULT 'PENDING'::character varying NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    processed_at timestamp without time zone
);


ALTER TABLE public.outbox_events OWNER TO mediqueue;

--
-- Name: pacientes; Type: TABLE; Schema: public; Owner: mediqueue
--

CREATE TABLE public.pacientes (
    id_paciente uuid DEFAULT gen_random_uuid() NOT NULL,
    dpi character varying(255) NOT NULL,
    correo character varying(255) NOT NULL,
    nombre character varying(255) NOT NULL,
    telefono character varying(255) NOT NULL,
    estado character varying(255) DEFAULT 'ACTIVO'::character varying NOT NULL,
    creado_en timestamp without time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp without time zone DEFAULT now() NOT NULL,
    version bigint DEFAULT 0 NOT NULL,
    CONSTRAINT chk_paciente_estado CHECK (((estado)::text = ANY (ARRAY[('ACTIVO'::character varying)::text, ('INACTIVO'::character varying)::text])))
);


ALTER TABLE public.pacientes OWNER TO mediqueue;

--
-- Name: pagos; Type: TABLE; Schema: public; Owner: mediqueue
--

CREATE TABLE public.pagos (
    id_pago uuid DEFAULT gen_random_uuid() NOT NULL,
    cita_id uuid NOT NULL,
    paciente_id uuid NOT NULL,
    monto numeric(12,2) NOT NULL,
    estado character varying(30) DEFAULT 'PENDIENTE'::character varying NOT NULL,
    metodo_pago character varying(30),
    referencia character varying(120),
    idempotency_key character varying(120),
    creado_en timestamp without time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp without time zone DEFAULT now() NOT NULL,
    version bigint DEFAULT 0 NOT NULL,
    CONSTRAINT chk_pago_estado CHECK (((estado)::text = ANY (ARRAY[('PENDIENTE'::character varying)::text, ('PAGADO'::character varying)::text, ('FALLIDO'::character varying)::text, ('CANCELADO'::character varying)::text])))
);


ALTER TABLE public.pagos OWNER TO mediqueue;

--
-- Name: payments; Type: TABLE; Schema: public; Owner: mediqueue
--

CREATE TABLE public.payments (
    id bigint NOT NULL,
    appointment_id character varying(80) NOT NULL,
    patient_id character varying(80) NOT NULL,
    amount numeric(38,2) NOT NULL,
    status character varying(30) NOT NULL,
    idempotency_key character varying(120),
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    version bigint
);


ALTER TABLE public.payments OWNER TO mediqueue;

--
-- Name: payments_id_seq; Type: SEQUENCE; Schema: public; Owner: mediqueue
--

CREATE SEQUENCE public.payments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.payments_id_seq OWNER TO mediqueue;

--
-- Name: payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mediqueue
--

ALTER SEQUENCE public.payments_id_seq OWNED BY public.payments.id;


--
-- Name: payments id; Type: DEFAULT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.payments ALTER COLUMN id SET DEFAULT nextval('public.payments_id_seq'::regclass);


--
-- Data for Name: appointments; Type: TABLE DATA; Schema: public; Owner: mediqueue
--

COPY public.appointments (id, patient_id, doctor_id, appointment_date, duration_minutes, consultation_price, status, idempotency_key, created_at, updated_at, version, doctor_name, patient_name) FROM stdin;
a0bdc2ed-58eb-4f4f-ab90-9397318a7b48	952c6e62-70a9-4859-81f9-48572560a828	e1359886-af00-4be4-806a-846b2c8899c6	2026-06-03 14:00:00	30	200.00	CONFIRMED	cita-952c6e62-70a9-4859-81f9-48572560a828-e1359886-af00-4be4-806a-846b2c8899c6-2026-06-03T14:00-30	2026-06-02 07:26:05.20922	2026-06-02 07:26:16.856151	1	\N	\N
aefdba29-7f83-419d-8a01-37f3323b0728	df7e58c8-adf1-4ea2-ade8-8301ac9e2c96	22222222-2222-4222-8222-222222222222	2026-06-05 11:30:00	30	300.00	CANCELLED	cita-df7e58c8-adf1-4ea2-ade8-8301ac9e2c96-22222222-2222-4222-8222-222222222222-2026-06-05T11:30-30	2026-06-02 07:22:33.326906	2026-06-02 10:25:56.381677	2	\N	\N
6c1f8416-1384-4979-9fa9-6f8eed88b4c5	e7c7f9eb-87b7-418a-b0b1-997c52e51120	5c3d12cd-3561-4ef6-81db-3edf7c68d39d	2026-06-04 13:00:00	30	180.00	CANCELLED	cita-e7c7f9eb-87b7-418a-b0b1-997c52e51120-5c3d12cd-3561-4ef6-81db-3edf7c68d39d-2026-06-04T13:00-30	2026-06-02 08:09:28.835813	2026-06-02 10:26:05.513035	2	\N	\N
3536d46e-d04c-4661-8e77-fd66fc9b7c38	051c63a7-e758-4231-99f8-f09262fc876b	f7c5274b-259f-4edd-a1d1-84a23863bc2a	2026-06-19 14:00:00	30	220.00	CANCELLED	cita-051c63a7-e758-4231-99f8-f09262fc876b-f7c5274b-259f-4edd-a1d1-84a23863bc2a-2026-06-19T14:00-30	2026-06-02 10:28:57.646288	2026-06-02 10:33:47.990143	2	Pancracio Vielman	Panchito Barrios
d99aca75-d530-4fa4-a706-1efc148af7ab	051c63a7-e758-4231-99f8-f09262fc876b	e1359886-af00-4be4-806a-846b2c8899c6	2026-06-03 14:30:00	30	200.00	CONFIRMED	cita-051c63a7-e758-4231-99f8-f09262fc876b-e1359886-af00-4be4-806a-846b2c8899c6-2026-06-03T14:30-30	2026-06-02 10:41:45.662868	2026-06-02 10:41:52.47841	1	Juanito Ixcoy	Panchito Barrios
dd7d669e-21f9-4521-8199-f643c4f1052c	952c6e62-70a9-4859-81f9-48572560a828	f7c5274b-259f-4edd-a1d1-84a23863bc2a	2026-06-25 11:30:00	30	220.00	CANCELLED	cita-952c6e62-70a9-4859-81f9-48572560a828-f7c5274b-259f-4edd-a1d1-84a23863bc2a-2026-06-25T11:30-30	2026-06-02 11:05:47.695448	2026-06-02 11:20:31.03888	1	Pancracio Vielman	Marcela Merida
b2b16d98-ff5d-4504-81d5-095ae5ae3a37	07937abf-707e-4065-a893-a923baf72322	8d2264bf-2002-43e4-a829-6c545bad2377	2026-06-19 13:30:00	30	175.00	CANCELLED	cita-07937abf-707e-4065-a893-a923baf72322-1780399344038	2026-06-02 11:22:24.075945	2026-06-02 11:23:01.502186	1	Cliford Red	Danny Vel??squez
187f95c0-edde-4846-a3d8-877c83fb9298	df7e58c8-adf1-4ea2-ade8-8301ac9e2c96	55d9b533-3f83-4904-95e8-14823ab5ee69	2026-06-22 13:45:00	30	230.00	CONFIRMED	cita-1780400248874	2026-06-02 11:37:29.712349	2026-06-02 11:37:39.782395	1	Calamardo Pardo	Emir Gutierrez
7bc9a9a7-cb7b-481a-892a-0b86d6842180	07937abf-707e-4065-a893-a923baf72322	5c3d12cd-3561-4ef6-81db-3edf7c68d39d	2026-06-26 12:00:00	30	180.00	CANCELLED	cita-07937abf-707e-4065-a893-a923baf72322-1780399537021	2026-06-02 11:25:36.933334	2026-06-02 11:46:58.100322	1	Jack Vel??squez	Danny Vel??squez
ee27330f-0d25-4e39-9353-e494ad4338fe	07937abf-707e-4065-a893-a923baf72322	f7c5274b-259f-4edd-a1d1-84a23863bc2a	2026-06-11 10:55:00	30	220.00	CONFIRMED	cita-1780400871244	2026-06-02 11:47:52.399073	2026-06-02 11:47:58.697464	1	Pancracio Vielman	Danny Vel??squez
78d9852d-8355-4117-86d3-2e09b8c72f31	051c63a7-e758-4231-99f8-f09262fc876b	55d9b533-3f83-4904-95e8-14823ab5ee69	2026-06-12 14:00:00	30	230.00	CONFIRMED	cita-1780423875449	2026-06-02 18:11:20.085546	2026-06-02 18:11:37.014306	1	Calamardo Pardo	Panchito Barrios
ae53445a-eccb-4f23-b7d3-592e01ba4fe2	aa9e2b24-e6f4-4354-a796-156531fca09e	e1359886-af00-4be4-806a-846b2c8899c6	2026-06-10 12:00:00	30	200.00	CONFIRMED	cita-1780424185601	2026-06-02 18:16:26.210976	2026-06-02 18:18:02.10362	1	Juanito Ixcoy	Anastasio Gomez
\.


--
-- Data for Name: citas; Type: TABLE DATA; Schema: public; Owner: mediqueue
--

COPY public.citas (id_cita, paciente_id, doctor_id, horario_id, estado_cita, duracion_minutos, precio_consulta, numero_turno, motivo_consulta, observaciones, creado_en, actualizado_en, version) FROM stdin;
\.


--
-- Data for Name: doctores; Type: TABLE DATA; Schema: public; Owner: mediqueue
--

COPY public.doctores (id_doctor, especialidad_id, nombre, telefono, correo, estado, creado_en, actualizado_en, version, max_appointments_per_day) FROM stdin;
e1359886-af00-4be4-806a-846b2c8899c6	6c0189a7-89d0-4ace-9760-c1e13351a7ee	Juanito Ixcoy	67676969	juanito@gmail.com	ACTIVO	2026-06-02 07:20:27.596397	2026-06-02 07:20:27.596397	0	10
5c3d12cd-3561-4ef6-81db-3edf7c68d39d	e25e607b-58ff-4510-b964-01f6900a41e5	Jack Vel??squez	67676969	jack@gmail.com	ACTIVO	2026-06-02 08:07:17.890233	2026-06-02 08:07:17.890233	0	10
f7c5274b-259f-4edd-a1d1-84a23863bc2a	2256f698-5563-4477-b6f0-5c3d23e085b4	Pancracio Vielman	69696969	pancra@gmail.com	ACTIVO	2026-06-02 08:21:00.048946	2026-06-02 08:21:00.048946	0	10
22222222-2222-4222-8222-222222222222	3b123a2c-f09e-4b4e-8a81-7a36f975e3aa	Doctor Demo Cardiologia	44440001	doctor.demo@mediqueue.com	ACTIVO	2026-06-02 07:04:58.220159	2026-06-02 09:05:47.623699	0	10
8d2264bf-2002-43e4-a829-6c545bad2377	3f4c45d0-bc7d-4274-acc8-f44e29ec8eba	Cliford Red	45652585	clifi@gmail.com	ACTIVO	2026-06-02 10:25:24.883659	2026-06-02 10:25:24.883659	0	7
55d9b533-3f83-4904-95e8-14823ab5ee69	af80f221-7f9d-4fb7-92ec-05973b012d2a	Calamardo Pardo	67430012	\N	ACTIVO	2026-06-02 11:24:04.840456	2026-06-02 11:24:04.840456	0	7
cb51df91-b402-453f-8545-a2fcb653a0ee	20f5dd59-bece-406e-98cb-b8313715c530	Petronila Potaxio	67968567	\N	ACTIVO	2026-06-02 18:24:24.796986	2026-06-02 18:24:24.796986	0	6
\.


--
-- Data for Name: especialidades; Type: TABLE DATA; Schema: public; Owner: mediqueue
--

COPY public.especialidades (id_especialidad, nombre, descripcion, precio_consulta, activa, creado_en) FROM stdin;
aac8b979-d6f7-47e7-a736-160f9b392014	Oftalmolog??a	Salud ocular y cirug??a de visi??n	250.00	t	2026-06-02 09:07:08.871995
3f4c45d0-bc7d-4274-acc8-f44e29ec8eba	Odontolog??a	Salud dental y ortodoncia	175.00	t	2026-06-02 09:07:08.871995
20f5dd59-bece-406e-98cb-b8313715c530	Nutrici??n	Asesor??a alimenticia y diet??tica	130.00	t	2026-06-02 09:07:08.871995
8a975b90-9ae7-496f-a7d4-903905b01653	Psicolog??a	Apoyo emocional y salud mental	150.00	t	2026-06-02 09:07:08.871995
9985ab01-84f2-4e22-abe7-a326938a4283	Traumatolog??a	Lesiones ??seas y musculares	210.00	t	2026-06-02 09:07:08.871995
8f05d8d6-af06-4a6c-871d-5caf0abaaef1	Neurolog??a	Trastornos del sistema nervioso	350.00	t	2026-06-02 09:07:08.871995
90ed1999-6323-4302-a78c-f773c495ed85	Endocrinolog??a	Trastornos hormonales y metab??licos	280.00	t	2026-06-02 09:07:08.871995
af80f221-7f9d-4fb7-92ec-05973b012d2a	Urolog??a	Salud del sistema urinario	230.00	t	2026-06-02 09:07:08.871995
2b14023d-584e-4b7d-9fdd-8457432dc1a2	Gastroenterolog??a	Salud del sistema digestivo	225.00	t	2026-06-02 09:07:08.871995
e25e607b-58ff-4510-b964-01f6900a41e5	Pediatr??a	Cuidado m??dico de beb??s, ni??os y adolescentes	180.00	f	2026-06-02 07:04:58.159051
2256f698-5563-4477-b6f0-5c3d23e085b4	Ginecolog??a	Salud del sistema reproductor femenino	220.00	f	2026-06-02 07:04:58.159051
3b123a2c-f09e-4b4e-8a81-7a36f975e3aa	Cardiolog??a	Tratamiento de trastornos del coraz??n	300.00	f	2026-06-02 07:04:58.159051
6c0189a7-89d0-4ace-9760-c1e13351a7ee	Dermatolog??a	Cuidado de la piel, cabello y u??as	200.00	f	2026-06-02 07:04:58.159051
e1b2d517-af30-4aae-8bf2-0ccdd8d24ef4	Medicina General	Atenci??n m??dica primaria y preventiva	150.00	t	2026-06-02 07:01:20.290134
28922ab0-e499-4eeb-af29-aaf77abcfa63	Pediatr??a	Cuidado m??dico de beb??s, ni??os y adolescentes	180.00	t	2026-06-02 07:01:20.290134
535c4fab-1003-499b-9b9c-f4640a579024	Ginecolog??a	Salud del sistema reproductor femenino	220.00	t	2026-06-02 07:01:20.290134
3a82d378-d77f-4144-95b6-d382745e770e	Cardiolog??a	Tratamiento de trastornos del coraz??n	300.00	t	2026-06-02 07:01:20.290134
5668efca-2e1b-4e65-ab12-5b2c210d80c2	Dermatolog??a	Cuidado de la piel, cabello y u??as	200.00	t	2026-06-02 07:01:20.290134
\.


--
-- Data for Name: eventos_salientes; Type: TABLE DATA; Schema: public; Owner: mediqueue
--

COPY public.eventos_salientes (id, aggregate_id, aggregate_type, event_type, exchange_name, routing_key, payload, status, intentos, creado_en, procesado_en) FROM stdin;
\.


--
-- Data for Name: horarios; Type: TABLE DATA; Schema: public; Owner: mediqueue
--

COPY public.horarios (id_horario, doctor_id, dia_semana, hora_inicio, hora_fin, disponible, creado_en) FROM stdin;
d51f5d12-6ea7-40a0-a15a-53de220f13cd	e1359886-af00-4be4-806a-846b2c8899c6	MONDAY	08:00:00	17:00:00	t	2026-06-02 07:20:27.824424
e0560c35-0ff0-4734-aae9-9843f0c57d8c	e1359886-af00-4be4-806a-846b2c8899c6	WEDNESDAY	08:00:00	17:00:00	t	2026-06-02 07:20:27.824424
74078624-606d-407a-8185-2f0cac2f52a8	e1359886-af00-4be4-806a-846b2c8899c6	FRIDAY	08:00:00	16:00:00	t	2026-06-02 07:20:27.824424
801bc5c5-c1e6-4de8-bdf7-f59b2ecec139	5c3d12cd-3561-4ef6-81db-3edf7c68d39d	MONDAY	08:00:00	17:00:00	t	2026-06-02 08:07:18.134502
8737cab1-7dd9-4d45-976a-9a555fdc4188	5c3d12cd-3561-4ef6-81db-3edf7c68d39d	TUESDAY	08:00:00	17:00:00	t	2026-06-02 08:07:18.134502
aa03e458-098c-419e-9a34-fa0eed320986	5c3d12cd-3561-4ef6-81db-3edf7c68d39d	WEDNESDAY	08:00:00	17:00:00	t	2026-06-02 08:07:18.134502
efa98952-df8b-45f8-917c-1f6d00b4c5ff	5c3d12cd-3561-4ef6-81db-3edf7c68d39d	THURSDAY	08:00:00	17:00:00	t	2026-06-02 08:07:18.134502
11b07097-79c9-4bcd-9264-54cfce19b510	5c3d12cd-3561-4ef6-81db-3edf7c68d39d	FRIDAY	08:00:00	16:00:00	t	2026-06-02 08:07:18.134502
89dcc0b7-203c-4bf3-9c0e-cbe9216e9a80	f7c5274b-259f-4edd-a1d1-84a23863bc2a	MONDAY	08:00:00	16:00:00	t	2026-06-02 08:21:00.298012
d17bb1af-3386-45bb-9fba-56a11a0c8ddc	f7c5274b-259f-4edd-a1d1-84a23863bc2a	TUESDAY	08:00:00	16:00:00	t	2026-06-02 08:21:00.298012
e582b456-356b-4600-9cc8-3870fca7c23d	f7c5274b-259f-4edd-a1d1-84a23863bc2a	WEDNESDAY	08:00:00	16:00:00	t	2026-06-02 08:21:00.298012
0af921f8-54a8-4d1c-842e-e17f5eba4f8c	f7c5274b-259f-4edd-a1d1-84a23863bc2a	THURSDAY	08:00:00	16:00:00	t	2026-06-02 08:21:00.298012
02f504f3-8fe8-474f-9ce0-ade5cc05ec02	f7c5274b-259f-4edd-a1d1-84a23863bc2a	FRIDAY	08:00:00	15:00:00	t	2026-06-02 08:21:00.298012
33333333-3333-4333-8333-333333333331	22222222-2222-4222-8222-222222222222	MONDAY	08:00:00	12:00:00	t	2026-06-02 07:04:58.249221
33333333-3333-4333-8333-333333333332	22222222-2222-4222-8222-222222222222	WEDNESDAY	08:00:00	12:00:00	t	2026-06-02 07:04:58.249221
33333333-3333-4333-8333-333333333333	22222222-2222-4222-8222-222222222222	FRIDAY	08:00:00	12:00:00	t	2026-06-02 07:04:58.249221
6cb891ad-3ba9-416a-9bcb-9f2c89c376a6	8d2264bf-2002-43e4-a829-6c545bad2377	MONDAY	08:00:00	18:00:00	t	2026-06-02 10:25:25.27638
da15d6f3-52b2-4378-98ff-300a37249fe7	8d2264bf-2002-43e4-a829-6c545bad2377	TUESDAY	08:00:00	18:00:00	t	2026-06-02 10:25:25.27638
41793267-5048-4f8c-bac8-abb427e42576	8d2264bf-2002-43e4-a829-6c545bad2377	WEDNESDAY	08:00:00	18:00:00	t	2026-06-02 10:25:25.27638
dad1535b-58af-40a0-8cfa-7ccefb72d546	8d2264bf-2002-43e4-a829-6c545bad2377	THURSDAY	08:00:00	18:00:00	t	2026-06-02 10:25:25.27638
7b858af2-ff90-44ce-81b5-83adc9f02ed7	8d2264bf-2002-43e4-a829-6c545bad2377	FRIDAY	08:00:00	17:00:00	t	2026-06-02 10:25:25.27638
1a3ca4d9-77f7-46d4-a824-aceeea34f677	55d9b533-3f83-4904-95e8-14823ab5ee69	MONDAY	08:00:00	18:00:00	t	2026-06-02 11:24:04.809282
0f35535d-d464-43af-a1cf-d35bafec4ca5	55d9b533-3f83-4904-95e8-14823ab5ee69	FRIDAY	08:00:00	18:00:00	t	2026-06-02 11:24:04.809282
9a4321a7-7161-4184-8ed3-b221d5babb7b	cb51df91-b402-453f-8545-a2fcb653a0ee	TUESDAY	08:00:00	20:00:00	t	2026-06-02 18:24:25.053569
f7247280-7263-4d9f-8f80-7ed59d1ad68c	cb51df91-b402-453f-8545-a2fcb653a0ee	THURSDAY	08:00:00	20:00:00	t	2026-06-02 18:24:25.053569
e313cf98-06ec-40a9-80a1-9cb329dac598	cb51df91-b402-453f-8545-a2fcb653a0ee	SATURDAY	08:00:00	18:00:00	t	2026-06-02 18:24:25.053569
\.


--
-- Data for Name: llaves_idempotencia; Type: TABLE DATA; Schema: public; Owner: mediqueue
--

COPY public.llaves_idempotencia (client_id, servicio_origen, request_hash, idempotency_key, cuerpo_respuesta, creado_en, expira_en) FROM stdin;
\.


--
-- Data for Name: outbox_events; Type: TABLE DATA; Schema: public; Owner: mediqueue
--

COPY public.outbox_events (id, aggregate_id, aggregate_type, event_type, exchange_name, routing_key, payload, status, attempts, created_at, processed_at) FROM stdin;
30167b93-d354-4570-a636-5224fd997e5f	aefdba29-7f83-419d-8a01-37f3323b0728	APPOINTMENT	APPOINTMENT_CREATED	mediqueue.appointments.exchange	appointments.created	{"appointmentId":"aefdba29-7f83-419d-8a01-37f3323b0728","patientId":"df7e58c8-adf1-4ea2-ade8-8301ac9e2c96","doctorId":"22222222-2222-4222-8222-222222222222","appointmentDate":"2026-06-05T11:30:00","status":"PENDING","eventType":"APPOINTMENT_CREATED","occurredAt":"2026-06-02T07:22:33.336908764"}	SENT	0	2026-06-02 07:22:33.341786	2026-06-02 07:22:34.022333
78ba5c5c-b9b9-4b18-80ed-1b945c374d34	1	PAYMENT	PAYMENT_SUCCESS	mediqueue.payments.exchange	payments.success	{"paymentId":1,"appointmentId":"aefdba29-7f83-419d-8a01-37f3323b0728","patientId":"df7e58c8-adf1-4ea2-ade8-8301ac9e2c96","amount":300.00,"status":"SUCCESS","eventType":"PAYMENT_SUCCESS","occurredAt":"2026-06-02T07:22:59.177146197"}	SENT	0	2026-06-02 07:22:59.186051	2026-06-02 07:23:00.671951
1873ca49-b869-4e17-967c-90ae6980b444	a0bdc2ed-58eb-4f4f-ab90-9397318a7b48	APPOINTMENT	APPOINTMENT_CREATED	mediqueue.appointments.exchange	appointments.created	{"appointmentId":"a0bdc2ed-58eb-4f4f-ab90-9397318a7b48","patientId":"952c6e62-70a9-4859-81f9-48572560a828","doctorId":"e1359886-af00-4be4-806a-846b2c8899c6","appointmentDate":"2026-06-03T14:00:00","status":"PENDING","eventType":"APPOINTMENT_CREATED","occurredAt":"2026-06-02T07:26:05.209546173"}	SENT	0	2026-06-02 07:26:05.210075	2026-06-02 07:26:06.262687
c6fa938f-fd68-470b-a8b4-bc7e8e330583	2	PAYMENT	PAYMENT_SUCCESS	mediqueue.payments.exchange	payments.success	{"paymentId":2,"appointmentId":"a0bdc2ed-58eb-4f4f-ab90-9397318a7b48","patientId":"952c6e62-70a9-4859-81f9-48572560a828","amount":200.00,"status":"SUCCESS","eventType":"PAYMENT_SUCCESS","occurredAt":"2026-06-02T07:26:16.931103778"}	SENT	0	2026-06-02 07:26:16.931648	2026-06-02 07:26:18.530464
e159a28b-8b08-4d8c-a380-b0c8a02db30d	6c1f8416-1384-4979-9fa9-6f8eed88b4c5	APPOINTMENT	APPOINTMENT_CREATED	mediqueue.appointments.exchange	appointments.created	{"appointmentId":"6c1f8416-1384-4979-9fa9-6f8eed88b4c5","patientId":"e7c7f9eb-87b7-418a-b0b1-997c52e51120","doctorId":"5c3d12cd-3561-4ef6-81db-3edf7c68d39d","appointmentDate":"2026-06-04T13:00:00","status":"PENDING","eventType":"APPOINTMENT_CREATED","occurredAt":"2026-06-02T08:09:28.840805641"}	SENT	0	2026-06-02 08:09:28.844995	2026-06-02 08:09:30.841381
62818eaf-1ea5-4316-bd1a-4f2a6d6bafbd	3	PAYMENT	PAYMENT_SUCCESS	mediqueue.payments.exchange	payments.success	{"paymentId":3,"appointmentId":"6c1f8416-1384-4979-9fa9-6f8eed88b4c5","patientId":"e7c7f9eb-87b7-418a-b0b1-997c52e51120","amount":180.00,"status":"SUCCESS","eventType":"PAYMENT_SUCCESS","occurredAt":"2026-06-02T08:09:44.530783366"}	SENT	0	2026-06-02 08:09:44.540548	2026-06-02 08:09:46.048275
ac5b7c7a-50cb-4e73-9d96-9bd09c27cc72	aefdba29-7f83-419d-8a01-37f3323b0728	APPOINTMENT	APPOINTMENT_CANCELLED	mediqueue.appointments.exchange	appointments.cancelled	{"appointmentId":"aefdba29-7f83-419d-8a01-37f3323b0728","patientId":"df7e58c8-adf1-4ea2-ade8-8301ac9e2c96","doctorId":"22222222-2222-4222-8222-222222222222","appointmentDate":"2026-06-05T11:30:00","status":"CANCELLED","eventType":"APPOINTMENT_CANCELLED","occurredAt":"2026-06-02T10:25:56.34659287"}	SENT	0	2026-06-02 10:25:56.363428	2026-06-02 10:25:58.113274
87f239e6-5c0a-4686-81ce-d255d81ecc83	6c1f8416-1384-4979-9fa9-6f8eed88b4c5	APPOINTMENT	APPOINTMENT_CANCELLED	mediqueue.appointments.exchange	appointments.cancelled	{"appointmentId":"6c1f8416-1384-4979-9fa9-6f8eed88b4c5","patientId":"e7c7f9eb-87b7-418a-b0b1-997c52e51120","doctorId":"5c3d12cd-3561-4ef6-81db-3edf7c68d39d","appointmentDate":"2026-06-04T13:00:00","status":"CANCELLED","eventType":"APPOINTMENT_CANCELLED","occurredAt":"2026-06-02T10:26:05.512083341"}	SENT	0	2026-06-02 10:26:05.512685	2026-06-02 10:26:06.372656
2f411abf-cd85-43d6-a73b-0eeea45b7448	3536d46e-d04c-4661-8e77-fd66fc9b7c38	APPOINTMENT	APPOINTMENT_CREATED	mediqueue.appointments.exchange	appointments.created	{"appointmentId":"3536d46e-d04c-4661-8e77-fd66fc9b7c38","patientId":"051c63a7-e758-4231-99f8-f09262fc876b","doctorId":"f7c5274b-259f-4edd-a1d1-84a23863bc2a","appointmentDate":"2026-06-19T14:00:00","status":"PENDING","eventType":"APPOINTMENT_CREATED","occurredAt":"2026-06-02T10:28:57.646617202"}	SENT	0	2026-06-02 10:28:57.646922	2026-06-02 10:28:58.839871
e4c8ade2-5188-403e-ae1f-3f1907745b2f	4	PAYMENT	PAYMENT_SUCCESS	mediqueue.payments.exchange	payments.success	{"paymentId":4,"appointmentId":"3536d46e-d04c-4661-8e77-fd66fc9b7c38","patientId":"051c63a7-e758-4231-99f8-f09262fc876b","amount":220.00,"status":"SUCCESS","eventType":"PAYMENT_SUCCESS","occurredAt":"2026-06-02T10:29:13.4219202"}	SENT	0	2026-06-02 10:29:13.43256	2026-06-02 10:29:13.94304
7bbc675a-21e0-49e4-9ac3-09385286ade9	3536d46e-d04c-4661-8e77-fd66fc9b7c38	APPOINTMENT	APPOINTMENT_CANCELLED	mediqueue.appointments.exchange	appointments.cancelled	{"appointmentId":"3536d46e-d04c-4661-8e77-fd66fc9b7c38","patientId":"051c63a7-e758-4231-99f8-f09262fc876b","doctorId":"f7c5274b-259f-4edd-a1d1-84a23863bc2a","appointmentDate":"2026-06-19T14:00:00","status":"CANCELLED","eventType":"APPOINTMENT_CANCELLED","occurredAt":"2026-06-02T10:33:47.98930751"}	SENT	0	2026-06-02 10:33:47.989739	2026-06-02 10:33:49.751127
828e3d39-2522-40cf-8ed6-07dee0a6a66a	d99aca75-d530-4fa4-a706-1efc148af7ab	APPOINTMENT	APPOINTMENT_CREATED	mediqueue.appointments.exchange	appointments.created	{"appointmentId":"d99aca75-d530-4fa4-a706-1efc148af7ab","patientId":"051c63a7-e758-4231-99f8-f09262fc876b","doctorId":"e1359886-af00-4be4-806a-846b2c8899c6","appointmentDate":"2026-06-03T14:30:00","status":"PENDING","eventType":"APPOINTMENT_CREATED","occurredAt":"2026-06-02T10:41:45.663056604"}	SENT	0	2026-06-02 10:41:45.663332	2026-06-02 10:41:48.043313
004fe517-bf7f-4cb5-9372-a9647c0fcecd	5	PAYMENT	PAYMENT_SUCCESS	mediqueue.payments.exchange	payments.success	{"paymentId":5,"appointmentId":"d99aca75-d530-4fa4-a706-1efc148af7ab","patientId":"051c63a7-e758-4231-99f8-f09262fc876b","amount":200.00,"status":"SUCCESS","eventType":"PAYMENT_SUCCESS","occurredAt":"2026-06-02T10:41:52.554106011"}	SENT	0	2026-06-02 10:41:52.554888	2026-06-02 10:41:53.139458
2da1372a-38de-4359-9844-6eb62433239e	dd7d669e-21f9-4521-8199-f643c4f1052c	APPOINTMENT	APPOINTMENT_CREATED	mediqueue.appointments.exchange	appointments.created	{"appointmentId":"dd7d669e-21f9-4521-8199-f643c4f1052c","patientId":"952c6e62-70a9-4859-81f9-48572560a828","doctorId":"f7c5274b-259f-4edd-a1d1-84a23863bc2a","appointmentDate":"2026-06-25T11:30:00","status":"PENDING","eventType":"APPOINTMENT_CREATED","occurredAt":"2026-06-02T11:05:47.705932385"}	SENT	0	2026-06-02 11:05:47.714297	2026-06-02 11:05:48.821747
d0146116-182b-4ded-a8ae-d9b78edf2dcf	dd7d669e-21f9-4521-8199-f643c4f1052c	APPOINTMENT	APPOINTMENT_CANCELLED	mediqueue.appointments.exchange	appointments.cancelled	{"appointmentId":"dd7d669e-21f9-4521-8199-f643c4f1052c","patientId":"952c6e62-70a9-4859-81f9-48572560a828","doctorId":"f7c5274b-259f-4edd-a1d1-84a23863bc2a","appointmentDate":"2026-06-25T11:30:00","status":"CANCELLED","eventType":"APPOINTMENT_CANCELLED","occurredAt":"2026-06-02T11:20:31.023237541"}	SENT	0	2026-06-02 11:20:31.034729	2026-06-02 11:20:31.977407
27dc1f52-8b26-43fa-9dea-94b2f2577ca9	b2b16d98-ff5d-4504-81d5-095ae5ae3a37	APPOINTMENT	APPOINTMENT_CREATED	mediqueue.appointments.exchange	appointments.created	{"appointmentId":"b2b16d98-ff5d-4504-81d5-095ae5ae3a37","patientId":"07937abf-707e-4065-a893-a923baf72322","doctorId":"8d2264bf-2002-43e4-a829-6c545bad2377","appointmentDate":"2026-06-19T13:30:00","status":"PENDING","eventType":"APPOINTMENT_CREATED","occurredAt":"2026-06-02T11:22:24.076269559"}	SENT	0	2026-06-02 11:22:24.076661	2026-06-02 11:22:25.17294
3941c130-fb71-4cfc-9109-60e345383e35	b2b16d98-ff5d-4504-81d5-095ae5ae3a37	APPOINTMENT	APPOINTMENT_CANCELLED	mediqueue.appointments.exchange	appointments.cancelled	{"appointmentId":"b2b16d98-ff5d-4504-81d5-095ae5ae3a37","patientId":"07937abf-707e-4065-a893-a923baf72322","doctorId":"8d2264bf-2002-43e4-a829-6c545bad2377","appointmentDate":"2026-06-19T13:30:00","status":"CANCELLED","eventType":"APPOINTMENT_CANCELLED","occurredAt":"2026-06-02T11:23:01.501460587"}	SENT	0	2026-06-02 11:23:01.501837	2026-06-02 11:23:02.195172
47182090-2ae1-4c57-8cbf-4c4bb5507515	7bc9a9a7-cb7b-481a-892a-0b86d6842180	APPOINTMENT	APPOINTMENT_CREATED	mediqueue.appointments.exchange	appointments.created	{"appointmentId":"7bc9a9a7-cb7b-481a-892a-0b86d6842180","patientId":"07937abf-707e-4065-a893-a923baf72322","doctorId":"5c3d12cd-3561-4ef6-81db-3edf7c68d39d","appointmentDate":"2026-06-26T12:00:00","status":"PENDING","eventType":"APPOINTMENT_CREATED","occurredAt":"2026-06-02T11:25:36.933554392"}	SENT	0	2026-06-02 11:25:36.934071	2026-06-02 11:25:39.158828
449b8aa2-7f14-4ba8-9f56-8c60b2c0aeb1	187f95c0-edde-4846-a3d8-877c83fb9298	APPOINTMENT	APPOINTMENT_CREATED	mediqueue.appointments.exchange	appointments.created	{"appointmentId":"187f95c0-edde-4846-a3d8-877c83fb9298","patientId":"df7e58c8-adf1-4ea2-ade8-8301ac9e2c96","doctorId":"55d9b533-3f83-4904-95e8-14823ab5ee69","appointmentDate":"2026-06-22T13:45:00","status":"PENDING","eventType":"APPOINTMENT_CREATED","occurredAt":"2026-06-02T11:37:29.722338328"}	SENT	0	2026-06-02 11:37:29.730187	2026-06-02 11:37:30.330804
e8a7e98a-4086-42a7-a2a6-bab915a0015f	6	PAYMENT	PAYMENT_SUCCESS	mediqueue.payments.exchange	payments.success	{"paymentId":6,"appointmentId":"187f95c0-edde-4846-a3d8-877c83fb9298","patientId":"df7e58c8-adf1-4ea2-ade8-8301ac9e2c96","amount":230.00,"status":"SUCCESS","eventType":"PAYMENT_SUCCESS","occurredAt":"2026-06-02T11:37:39.819651007"}	SENT	0	2026-06-02 11:37:39.845299	2026-06-02 11:37:40.395229
1a59b14f-74c4-4c04-be0d-f79e3ad17771	7bc9a9a7-cb7b-481a-892a-0b86d6842180	APPOINTMENT	APPOINTMENT_CANCELLED	mediqueue.appointments.exchange	appointments.cancelled	{"appointmentId":"7bc9a9a7-cb7b-481a-892a-0b86d6842180","patientId":"07937abf-707e-4065-a893-a923baf72322","doctorId":"5c3d12cd-3561-4ef6-81db-3edf7c68d39d","appointmentDate":"2026-06-26T12:00:00","status":"CANCELLED","eventType":"APPOINTMENT_CANCELLED","occurredAt":"2026-06-02T11:46:58.098780265"}	SENT	0	2026-06-02 11:46:58.099457	2026-06-02 11:46:58.36411
371211e3-021b-4b83-a32b-322a7ba46ee5	ee27330f-0d25-4e39-9353-e494ad4338fe	APPOINTMENT	APPOINTMENT_CREATED	mediqueue.appointments.exchange	appointments.created	{"appointmentId":"ee27330f-0d25-4e39-9353-e494ad4338fe","patientId":"07937abf-707e-4065-a893-a923baf72322","doctorId":"f7c5274b-259f-4edd-a1d1-84a23863bc2a","appointmentDate":"2026-06-11T10:55:00","status":"PENDING","eventType":"APPOINTMENT_CREATED","occurredAt":"2026-06-02T11:47:52.420026842"}	SENT	0	2026-06-02 11:47:52.430147	2026-06-02 11:47:53.875114
b16ac869-d3a5-4b66-a011-9ba7b8c8d7ef	7	PAYMENT	PAYMENT_SUCCESS	mediqueue.payments.exchange	payments.success	{"paymentId":7,"appointmentId":"ee27330f-0d25-4e39-9353-e494ad4338fe","patientId":"07937abf-707e-4065-a893-a923baf72322","amount":220.00,"status":"SUCCESS","eventType":"PAYMENT_SUCCESS","occurredAt":"2026-06-02T11:47:58.734158999"}	SENT	0	2026-06-02 11:47:58.745965	2026-06-02 11:47:58.915045
452051d8-6825-4eb4-947c-34c970d7a05d	78d9852d-8355-4117-86d3-2e09b8c72f31	APPOINTMENT	APPOINTMENT_CREATED	mediqueue.appointments.exchange	appointments.created	{"appointmentId":"78d9852d-8355-4117-86d3-2e09b8c72f31","patientId":"051c63a7-e758-4231-99f8-f09262fc876b","doctorId":"55d9b533-3f83-4904-95e8-14823ab5ee69","appointmentDate":"2026-06-12T14:00:00","status":"PENDING","eventType":"APPOINTMENT_CREATED","occurredAt":"2026-06-02T18:11:20.086052725"}	SENT	0	2026-06-02 18:11:20.086891	2026-06-02 18:11:20.891358
1ae08722-bd38-4f25-9a40-661be0965ed3	40	PAYMENT	PAYMENT_SUCCESS	mediqueue.payments.exchange	payments.success	{"paymentId":40,"appointmentId":"78d9852d-8355-4117-86d3-2e09b8c72f31","patientId":"051c63a7-e758-4231-99f8-f09262fc876b","amount":230.00,"status":"SUCCESS","eventType":"PAYMENT_SUCCESS","occurredAt":"2026-06-02T18:11:37.106061766"}	SENT	0	2026-06-02 18:11:37.124478	2026-06-02 18:11:41.149597
97b921a9-e953-46ee-b00e-49c86826f62b	ae53445a-eccb-4f23-b7d3-592e01ba4fe2	APPOINTMENT	APPOINTMENT_CREATED	mediqueue.appointments.exchange	appointments.created	{"appointmentId":"ae53445a-eccb-4f23-b7d3-592e01ba4fe2","patientId":"aa9e2b24-e6f4-4354-a796-156531fca09e","doctorId":"e1359886-af00-4be4-806a-846b2c8899c6","appointmentDate":"2026-06-10T12:00:00","status":"PENDING","eventType":"APPOINTMENT_CREATED","occurredAt":"2026-06-02T18:16:26.211266968"}	SENT	0	2026-06-02 18:16:26.211702	2026-06-02 18:16:27.330409
f6a62ae8-e70e-406a-afde-7ebdf82bf4a0	41	PAYMENT	PAYMENT_SUCCESS	mediqueue.payments.exchange	payments.success	{"paymentId":41,"appointmentId":"ae53445a-eccb-4f23-b7d3-592e01ba4fe2","patientId":"aa9e2b24-e6f4-4354-a796-156531fca09e","amount":200.00,"status":"SUCCESS","eventType":"PAYMENT_SUCCESS","occurredAt":"2026-06-02T18:18:02.200084095"}	SENT	0	2026-06-02 18:18:02.201102	2026-06-02 18:18:06.512288
\.


--
-- Data for Name: pacientes; Type: TABLE DATA; Schema: public; Owner: mediqueue
--

COPY public.pacientes (id_paciente, dpi, correo, nombre, telefono, estado, creado_en, actualizado_en, version) FROM stdin;
07937abf-707e-4065-a893-a923baf72322	1254879541632	danny@gmail.com	Danny Vel??squez	45986315	ACTIVO	2026-06-02 07:14:00.939416	2026-06-02 07:14:00.939416	0
952c6e62-70a9-4859-81f9-48572560a828	1234567890123	marmer711@gmail.com	Marcela Merida	34562122	ACTIVO	2026-06-02 07:16:21.888273	2026-06-02 07:16:21.888273	0
df7e58c8-adf1-4ea2-ade8-8301ac9e2c96	32165498732145	emir@gmail.com	Emir Gutierrez	54786767	ACTIVO	2026-06-02 07:17:37.66144	2026-06-02 07:17:37.66144	0
e7c7f9eb-87b7-418a-b0b1-997c52e51120	1234659851236	bruno@gmail.com	Bruno Gutierrez	67676767	ACTIVO	2026-06-02 08:06:01.050843	2026-06-02 08:06:01.050843	0
11111111-1111-4111-8111-111111111111	9000000000001	paciente.demo@mediqueue.com	Paciente Demo	55550001	ACTIVO	2026-06-02 07:04:58.187129	2026-06-02 09:05:47.601547	0
051c63a7-e758-4231-99f8-f09262fc876b	1254365241458	panchis@gmail.com	Panchito Barrios	87964512	ACTIVO	2026-06-02 10:10:40.808075	2026-06-02 10:10:40.808075	0
aa9e2b24-e6f4-4354-a796-156531fca09e	7989654123265	anastasio@gmail.com	Anastasio Gomez	45789612	ACTIVO	2026-06-02 17:39:44.082569	2026-06-02 17:39:44.082569	0
ec5d3f53-3156-4236-ab92-10e5918f2f77	93778434000000113	stress-37784340-113@mediqueue.test	Paciente Stress 37784340-113	55000113	ACTIVO	2026-06-02 22:03:20.429185	2026-06-02 22:03:20.429185	0
15995862-0885-4e28-a4f7-8a93aa68e4f2	93778432700000081	stress-37784327-81@mediqueue.test	Paciente Stress 37784327-81	55000081	ACTIVO	2026-06-02 22:03:20.429256	2026-06-02 22:03:20.429256	0
aca17746-fd30-4b06-910d-b1825471eeec	93778434300000094	stress-37784343-94@mediqueue.test	Paciente Stress 37784343-94	55000094	ACTIVO	2026-06-02 22:03:20.429295	2026-06-02 22:03:20.429295	0
4c6bda4a-6665-43c0-90f8-9746204a86f2	93778431600000174	stress-37784316-174@mediqueue.test	Paciente Stress 37784316-174	55000174	ACTIVO	2026-06-02 22:03:20.436752	2026-06-02 22:03:20.436752	0
507c6f17-cdfd-440c-bb10-1a3afa463002	93778430600000165	stress-37784306-165@mediqueue.test	Paciente Stress 37784306-165	55000165	ACTIVO	2026-06-02 22:03:20.443353	2026-06-02 22:03:20.443353	0
9c06cbd2-bc23-4ee3-aced-1b000f423625	93778433100000219	stress-37784331-219@mediqueue.test	Paciente Stress 37784331-219	55000219	ACTIVO	2026-06-02 22:03:20.443288	2026-06-02 22:03:20.443288	0
c445c6e1-fa20-4262-9b40-00a445d3c1a8	93778433200000092	stress-37784332-92@mediqueue.test	Paciente Stress 37784332-92	55000092	ACTIVO	2026-06-02 22:03:20.443295	2026-06-02 22:03:20.443295	0
6452da79-2202-4df2-9530-3670f774e251	93778432400000200	stress-37784324-200@mediqueue.test	Paciente Stress 37784324-200	55000200	ACTIVO	2026-06-02 22:03:20.443172	2026-06-02 22:03:20.443172	0
c875784f-1c2d-45c2-98d3-b92b6fc80b21	93778434300000102	stress-37784343-102@mediqueue.test	Paciente Stress 37784343-102	55000102	ACTIVO	2026-06-02 22:03:20.443328	2026-06-02 22:03:20.443328	0
ff903b05-5217-41bc-906d-9fdd7b13359f	93778431600000314	stress-37784316-314@mediqueue.test	Paciente Stress 37784316-314	55000314	ACTIVO	2026-06-02 22:03:20.445868	2026-06-02 22:03:20.445868	0
ea405b7d-9507-4d70-b283-e465ee4a3864	93778434100000048	stress-37784341-48@mediqueue.test	Paciente Stress 37784341-48	55000048	ACTIVO	2026-06-02 22:03:20.518588	2026-06-02 22:03:20.518588	0
e7b7a2e7-1b08-4e09-be33-1003e76d0d6f	93778434600000211	stress-37784346-211@mediqueue.test	Paciente Stress 37784346-211	55000211	ACTIVO	2026-06-02 22:03:20.518592	2026-06-02 22:03:20.518592	0
350b87ea-82c2-4da3-894d-cf2e74b92880	93778433000000120	stress-37784330-120@mediqueue.test	Paciente Stress 37784330-120	55000120	ACTIVO	2026-06-02 22:03:20.528732	2026-06-02 22:03:20.528732	0
dad52fc8-6b32-4b1b-bf3e-2f7e15150496	93778434400000197	stress-37784344-197@mediqueue.test	Paciente Stress 37784344-197	55000197	ACTIVO	2026-06-02 22:03:20.581593	2026-06-02 22:03:20.581593	0
7021cad6-4f03-453a-b109-747bccccab69	93778433100000280	stress-37784331-280@mediqueue.test	Paciente Stress 37784331-280	55000280	ACTIVO	2026-06-02 22:03:20.611976	2026-06-02 22:03:20.611976	0
b6e03d59-ad24-44c9-8307-4a8483607b08	93778430600000032	stress-37784306-32@mediqueue.test	Paciente Stress 37784306-32	55000032	ACTIVO	2026-06-02 22:03:20.639626	2026-06-02 22:03:20.639626	0
c3bcd6ef-b2b4-4b37-9c2f-b6e49cfcc319	93778431500000242	stress-37784315-242@mediqueue.test	Paciente Stress 37784315-242	55000242	ACTIVO	2026-06-02 22:03:20.659897	2026-06-02 22:03:20.659897	0
fd2a5d4f-0f84-43d7-9077-55761a05935b	93778433000000358	stress-37784330-358@mediqueue.test	Paciente Stress 37784330-358	55000358	ACTIVO	2026-06-02 22:03:20.7035	2026-06-02 22:03:20.7035	0
3afd5ab5-af49-4e21-a737-036075efb42d	93778433100000085	stress-37784331-85@mediqueue.test	Paciente Stress 37784331-85	55000085	ACTIVO	2026-06-02 22:03:20.703442	2026-06-02 22:03:20.703442	0
65884c58-53b8-491e-b227-42885e820720	93778431600000400	stress-37784316-400@mediqueue.test	Paciente Stress 37784316-400	55000400	ACTIVO	2026-06-02 22:03:21.397865	2026-06-02 22:03:21.397865	0
63fb86b9-58ad-43c7-bdde-40ae155d2ece	93778430200000397	stress-37784302-397@mediqueue.test	Paciente Stress 37784302-397	55000397	ACTIVO	2026-06-02 22:03:21.6012	2026-06-02 22:03:21.6012	0
515b1e1f-a5c7-42f5-924f-fa2f3f21d983	93778434000000548	stress-37784340-548@mediqueue.test	Paciente Stress 37784340-548	55000548	ACTIVO	2026-06-02 22:03:22.771964	2026-06-02 22:03:22.771964	0
a48a5b79-eca9-4578-ab63-7263abc41aa7	93778431600000536	stress-37784316-536@mediqueue.test	Paciente Stress 37784316-536	55000536	ACTIVO	2026-06-02 22:03:22.785686	2026-06-02 22:03:22.785686	0
c889e05c-52a4-498e-bbce-35c845c99d18	93778434100000573	stress-37784341-573@mediqueue.test	Paciente Stress 37784341-573	55000573	ACTIVO	2026-06-02 22:03:22.87713	2026-06-02 22:03:22.87713	0
5bf9cc17-67c5-4954-a88e-f73d81d46fc3	93778431900000587	stress-37784319-587@mediqueue.test	Paciente Stress 37784319-587	55000587	ACTIVO	2026-06-02 22:03:23.181006	2026-06-02 22:03:23.181006	0
7df03afc-c7fa-467a-913e-8314b7f92b5f	93778430500000628	stress-37784305-628@mediqueue.test	Paciente Stress 37784305-628	55000628	ACTIVO	2026-06-02 22:03:23.715275	2026-06-02 22:03:23.715275	0
bbe8a7f6-ac49-41e6-8aec-d38798425194	93778431500000645	stress-37784315-645@mediqueue.test	Paciente Stress 37784315-645	55000645	ACTIVO	2026-06-02 22:03:23.844647	2026-06-02 22:03:23.844647	0
8b6475db-cca5-4c39-8f79-cba337cadd4e	93778431600000667	stress-37784316-667@mediqueue.test	Paciente Stress 37784316-667	55000667	ACTIVO	2026-06-02 22:03:24.002549	2026-06-02 22:03:24.002549	0
2d7eb9da-50e1-4f35-b37d-ad31d56bad70	93778434300000655	stress-37784343-655@mediqueue.test	Paciente Stress 37784343-655	55000655	ACTIVO	2026-06-02 22:03:24.008529	2026-06-02 22:03:24.008529	0
0c45ff0c-3a34-4399-b126-27e32df0ba79	93778429900000666	stress-37784299-666@mediqueue.test	Paciente Stress 37784299-666	55000666	ACTIVO	2026-06-02 22:03:24.012705	2026-06-02 22:03:24.012705	0
a924efda-1cc8-4e7f-8fe5-e53021b7b476	93778431500000721	stress-37784315-721@mediqueue.test	Paciente Stress 37784315-721	55000721	ACTIVO	2026-06-02 22:03:24.623041	2026-06-02 22:03:24.623041	0
c0170320-bf45-4e06-a53e-68678814751c	93778430600000735	stress-37784306-735@mediqueue.test	Paciente Stress 37784306-735	55000735	ACTIVO	2026-06-02 22:03:24.74273	2026-06-02 22:03:24.74273	0
d47b86f7-fd52-49a8-9cb5-51c5df2fb356	93778431600000795	stress-37784316-795@mediqueue.test	Paciente Stress 37784316-795	55000795	ACTIVO	2026-06-02 22:03:25.652611	2026-06-02 22:03:25.652611	0
050dccc3-964b-4e06-81e9-27e16dd03db9	93778429900000805	stress-37784299-805@mediqueue.test	Paciente Stress 37784299-805	55000805	ACTIVO	2026-06-02 22:03:25.832071	2026-06-02 22:03:25.832071	0
a912daf5-0144-4395-aeb2-a5a7323078bd	93778433100000814	stress-37784331-814@mediqueue.test	Paciente Stress 37784331-814	55000814	ACTIVO	2026-06-02 22:03:25.880689	2026-06-02 22:03:25.880689	0
367f54e5-4f66-4358-8df0-81145ed79590	93778431400000820	stress-37784314-820@mediqueue.test	Paciente Stress 37784314-820	55000820	ACTIVO	2026-06-02 22:03:25.906798	2026-06-02 22:03:25.906798	0
f3e19618-0a22-4c3f-b995-32d629a0e261	93778430600000863	stress-37784306-863@mediqueue.test	Paciente Stress 37784306-863	55000863	ACTIVO	2026-06-02 22:03:26.421276	2026-06-02 22:03:26.421276	0
0a1ac846-4393-4aed-ac11-3f4a4242a94d	93778430800000860	stress-37784308-860@mediqueue.test	Paciente Stress 37784308-860	55000860	ACTIVO	2026-06-02 22:03:26.432549	2026-06-02 22:03:26.432549	0
246c8d0f-1d45-499e-ba92-28d0e6e67fe4	93778429900000879	stress-37784299-879@mediqueue.test	Paciente Stress 37784299-879	55000879	ACTIVO	2026-06-02 22:03:26.609296	2026-06-02 22:03:26.609296	0
1e454ba3-f840-44e6-a15d-87bd75e71e3d	93778434000000887	stress-37784340-887@mediqueue.test	Paciente Stress 37784340-887	55000887	ACTIVO	2026-06-02 22:03:26.705303	2026-06-02 22:03:26.705303	0
09c43037-3653-4727-aefc-6b38c4d83dd6	93778430500000893	stress-37784305-893@mediqueue.test	Paciente Stress 37784305-893	55000893	ACTIVO	2026-06-02 22:03:26.710842	2026-06-02 22:03:26.710842	0
9ed7b8a3-3aa9-4b4e-b021-c24c8e6a9be3	93778434000000909	stress-37784340-909@mediqueue.test	Paciente Stress 37784340-909	55000909	ACTIVO	2026-06-02 22:03:26.870011	2026-06-02 22:03:26.870011	0
9a86168b-5a53-4cd8-a2d6-d57acea76cf8	93778434600000919	stress-37784346-919@mediqueue.test	Paciente Stress 37784346-919	55000919	ACTIVO	2026-06-02 22:03:27.030093	2026-06-02 22:03:27.030093	0
40d9ea57-bd22-4b6e-ba01-44fb145a3088	93778434100000957	stress-37784341-957@mediqueue.test	Paciente Stress 37784341-957	55000957	ACTIVO	2026-06-02 22:03:27.501954	2026-06-02 22:03:27.501954	0
1ac1fb35-2785-46f4-ad12-ca2493bcb7ad	93778432400001001	stress-37784324-1001@mediqueue.test	Paciente Stress 37784324-1001	55001001	ACTIVO	2026-06-02 22:03:27.80674	2026-06-02 22:03:27.80674	0
1c9a76d8-1629-4066-8b86-1f8d193b029b	93778432200001034	stress-37784322-1034@mediqueue.test	Paciente Stress 37784322-1034	55001034	ACTIVO	2026-06-02 22:03:28.289881	2026-06-02 22:03:28.289881	0
eb727fff-bdc8-4ed8-bb82-c5f5170f2914	93778431600001137	stress-37784316-1137@mediqueue.test	Paciente Stress 37784316-1137	55001137	ACTIVO	2026-06-02 22:03:28.995761	2026-06-02 22:03:28.995761	0
65f309ec-a227-4333-beb2-195c0001a110	93778431500001161	stress-37784315-1161@mediqueue.test	Paciente Stress 37784315-1161	55001161	ACTIVO	2026-06-02 22:03:29.372521	2026-06-02 22:03:29.372521	0
3b81eb7d-6637-431f-a7b0-bc01d8b843ec	93778431600001197	stress-37784316-1197@mediqueue.test	Paciente Stress 37784316-1197	55001197	ACTIVO	2026-06-02 22:03:29.606615	2026-06-02 22:03:29.606615	0
307fdc8f-c7fa-437f-a70e-0e959a402eda	93778434100001342	stress-37784341-1342@mediqueue.test	Paciente Stress 37784341-1342	55001342	ACTIVO	2026-06-02 22:03:31.066295	2026-06-02 22:03:31.066295	0
432c6a9f-3397-4758-a1e4-e16d83a3e5ef	93778431600001363	stress-37784316-1363@mediqueue.test	Paciente Stress 37784316-1363	55001363	ACTIVO	2026-06-02 22:03:31.362351	2026-06-02 22:03:31.362351	0
b7b44ddc-5e2b-4551-8a5a-62403c8d077f	93778434000001436	stress-37784340-1436@mediqueue.test	Paciente Stress 37784340-1436	55001436	ACTIVO	2026-06-02 22:03:32.026769	2026-06-02 22:03:32.026769	0
0fc52ee3-b594-4fa8-a79e-32d60a30aef9	93778431500001478	stress-37784315-1478@mediqueue.test	Paciente Stress 37784315-1478	55001478	ACTIVO	2026-06-02 22:03:32.433659	2026-06-02 22:03:32.433659	0
c9376c4f-1b5a-4df7-be79-0dca6c2411c9	93778430500001823	stress-37784305-1823@mediqueue.test	Paciente Stress 37784305-1823	55001823	ACTIVO	2026-06-02 22:03:39.792755	2026-06-02 22:03:39.792755	0
f1fbccad-4a95-480c-978b-1023575d6e12	93979295300000001	stress-39792953-1@mediqueue.test	Paciente Stress 39792953-1	55000001	ACTIVO	2026-06-02 22:36:33.492028	2026-06-02 22:36:33.492028	0
56cf17bf-6590-41a8-8799-b5e6270b6cfc	93979305900000184	stress-39793059-184@mediqueue.test	Paciente Stress 39793059-184	55000184	ACTIVO	2026-06-02 22:36:33.848915	2026-06-02 22:36:33.848915	0
21c85250-585c-4621-9859-52e997f74380	93979302700000108	stress-39793027-108@mediqueue.test	Paciente Stress 39793027-108	55000108	ACTIVO	2026-06-02 22:36:36.537693	2026-06-02 22:36:36.537693	0
8fa52230-2dcd-4486-921c-e3d6f33d9b7e	93979297400000730	stress-39792974-730@mediqueue.test	Paciente Stress 39792974-730	55000730	ACTIVO	2026-06-02 22:36:39.545259	2026-06-02 22:36:39.545259	0
9d3ed752-e46f-403c-b53b-f694eb3dd1f9	93979300300000823	stress-39793003-823@mediqueue.test	Paciente Stress 39793003-823	55000823	ACTIVO	2026-06-02 22:36:40.34241	2026-06-02 22:36:40.34241	0
682dbbf8-f56d-48b3-bae8-95ad81d21a95	93979302600002274	stress-39793026-2274@mediqueue.test	Paciente Stress 39793026-2274	55002274	ACTIVO	2026-06-02 22:36:54.207072	2026-06-02 22:36:54.207072	0
725078f4-d3fa-4503-b054-2813ebe239af	93979305600003459	stress-39793056-3459@mediqueue.test	Paciente Stress 39793056-3459	55003459	ACTIVO	2026-06-02 22:37:13.712169	2026-06-02 22:37:13.712169	0
7d105617-b44c-4541-b562-925a8dc89cf2	93979303200003819	stress-39793032-3819@mediqueue.test	Paciente Stress 39793032-3819	55003819	ACTIVO	2026-06-02 22:37:16.664625	2026-06-02 22:37:16.664625	0
a3ac2b93-f865-4d51-815b-107be197ab44	94045696300006499	stress-40456963-6499@mediqueue.test	Paciente Stress 40456963-6499	55006499	ACTIVO	2026-06-02 22:48:40.924568	2026-06-02 22:48:40.924568	0
eb63dc79-31c3-4c0c-a726-cf42a05b6dce	94045695400006660	stress-40456954-6660@mediqueue.test	Paciente Stress 40456954-6660	55006660	ACTIVO	2026-06-02 22:48:42.209337	2026-06-02 22:48:42.209337	0
62a6449a-0c70-45d9-9bd6-34080e12a45a	94045691700006831	stress-40456917-6831@mediqueue.test	Paciente Stress 40456917-6831	55006831	ACTIVO	2026-06-02 22:48:43.591854	2026-06-02 22:48:43.591854	0
f059583f-8081-4474-a924-1f689aa80e6e	94045695300006876	stress-40456953-6876@mediqueue.test	Paciente Stress 40456953-6876	55006876	ACTIVO	2026-06-02 22:48:43.946482	2026-06-02 22:48:43.946482	0
b956d394-2aa3-47d5-958d-c02f456ee0d1	94173202000000019	stress-41732020-19@mediqueue.test	Paciente Stress 41732020-19	55000019	ACTIVO	2026-06-02 23:08:53.011102	2026-06-02 23:08:53.011102	0
b6dc47fa-7a35-4a2f-a367-66e85db652e9	94173204600000391	stress-41732046-391@mediqueue.test	Paciente Stress 41732046-391	55000391	ACTIVO	2026-06-02 23:08:57.735454	2026-06-02 23:08:57.735454	0
7af9e5c5-a7e7-41a6-8592-be0a58d5a7f9	94173203200000523	stress-41732032-523@mediqueue.test	Paciente Stress 41732032-523	55000523	ACTIVO	2026-06-02 23:08:58.793467	2026-06-02 23:08:58.793467	0
48590e48-9a7b-4421-8849-4bcdc1b939c1	94173200000000410	stress-41732000-410@mediqueue.test	Paciente Stress 41732000-410	55000410	ACTIVO	2026-06-02 23:08:58.957838	2026-06-02 23:08:58.957838	0
55ab2cdd-beac-43c4-ab71-ea895f9b992f	94173198500000588	stress-41731985-588@mediqueue.test	Paciente Stress 41731985-588	55000588	ACTIVO	2026-06-02 23:08:59.051089	2026-06-02 23:08:59.051089	0
243946e2-65e7-4a90-bfcd-d8da9b4a2590	94173204100000611	stress-41732041-611@mediqueue.test	Paciente Stress 41732041-611	55000611	ACTIVO	2026-06-02 23:08:59.309004	2026-06-02 23:08:59.309004	0
6cc5664c-78a6-4e87-91b0-bbcb66f4bb27	94173199200000762	stress-41731992-762@mediqueue.test	Paciente Stress 41731992-762	55000762	ACTIVO	2026-06-02 23:09:00.162858	2026-06-02 23:09:00.162858	0
6bb48d9d-d863-4076-8a10-c60fa621badc	94173200400000988	stress-41732004-988@mediqueue.test	Paciente Stress 41732004-988	55000988	ACTIVO	2026-06-02 23:09:01.224478	2026-06-02 23:09:01.224478	0
b8155a31-31c1-4451-ba7f-8c5f4a594fab	94173205600001002	stress-41732056-1002@mediqueue.test	Paciente Stress 41732056-1002	55001002	ACTIVO	2026-06-02 23:09:01.377786	2026-06-02 23:09:01.377786	0
127ce82b-b2f0-49c3-a082-7f59440876e0	94173206500001150	stress-41732065-1150@mediqueue.test	Paciente Stress 41732065-1150	55001150	ACTIVO	2026-06-02 23:09:03.295494	2026-06-02 23:09:03.295494	0
31a702bc-f3a7-4e43-aac9-7b6cbc4ea482	94173197900001216	stress-41731979-1216@mediqueue.test	Paciente Stress 41731979-1216	55001216	ACTIVO	2026-06-02 23:09:03.782733	2026-06-02 23:09:03.782733	0
001c3c96-0778-4240-af50-3cb5bd3a7db9	94173204900001257	stress-41732049-1257@mediqueue.test	Paciente Stress 41732049-1257	55001257	ACTIVO	2026-06-02 23:09:04.153639	2026-06-02 23:09:04.153639	0
3c07b33c-2ce7-4567-9da9-0cb85579f779	94173204100001256	stress-41732041-1256@mediqueue.test	Paciente Stress 41732041-1256	55001256	ACTIVO	2026-06-02 23:09:04.170764	2026-06-02 23:09:04.170764	0
15da25ea-fb89-4342-aa53-c355092d0954	94173206500001268	stress-41732065-1268@mediqueue.test	Paciente Stress 41732065-1268	55001268	ACTIVO	2026-06-02 23:09:04.720364	2026-06-02 23:09:04.720364	0
fcadd435-b693-4ed8-a262-3c6f110b8c4e	94173206800001334	stress-41732068-1334@mediqueue.test	Paciente Stress 41732068-1334	55001334	ACTIVO	2026-06-02 23:09:05.066703	2026-06-02 23:09:05.066703	0
c634b966-2736-43b1-a72a-25832b2052af	94173200300001338	stress-41732003-1338@mediqueue.test	Paciente Stress 41732003-1338	55001338	ACTIVO	2026-06-02 23:09:05.078047	2026-06-02 23:09:05.078047	0
137baf6f-0d6c-4f2d-b45c-7b3dcb9c7367	94173202200001356	stress-41732022-1356@mediqueue.test	Paciente Stress 41732022-1356	55001356	ACTIVO	2026-06-02 23:09:05.536762	2026-06-02 23:09:05.536762	0
7727015f-04b0-4812-87cf-079e5bf48337	94173205200001506	stress-41732052-1506@mediqueue.test	Paciente Stress 41732052-1506	55001506	ACTIVO	2026-06-02 23:09:07.041931	2026-06-02 23:09:07.041931	0
cedc01fd-05a7-4b75-b0b3-e60e1d897f85	94173204800001565	stress-41732048-1565@mediqueue.test	Paciente Stress 41732048-1565	55001565	ACTIVO	2026-06-02 23:09:07.666784	2026-06-02 23:09:07.666784	0
bde68f71-375f-4bf9-a7b9-5131afc392e7	94173203000001748	stress-41732030-1748@mediqueue.test	Paciente Stress 41732030-1748	55001748	ACTIVO	2026-06-02 23:09:09.467845	2026-06-02 23:09:09.467845	0
961ea0be-fc87-4961-91bb-da367ba7234e	94173204600001798	stress-41732046-1798@mediqueue.test	Paciente Stress 41732046-1798	55001798	ACTIVO	2026-06-02 23:09:09.782629	2026-06-02 23:09:09.782629	0
4f161f97-1ea4-4333-95ac-76ecf9253880	94173204500001818	stress-41732045-1818@mediqueue.test	Paciente Stress 41732045-1818	55001818	ACTIVO	2026-06-02 23:09:10.043554	2026-06-02 23:09:10.043554	0
3da79a48-332f-4b29-b681-89b30c8265d8	94173199100001845	stress-41731991-1845@mediqueue.test	Paciente Stress 41731991-1845	55001845	ACTIVO	2026-06-02 23:09:10.201226	2026-06-02 23:09:10.201226	0
2127263e-67f3-48fc-bdfb-9815a5166d9b	93778432700000932	stress-37784327-932@mediqueue.test	Paciente Stress 37784327-932	55000932	ACTIVO	2026-06-02 22:03:27.105406	2026-06-02 22:03:27.105406	0
a90dbb89-6173-4683-b47d-0a9cc6875c0d	93778431000001026	stress-37784310-1026@mediqueue.test	Paciente Stress 37784310-1026	55001026	ACTIVO	2026-06-02 22:03:28.198457	2026-06-02 22:03:28.198457	0
627b27eb-f3c9-4294-bbc9-483a4ccdc913	93778432200001075	stress-37784322-1075@mediqueue.test	Paciente Stress 37784322-1075	55001075	ACTIVO	2026-06-02 22:03:28.589691	2026-06-02 22:03:28.589691	0
d12830e3-b241-44cd-bee5-cea856e80016	93778430900001339	stress-37784309-1339@mediqueue.test	Paciente Stress 37784309-1339	55001339	ACTIVO	2026-06-02 22:03:31.110177	2026-06-02 22:03:31.110177	0
8dd6bbb1-19fe-42aa-a7a2-c8ff1a185282	93778430500001389	stress-37784305-1389@mediqueue.test	Paciente Stress 37784305-1389	55001389	ACTIVO	2026-06-02 22:03:31.482694	2026-06-02 22:03:31.482694	0
76e8700e-e2b0-488e-a864-37de396c9046	93778431600001469	stress-37784316-1469@mediqueue.test	Paciente Stress 37784316-1469	55001469	ACTIVO	2026-06-02 22:03:32.333974	2026-06-02 22:03:32.333974	0
e4ffe7ab-472c-4d32-b272-33545215725b	93778430600001566	stress-37784306-1566@mediqueue.test	Paciente Stress 37784306-1566	55001566	ACTIVO	2026-06-02 22:03:33.731776	2026-06-02 22:03:33.731776	0
9d22e712-456d-4c09-8823-89d34345fd5a	93778434300001620	stress-37784343-1620@mediqueue.test	Paciente Stress 37784343-1620	55001620	ACTIVO	2026-06-02 22:03:34.539153	2026-06-02 22:03:34.539153	0
4ea87480-189f-4017-9d17-ef8f8c679053	93778432000001889	stress-37784320-1889@mediqueue.test	Paciente Stress 37784320-1889	55001889	ACTIVO	2026-06-02 22:03:40.617825	2026-06-02 22:03:40.617825	0
70873aa9-8797-4fa8-97e0-f4703c1fe4d7	93778431000002063	stress-37784310-2063@mediqueue.test	Paciente Stress 37784310-2063	55002063	ACTIVO	2026-06-02 22:03:42.996162	2026-06-02 22:03:42.996162	0
a7869b15-efc9-4cb3-97ea-9e1d9663de3c	93778433100002252	stress-37784331-2252@mediqueue.test	Paciente Stress 37784331-2252	55002252	ACTIVO	2026-06-02 22:03:44.994991	2026-06-02 22:03:44.994991	0
df89c5a7-ca94-4f4b-8f7b-8cb9e4e56e5c	93979305900000156	stress-39793059-156@mediqueue.test	Paciente Stress 39793059-156	55000156	ACTIVO	2026-06-02 22:36:33.794213	2026-06-02 22:36:33.794213	0
0c9be81f-6adc-4220-ac65-2788ee22d992	93979299900000035	stress-39792999-35@mediqueue.test	Paciente Stress 39792999-35	55000035	ACTIVO	2026-06-02 22:36:35.601867	2026-06-02 22:36:35.601867	0
f03c3103-104f-4881-acaf-c9cf2f63f951	93979295900000258	stress-39792959-258@mediqueue.test	Paciente Stress 39792959-258	55000258	ACTIVO	2026-06-02 22:36:35.930385	2026-06-02 22:36:35.930385	0
03e70620-e4ef-41db-b8ec-a43293fa8a7a	93979296000000271	stress-39792960-271@mediqueue.test	Paciente Stress 39792960-271	55000271	ACTIVO	2026-06-02 22:36:36.75505	2026-06-02 22:36:36.75505	0
47fef87c-ed9c-447e-ad50-446f0a074c96	93979298000000522	stress-39792980-522@mediqueue.test	Paciente Stress 39792980-522	55000522	ACTIVO	2026-06-02 22:36:37.954362	2026-06-02 22:36:37.954362	0
d50aa84e-e76b-47ab-ae4b-b83976b324e3	93979300700000749	stress-39793007-749@mediqueue.test	Paciente Stress 39793007-749	55000749	ACTIVO	2026-06-02 22:36:39.541209	2026-06-02 22:36:39.541209	0
27b27a90-b864-490e-ac85-9c340a80d481	93979300700000972	stress-39793007-972@mediqueue.test	Paciente Stress 39793007-972	55000972	ACTIVO	2026-06-02 22:36:41.666274	2026-06-02 22:36:41.666274	0
ac5fd6ee-792e-4803-bc24-85bc6d976d20	93979305900001021	stress-39793059-1021@mediqueue.test	Paciente Stress 39793059-1021	55001021	ACTIVO	2026-06-02 22:36:42.149393	2026-06-02 22:36:42.149393	0
5aad0271-536f-423d-9c11-2158cfe4611a	93979300000001156	stress-39793000-1156@mediqueue.test	Paciente Stress 39793000-1156	55001156	ACTIVO	2026-06-02 22:36:43.279182	2026-06-02 22:36:43.279182	0
074e2994-f2cc-437b-8876-cd37a0e3a17d	93979300300001217	stress-39793003-1217@mediqueue.test	Paciente Stress 39793003-1217	55001217	ACTIVO	2026-06-02 22:36:43.897636	2026-06-02 22:36:43.897636	0
2678f387-863e-4677-bc13-9ff654967ca7	93979299900001427	stress-39792999-1427@mediqueue.test	Paciente Stress 39792999-1427	55001427	ACTIVO	2026-06-02 22:36:46.243404	2026-06-02 22:36:46.243404	0
f990b3d5-1f73-41a8-8c53-610532a66586	93979295700001599	stress-39792957-1599@mediqueue.test	Paciente Stress 39792957-1599	55001599	ACTIVO	2026-06-02 22:36:48.621282	2026-06-02 22:36:48.621282	0
8b6888c9-5b16-490d-976e-a37a3af2fac9	93979296000001758	stress-39792960-1758@mediqueue.test	Paciente Stress 39792960-1758	55001758	ACTIVO	2026-06-02 22:36:50.019093	2026-06-02 22:36:50.019093	0
147e8656-4905-44ef-8ff0-a4119cab579b	93979299900001819	stress-39792999-1819@mediqueue.test	Paciente Stress 39792999-1819	55001819	ACTIVO	2026-06-02 22:36:50.470621	2026-06-02 22:36:50.470621	0
41d085bf-7455-47df-bfa8-9a6e3adfecef	93979299300001918	stress-39792993-1918@mediqueue.test	Paciente Stress 39792993-1918	55001918	ACTIVO	2026-06-02 22:36:51.426413	2026-06-02 22:36:51.426413	0
8ac137a3-d932-4f9f-8936-f9b89b86ba0e	93979304100002156	stress-39793041-2156@mediqueue.test	Paciente Stress 39793041-2156	55002156	ACTIVO	2026-06-02 22:36:53.242223	2026-06-02 22:36:53.242223	0
592124b8-1143-45a6-9374-d48cfec2bd95	93979300300002351	stress-39793003-2351@mediqueue.test	Paciente Stress 39793003-2351	55002351	ACTIVO	2026-06-02 22:36:55.041146	2026-06-02 22:36:55.041146	0
ecf76fc9-1f63-4b4c-b53e-8a8dab164efc	93979299200002638	stress-39792992-2638@mediqueue.test	Paciente Stress 39792992-2638	55002638	ACTIVO	2026-06-02 22:36:57.242172	2026-06-02 22:36:57.242172	0
7c7254a8-988b-467f-9bbd-4fbd1b05332f	93979298900002802	stress-39792989-2802@mediqueue.test	Paciente Stress 39792989-2802	55002802	ACTIVO	2026-06-02 22:37:08.018184	2026-06-02 22:37:08.018184	0
09acb5d7-f6d5-4e36-a32b-5e030105e237	93979300000003124	stress-39793000-3124@mediqueue.test	Paciente Stress 39793000-3124	55003124	ACTIVO	2026-06-02 22:37:11.11576	2026-06-02 22:37:11.11576	0
a329fb1b-f1a8-425b-b892-761ce4a2031e	93979300500003239	stress-39793005-3239@mediqueue.test	Paciente Stress 39793005-3239	55003239	ACTIVO	2026-06-02 22:37:11.947794	2026-06-02 22:37:11.947794	0
5195088b-b90b-4f3f-9ea3-a7996c9d51c2	93979297700003393	stress-39792977-3393@mediqueue.test	Paciente Stress 39792977-3393	55003393	ACTIVO	2026-06-02 22:37:13.30345	2026-06-02 22:37:13.30345	0
1b57d86b-19b9-44d6-8ee1-d9b4c0a4f3bb	94045695900007182	stress-40456959-7182@mediqueue.test	Paciente Stress 40456959-7182	55007182	ACTIVO	2026-06-02 22:48:46.513218	2026-06-02 22:48:46.513218	0
d1203e62-92da-408a-b9d7-d366321417e9	94045691500007478	stress-40456915-7478@mediqueue.test	Paciente Stress 40456915-7478	55007478	ACTIVO	2026-06-02 22:48:49.158171	2026-06-02 22:48:49.158171	0
264f8295-7295-4e5f-87f8-8fdce216a313	94045696300008017	stress-40456963-8017@mediqueue.test	Paciente Stress 40456963-8017	55008017	ACTIVO	2026-06-02 22:49:30.173485	2026-06-02 22:49:30.173485	0
1eeb2be9-23cf-471f-954e-acef8e6e1edf	94045695600008036	stress-40456956-8036@mediqueue.test	Paciente Stress 40456956-8036	55008036	ACTIVO	2026-06-02 22:49:30.271662	2026-06-02 22:49:30.271662	0
3f60d435-6680-4258-9c16-9256687350fd	94045695300007957	stress-40456953-7957@mediqueue.test	Paciente Stress 40456953-7957	55007957	ACTIVO	2026-06-02 22:49:30.343079	2026-06-02 22:49:30.343079	0
91d36e74-0ce0-43f4-94d2-ebfd821e28e7	94045692900007992	stress-40456929-7992@mediqueue.test	Paciente Stress 40456929-7992	55007992	ACTIVO	2026-06-02 22:49:30.421975	2026-06-02 22:49:30.421975	0
7102ca9c-6ab3-443b-a2e4-0a2674adbf7e	94045694900007879	stress-40456949-7879@mediqueue.test	Paciente Stress 40456949-7879	55007879	ACTIVO	2026-06-02 22:49:30.498612	2026-06-02 22:49:30.498612	0
6d8a6246-7d1c-4d99-ba01-3c351afd4d8f	94045696000008293	stress-40456960-8293@mediqueue.test	Paciente Stress 40456960-8293	55008293	ACTIVO	2026-06-02 22:49:31.682545	2026-06-02 22:49:31.682545	0
c2ffc24e-a76f-4624-892a-35c183734209	94045693000008345	stress-40456930-8345@mediqueue.test	Paciente Stress 40456930-8345	55008345	ACTIVO	2026-06-02 22:49:32.470707	2026-06-02 22:49:32.470707	0
ee12b356-ffcd-4b09-b96e-b78b9679c02f	94045693000008408	stress-40456930-8408@mediqueue.test	Paciente Stress 40456930-8408	55008408	ACTIVO	2026-06-02 22:49:33.051307	2026-06-02 22:49:33.051307	0
7994cf76-1c0a-4d6c-947b-4539dacd9fca	94045693400008491	stress-40456934-8491@mediqueue.test	Paciente Stress 40456934-8491	55008491	ACTIVO	2026-06-02 22:49:33.860254	2026-06-02 22:49:33.860254	0
c6195c50-bdf4-4ca1-8c5f-0fbaebbc9807	94045696200008780	stress-40456962-8780@mediqueue.test	Paciente Stress 40456962-8780	55008780	ACTIVO	2026-06-02 22:49:36.511217	2026-06-02 22:49:36.511217	0
2b8a7761-7075-4720-9828-6646bb1b0b52	94045694600008832	stress-40456946-8832@mediqueue.test	Paciente Stress 40456946-8832	55008832	ACTIVO	2026-06-02 22:49:37.007791	2026-06-02 22:49:37.007791	0
e82aab6c-afd3-4636-a10b-0375c14806ac	94045694000008949	stress-40456940-8949@mediqueue.test	Paciente Stress 40456940-8949	55008949	ACTIVO	2026-06-02 22:49:38.142818	2026-06-02 22:49:38.142818	0
eafccf72-9235-43c9-8220-4a9a664d5d43	93778430900000934	stress-37784309-934@mediqueue.test	Paciente Stress 37784309-934	55000934	ACTIVO	2026-06-02 22:03:27.127411	2026-06-02 22:03:27.127411	0
dff75ce7-01fe-4510-ad83-708aec80d905	93778431300000971	stress-37784313-971@mediqueue.test	Paciente Stress 37784313-971	55000971	ACTIVO	2026-06-02 22:03:27.560367	2026-06-02 22:03:27.560367	0
ff910556-d951-43f7-bae2-86c990331f70	93778434400000989	stress-37784344-989@mediqueue.test	Paciente Stress 37784344-989	55000989	ACTIVO	2026-06-02 22:03:27.787981	2026-06-02 22:03:27.787981	0
4df33243-df03-4347-a81c-4dc2a94bb99b	93778431400001168	stress-37784314-1168@mediqueue.test	Paciente Stress 37784314-1168	55001168	ACTIVO	2026-06-02 22:03:29.356566	2026-06-02 22:03:29.356566	0
4e71e6b9-394a-405f-afb1-c69dd541cba1	93778433000001198	stress-37784330-1198@mediqueue.test	Paciente Stress 37784330-1198	55001198	ACTIVO	2026-06-02 22:03:29.588804	2026-06-02 22:03:29.588804	0
c16f1d5d-4fc7-4a7b-9058-b1059a188811	93778433100001282	stress-37784331-1282@mediqueue.test	Paciente Stress 37784331-1282	55001282	ACTIVO	2026-06-02 22:03:30.150157	2026-06-02 22:03:30.150157	0
9b5e50e5-84c4-426b-b29f-442e9a1c9211	93778434000001422	stress-37784340-1422@mediqueue.test	Paciente Stress 37784340-1422	55001422	ACTIVO	2026-06-02 22:03:31.712283	2026-06-02 22:03:31.712283	0
03a2c6e8-9ce0-458c-8cc7-9cc0970bef2a	93778430900001441	stress-37784309-1441@mediqueue.test	Paciente Stress 37784309-1441	55001441	ACTIVO	2026-06-02 22:03:32.16537	2026-06-02 22:03:32.16537	0
187e67f2-a1e4-4027-8a71-71527e2e07dd	93778431300001513	stress-37784313-1513@mediqueue.test	Paciente Stress 37784313-1513	55001513	ACTIVO	2026-06-02 22:03:32.783924	2026-06-02 22:03:32.783924	0
5c62461f-e959-4fff-acff-633dca515b10	93778429900001605	stress-37784299-1605@mediqueue.test	Paciente Stress 37784299-1605	55001605	ACTIVO	2026-06-02 22:03:34.276676	2026-06-02 22:03:34.276676	0
166f3d37-6ce9-4f56-8ab6-cef79e6205fa	93778429900001664	stress-37784299-1664@mediqueue.test	Paciente Stress 37784299-1664	55001664	ACTIVO	2026-06-02 22:03:38.806662	2026-06-02 22:03:38.806662	0
be17f5aa-fb77-4b9d-8b90-c20575ae3bf4	93778434100001705	stress-37784341-1705@mediqueue.test	Paciente Stress 37784341-1705	55001705	ACTIVO	2026-06-02 22:03:39.117219	2026-06-02 22:03:39.117219	0
d319bcfd-b519-4802-9500-17758370107b	93778431900001802	stress-37784319-1802@mediqueue.test	Paciente Stress 37784319-1802	55001802	ACTIVO	2026-06-02 22:03:39.928834	2026-06-02 22:03:39.928834	0
69f53d7c-9ee1-4ea6-98e6-70d6cd06eacd	93778432800001903	stress-37784328-1903@mediqueue.test	Paciente Stress 37784328-1903	55001903	ACTIVO	2026-06-02 22:03:40.507682	2026-06-02 22:03:40.507682	0
83150065-58bf-4437-8ab2-533496a07bfb	93778432200002079	stress-37784322-2079@mediqueue.test	Paciente Stress 37784322-2079	55002079	ACTIVO	2026-06-02 22:03:43.191775	2026-06-02 22:03:43.191775	0
9fd5c758-1bb0-43d0-8794-8be83c175853	93778429900002211	stress-37784299-2211@mediqueue.test	Paciente Stress 37784299-2211	55002211	ACTIVO	2026-06-02 22:03:44.4528	2026-06-02 22:03:44.4528	0
692ef41e-1ea4-4951-83da-451427920863	93979299700000033	stress-39792997-33@mediqueue.test	Paciente Stress 39792997-33	55000033	ACTIVO	2026-06-02 22:36:33.83139	2026-06-02 22:36:33.83139	0
2a11633a-03f7-43e8-adb6-1b50ffed4b79	93979295900000928	stress-39792959-928@mediqueue.test	Paciente Stress 39792959-928	55000928	ACTIVO	2026-06-02 22:36:41.371042	2026-06-02 22:36:41.371042	0
7a2cba12-58c6-458a-9d90-6d00459c3b16	93979306100001555	stress-39793061-1555@mediqueue.test	Paciente Stress 39793061-1555	55001555	ACTIVO	2026-06-02 22:36:47.963342	2026-06-02 22:36:47.963342	0
b64cd0bd-7988-4da4-9c21-c36e89ea8ac3	93979302800001586	stress-39793028-1586@mediqueue.test	Paciente Stress 39793028-1586	55001586	ACTIVO	2026-06-02 22:36:48.441935	2026-06-02 22:36:48.441935	0
42c6d1af-2eef-48c5-b504-6c330dc7c602	93979298800001613	stress-39792988-1613@mediqueue.test	Paciente Stress 39792988-1613	55001613	ACTIVO	2026-06-02 22:36:48.763916	2026-06-02 22:36:48.763916	0
c1b38a55-87b2-4692-be8d-8a4a781dfdca	93979298500001669	stress-39792985-1669@mediqueue.test	Paciente Stress 39792985-1669	55001669	ACTIVO	2026-06-02 22:36:49.224665	2026-06-02 22:36:49.224665	0
ab03edff-74b6-4214-b6fa-dc999599de13	93979301600001879	stress-39793016-1879@mediqueue.test	Paciente Stress 39793016-1879	55001879	ACTIVO	2026-06-02 22:36:51.03522	2026-06-02 22:36:51.03522	0
61c93cd7-281a-417f-bd57-f1aaf9ef52c2	93979306100002047	stress-39793061-2047@mediqueue.test	Paciente Stress 39793061-2047	55002047	ACTIVO	2026-06-02 22:36:52.46627	2026-06-02 22:36:52.46627	0
f593ed32-7b05-4505-96ab-4cf5f9099d9e	93979298800002151	stress-39792988-2151@mediqueue.test	Paciente Stress 39792988-2151	55002151	ACTIVO	2026-06-02 22:36:53.230558	2026-06-02 22:36:53.230558	0
55eb3c4f-df39-4116-bb74-c45a2e8a9a28	93979302800002445	stress-39793028-2445@mediqueue.test	Paciente Stress 39793028-2445	55002445	ACTIVO	2026-06-02 22:36:55.860862	2026-06-02 22:36:55.860862	0
8ecd4d4b-dfca-42fa-a9cd-929b351f8c68	93979305900002504	stress-39793059-2504@mediqueue.test	Paciente Stress 39793059-2504	55002504	ACTIVO	2026-06-02 22:36:56.390636	2026-06-02 22:36:56.390636	0
7e6e29fb-2366-45d7-af33-1fd234512a44	93979298500002625	stress-39792985-2625@mediqueue.test	Paciente Stress 39792985-2625	55002625	ACTIVO	2026-06-02 22:36:57.181634	2026-06-02 22:36:57.181634	0
7e79463c-ba3b-40a1-82d1-9275c95152ef	93979297900002750	stress-39792979-2750@mediqueue.test	Paciente Stress 39792979-2750	55002750	ACTIVO	2026-06-02 22:37:07.726761	2026-06-02 22:37:07.726761	0
533796d9-2240-4f2a-816f-156dc8aa9761	93979306000002952	stress-39793060-2952@mediqueue.test	Paciente Stress 39793060-2952	55002952	ACTIVO	2026-06-02 22:37:09.425973	2026-06-02 22:37:09.425973	0
b1edd987-459a-4b80-b295-1022d1920ecf	93979302800003207	stress-39793028-3207@mediqueue.test	Paciente Stress 39793028-3207	55003207	ACTIVO	2026-06-02 22:37:11.747017	2026-06-02 22:37:11.747017	0
d036d902-0130-4c26-8736-585decc2a3c8	93979300500003307	stress-39793005-3307@mediqueue.test	Paciente Stress 39793005-3307	55003307	ACTIVO	2026-06-02 22:37:12.708346	2026-06-02 22:37:12.708346	0
19c9b836-b7e6-4b37-8027-3b788b909759	93979305900003361	stress-39793059-3361@mediqueue.test	Paciente Stress 39793059-3361	55003361	ACTIVO	2026-06-02 22:37:13.063905	2026-06-02 22:37:13.063905	0
e97fcb38-8d1b-4064-b332-fb7d9628a74f	93979301400003493	stress-39793014-3493@mediqueue.test	Paciente Stress 39793014-3493	55003493	ACTIVO	2026-06-02 22:37:14.094228	2026-06-02 22:37:14.094228	0
9c4afe59-8b02-4160-9981-02c87e7714b7	93979300600003969	stress-39793006-3969@mediqueue.test	Paciente Stress 39793006-3969	55003969	ACTIVO	2026-06-02 22:37:18.068788	2026-06-02 22:37:18.068788	0
b16ecc2f-00db-4a3c-8b04-0e61024161e3	93979301500004280	stress-39793015-4280@mediqueue.test	Paciente Stress 39793015-4280	55004280	ACTIVO	2026-06-02 22:37:20.436315	2026-06-02 22:37:20.436315	0
e86cbdd9-bd37-4c4c-be1a-6cb3b5b02167	94045696100007204	stress-40456961-7204@mediqueue.test	Paciente Stress 40456961-7204	55007204	ACTIVO	2026-06-02 22:48:46.624533	2026-06-02 22:48:46.624533	0
414a0497-44bd-4bda-952a-95237573d3db	94045691200007500	stress-40456912-7500@mediqueue.test	Paciente Stress 40456912-7500	55007500	ACTIVO	2026-06-02 22:48:49.319393	2026-06-02 22:48:49.319393	0
51bcbae4-9852-458f-9050-dd759eee0fba	94045696100007917	stress-40456961-7917@mediqueue.test	Paciente Stress 40456961-7917	55007917	ACTIVO	2026-06-02 22:49:26.870267	2026-06-02 22:49:26.870267	0
0fc9da15-8e7c-4c66-9ae9-6e18c5ae94e4	94045696600007738	stress-40456966-7738@mediqueue.test	Paciente Stress 40456966-7738	55007738	ACTIVO	2026-06-02 22:49:29.350757	2026-06-02 22:49:29.350757	0
e2f34e12-0262-4388-b182-32db936b6464	94045696600008075	stress-40456966-8075@mediqueue.test	Paciente Stress 40456966-8075	55008075	ACTIVO	2026-06-02 22:49:30.715986	2026-06-02 22:49:30.715986	0
e9be1030-d33b-4a58-8c42-5d8eb189d018	94045693500008517	stress-40456935-8517@mediqueue.test	Paciente Stress 40456935-8517	55008517	ACTIVO	2026-06-02 22:49:34.139199	2026-06-02 22:49:34.139199	0
1ad3b8f5-262f-4997-8d66-79d27c5174a1	94045695700008535	stress-40456957-8535@mediqueue.test	Paciente Stress 40456957-8535	55008535	ACTIVO	2026-06-02 22:49:34.240876	2026-06-02 22:49:34.240876	0
ac91ef97-d4a9-4cc2-b942-5754220fc546	94045695600009166	stress-40456956-9166@mediqueue.test	Paciente Stress 40456956-9166	55009166	ACTIVO	2026-06-02 22:49:40.302378	2026-06-02 22:49:40.302378	0
9cd4a303-451b-45fd-be1e-8ae4eef2db79	94045694000009623	stress-40456940-9623@mediqueue.test	Paciente Stress 40456940-9623	55009623	ACTIVO	2026-06-02 22:49:44.477107	2026-06-02 22:49:44.477107	0
54fddee3-e1a8-4b11-8cbd-99bf23c3c412	94045695600009765	stress-40456956-9765@mediqueue.test	Paciente Stress 40456956-9765	55009765	ACTIVO	2026-06-02 22:51:05.447894	2026-06-02 22:51:05.447894	0
8af6fe74-5d74-4b68-9ff8-41b5284230fc	94045691500009821	stress-40456915-9821@mediqueue.test	Paciente Stress 40456915-9821	55009821	ACTIVO	2026-06-02 22:51:05.80772	2026-06-02 22:51:05.80772	0
3a6f6ed5-328f-41f4-8d33-c8de1ae916f3	93778430900000994	stress-37784309-994@mediqueue.test	Paciente Stress 37784309-994	55000994	ACTIVO	2026-06-02 22:03:27.819106	2026-06-02 22:03:27.819106	0
1fa9181b-20ad-4cfa-bfa2-30f6319c0766	93778432400001055	stress-37784324-1055@mediqueue.test	Paciente Stress 37784324-1055	55001055	ACTIVO	2026-06-02 22:03:28.454967	2026-06-02 22:03:28.454967	0
f2202bbc-c198-480e-af41-07735490dac9	93778432200001133	stress-37784322-1133@mediqueue.test	Paciente Stress 37784322-1133	55001133	ACTIVO	2026-06-02 22:03:29.000959	2026-06-02 22:03:29.000959	0
a5b381f8-4c4a-4fc8-8254-09de04f57783	93778433000001250	stress-37784330-1250@mediqueue.test	Paciente Stress 37784330-1250	55001250	ACTIVO	2026-06-02 22:03:29.994436	2026-06-02 22:03:29.994436	0
bb2a4960-a337-4df4-bae5-2453209c2cd3	93778434200001336	stress-37784342-1336@mediqueue.test	Paciente Stress 37784342-1336	55001336	ACTIVO	2026-06-02 22:03:31.110217	2026-06-02 22:03:31.110217	0
6296ef61-adea-4320-afd4-a984c3c2187a	93778430300001768	stress-37784303-1768@mediqueue.test	Paciente Stress 37784303-1768	55001768	ACTIVO	2026-06-02 22:03:39.527043	2026-06-02 22:03:39.527043	0
6329ac45-893c-4c1a-abfb-b1e3f5c2a0f3	93778430900001926	stress-37784309-1926@mediqueue.test	Paciente Stress 37784309-1926	55001926	ACTIVO	2026-06-02 22:03:40.797862	2026-06-02 22:03:40.797862	0
044ae5f4-3560-410e-a637-c4f48a268cec	93778430600001967	stress-37784306-1967@mediqueue.test	Paciente Stress 37784306-1967	55001967	ACTIVO	2026-06-02 22:03:41.579096	2026-06-02 22:03:41.579096	0
024e708a-8b0e-4fd0-a82e-ce11608c0806	93979299100000084	stress-39792991-84@mediqueue.test	Paciente Stress 39792991-84	55000084	ACTIVO	2026-06-02 22:36:34.54243	2026-06-02 22:36:34.54243	0
cf8d9d52-dc12-497a-a7c6-a07c9fe28bb4	93979298500000456	stress-39792985-456@mediqueue.test	Paciente Stress 39792985-456	55000456	ACTIVO	2026-06-02 22:36:37.493218	2026-06-02 22:36:37.493218	0
43c3f377-3d32-4ad5-95bd-4fe828727bf4	93979302300000577	stress-39793023-577@mediqueue.test	Paciente Stress 39793023-577	55000577	ACTIVO	2026-06-02 22:36:38.062817	2026-06-02 22:36:38.062817	0
31f1bf8d-5a24-4709-b8ad-7d2e00669e2e	93979294800000704	stress-39792948-704@mediqueue.test	Paciente Stress 39792948-704	55000704	ACTIVO	2026-06-02 22:36:39.40925	2026-06-02 22:36:39.40925	0
628489c0-6f64-42fe-9891-de5726b2ed72	93979295700001154	stress-39792957-1154@mediqueue.test	Paciente Stress 39792957-1154	55001154	ACTIVO	2026-06-02 22:36:43.302067	2026-06-02 22:36:43.302067	0
3e0c75f9-b46c-4a31-a46a-17671fa8dd4e	93979305600001346	stress-39793056-1346@mediqueue.test	Paciente Stress 39793056-1346	55001346	ACTIVO	2026-06-02 22:36:45.397397	2026-06-02 22:36:45.397397	0
6c1da487-a2fa-459f-92fa-324bbb514c55	93979302600001692	stress-39793026-1692@mediqueue.test	Paciente Stress 39793026-1692	55001692	ACTIVO	2026-06-02 22:36:49.35804	2026-06-02 22:36:49.35804	0
4e0a04cf-4eb0-4ee4-9e77-654180bb954b	93979300500001814	stress-39793005-1814@mediqueue.test	Paciente Stress 39793005-1814	55001814	ACTIVO	2026-06-02 22:36:50.471021	2026-06-02 22:36:50.471021	0
0545c1c6-c344-4187-b9b0-ba87a962c184	93979300500001915	stress-39793005-1915@mediqueue.test	Paciente Stress 39793005-1915	55001915	ACTIVO	2026-06-02 22:36:51.435592	2026-06-02 22:36:51.435592	0
524a4a0a-9bde-4eb5-a3cc-7d15fa2198c4	93979300000002211	stress-39793000-2211@mediqueue.test	Paciente Stress 39793000-2211	55002211	ACTIVO	2026-06-02 22:36:53.664877	2026-06-02 22:36:53.664877	0
9a59d102-536f-4ba9-b168-54acd53bedb3	93979298500002560	stress-39792985-2560@mediqueue.test	Paciente Stress 39792985-2560	55002560	ACTIVO	2026-06-02 22:36:56.774873	2026-06-02 22:36:56.774873	0
bfdf3caf-0a95-4783-8388-fff1f4643e91	93979295900002759	stress-39792959-2759@mediqueue.test	Paciente Stress 39792959-2759	55002759	ACTIVO	2026-06-02 22:37:07.726626	2026-06-02 22:37:07.726626	0
e77538f0-bffb-45d4-b137-479df96f260d	93979300500002811	stress-39793005-2811@mediqueue.test	Paciente Stress 39793005-2811	55002811	ACTIVO	2026-06-02 22:37:08.212492	2026-06-02 22:37:08.212492	0
0bcde7de-3e6a-4ddd-93db-a0042318cf7b	93979298500003585	stress-39792985-3585@mediqueue.test	Paciente Stress 39792985-3585	55003585	ACTIVO	2026-06-02 22:37:14.797483	2026-06-02 22:37:14.797483	0
320215f4-6949-4cac-a107-133d0b56d33c	93979297900003648	stress-39792979-3648@mediqueue.test	Paciente Stress 39792979-3648	55003648	ACTIVO	2026-06-02 22:37:15.182986	2026-06-02 22:37:15.182986	0
542c87f4-162f-4739-9935-23a972b10fd0	93979298600003683	stress-39792986-3683@mediqueue.test	Paciente Stress 39792986-3683	55003683	ACTIVO	2026-06-02 22:37:15.402687	2026-06-02 22:37:15.402687	0
c423a015-07ba-4e4b-9517-98e52d698534	93979294900003852	stress-39792949-3852@mediqueue.test	Paciente Stress 39792949-3852	55003852	ACTIVO	2026-06-02 22:37:17.344853	2026-06-02 22:37:17.344853	0
7403f56f-976d-4eff-9acc-9485be225e22	93979300000003950	stress-39793000-3950@mediqueue.test	Paciente Stress 39793000-3950	55003950	ACTIVO	2026-06-02 22:37:17.910445	2026-06-02 22:37:17.910445	0
2c692f6d-0a7d-4984-9902-4038fd35a7fe	93979300200004084	stress-39793002-4084@mediqueue.test	Paciente Stress 39793002-4084	55004084	ACTIVO	2026-06-02 22:37:18.786808	2026-06-02 22:37:18.786808	0
96f298ef-461c-4941-97ec-864d1739c145	93979297900004286	stress-39792979-4286@mediqueue.test	Paciente Stress 39792979-4286	55004286	ACTIVO	2026-06-02 22:37:20.451594	2026-06-02 22:37:20.451594	0
3bce290c-322a-4e0c-8916-3ac3f486ab94	93979305900004350	stress-39793059-4350@mediqueue.test	Paciente Stress 39793059-4350	55004350	ACTIVO	2026-06-02 22:37:21.128703	2026-06-02 22:37:21.128703	0
43e2e76b-a7be-4933-abfa-d4e6e9171c84	94045696200007225	stress-40456962-7225@mediqueue.test	Paciente Stress 40456962-7225	55007225	ACTIVO	2026-06-02 22:48:46.712088	2026-06-02 22:48:46.712088	0
11bfb17f-d1ec-4506-8195-2e744ec62e52	94045695100007348	stress-40456951-7348@mediqueue.test	Paciente Stress 40456951-7348	55007348	ACTIVO	2026-06-02 22:48:47.827087	2026-06-02 22:48:47.827087	0
91e5efce-d8e2-4a25-8d04-d386bb5f4da4	94045691800007575	stress-40456918-7575@mediqueue.test	Paciente Stress 40456918-7575	55007575	ACTIVO	2026-06-02 22:48:50.143578	2026-06-02 22:48:50.143578	0
5692a6b0-c814-4258-b613-c7b24566e43e	94045691800007740	stress-40456918-7740@mediqueue.test	Paciente Stress 40456918-7740	55007740	ACTIVO	2026-06-02 22:49:28.090601	2026-06-02 22:49:28.090601	0
aa53d9da-0d79-4b80-9921-d0a2581e13ed	94045692800007956	stress-40456928-7956@mediqueue.test	Paciente Stress 40456928-7956	55007956	ACTIVO	2026-06-02 22:49:30.356981	2026-06-02 22:49:30.356981	0
b3463cac-710d-4fd4-bc09-68efb51aa60a	94045696600008269	stress-40456966-8269@mediqueue.test	Paciente Stress 40456966-8269	55008269	ACTIVO	2026-06-02 22:49:31.681987	2026-06-02 22:49:31.681987	0
eba85d95-edd0-423c-91df-abb8e2f55506	94045696700008396	stress-40456967-8396@mediqueue.test	Paciente Stress 40456967-8396	55008396	ACTIVO	2026-06-02 22:49:32.933217	2026-06-02 22:49:32.933217	0
c468bf1d-75ca-4447-afeb-469910184f9e	94045693200008921	stress-40456932-8921@mediqueue.test	Paciente Stress 40456932-8921	55008921	ACTIVO	2026-06-02 22:49:37.687762	2026-06-02 22:49:37.687762	0
6bd84955-464e-4932-b5b8-9c445972648a	94045691700008972	stress-40456917-8972@mediqueue.test	Paciente Stress 40456917-8972	55008972	ACTIVO	2026-06-02 22:49:38.260764	2026-06-02 22:49:38.260764	0
ecf73286-e9be-4ebe-829b-3a8026762d58	94045696100009099	stress-40456961-9099@mediqueue.test	Paciente Stress 40456961-9099	55009099	ACTIVO	2026-06-02 22:49:39.480534	2026-06-02 22:49:39.480534	0
b9e8a91f-e8da-4fb1-aa2b-4b39a3b62512	94045695300009494	stress-40456953-9494@mediqueue.test	Paciente Stress 40456953-9494	55009494	ACTIVO	2026-06-02 22:49:43.396311	2026-06-02 22:49:43.396311	0
c21daeba-fb43-4700-8c23-239a9ffce3cc	94070642300000004	stress-40706423-4@mediqueue.test	Paciente Stress 40706423-4	55000004	ACTIVO	2026-06-02 22:51:49.387957	2026-06-02 22:51:49.387957	0
3d8bc75e-b695-4492-979b-850a331eac5b	94070641700000499	stress-40706417-499@mediqueue.test	Paciente Stress 40706417-499	55000499	ACTIVO	2026-06-02 22:51:52.394536	2026-06-02 22:51:52.394536	0
42b64917-11f8-45b4-a1e3-6bb0163e88f6	94070642200000459	stress-40706422-459@mediqueue.test	Paciente Stress 40706422-459	55000459	ACTIVO	2026-06-02 22:51:52.673005	2026-06-02 22:51:52.673005	0
d2471903-b957-4e9f-971d-4c5148743f7f	94070645500000658	stress-40706455-658@mediqueue.test	Paciente Stress 40706455-658	55000658	ACTIVO	2026-06-02 22:51:52.897023	2026-06-02 22:51:52.897023	0
16af64a6-fbe1-46a3-9fba-3206869c85cd	94070645100000680	stress-40706451-680@mediqueue.test	Paciente Stress 40706451-680	55000680	ACTIVO	2026-06-02 22:51:53.219244	2026-06-02 22:51:53.219244	0
8aa729a2-7806-4e07-b7a8-86801a522373	94070642300000946	stress-40706423-946@mediqueue.test	Paciente Stress 40706423-946	55000946	ACTIVO	2026-06-02 22:51:55.881131	2026-06-02 22:51:55.881131	0
b3bfd9e2-5416-4b71-adb0-74bc80f7b4df	94070643700001095	stress-40706437-1095@mediqueue.test	Paciente Stress 40706437-1095	55001095	ACTIVO	2026-06-02 22:51:57.660813	2026-06-02 22:51:57.660813	0
1d49563f-d59d-4018-8be2-8aa63cfab257	93778429900001019	stress-37784299-1019@mediqueue.test	Paciente Stress 37784299-1019	55001019	ACTIVO	2026-06-02 22:03:28.138291	2026-06-02 22:03:28.138291	0
18652750-281c-4d90-ad1c-ec7f5130cbb2	93778430700001162	stress-37784307-1162@mediqueue.test	Paciente Stress 37784307-1162	55001162	ACTIVO	2026-06-02 22:03:29.315018	2026-06-02 22:03:29.315018	0
f5799aa4-f874-457a-b591-a083e5f3db0a	93778431600001503	stress-37784316-1503@mediqueue.test	Paciente Stress 37784316-1503	55001503	ACTIVO	2026-06-02 22:03:32.713788	2026-06-02 22:03:32.713788	0
d6da4f66-907e-4bf1-bd74-a3f643019513	93778431600001520	stress-37784316-1520@mediqueue.test	Paciente Stress 37784316-1520	55001520	ACTIVO	2026-06-02 22:03:32.920587	2026-06-02 22:03:32.920587	0
738df2a7-efac-4855-9251-6a403a1f8a91	93778434000001816	stress-37784340-1816@mediqueue.test	Paciente Stress 37784340-1816	55001816	ACTIVO	2026-06-02 22:03:39.793966	2026-06-02 22:03:39.793966	0
dc1e7ab1-7163-40ae-b988-028224b60181	93778434300001922	stress-37784343-1922@mediqueue.test	Paciente Stress 37784343-1922	55001922	ACTIVO	2026-06-02 22:03:40.759885	2026-06-02 22:03:40.759885	0
b398e43c-466a-42ae-9fc6-fad0baaaab40	93778431300002042	stress-37784313-2042@mediqueue.test	Paciente Stress 37784313-2042	55002042	ACTIVO	2026-06-02 22:03:42.872466	2026-06-02 22:03:42.872466	0
7f34e2af-3f68-425b-8342-dc220fcaba9b	93778434600002200	stress-37784346-2200@mediqueue.test	Paciente Stress 37784346-2200	55002200	ACTIVO	2026-06-02 22:03:44.374707	2026-06-02 22:03:44.374707	0
108c661b-571c-40b3-b52c-e51bfdcc32ad	93979304600000150	stress-39793046-150@mediqueue.test	Paciente Stress 39793046-150	55000150	ACTIVO	2026-06-02 22:36:35.179033	2026-06-02 22:36:35.179033	0
4c374322-2c5f-4d5a-b143-d078e70fa8b2	93979300600000029	stress-39793006-29@mediqueue.test	Paciente Stress 39793006-29	55000029	ACTIVO	2026-06-02 22:36:35.654716	2026-06-02 22:36:35.654716	0
c3032088-d1d9-4beb-8c3c-f0a9a361aa2e	93979297900000336	stress-39792979-336@mediqueue.test	Paciente Stress 39792979-336	55000336	ACTIVO	2026-06-02 22:36:35.864778	2026-06-02 22:36:35.864778	0
cc606c86-4f8d-4a3c-b930-bbbb832c405f	93979306000000462	stress-39793060-462@mediqueue.test	Paciente Stress 39793060-462	55000462	ACTIVO	2026-06-02 22:36:37.48006	2026-06-02 22:36:37.48006	0
3c2b877a-4772-4e05-a244-a6088748653d	93979306000000559	stress-39793060-559@mediqueue.test	Paciente Stress 39793060-559	55000559	ACTIVO	2026-06-02 22:36:37.741625	2026-06-02 22:36:37.741625	0
ca7c4fb4-f034-4ff5-8ff7-3ffe4c0d0688	93979300000000477	stress-39793000-477@mediqueue.test	Paciente Stress 39793000-477	55000477	ACTIVO	2026-06-02 22:36:37.956404	2026-06-02 22:36:37.956404	0
ae8e68b8-bdd6-48a2-b7ed-9de5ac146fd0	93979296000000641	stress-39792960-641@mediqueue.test	Paciente Stress 39792960-641	55000641	ACTIVO	2026-06-02 22:36:38.314453	2026-06-02 22:36:38.314453	0
e46c6d8d-179e-4144-9193-91cba2a88ccd	93979296400000826	stress-39792964-826@mediqueue.test	Paciente Stress 39792964-826	55000826	ACTIVO	2026-06-02 22:36:40.306226	2026-06-02 22:36:40.306226	0
ae91157d-a271-42fe-b7c9-83df99bfd4c0	93979295800000937	stress-39792958-937@mediqueue.test	Paciente Stress 39792958-937	55000937	ACTIVO	2026-06-02 22:36:41.466742	2026-06-02 22:36:41.466742	0
e3cc3e4a-a3d9-47ba-9bc2-d5dc2e12ae12	93979302800000963	stress-39793028-963@mediqueue.test	Paciente Stress 39793028-963	55000963	ACTIVO	2026-06-02 22:36:41.635617	2026-06-02 22:36:41.635617	0
61b59be4-b49d-4bc5-8a9e-22ec781d2ed5	93979306000001180	stress-39793060-1180@mediqueue.test	Paciente Stress 39793060-1180	55001180	ACTIVO	2026-06-02 22:36:43.565859	2026-06-02 22:36:43.565859	0
32dc71de-bef1-420a-bcd4-69093e3eeb62	93979306100001290	stress-39793061-1290@mediqueue.test	Paciente Stress 39793061-1290	55001290	ACTIVO	2026-06-02 22:36:44.741628	2026-06-02 22:36:44.741628	0
c061b87a-6307-44bb-8b43-0cd03c359bbf	93979300700001482	stress-39793007-1482@mediqueue.test	Paciente Stress 39793007-1482	55001482	ACTIVO	2026-06-02 22:36:47.019614	2026-06-02 22:36:47.019614	0
d36fd7f8-bd05-4d51-b939-83b22786ecc2	93979300700001545	stress-39793007-1545@mediqueue.test	Paciente Stress 39793007-1545	55001545	ACTIVO	2026-06-02 22:36:47.768872	2026-06-02 22:36:47.768872	0
bebf1fa0-81d7-4ee1-9fb9-335897a0c2be	93979305600001566	stress-39793056-1566@mediqueue.test	Paciente Stress 39793056-1566	55001566	ACTIVO	2026-06-02 22:36:48.076368	2026-06-02 22:36:48.076368	0
cadd86ef-7323-4213-9851-6c7a36fc36cd	93979299300001641	stress-39792993-1641@mediqueue.test	Paciente Stress 39792993-1641	55001641	ACTIVO	2026-06-02 22:36:49.050914	2026-06-02 22:36:49.050914	0
9955ada1-1bf1-4ff3-b7bf-141c84693fc5	93979302300001764	stress-39793023-1764@mediqueue.test	Paciente Stress 39793023-1764	55001764	ACTIVO	2026-06-02 22:36:50.027573	2026-06-02 22:36:50.027573	0
f9b86223-841c-4bde-b1a8-b84c7b87f2ad	93979305900001852	stress-39793059-1852@mediqueue.test	Paciente Stress 39793059-1852	55001852	ACTIVO	2026-06-02 22:36:50.814708	2026-06-02 22:36:50.814708	0
dbdd204f-a241-449f-bba2-5e2876cb18cd	93979301400001993	stress-39793014-1993@mediqueue.test	Paciente Stress 39793014-1993	55001993	ACTIVO	2026-06-02 22:36:52.188749	2026-06-02 22:36:52.188749	0
031622d6-69eb-4a9c-933c-c31e8b85e7f2	93979297900002065	stress-39792979-2065@mediqueue.test	Paciente Stress 39792979-2065	55002065	ACTIVO	2026-06-02 22:36:52.613759	2026-06-02 22:36:52.613759	0
97bacd9f-166f-42a7-a0f3-8a17f6b2e8ce	93979299200002092	stress-39792992-2092@mediqueue.test	Paciente Stress 39792992-2092	55002092	ACTIVO	2026-06-02 22:36:52.758935	2026-06-02 22:36:52.758935	0
9c6fad5c-f8a6-4ecf-b48e-1ec20eb87e9f	93979300200002106	stress-39793002-2106@mediqueue.test	Paciente Stress 39793002-2106	55002106	ACTIVO	2026-06-02 22:36:52.906575	2026-06-02 22:36:52.906575	0
a3988345-2681-4575-8c08-16b35bc97432	93979296000002140	stress-39792960-2140@mediqueue.test	Paciente Stress 39792960-2140	55002140	ACTIVO	2026-06-02 22:36:53.116328	2026-06-02 22:36:53.116328	0
2f1a72c0-9365-4643-8741-11eea66099ce	93979299100002284	stress-39792991-2284@mediqueue.test	Paciente Stress 39792991-2284	55002284	ACTIVO	2026-06-02 22:36:54.279312	2026-06-02 22:36:54.279312	0
e149df7d-bd37-48a8-9a14-5411e1fcee11	93979301600002357	stress-39793016-2357@mediqueue.test	Paciente Stress 39793016-2357	55002357	ACTIVO	2026-06-02 22:36:55.069003	2026-06-02 22:36:55.069003	0
f31ca0eb-d56a-4b95-99b9-d4cc4c0f8d56	93979297400002441	stress-39792974-2441@mediqueue.test	Paciente Stress 39792974-2441	55002441	ACTIVO	2026-06-02 22:36:55.835071	2026-06-02 22:36:55.835071	0
ce464979-e2e4-4d13-bbd8-0f4317edc2bd	93979305800002464	stress-39793058-2464@mediqueue.test	Paciente Stress 39793058-2464	55002464	ACTIVO	2026-06-02 22:36:56.062399	2026-06-02 22:36:56.062399	0
d7e6b02d-dbe2-4425-80a8-894cfbaf2b3a	93979297600002618	stress-39792976-2618@mediqueue.test	Paciente Stress 39792976-2618	55002618	ACTIVO	2026-06-02 22:36:57.138883	2026-06-02 22:36:57.138883	0
d60d9858-796e-4834-9e47-971e8d9277fe	93979300200003174	stress-39793002-3174@mediqueue.test	Paciente Stress 39793002-3174	55003174	ACTIVO	2026-06-02 22:37:11.512574	2026-06-02 22:37:11.512574	0
1a3cba8a-f29e-4129-b3f9-3ac0f3c766f4	93979297500003312	stress-39792975-3312@mediqueue.test	Paciente Stress 39792975-3312	55003312	ACTIVO	2026-06-02 22:37:12.746921	2026-06-02 22:37:12.746921	0
0dfa44a5-2488-4358-a4f8-b4538cbb7ed0	93979295300003425	stress-39792953-3425@mediqueue.test	Paciente Stress 39792953-3425	55003425	ACTIVO	2026-06-02 22:37:13.460551	2026-06-02 22:37:13.460551	0
dc639694-0a54-4fcf-abe8-a5a2507de204	93979301400003528	stress-39793014-3528@mediqueue.test	Paciente Stress 39793014-3528	55003528	ACTIVO	2026-06-02 22:37:14.26619	2026-06-02 22:37:14.26619	0
b47a8d44-1ebe-4b8b-bcf1-c0a35b46ea13	93979299800003620	stress-39792998-3620@mediqueue.test	Paciente Stress 39792998-3620	55003620	ACTIVO	2026-06-02 22:37:15.019933	2026-06-02 22:37:15.019933	0
dde33e9d-2e60-4060-a232-58bf709b7183	93979295300003932	stress-39792953-3932@mediqueue.test	Paciente Stress 39792953-3932	55003932	ACTIVO	2026-06-02 22:37:17.787452	2026-06-02 22:37:17.787452	0
18f80076-c096-4979-83fe-ffea611e8fa2	93979304500004083	stress-39793045-4083@mediqueue.test	Paciente Stress 39793045-4083	55004083	ACTIVO	2026-06-02 22:37:18.768734	2026-06-02 22:37:18.768734	0
34052d90-1e4a-4f47-8999-c6844a0bc7b8	94045691800007252	stress-40456918-7252@mediqueue.test	Paciente Stress 40456918-7252	55007252	ACTIVO	2026-06-02 22:48:47.009412	2026-06-02 22:48:47.009412	0
68187461-2f67-4bb9-96f5-d14d68256e8b	94045692200007315	stress-40456922-7315@mediqueue.test	Paciente Stress 40456922-7315	55007315	ACTIVO	2026-06-02 22:48:47.628967	2026-06-02 22:48:47.628967	0
6bb83143-2e35-4010-abaf-bee164c81e97	94045691300007494	stress-40456913-7494@mediqueue.test	Paciente Stress 40456913-7494	55007494	ACTIVO	2026-06-02 22:48:49.334055	2026-06-02 22:48:49.334055	0
db9dcede-1ac4-41d1-a4cd-091716ba39f0	94045693600008058	stress-40456936-8058@mediqueue.test	Paciente Stress 40456936-8058	55008058	ACTIVO	2026-06-02 22:49:30.316702	2026-06-02 22:49:30.316702	0
e0a5b831-3f96-49d9-a81b-aeba6ceaf7e5	93778432300001051	stress-37784323-1051@mediqueue.test	Paciente Stress 37784323-1051	55001051	ACTIVO	2026-06-02 22:03:28.414469	2026-06-02 22:03:28.414469	0
6aa64d16-b94a-489a-a23a-12d817e6477c	93778432200001117	stress-37784322-1117@mediqueue.test	Paciente Stress 37784322-1117	55001117	ACTIVO	2026-06-02 22:03:28.795109	2026-06-02 22:03:28.795109	0
1206ea22-88ab-4a3b-af1c-8edb9a48186f	93778434600001172	stress-37784346-1172@mediqueue.test	Paciente Stress 37784346-1172	55001172	ACTIVO	2026-06-02 22:03:29.412638	2026-06-02 22:03:29.412638	0
981ff19e-501f-461f-9b6b-72843b7b3b64	93778434000001709	stress-37784340-1709@mediqueue.test	Paciente Stress 37784340-1709	55001709	ACTIVO	2026-06-02 22:03:39.194389	2026-06-02 22:03:39.194389	0
4194d861-8b8f-443e-9634-684ef5815d39	93778431500001778	stress-37784315-1778@mediqueue.test	Paciente Stress 37784315-1778	55001778	ACTIVO	2026-06-02 22:03:39.528212	2026-06-02 22:03:39.528212	0
56a558d7-a80c-4366-9d98-0c62fe261f83	93778434600001915	stress-37784346-1915@mediqueue.test	Paciente Stress 37784346-1915	55001915	ACTIVO	2026-06-02 22:03:40.760142	2026-06-02 22:03:40.760142	0
02265e9e-b035-4346-abe6-ed847e0921ca	93778430600001951	stress-37784306-1951@mediqueue.test	Paciente Stress 37784306-1951	55001951	ACTIVO	2026-06-02 22:03:41.309268	2026-06-02 22:03:41.309268	0
0bacc56e-f80c-476e-ae10-4cb1ca196b45	93778431500001995	stress-37784315-1995@mediqueue.test	Paciente Stress 37784315-1995	55001995	ACTIVO	2026-06-02 22:03:41.99242	2026-06-02 22:03:41.99242	0
ee6502b2-0ecf-4052-874d-7d61baae2112	93778431300002242	stress-37784313-2242@mediqueue.test	Paciente Stress 37784313-2242	55002242	ACTIVO	2026-06-02 22:03:44.780864	2026-06-02 22:03:44.780864	0
2b87d23d-8078-4421-b03a-b04e4ee5854a	93778429900002264	stress-37784299-2264@mediqueue.test	Paciente Stress 37784299-2264	55002264	ACTIVO	2026-06-02 22:03:45.12038	2026-06-02 22:03:45.12038	0
25eff240-869f-418f-9363-1baf44eed2dc	93979296300000239	stress-39792963-239@mediqueue.test	Paciente Stress 39792963-239	55000239	ACTIVO	2026-06-02 22:36:35.855987	2026-06-02 22:36:35.855987	0
aa2e0e54-f642-484b-8dcc-cb0055c28199	93979295800000289	stress-39792958-289@mediqueue.test	Paciente Stress 39792958-289	55000289	ACTIVO	2026-06-02 22:36:36.380578	2026-06-02 22:36:36.380578	0
0c5cf733-8657-4c04-b6d1-cd6d491bceac	93979298000000075	stress-39792980-75@mediqueue.test	Paciente Stress 39792980-75	55000075	ACTIVO	2026-06-02 22:36:36.958366	2026-06-02 22:36:36.958366	0
f49a6a81-0e61-44e1-80d2-935e43f92af0	93979298700000453	stress-39792987-453@mediqueue.test	Paciente Stress 39792987-453	55000453	ACTIVO	2026-06-02 22:36:37.144307	2026-06-02 22:36:37.144307	0
d07f31c7-8178-435b-aab2-056620953142	93979304000000734	stress-39793040-734@mediqueue.test	Paciente Stress 39793040-734	55000734	ACTIVO	2026-06-02 22:36:39.504614	2026-06-02 22:36:39.504614	0
b6e6bc13-bee8-4aff-aeff-965d967cacc6	93979297700000994	stress-39792977-994@mediqueue.test	Paciente Stress 39792977-994	55000994	ACTIVO	2026-06-02 22:36:41.881994	2026-06-02 22:36:41.881994	0
05f4a8ef-30ca-48fa-b27b-168ff3c7f4ab	93979304000001239	stress-39793040-1239@mediqueue.test	Paciente Stress 39793040-1239	55001239	ACTIVO	2026-06-02 22:36:44.169253	2026-06-02 22:36:44.169253	0
252e97db-35d2-4fb2-acde-8c9adaefe53b	93979300100001259	stress-39793001-1259@mediqueue.test	Paciente Stress 39793001-1259	55001259	ACTIVO	2026-06-02 22:36:44.392618	2026-06-02 22:36:44.392618	0
d6b3a48c-ce19-4727-a73c-f03f548b36e8	93979298600001333	stress-39792986-1333@mediqueue.test	Paciente Stress 39792986-1333	55001333	ACTIVO	2026-06-02 22:36:45.311018	2026-06-02 22:36:45.311018	0
b56bc670-abfd-4281-8b35-abf9d131aac2	93979300200001424	stress-39793002-1424@mediqueue.test	Paciente Stress 39793002-1424	55001424	ACTIVO	2026-06-02 22:36:46.240262	2026-06-02 22:36:46.240262	0
b8968c7e-cdcb-488b-b635-0804bf4e0f7f	93979300100001439	stress-39793001-1439@mediqueue.test	Paciente Stress 39793001-1439	55001439	ACTIVO	2026-06-02 22:36:46.470359	2026-06-02 22:36:46.470359	0
154749a5-da6c-436d-9083-f654575c0466	93979294900001511	stress-39792949-1511@mediqueue.test	Paciente Stress 39792949-1511	55001511	ACTIVO	2026-06-02 22:36:47.32787	2026-06-02 22:36:47.32787	0
93171805-aede-4a71-9605-916f224c32f1	93979300100001698	stress-39793001-1698@mediqueue.test	Paciente Stress 39793001-1698	55001698	ACTIVO	2026-06-02 22:36:49.43252	2026-06-02 22:36:49.43252	0
7e695fea-8c29-4db2-969b-ac638229f530	93979300300001823	stress-39793003-1823@mediqueue.test	Paciente Stress 39793003-1823	55001823	ACTIVO	2026-06-02 22:36:50.549199	2026-06-02 22:36:50.549199	0
9c35b216-8e08-444c-90eb-f61e67a08ac5	93979302600002046	stress-39793026-2046@mediqueue.test	Paciente Stress 39793026-2046	55002046	ACTIVO	2026-06-02 22:36:52.463156	2026-06-02 22:36:52.463156	0
419d32bc-1d0b-46ae-8aac-656904dbb974	93979302900002162	stress-39793029-2162@mediqueue.test	Paciente Stress 39793029-2162	55002162	ACTIVO	2026-06-02 22:36:53.294125	2026-06-02 22:36:53.294125	0
cc3b2b16-07c0-4f00-88c4-49884f6038ce	93979297700002420	stress-39792977-2420@mediqueue.test	Paciente Stress 39792977-2420	55002420	ACTIVO	2026-06-02 22:36:55.65036	2026-06-02 22:36:55.65036	0
c1bfa1c6-c4a9-4644-a827-afd78d208f52	93979296000002760	stress-39792960-2760@mediqueue.test	Paciente Stress 39792960-2760	55002760	ACTIVO	2026-06-02 22:37:07.806074	2026-06-02 22:37:07.806074	0
d8e0e468-fd2c-47b2-9fc8-732e7cce0c15	93979296300002814	stress-39792963-2814@mediqueue.test	Paciente Stress 39792963-2814	55002814	ACTIVO	2026-06-02 22:37:08.227172	2026-06-02 22:37:08.227172	0
9a93b342-a3d3-4e17-a46c-80009e7d1a25	93979304300002921	stress-39793043-2921@mediqueue.test	Paciente Stress 39793043-2921	55002921	ACTIVO	2026-06-02 22:37:09.167336	2026-06-02 22:37:09.167336	0
8d7fffe0-1308-496a-8eea-af6e1c75084d	93979305900003226	stress-39793059-3226@mediqueue.test	Paciente Stress 39793059-3226	55003226	ACTIVO	2026-06-02 22:37:11.795716	2026-06-02 22:37:11.795716	0
66899e14-5237-4482-97a4-57b2c5c14aad	93979300000003302	stress-39793000-3302@mediqueue.test	Paciente Stress 39793000-3302	55003302	ACTIVO	2026-06-02 22:37:12.665288	2026-06-02 22:37:12.665288	0
4f3f542f-150d-4d03-9e7d-c29410e0f02a	93979297700003338	stress-39792977-3338@mediqueue.test	Paciente Stress 39792977-3338	55003338	ACTIVO	2026-06-02 22:37:12.96807	2026-06-02 22:37:12.96807	0
7f09ea39-3068-44d4-830f-91ddf0e78e54	93979295700003419	stress-39792957-3419@mediqueue.test	Paciente Stress 39792957-3419	55003419	ACTIVO	2026-06-02 22:37:13.428859	2026-06-02 22:37:13.428859	0
002745bd-31f3-4864-ad2c-b25ff38949de	93979300400003437	stress-39793004-3437@mediqueue.test	Paciente Stress 39793004-3437	55003437	ACTIVO	2026-06-02 22:37:13.570649	2026-06-02 22:37:13.570649	0
1305fb40-a42e-4294-867d-c71b34bd64ad	93979300500003776	stress-39793005-3776@mediqueue.test	Paciente Stress 39793005-3776	55003776	ACTIVO	2026-06-02 22:37:16.364397	2026-06-02 22:37:16.364397	0
5e4f907f-3982-4b06-bf4f-0e7b2d1d5553	93979294900003898	stress-39792949-3898@mediqueue.test	Paciente Stress 39792949-3898	55003898	ACTIVO	2026-06-02 22:37:17.558905	2026-06-02 22:37:17.558905	0
9a730783-d056-48ec-80e0-d353c8269f17	93979300000004009	stress-39793000-4009@mediqueue.test	Paciente Stress 39793000-4009	55004009	ACTIVO	2026-06-02 22:37:18.398473	2026-06-02 22:37:18.398473	0
db2b34f6-3967-4b93-9452-8dde912b1a96	93979305800004153	stress-39793058-4153@mediqueue.test	Paciente Stress 39793058-4153	55004153	ACTIVO	2026-06-02 22:37:19.353178	2026-06-02 22:37:19.353178	0
d8de4370-a1cc-47e7-9333-c0f8ce861cf2	93979301200004211	stress-39793012-4211@mediqueue.test	Paciente Stress 39793012-4211	55004211	ACTIVO	2026-06-02 22:37:19.835614	2026-06-02 22:37:19.835614	0
b9e06df7-bd80-484f-afec-85c37842d5f0	93979300200004291	stress-39793002-4291@mediqueue.test	Paciente Stress 39793002-4291	55004291	ACTIVO	2026-06-02 22:37:20.544096	2026-06-02 22:37:20.544096	0
ec88ac76-5b1e-460e-8701-db91dc4c81bd	94045692900007435	stress-40456929-7435@mediqueue.test	Paciente Stress 40456929-7435	55007435	ACTIVO	2026-06-02 22:48:48.787387	2026-06-02 22:48:48.787387	0
89ad5df5-2b64-40fa-baa4-bcfe7d5e0541	94045695400008180	stress-40456954-8180@mediqueue.test	Paciente Stress 40456954-8180	55008180	ACTIVO	2026-06-02 22:49:31.14569	2026-06-02 22:49:31.14569	0
4e8c688a-c90f-46c3-b547-4073c6e9cad2	94045692800008823	stress-40456928-8823@mediqueue.test	Paciente Stress 40456928-8823	55008823	ACTIVO	2026-06-02 22:49:36.923303	2026-06-02 22:49:36.923303	0
219ab8ff-c52d-4209-9ded-a232dad62599	94045696800008873	stress-40456968-8873@mediqueue.test	Paciente Stress 40456968-8873	55008873	ACTIVO	2026-06-02 22:49:37.297023	2026-06-02 22:49:37.297023	0
e775e32b-d35c-4ba1-88ea-de1bffcb17fd	94045695800009116	stress-40456958-9116@mediqueue.test	Paciente Stress 40456958-9116	55009116	ACTIVO	2026-06-02 22:49:39.597589	2026-06-02 22:49:39.597589	0
bfa18319-632d-4f43-b720-b0ba8a30ed3e	94045696200009273	stress-40456962-9273@mediqueue.test	Paciente Stress 40456962-9273	55009273	ACTIVO	2026-06-02 22:49:41.185429	2026-06-02 22:49:41.185429	0
44a24dcc-0a48-41dc-ab08-cacdb9aa3957	93778432700001062	stress-37784327-1062@mediqueue.test	Paciente Stress 37784327-1062	55001062	ACTIVO	2026-06-02 22:03:28.483975	2026-06-02 22:03:28.483975	0
dcc5d886-ec00-46b1-8819-b2bbd974be0e	93778430600001091	stress-37784306-1091@mediqueue.test	Paciente Stress 37784306-1091	55001091	ACTIVO	2026-06-02 22:03:28.6533	2026-06-02 22:03:28.6533	0
bcda5f67-eae0-4b2e-8014-60913d117047	93778431500001166	stress-37784315-1166@mediqueue.test	Paciente Stress 37784315-1166	55001166	ACTIVO	2026-06-02 22:03:29.412715	2026-06-02 22:03:29.412715	0
867a39af-02f6-42c9-bb24-8ce4d5928d1c	93778434100001187	stress-37784341-1187@mediqueue.test	Paciente Stress 37784341-1187	55001187	ACTIVO	2026-06-02 22:03:29.553018	2026-06-02 22:03:29.553018	0
71a1a170-6ced-4168-b05d-a90b6bcc6cf6	93778431600001312	stress-37784316-1312@mediqueue.test	Paciente Stress 37784316-1312	55001312	ACTIVO	2026-06-02 22:03:31.018918	2026-06-02 22:03:31.018918	0
3b8811e9-730c-471f-876e-4fe9ad61e6d9	93778430600001420	stress-37784306-1420@mediqueue.test	Paciente Stress 37784306-1420	55001420	ACTIVO	2026-06-02 22:03:31.838411	2026-06-02 22:03:31.838411	0
8867e77a-8a70-4c81-9de9-0e873789e072	93778432700001476	stress-37784327-1476@mediqueue.test	Paciente Stress 37784327-1476	55001476	ACTIVO	2026-06-02 22:03:32.421273	2026-06-02 22:03:32.421273	0
9f18ea09-a438-424f-836a-fea95973e3f6	93778434300001543	stress-37784343-1543@mediqueue.test	Paciente Stress 37784343-1543	55001543	ACTIVO	2026-06-02 22:03:33.402777	2026-06-02 22:03:33.402777	0
b13f183d-0310-407b-85eb-70dc3b19da38	93778429900001607	stress-37784299-1607@mediqueue.test	Paciente Stress 37784299-1607	55001607	ACTIVO	2026-06-02 22:03:34.539147	2026-06-02 22:03:34.539147	0
cefada9b-3095-4a3b-8b98-2d4cab08be41	93778434000001793	stress-37784340-1793@mediqueue.test	Paciente Stress 37784340-1793	55001793	ACTIVO	2026-06-02 22:03:39.794048	2026-06-02 22:03:39.794048	0
674abfee-a281-44a6-a1db-409cf4e68d35	93979300000000056	stress-39793000-56@mediqueue.test	Paciente Stress 39793000-56	55000056	ACTIVO	2026-06-02 22:36:36.273018	2026-06-02 22:36:36.273018	0
39e15e07-c524-4ca0-bc6b-4e04ffb7c878	93979306300000195	stress-39793063-195@mediqueue.test	Paciente Stress 39793063-195	55000195	ACTIVO	2026-06-02 22:36:36.484841	2026-06-02 22:36:36.484841	0
79f1aef0-23d1-4c8c-8104-88ab95a4c308	93979296300000403	stress-39792963-403@mediqueue.test	Paciente Stress 39792963-403	55000403	ACTIVO	2026-06-02 22:36:36.910792	2026-06-02 22:36:36.910792	0
34c201f8-ccf4-46b7-bd4c-f1ffd84d50dc	93979304200000533	stress-39793042-533@mediqueue.test	Paciente Stress 39793042-533	55000533	ACTIVO	2026-06-02 22:36:37.883853	2026-06-02 22:36:37.883853	0
cbcc8f15-56ba-4f97-9206-27743f79486c	93979298000000542	stress-39792980-542@mediqueue.test	Paciente Stress 39792980-542	55000542	ACTIVO	2026-06-02 22:36:38.226859	2026-06-02 22:36:38.226859	0
c7ef7ac2-1a83-4546-9b5a-a081fd8a0515	93979306100000662	stress-39793061-662@mediqueue.test	Paciente Stress 39793061-662	55000662	ACTIVO	2026-06-02 22:36:38.949672	2026-06-02 22:36:38.949672	0
a45614ba-77d6-4085-a585-591ba98de4c0	93979301700000767	stress-39793017-767@mediqueue.test	Paciente Stress 39793017-767	55000767	ACTIVO	2026-06-02 22:36:39.61998	2026-06-02 22:36:39.61998	0
4a5ba4bf-3e79-4e14-817f-2e381c8d9b39	93979306100000804	stress-39793061-804@mediqueue.test	Paciente Stress 39793061-804	55000804	ACTIVO	2026-06-02 22:36:40.117287	2026-06-02 22:36:40.117287	0
489db633-52ed-4c61-b35f-80489b210d4f	93979306000000879	stress-39793060-879@mediqueue.test	Paciente Stress 39793060-879	55000879	ACTIVO	2026-06-02 22:36:40.909743	2026-06-02 22:36:40.909743	0
deecd75f-3ba4-4dfe-8553-b34847af15b9	93979297900000892	stress-39792979-892@mediqueue.test	Paciente Stress 39792979-892	55000892	ACTIVO	2026-06-02 22:36:41.029316	2026-06-02 22:36:41.029316	0
4d9f28c3-f830-4456-bb92-d26ef3db0a5f	93979302900000921	stress-39793029-921@mediqueue.test	Paciente Stress 39793029-921	55000921	ACTIVO	2026-06-02 22:36:41.303436	2026-06-02 22:36:41.303436	0
65704519-2bac-4b95-b5a8-67d035975a87	93979304600001224	stress-39793046-1224@mediqueue.test	Paciente Stress 39793046-1224	55001224	ACTIVO	2026-06-02 22:36:44.007208	2026-06-02 22:36:44.007208	0
ca253519-6993-4171-a3a5-5678de02b768	93979299800001293	stress-39792998-1293@mediqueue.test	Paciente Stress 39792998-1293	55001293	ACTIVO	2026-06-02 22:36:44.81431	2026-06-02 22:36:44.81431	0
5eaabef6-de14-4892-a73b-09394b4f90e6	93979294800001338	stress-39792948-1338@mediqueue.test	Paciente Stress 39792948-1338	55001338	ACTIVO	2026-06-02 22:36:45.365757	2026-06-02 22:36:45.365757	0
064ed011-049f-468f-b82e-61b49bf81131	93979296800001663	stress-39792968-1663@mediqueue.test	Paciente Stress 39792968-1663	55001663	ACTIVO	2026-06-02 22:36:49.23374	2026-06-02 22:36:49.23374	0
cd93c279-4977-4a4d-b0cd-be5719f9ed75	93979295900001919	stress-39792959-1919@mediqueue.test	Paciente Stress 39792959-1919	55001919	ACTIVO	2026-06-02 22:36:51.414004	2026-06-02 22:36:51.414004	0
0e838136-6ae2-4f99-bee1-0520e4036942	93979295900001938	stress-39792959-1938@mediqueue.test	Paciente Stress 39792959-1938	55001938	ACTIVO	2026-06-02 22:36:51.665159	2026-06-02 22:36:51.665159	0
fb3e9dd3-c432-499d-82d5-2301d59e02e0	93979300300002157	stress-39793003-2157@mediqueue.test	Paciente Stress 39793003-2157	55002157	ACTIVO	2026-06-02 22:36:53.259782	2026-06-02 22:36:53.259782	0
aa54bc6f-6b65-4af9-8f16-75cf301e6794	93979300100002275	stress-39793001-2275@mediqueue.test	Paciente Stress 39793001-2275	55002275	ACTIVO	2026-06-02 22:36:54.206537	2026-06-02 22:36:54.206537	0
47c902bc-0495-48ac-a9e1-4cfbe2aae86d	93979298700002338	stress-39792987-2338@mediqueue.test	Paciente Stress 39792987-2338	55002338	ACTIVO	2026-06-02 22:36:54.976253	2026-06-02 22:36:54.976253	0
b989343a-7d78-4f11-a332-944ea2913dce	93979298700002440	stress-39792987-2440@mediqueue.test	Paciente Stress 39792987-2440	55002440	ACTIVO	2026-06-02 22:36:55.836007	2026-06-02 22:36:55.836007	0
dea911e3-3827-41ca-b26a-eb7237180917	93979298700002550	stress-39792987-2550@mediqueue.test	Paciente Stress 39792987-2550	55002550	ACTIVO	2026-06-02 22:36:56.688554	2026-06-02 22:36:56.688554	0
e638938c-b8e6-47a4-bb99-cce0e5149e67	93979299300002607	stress-39792993-2607@mediqueue.test	Paciente Stress 39792993-2607	55002607	ACTIVO	2026-06-02 22:36:57.019483	2026-06-02 22:36:57.019483	0
9280fce6-0c56-4e80-9093-a4d4bef4b55c	93979302600002658	stress-39793026-2658@mediqueue.test	Paciente Stress 39793026-2658	55002658	ACTIVO	2026-06-02 22:36:57.355353	2026-06-02 22:36:57.355353	0
79c02168-b660-4604-970d-2cb081389f55	93979303200002745	stress-39793032-2745@mediqueue.test	Paciente Stress 39793032-2745	55002745	ACTIVO	2026-06-02 22:37:07.627727	2026-06-02 22:37:07.627727	0
13481748-fbdc-4ff1-96b9-be3b6af44f14	93979299300003092	stress-39792993-3092@mediqueue.test	Paciente Stress 39792993-3092	55003092	ACTIVO	2026-06-02 22:37:10.731188	2026-06-02 22:37:10.731188	0
bc0892ac-a8ea-46f7-9ca4-0e5fd858c89f	93979300200003121	stress-39793002-3121@mediqueue.test	Paciente Stress 39793002-3121	55003121	ACTIVO	2026-06-02 22:37:11.086839	2026-06-02 22:37:11.086839	0
8ef3263e-778b-4f2b-9f41-d9801453c374	93979300500003327	stress-39793005-3327@mediqueue.test	Paciente Stress 39793005-3327	55003327	ACTIVO	2026-06-02 22:37:12.831747	2026-06-02 22:37:12.831747	0
ec2c81a7-1fbb-4eb8-940c-191e289d4665	93979300500003582	stress-39793005-3582@mediqueue.test	Paciente Stress 39793005-3582	55003582	ACTIVO	2026-06-02 22:37:14.746498	2026-06-02 22:37:14.746498	0
487e2784-6772-4f0a-b5e9-60a7606a6ff1	93979299800003597	stress-39792998-3597@mediqueue.test	Paciente Stress 39792998-3597	55003597	ACTIVO	2026-06-02 22:37:14.899693	2026-06-02 22:37:14.899693	0
5ceb47f6-4df1-47ab-a5ab-6d33cfeb7a62	93979299900003747	stress-39792999-3747@mediqueue.test	Paciente Stress 39792999-3747	55003747	ACTIVO	2026-06-02 22:37:16.105733	2026-06-02 22:37:16.105733	0
7881c03e-3e67-42a3-8c4b-2150a2c0a18b	93979303200003787	stress-39793032-3787@mediqueue.test	Paciente Stress 39793032-3787	55003787	ACTIVO	2026-06-02 22:37:16.3939	2026-06-02 22:37:16.3939	0
f9f01640-7dc8-4ebe-90b4-33d5b08161fb	93979305900003879	stress-39793059-3879@mediqueue.test	Paciente Stress 39793059-3879	55003879	ACTIVO	2026-06-02 22:37:17.443913	2026-06-02 22:37:17.443913	0
d150f5b9-e275-4454-aa33-8d938856fad2	93979304600003923	stress-39793046-3923@mediqueue.test	Paciente Stress 39793046-3923	55003923	ACTIVO	2026-06-02 22:37:17.71353	2026-06-02 22:37:17.71353	0
64208666-92de-4a4e-88b8-1c059859d334	93979305900004007	stress-39793059-4007@mediqueue.test	Paciente Stress 39793059-4007	55004007	ACTIVO	2026-06-02 22:37:18.342842	2026-06-02 22:37:18.342842	0
4762a36b-56e3-4c75-885d-462a4208b173	93979306300004064	stress-39793063-4064@mediqueue.test	Paciente Stress 39793063-4064	55004064	ACTIVO	2026-06-02 22:37:18.683742	2026-06-02 22:37:18.683742	0
b68325c3-705d-4141-9ca3-1e96f1059fce	93979301600004182	stress-39793016-4182@mediqueue.test	Paciente Stress 39793016-4182	55004182	ACTIVO	2026-06-02 22:37:19.595114	2026-06-02 22:37:19.595114	0
454c6f25-c8ca-4a83-af93-2401e11c2eb8	93778431600001647	stress-37784316-1647@mediqueue.test	Paciente Stress 37784316-1647	55001647	ACTIVO	2026-06-02 22:03:34.748908	2026-06-02 22:03:34.748908	0
2a323bbc-7e76-464a-ba8d-2adcebbf5de0	93778431400001789	stress-37784314-1789@mediqueue.test	Paciente Stress 37784314-1789	55001789	ACTIVO	2026-06-02 22:03:39.654938	2026-06-02 22:03:39.654938	0
8ec2cb80-7752-4539-ac26-6ee57e693a8f	93778434300001948	stress-37784343-1948@mediqueue.test	Paciente Stress 37784343-1948	55001948	ACTIVO	2026-06-02 22:03:41.307649	2026-06-02 22:03:41.307649	0
005685e8-e194-4de1-869c-53b563b30fb1	93778433100002223	stress-37784331-2223@mediqueue.test	Paciente Stress 37784331-2223	55002223	ACTIVO	2026-06-02 22:03:44.628798	2026-06-02 22:03:44.628798	0
90578008-eba5-46f4-9175-b02a676bdf39	93856332000000179	stress-38563320-179@mediqueue.test	Paciente Stress 38563320-179	55000179	ACTIVO	2026-06-02 22:16:05.582657	2026-06-02 22:16:05.582657	0
22d0bcfc-3478-4411-861b-178422e2b7c0	93856332700000207	stress-38563327-207@mediqueue.test	Paciente Stress 38563327-207	55000207	ACTIVO	2026-06-02 22:16:05.871009	2026-06-02 22:16:05.871009	0
c7418ccf-c92c-46bf-b14f-5430072d34bc	93856333100000791	stress-38563331-791@mediqueue.test	Paciente Stress 38563331-791	55000791	ACTIVO	2026-06-02 22:16:11.231878	2026-06-02 22:16:11.231878	0
b3032df2-e703-47ef-89bb-e17dd649ef8c	93856331600000980	stress-38563316-980@mediqueue.test	Paciente Stress 38563316-980	55000980	ACTIVO	2026-06-02 22:16:13.117803	2026-06-02 22:16:13.117803	0
1b5e66b5-4402-4325-b94d-594e532d30b0	93856333600001816	stress-38563336-1816@mediqueue.test	Paciente Stress 38563336-1816	55001816	ACTIVO	2026-06-02 22:16:22.291639	2026-06-02 22:16:22.291639	0
deea4f4f-bd17-46ab-8d14-377099102247	93856331600002017	stress-38563316-2017@mediqueue.test	Paciente Stress 38563316-2017	55002017	ACTIVO	2026-06-02 22:16:23.050216	2026-06-02 22:16:23.050216	0
26797c41-e4d1-4f72-8a93-9e938fb85c7f	93856332200002130	stress-38563322-2130@mediqueue.test	Paciente Stress 38563322-2130	55002130	ACTIVO	2026-06-02 22:16:24.141026	2026-06-02 22:16:24.141026	0
c2fceef1-1343-455d-8037-7c6845afb945	93856333800002145	stress-38563338-2145@mediqueue.test	Paciente Stress 38563338-2145	55002145	ACTIVO	2026-06-02 22:16:24.364365	2026-06-02 22:16:24.364365	0
0cdc7706-df40-42b4-bb26-2342ff976e64	93856332300002536	stress-38563323-2536@mediqueue.test	Paciente Stress 38563323-2536	55002536	ACTIVO	2026-06-02 22:16:27.66284	2026-06-02 22:16:27.66284	0
963e914e-6891-404c-a052-da032fae0dce	93856332000002675	stress-38563320-2675@mediqueue.test	Paciente Stress 38563320-2675	55002675	ACTIVO	2026-06-02 22:16:28.504432	2026-06-02 22:16:28.504432	0
7fc7dab8-b8f2-438c-8f8f-c1fa9ec14e67	93856332000002830	stress-38563320-2830@mediqueue.test	Paciente Stress 38563320-2830	55002830	ACTIVO	2026-06-02 22:16:29.528396	2026-06-02 22:16:29.528396	0
473f5b60-e600-4b1e-9b28-8601671dca08	93856333400003310	stress-38563334-3310@mediqueue.test	Paciente Stress 38563334-3310	55003310	ACTIVO	2026-06-02 22:16:32.920781	2026-06-02 22:16:32.920781	0
8f6846ad-602b-4db0-aabd-4b370b2da964	93856332800003365	stress-38563328-3365@mediqueue.test	Paciente Stress 38563328-3365	55003365	ACTIVO	2026-06-02 22:16:33.399452	2026-06-02 22:16:33.399452	0
7e3f73bf-cb22-44c6-af1a-3275146585f6	93856333400003465	stress-38563334-3465@mediqueue.test	Paciente Stress 38563334-3465	55003465	ACTIVO	2026-06-02 22:16:34.092889	2026-06-02 22:16:34.092889	0
23d2723a-9c8c-4c08-a2da-0999cdb3fc5d	93856332000003886	stress-38563320-3886@mediqueue.test	Paciente Stress 38563320-3886	55003886	ACTIVO	2026-06-02 22:16:36.627975	2026-06-02 22:16:36.627975	0
6720b2f1-c0d6-42a9-9ab8-35f43c0410d9	93856330900004122	stress-38563309-4122@mediqueue.test	Paciente Stress 38563309-4122	55004122	ACTIVO	2026-06-02 22:16:38.834534	2026-06-02 22:16:38.834534	0
abe40e95-da82-4dc5-8b8c-c0b5df51fbce	93856332000004186	stress-38563320-4186@mediqueue.test	Paciente Stress 38563320-4186	55004186	ACTIVO	2026-06-02 22:16:39.315663	2026-06-02 22:16:39.315663	0
8c64d506-59ed-4098-a609-522139893137	93856332000004563	stress-38563320-4563@mediqueue.test	Paciente Stress 38563320-4563	55004563	ACTIVO	2026-06-02 22:16:42.551725	2026-06-02 22:16:42.551725	0
3084bd58-dbca-4f35-ae19-416962937b70	93856330900004782	stress-38563309-4782@mediqueue.test	Paciente Stress 38563309-4782	55004782	ACTIVO	2026-06-02 22:16:44.021613	2026-06-02 22:16:44.021613	0
7a1f844c-6a9b-461b-a270-43ff8413cd0c	93856333400004835	stress-38563334-4835@mediqueue.test	Paciente Stress 38563334-4835	55004835	ACTIVO	2026-06-02 22:16:44.484077	2026-06-02 22:16:44.484077	0
b4418fdb-f9da-41f1-aedb-4bc33dc1168b	93877653500007744	stress-38776535-7744@mediqueue.test	Paciente Stress 38776535-7744	55007744	ACTIVO	2026-06-02 22:20:45.954362	2026-06-02 22:20:45.954362	0
f8b0ef08-281b-4ff7-879c-ce375a40cf02	93877655900007909	stress-38776559-7909@mediqueue.test	Paciente Stress 38776559-7909	55007909	ACTIVO	2026-06-02 22:21:09.246813	2026-06-02 22:21:09.246813	0
4f576e44-58ab-476a-8eee-da5d7877a1e1	93877651300008022	stress-38776513-8022@mediqueue.test	Paciente Stress 38776513-8022	55008022	ACTIVO	2026-06-02 22:21:10.083892	2026-06-02 22:21:10.083892	0
a83cd79e-b876-4f08-973b-7c0f2775346f	93877653600008084	stress-38776536-8084@mediqueue.test	Paciente Stress 38776536-8084	55008084	ACTIVO	2026-06-02 22:21:10.654308	2026-06-02 22:21:10.654308	0
a7328b80-b84a-40cf-a599-a4150b7f0679	93877655600008137	stress-38776556-8137@mediqueue.test	Paciente Stress 38776556-8137	55008137	ACTIVO	2026-06-02 22:21:11.146746	2026-06-02 22:21:11.146746	0
fffaf194-f7bc-4cf4-98ae-228a0d0491e4	93877656500008168	stress-38776565-8168@mediqueue.test	Paciente Stress 38776565-8168	55008168	ACTIVO	2026-06-02 22:21:11.531404	2026-06-02 22:21:11.531404	0
dca11c0b-3656-4c82-9c44-6431fa7e8a0f	93877651300008308	stress-38776513-8308@mediqueue.test	Paciente Stress 38776513-8308	55008308	ACTIVO	2026-06-02 22:21:13.725561	2026-06-02 22:21:13.725561	0
a9f572e6-5463-463d-b036-e586163b5278	93877656200008398	stress-38776562-8398@mediqueue.test	Paciente Stress 38776562-8398	55008398	ACTIVO	2026-06-02 22:21:15.155326	2026-06-02 22:21:15.155326	0
18c49e0d-f57d-4681-938d-56ed32a64bc6	93877656200008410	stress-38776562-8410@mediqueue.test	Paciente Stress 38776562-8410	55008410	ACTIVO	2026-06-02 22:21:15.42478	2026-06-02 22:21:15.42478	0
035b79c3-7a75-490b-86a7-011ecdc505bd	93877653800008476	stress-38776538-8476@mediqueue.test	Paciente Stress 38776538-8476	55008476	ACTIVO	2026-06-02 22:21:16.365945	2026-06-02 22:21:16.365945	0
9362e3b5-5888-4e34-8216-8b81c4968fb0	93877650600008484	stress-38776506-8484@mediqueue.test	Paciente Stress 38776506-8484	55008484	ACTIVO	2026-06-02 22:21:16.754044	2026-06-02 22:21:16.754044	0
06adfae2-d7b3-4453-b4a5-e66e038c79d3	93877653600008521	stress-38776536-8521@mediqueue.test	Paciente Stress 38776536-8521	55008521	ACTIVO	2026-06-02 22:21:16.915937	2026-06-02 22:21:16.915937	0
d693bc4d-9685-4301-94ea-a4a573846ed9	93877656400008534	stress-38776564-8534@mediqueue.test	Paciente Stress 38776564-8534	55008534	ACTIVO	2026-06-02 22:21:17.035702	2026-06-02 22:21:17.035702	0
4952c79a-395d-42bf-bf39-807d7f8df813	93877651400008561	stress-38776514-8561@mediqueue.test	Paciente Stress 38776514-8561	55008561	ACTIVO	2026-06-02 22:21:17.309429	2026-06-02 22:21:17.309429	0
0e8c7ec2-0093-417e-89dd-0836a395bbc6	93877651000008585	stress-38776510-8585@mediqueue.test	Paciente Stress 38776510-8585	55008585	ACTIVO	2026-06-02 22:21:17.79194	2026-06-02 22:21:17.79194	0
81cfbbdc-10e0-4e2f-be19-242c09d99d3d	93877653600008618	stress-38776536-8618@mediqueue.test	Paciente Stress 38776536-8618	55008618	ACTIVO	2026-06-02 22:21:18.046812	2026-06-02 22:21:18.046812	0
578398fb-6838-42c6-8e31-cc6e69c3b3c2	93877653800008663	stress-38776538-8663@mediqueue.test	Paciente Stress 38776538-8663	55008663	ACTIVO	2026-06-02 22:21:18.526888	2026-06-02 22:21:18.526888	0
b623b32b-4663-4b74-a298-249c7d1c7119	93877655400008705	stress-38776554-8705@mediqueue.test	Paciente Stress 38776554-8705	55008705	ACTIVO	2026-06-02 22:21:18.9351	2026-06-02 22:21:18.9351	0
54a9eb54-b706-4fa7-9d0b-b96ff9ab6b4c	93877656400008818	stress-38776564-8818@mediqueue.test	Paciente Stress 38776564-8818	55008818	ACTIVO	2026-06-02 22:21:19.788333	2026-06-02 22:21:19.788333	0
de68b0bb-0ef8-45c3-a46f-c540e65388cd	93877654900008822	stress-38776549-8822@mediqueue.test	Paciente Stress 38776549-8822	55008822	ACTIVO	2026-06-02 22:21:19.811859	2026-06-02 22:21:19.811859	0
ed2b810a-adc0-4436-8498-2118ae7e2fe3	93877655900009031	stress-38776559-9031@mediqueue.test	Paciente Stress 38776559-9031	55009031	ACTIVO	2026-06-02 22:21:21.476148	2026-06-02 22:21:21.476148	0
93485d78-6c72-4d53-ad4e-4dce9e1737d4	93877655600009165	stress-38776556-9165@mediqueue.test	Paciente Stress 38776556-9165	55009165	ACTIVO	2026-06-02 22:21:22.979212	2026-06-02 22:21:22.979212	0
2011360b-fb43-4817-a800-d9141198f33b	93877653400009300	stress-38776534-9300@mediqueue.test	Paciente Stress 38776534-9300	55009300	ACTIVO	2026-06-02 22:21:24.984108	2026-06-02 22:21:24.984108	0
09084bc7-c53c-44c1-9447-b2c4a6bcd637	93778431600001680	stress-37784316-1680@mediqueue.test	Paciente Stress 37784316-1680	55001680	ACTIVO	2026-06-02 22:03:39.070157	2026-06-02 22:03:39.070157	0
2aed648b-63e3-4011-a891-1e87d566cf37	93778429900001856	stress-37784299-1856@mediqueue.test	Paciente Stress 37784299-1856	55001856	ACTIVO	2026-06-02 22:03:40.24899	2026-06-02 22:03:40.24899	0
dd9f80b9-4b48-4230-8814-e1167d1b63ef	93778430600001961	stress-37784306-1961@mediqueue.test	Paciente Stress 37784306-1961	55001961	ACTIVO	2026-06-02 22:03:41.453195	2026-06-02 22:03:41.453195	0
7f354612-9af0-4097-b2fb-d188b6bed783	93856332300000417	stress-38563323-417@mediqueue.test	Paciente Stress 38563323-417	55000417	ACTIVO	2026-06-02 22:16:07.567318	2026-06-02 22:16:07.567318	0
ddfcd79c-c7cd-436f-aacb-719953cf23fa	93856331600000507	stress-38563316-507@mediqueue.test	Paciente Stress 38563316-507	55000507	ACTIVO	2026-06-02 22:16:08.386795	2026-06-02 22:16:08.386795	0
691d4ecf-b05c-4d0d-8319-5589765beeee	93856332000000907	stress-38563320-907@mediqueue.test	Paciente Stress 38563320-907	55000907	ACTIVO	2026-06-02 22:16:12.456733	2026-06-02 22:16:12.456733	0
72b93c69-2002-44ff-931e-dd7be0ae9663	93856332100001001	stress-38563321-1001@mediqueue.test	Paciente Stress 38563321-1001	55001001	ACTIVO	2026-06-02 22:16:13.128636	2026-06-02 22:16:13.128636	0
dc694927-a2a4-4967-91b2-2ccf313d47ad	93856333400001754	stress-38563334-1754@mediqueue.test	Paciente Stress 38563334-1754	55001754	ACTIVO	2026-06-02 22:16:21.739376	2026-06-02 22:16:21.739376	0
a397daf6-ab8f-495d-9782-90914a67922c	93856332600001969	stress-38563326-1969@mediqueue.test	Paciente Stress 38563326-1969	55001969	ACTIVO	2026-06-02 22:16:22.539859	2026-06-02 22:16:22.539859	0
c4c49b59-2f0e-4043-85a1-def25ab33d57	93856333400002125	stress-38563334-2125@mediqueue.test	Paciente Stress 38563334-2125	55002125	ACTIVO	2026-06-02 22:16:23.999606	2026-06-02 22:16:23.999606	0
8fffa0f8-c2d0-4e9a-9f11-3946706b4cd0	93856331300002201	stress-38563313-2201@mediqueue.test	Paciente Stress 38563313-2201	55002201	ACTIVO	2026-06-02 22:16:24.838158	2026-06-02 22:16:24.838158	0
1bcba9d6-8439-4996-9805-ed20c42b5c13	93856333500002357	stress-38563335-2357@mediqueue.test	Paciente Stress 38563335-2357	55002357	ACTIVO	2026-06-02 22:16:26.108811	2026-06-02 22:16:26.108811	0
bc88f69b-f4aa-4bbe-80c4-25dfc880d7b5	93856332000002814	stress-38563320-2814@mediqueue.test	Paciente Stress 38563320-2814	55002814	ACTIVO	2026-06-02 22:16:29.470938	2026-06-02 22:16:29.470938	0
ae2a1b65-0d27-4002-8fa1-abc69d852715	93856333700002860	stress-38563337-2860@mediqueue.test	Paciente Stress 38563337-2860	55002860	ACTIVO	2026-06-02 22:16:29.685572	2026-06-02 22:16:29.685572	0
2dd58c20-d44b-4b81-8211-86fd3b0f3c72	93856330700003053	stress-38563307-3053@mediqueue.test	Paciente Stress 38563307-3053	55003053	ACTIVO	2026-06-02 22:16:31.0253	2026-06-02 22:16:31.0253	0
30e9ba9c-d2ea-4f94-8a1d-fe59ff0b3fcf	93856333800003393	stress-38563338-3393@mediqueue.test	Paciente Stress 38563338-3393	55003393	ACTIVO	2026-06-02 22:16:33.586384	2026-06-02 22:16:33.586384	0
d26c1be7-6857-4255-8007-ca6b86fb6188	93856331600003567	stress-38563316-3567@mediqueue.test	Paciente Stress 38563316-3567	55003567	ACTIVO	2026-06-02 22:16:34.662864	2026-06-02 22:16:34.662864	0
d086b1ba-0277-40ea-84b0-972cd90f2e5e	93856332200003998	stress-38563322-3998@mediqueue.test	Paciente Stress 38563322-3998	55003998	ACTIVO	2026-06-02 22:16:37.651846	2026-06-02 22:16:37.651846	0
22a5a218-2de3-46ab-80e8-8acdd41f3e5d	93856333800004062	stress-38563338-4062@mediqueue.test	Paciente Stress 38563338-4062	55004062	ACTIVO	2026-06-02 22:16:38.221714	2026-06-02 22:16:38.221714	0
edc79904-140f-49b5-af5c-a6e5fc3ca516	93856331300004265	stress-38563313-4265@mediqueue.test	Paciente Stress 38563313-4265	55004265	ACTIVO	2026-06-02 22:16:39.991285	2026-06-02 22:16:39.991285	0
023a5438-8649-493d-a8b4-399c49ef4e39	93856331100004344	stress-38563311-4344@mediqueue.test	Paciente Stress 38563311-4344	55004344	ACTIVO	2026-06-02 22:16:40.888911	2026-06-02 22:16:40.888911	0
85f84cd9-e1df-426f-8dc7-2788f5ea0f1b	93856332000004405	stress-38563320-4405@mediqueue.test	Paciente Stress 38563320-4405	55004405	ACTIVO	2026-06-02 22:16:41.418226	2026-06-02 22:16:41.418226	0
0ea8411c-9649-43ac-b4ea-34539f12d7fa	93856333800004536	stress-38563338-4536@mediqueue.test	Paciente Stress 38563338-4536	55004536	ACTIVO	2026-06-02 22:16:42.401929	2026-06-02 22:16:42.401929	0
8ed3911c-af81-4ccb-b3ee-d4477a810542	93877653500007771	stress-38776535-7771@mediqueue.test	Paciente Stress 38776535-7771	55007771	ACTIVO	2026-06-02 22:20:46.178471	2026-06-02 22:20:46.178471	0
22d8e872-58c0-4ee6-9755-d6768d298be2	93877651800008009	stress-38776518-8009@mediqueue.test	Paciente Stress 38776518-8009	55008009	ACTIVO	2026-06-02 22:21:09.993037	2026-06-02 22:21:09.993037	0
07251473-8b8d-4595-bef6-5dcb1809645a	93877651500008201	stress-38776515-8201@mediqueue.test	Paciente Stress 38776515-8201	55008201	ACTIVO	2026-06-02 22:21:12.191464	2026-06-02 22:21:12.191464	0
3fe5147f-ad1e-40c0-ab68-e947a3b489d4	93877651300008324	stress-38776513-8324@mediqueue.test	Paciente Stress 38776513-8324	55008324	ACTIVO	2026-06-02 22:21:14.002878	2026-06-02 22:21:14.002878	0
dfb35bb6-8a94-477d-b7af-e9e9eedf50cb	93877655500008458	stress-38776555-8458@mediqueue.test	Paciente Stress 38776555-8458	55008458	ACTIVO	2026-06-02 22:21:16.225499	2026-06-02 22:21:16.225499	0
6d86298e-dd0a-45d4-a02c-27ad466d76f2	93877655100008731	stress-38776551-8731@mediqueue.test	Paciente Stress 38776551-8731	55008731	ACTIVO	2026-06-02 22:21:19.118818	2026-06-02 22:21:19.118818	0
59d59686-f4a2-41aa-8f26-39abc0669391	93877651300008974	stress-38776513-8974@mediqueue.test	Paciente Stress 38776513-8974	55008974	ACTIVO	2026-06-02 22:21:20.95019	2026-06-02 22:21:20.95019	0
0591a57f-6ee5-40c2-8735-609cdaceffb4	93877655900009040	stress-38776559-9040@mediqueue.test	Paciente Stress 38776559-9040	55009040	ACTIVO	2026-06-02 22:21:21.570648	2026-06-02 22:21:21.570648	0
5e466857-352e-4224-9b25-62691f696c1e	93877655900009080	stress-38776559-9080@mediqueue.test	Paciente Stress 38776559-9080	55009080	ACTIVO	2026-06-02 22:21:21.933399	2026-06-02 22:21:21.933399	0
7da2af6a-95c0-4baa-9c06-4c185e62cb85	93877652300009125	stress-38776523-9125@mediqueue.test	Paciente Stress 38776523-9125	55009125	ACTIVO	2026-06-02 22:21:22.563618	2026-06-02 22:21:22.563618	0
af90dcbb-d6ac-493b-819d-8628db9aaef0	93877654300009164	stress-38776543-9164@mediqueue.test	Paciente Stress 38776543-9164	55009164	ACTIVO	2026-06-02 22:21:22.980608	2026-06-02 22:21:22.980608	0
adb7193d-b0a6-41d4-a20b-e03fb8aa4434	93877655500009254	stress-38776555-9254@mediqueue.test	Paciente Stress 38776555-9254	55009254	ACTIVO	2026-06-02 22:21:24.203684	2026-06-02 22:21:24.203684	0
8c823bb2-294f-40f8-a10d-3d2889999339	93877653800009365	stress-38776538-9365@mediqueue.test	Paciente Stress 38776538-9365	55009365	ACTIVO	2026-06-02 22:21:25.707902	2026-06-02 22:21:25.707902	0
8dcab822-a327-492c-979f-9d7190397f14	93877650900009422	stress-38776509-9422@mediqueue.test	Paciente Stress 38776509-9422	55009422	ACTIVO	2026-06-02 22:21:26.293765	2026-06-02 22:21:26.293765	0
8871965b-1984-415c-bc53-333fcd855c8b	93877655200009507	stress-38776552-9507@mediqueue.test	Paciente Stress 38776552-9507	55009507	ACTIVO	2026-06-02 22:21:27.039568	2026-06-02 22:21:27.039568	0
ca58af00-0adf-4fc7-bb2d-6389598b9ff1	93877651800009557	stress-38776518-9557@mediqueue.test	Paciente Stress 38776518-9557	55009557	ACTIVO	2026-06-02 22:21:27.457169	2026-06-02 22:21:27.457169	0
751e3964-c9bd-414c-a2d3-6c2784945aa0	93877656200009788	stress-38776562-9788@mediqueue.test	Paciente Stress 38776562-9788	55009788	ACTIVO	2026-06-02 22:22:08.168396	2026-06-02 22:22:08.168396	0
ea4ed9c5-df5a-4501-967f-28ed1465e5ec	93877655800009911	stress-38776558-9911@mediqueue.test	Paciente Stress 38776558-9911	55009911	ACTIVO	2026-06-02 22:22:08.514153	2026-06-02 22:22:08.514153	0
cbf59ad3-d837-4384-88b7-ea14e931cc9a	93877653500009974	stress-38776535-9974@mediqueue.test	Paciente Stress 38776535-9974	55009974	ACTIVO	2026-06-02 22:22:08.564066	2026-06-02 22:22:08.564066	0
fc0fc3d8-76bf-4297-84c7-6646da9e098f	93969226400000162	stress-39692264-162@mediqueue.test	Paciente Stress 39692264-162	55000162	ACTIVO	2026-06-02 22:35:00.551258	2026-06-02 22:35:00.551258	0
b8aeb3eb-bb06-4739-a0ff-68088995f1bf	93969225600000264	stress-39692256-264@mediqueue.test	Paciente Stress 39692256-264	55000264	ACTIVO	2026-06-02 22:35:01.513871	2026-06-02 22:35:01.513871	0
561419c8-7819-4920-947f-98035aff636a	93969228000000387	stress-39692280-387@mediqueue.test	Paciente Stress 39692280-387	55000387	ACTIVO	2026-06-02 22:35:02.176141	2026-06-02 22:35:02.176141	0
1b9b3ddc-585e-46ad-9118-c723d804b168	93969228000000399	stress-39692280-399@mediqueue.test	Paciente Stress 39692280-399	55000399	ACTIVO	2026-06-02 22:35:02.556875	2026-06-02 22:35:02.556875	0
b65176da-3625-4c04-81a4-57edc076abb6	93969227100000500	stress-39692271-500@mediqueue.test	Paciente Stress 39692271-500	55000500	ACTIVO	2026-06-02 22:35:02.702441	2026-06-02 22:35:02.702441	0
d8a09576-35f4-4692-8e5a-67d4b0b68ed3	93778431500002286	stress-37784315-2286@mediqueue.test	Paciente Stress 37784315-2286	55002286	ACTIVO	2026-06-02 22:03:45.523998	2026-06-02 22:03:45.523998	0
f546c6cf-2844-47d2-bbca-25c53f836822	93778434000002403	stress-37784340-2403@mediqueue.test	Paciente Stress 37784340-2403	55002403	ACTIVO	2026-06-02 22:03:47.1543	2026-06-02 22:03:47.1543	0
65956afd-ac76-4926-9401-6883e0814344	93778432700002533	stress-37784327-2533@mediqueue.test	Paciente Stress 37784327-2533	55002533	ACTIVO	2026-06-02 22:03:48.473108	2026-06-02 22:03:48.473108	0
69d83c7a-e8fb-4d91-9650-e0b8a58b5a65	93778431300002578	stress-37784313-2578@mediqueue.test	Paciente Stress 37784313-2578	55002578	ACTIVO	2026-06-02 22:03:49.000067	2026-06-02 22:03:49.000067	0
b72caf11-9a38-45d6-b49f-a2bc611a1aad	93778431300002616	stress-37784313-2616@mediqueue.test	Paciente Stress 37784313-2616	55002616	ACTIVO	2026-06-02 22:03:49.305692	2026-06-02 22:03:49.305692	0
94cd445f-9c10-4870-aa33-20ee3a2af05d	93778433100002898	stress-37784331-2898@mediqueue.test	Paciente Stress 37784331-2898	55002898	ACTIVO	2026-06-02 22:03:51.596136	2026-06-02 22:03:51.596136	0
84d44484-ade1-4c9e-b9ee-e0c940a0cbab	93778432400003240	stress-37784324-3240@mediqueue.test	Paciente Stress 37784324-3240	55003240	ACTIVO	2026-06-02 22:03:56.390934	2026-06-02 22:03:56.390934	0
ec72c5c9-c450-4d8d-9258-35dcdf93ef2e	93778432800003515	stress-37784328-3515@mediqueue.test	Paciente Stress 37784328-3515	55003515	ACTIVO	2026-06-02 22:03:58.533182	2026-06-02 22:03:58.533182	0
b534f6a8-ec20-44ae-92e1-623203399e21	93778430600003956	stress-37784306-3956@mediqueue.test	Paciente Stress 37784306-3956	55003956	ACTIVO	2026-06-02 22:04:02.377869	2026-06-02 22:04:02.377869	0
3c098512-91af-4ba4-9199-c8fd4091a17a	93778434000004017	stress-37784340-4017@mediqueue.test	Paciente Stress 37784340-4017	55004017	ACTIVO	2026-06-02 22:04:02.885401	2026-06-02 22:04:02.885401	0
eeb1eddf-df5e-4670-bd40-e4cac3113f01	93778431300004077	stress-37784313-4077@mediqueue.test	Paciente Stress 37784313-4077	55004077	ACTIVO	2026-06-02 22:04:03.365852	2026-06-02 22:04:03.365852	0
df5a55b2-6772-4a6d-bfca-0dca505a0e24	93778430800004311	stress-37784308-4311@mediqueue.test	Paciente Stress 37784308-4311	55004311	ACTIVO	2026-06-02 22:04:05.560131	2026-06-02 22:04:05.560131	0
f7180564-491b-4c98-a302-0e1051c1acea	93778434400004502	stress-37784344-4502@mediqueue.test	Paciente Stress 37784344-4502	55004502	ACTIVO	2026-06-02 22:04:07.330325	2026-06-02 22:04:07.330325	0
73f79ef4-67ad-4c6a-b179-d7d4266bb89a	93778432200004691	stress-37784322-4691@mediqueue.test	Paciente Stress 37784322-4691	55004691	ACTIVO	2026-06-02 22:04:09.113467	2026-06-02 22:04:09.113467	0
cb05061f-4e5a-437c-a408-c5077ded5141	93778434000004929	stress-37784340-4929@mediqueue.test	Paciente Stress 37784340-4929	55004929	ACTIVO	2026-06-02 22:04:10.983855	2026-06-02 22:04:10.983855	0
1c32504f-ccc5-4f18-95a6-d960e28e0361	93877650900000051	stress-38776509-51@mediqueue.test	Paciente Stress 38776509-51	55000051	ACTIVO	2026-06-02 22:19:37.530676	2026-06-02 22:19:37.530676	0
cb6e7eb9-a8db-460a-9bf5-42e430c58dda	93877653500000233	stress-38776535-233@mediqueue.test	Paciente Stress 38776535-233	55000233	ACTIVO	2026-06-02 22:19:37.800505	2026-06-02 22:19:37.800505	0
f34df8f1-834c-4c9e-8a0f-2ed398abb389	93877653600000246	stress-38776536-246@mediqueue.test	Paciente Stress 38776536-246	55000246	ACTIVO	2026-06-02 22:19:38.214655	2026-06-02 22:19:38.214655	0
cf71321c-96fa-4aaf-b01c-f39e7ce71183	93877650600000343	stress-38776506-343@mediqueue.test	Paciente Stress 38776506-343	55000343	ACTIVO	2026-06-02 22:19:38.984226	2026-06-02 22:19:38.984226	0
d105cc7d-f452-4fca-b9ab-3f223797b2f6	93877655500000457	stress-38776555-457@mediqueue.test	Paciente Stress 38776555-457	55000457	ACTIVO	2026-06-02 22:19:39.943259	2026-06-02 22:19:39.943259	0
e3c7cedc-6b08-4ab8-a25d-1d54bbe560e4	93877655500000627	stress-38776555-627@mediqueue.test	Paciente Stress 38776555-627	55000627	ACTIVO	2026-06-02 22:19:41.57636	2026-06-02 22:19:41.57636	0
bfd6a4db-5092-4d77-b063-e5292384b915	93877654400000655	stress-38776544-655@mediqueue.test	Paciente Stress 38776544-655	55000655	ACTIVO	2026-06-02 22:19:41.890035	2026-06-02 22:19:41.890035	0
eb2d9fe6-8080-4396-8d28-4fe5c259d626	93877653300000790	stress-38776533-790@mediqueue.test	Paciente Stress 38776533-790	55000790	ACTIVO	2026-06-02 22:19:42.033168	2026-06-02 22:19:42.033168	0
5bf93f3d-259a-4434-a565-c2cd1d12f97b	93877655100001652	stress-38776551-1652@mediqueue.test	Paciente Stress 38776551-1652	55001652	ACTIVO	2026-06-02 22:19:48.503162	2026-06-02 22:19:48.503162	0
1280c385-2c0f-4e23-9873-fa074149353b	93877655900001799	stress-38776559-1799@mediqueue.test	Paciente Stress 38776559-1799	55001799	ACTIVO	2026-06-02 22:19:50.780461	2026-06-02 22:19:50.780461	0
b9c9f7c2-3c8c-40c2-9d60-1972901b1686	93877654000002591	stress-38776540-2591@mediqueue.test	Paciente Stress 38776540-2591	55002591	ACTIVO	2026-06-02 22:19:59.580264	2026-06-02 22:19:59.580264	0
1c49139d-b69c-4eb6-b2ac-5786a546cda5	93877654200002268	stress-38776542-2268@mediqueue.test	Paciente Stress 38776542-2268	55002268	ACTIVO	2026-06-02 22:19:59.761471	2026-06-02 22:19:59.761471	0
ff97944e-3773-4005-a201-e0fc28c9ad50	93877656100002528	stress-38776561-2528@mediqueue.test	Paciente Stress 38776561-2528	55002528	ACTIVO	2026-06-02 22:20:01.391928	2026-06-02 22:20:01.391928	0
06261391-69fe-4e20-aa12-a992613dc146	93877652900002808	stress-38776529-2808@mediqueue.test	Paciente Stress 38776529-2808	55002808	ACTIVO	2026-06-02 22:20:01.55955	2026-06-02 22:20:01.55955	0
a4ec9d94-4460-4b7f-9109-9687f67128b0	93877655500003439	stress-38776555-3439@mediqueue.test	Paciente Stress 38776555-3439	55003439	ACTIVO	2026-06-02 22:20:05.037663	2026-06-02 22:20:05.037663	0
8ff7f3b5-3a97-4973-8e65-2867af82172f	93877650900003849	stress-38776509-3849@mediqueue.test	Paciente Stress 38776509-3849	55003849	ACTIVO	2026-06-02 22:20:07.62245	2026-06-02 22:20:07.62245	0
702c2b65-c6d4-4010-8a8f-665652b19d78	93877655000004236	stress-38776550-4236@mediqueue.test	Paciente Stress 38776550-4236	55004236	ACTIVO	2026-06-02 22:20:10.875253	2026-06-02 22:20:10.875253	0
ee786d40-94cb-4759-bf1b-3e2cdc23ae39	93877656300005101	stress-38776563-5101@mediqueue.test	Paciente Stress 38776563-5101	55005101	ACTIVO	2026-06-02 22:20:21.658887	2026-06-02 22:20:21.658887	0
670d261a-f7ca-446f-9f44-e3d835861c66	93877655200005268	stress-38776552-5268@mediqueue.test	Paciente Stress 38776552-5268	55005268	ACTIVO	2026-06-02 22:20:23.589377	2026-06-02 22:20:23.589377	0
7a3cdba1-d27b-4f62-b751-f840b654ff20	93877655900005406	stress-38776559-5406@mediqueue.test	Paciente Stress 38776559-5406	55005406	ACTIVO	2026-06-02 22:20:24.810263	2026-06-02 22:20:24.810263	0
5c25054c-4f80-4308-a563-6e11b0739d23	93877653800005670	stress-38776538-5670@mediqueue.test	Paciente Stress 38776538-5670	55005670	ACTIVO	2026-06-02 22:20:27.30566	2026-06-02 22:20:27.30566	0
a0c1f959-972f-471f-a006-afa5c9bbdea3	93877653500005940	stress-38776535-5940@mediqueue.test	Paciente Stress 38776535-5940	55005940	ACTIVO	2026-06-02 22:20:30.22687	2026-06-02 22:20:30.22687	0
99662c27-c928-47b4-adfa-4d3c478330d1	93877650600006026	stress-38776506-6026@mediqueue.test	Paciente Stress 38776506-6026	55006026	ACTIVO	2026-06-02 22:20:30.763458	2026-06-02 22:20:30.763458	0
3e1c3839-3004-47c7-ae96-132d2fe37f0f	93877653800006142	stress-38776538-6142@mediqueue.test	Paciente Stress 38776538-6142	55006142	ACTIVO	2026-06-02 22:20:32.270094	2026-06-02 22:20:32.270094	0
06697776-4b13-45fe-bccf-9d856b7c26c1	93877653600006169	stress-38776536-6169@mediqueue.test	Paciente Stress 38776536-6169	55006169	ACTIVO	2026-06-02 22:20:32.708288	2026-06-02 22:20:32.708288	0
21739101-35a9-43c1-a33e-f8abf5e7669b	93877654500006572	stress-38776545-6572@mediqueue.test	Paciente Stress 38776545-6572	55006572	ACTIVO	2026-06-02 22:20:35.421989	2026-06-02 22:20:35.421989	0
b77b5399-cafc-42e9-bd68-8c17f71cc967	93877652900006896	stress-38776529-6896@mediqueue.test	Paciente Stress 38776529-6896	55006896	ACTIVO	2026-06-02 22:20:38.915547	2026-06-02 22:20:38.915547	0
24bee6bd-5d14-4109-806b-cb44c7b32b9b	93877651300007042	stress-38776513-7042@mediqueue.test	Paciente Stress 38776513-7042	55007042	ACTIVO	2026-06-02 22:20:39.991849	2026-06-02 22:20:39.991849	0
9a22c611-6fc7-489f-a7f5-38311ce00192	93877654300007504	stress-38776543-7504@mediqueue.test	Paciente Stress 38776543-7504	55007504	ACTIVO	2026-06-02 22:20:43.883364	2026-06-02 22:20:43.883364	0
e7d4d7a7-cdc7-4959-8440-6f04ea6dda58	93877655200007815	stress-38776552-7815@mediqueue.test	Paciente Stress 38776552-7815	55007815	ACTIVO	2026-06-02 22:21:08.731439	2026-06-02 22:21:08.731439	0
b7ee055f-7860-4fb8-8c4b-7f060755e0e0	93877655500007954	stress-38776555-7954@mediqueue.test	Paciente Stress 38776555-7954	55007954	ACTIVO	2026-06-02 22:21:09.587666	2026-06-02 22:21:09.587666	0
bbdd2e37-65a8-4a26-bf25-9506aaf3965b	93877654700008060	stress-38776547-8060@mediqueue.test	Paciente Stress 38776547-8060	55008060	ACTIVO	2026-06-02 22:21:10.375024	2026-06-02 22:21:10.375024	0
6b0bd154-10f6-466a-a5dc-183235fc002d	93778431500002319	stress-37784315-2319@mediqueue.test	Paciente Stress 37784315-2319	55002319	ACTIVO	2026-06-02 22:03:45.779406	2026-06-02 22:03:45.779406	0
97a87e20-7b00-48a5-bf5c-30b7989baf76	93778431800002769	stress-37784318-2769@mediqueue.test	Paciente Stress 37784318-2769	55002769	ACTIVO	2026-06-02 22:03:50.744792	2026-06-02 22:03:50.744792	0
dc94b5c7-dc28-4931-a071-3e3921cd1b80	93778432200003491	stress-37784322-3491@mediqueue.test	Paciente Stress 37784322-3491	55003491	ACTIVO	2026-06-02 22:03:58.417663	2026-06-02 22:03:58.417663	0
b2eafee0-b9ef-4fd5-9012-a8eb4afe3466	93778434300003707	stress-37784343-3707@mediqueue.test	Paciente Stress 37784343-3707	55003707	ACTIVO	2026-06-02 22:04:00.287592	2026-06-02 22:04:00.287592	0
32d91023-9e7c-4d41-b115-dab878206f89	93778431600003746	stress-37784316-3746@mediqueue.test	Paciente Stress 37784316-3746	55003746	ACTIVO	2026-06-02 22:04:00.635305	2026-06-02 22:04:00.635305	0
850a6c74-4762-4582-a9b6-4abdf4d57841	93778434300003899	stress-37784343-3899@mediqueue.test	Paciente Stress 37784343-3899	55003899	ACTIVO	2026-06-02 22:04:01.708241	2026-06-02 22:04:01.708241	0
8856e316-fb4c-424b-a42e-dcf0da6539cd	93778432300004519	stress-37784323-4519@mediqueue.test	Paciente Stress 37784323-4519	55004519	ACTIVO	2026-06-02 22:04:07.434531	2026-06-02 22:04:07.434531	0
cc089588-4a3f-481d-8397-9d3cb014a528	93778430600004534	stress-37784306-4534@mediqueue.test	Paciente Stress 37784306-4534	55004534	ACTIVO	2026-06-02 22:04:07.645148	2026-06-02 22:04:07.645148	0
de987eca-de23-4fee-82cd-4c8b0a3f2ec6	93778433000004992	stress-37784330-4992@mediqueue.test	Paciente Stress 37784330-4992	55004992	ACTIVO	2026-06-02 22:04:11.462318	2026-06-02 22:04:11.462318	0
cf1ee819-dc1a-4cf3-ac93-48ff63b8cb6c	93877651300000023	stress-38776513-23@mediqueue.test	Paciente Stress 38776513-23	55000023	ACTIVO	2026-06-02 22:19:37.531394	2026-06-02 22:19:37.531394	0
b81ddc4c-6e0b-4795-957a-e4615ff27902	93877654900000235	stress-38776549-235@mediqueue.test	Paciente Stress 38776549-235	55000235	ACTIVO	2026-06-02 22:19:37.776512	2026-06-02 22:19:37.776512	0
a16878d5-6c8a-4834-8c57-2a51a968c1a0	93877656000000239	stress-38776560-239@mediqueue.test	Paciente Stress 38776560-239	55000239	ACTIVO	2026-06-02 22:19:38.214852	2026-06-02 22:19:38.214852	0
cdd8f101-37f1-428a-8bae-6fa207d45469	93877655800000172	stress-38776558-172@mediqueue.test	Paciente Stress 38776558-172	55000172	ACTIVO	2026-06-02 22:19:38.394736	2026-06-02 22:19:38.394736	0
511bcadb-c657-4241-b483-efc2ac733d9e	93877654100000470	stress-38776541-470@mediqueue.test	Paciente Stress 38776541-470	55000470	ACTIVO	2026-06-02 22:19:41.058826	2026-06-02 22:19:41.058826	0
e79a2a58-5959-42dc-9e7a-7067f0b8e995	93877654700000670	stress-38776547-670@mediqueue.test	Paciente Stress 38776547-670	55000670	ACTIVO	2026-06-02 22:19:41.798691	2026-06-02 22:19:41.798691	0
9a9e2c0a-5965-4069-bcb7-935137b8d90c	93877652100000730	stress-38776521-730@mediqueue.test	Paciente Stress 38776521-730	55000730	ACTIVO	2026-06-02 22:19:42.084932	2026-06-02 22:19:42.084932	0
ce0d713c-7ea9-4a29-8dba-69c44510298f	93877655700000919	stress-38776557-919@mediqueue.test	Paciente Stress 38776557-919	55000919	ACTIVO	2026-06-02 22:19:42.674652	2026-06-02 22:19:42.674652	0
ebe122a5-e41c-43b9-b8b5-e426b5960bd0	93877655700001165	stress-38776557-1165@mediqueue.test	Paciente Stress 38776557-1165	55001165	ACTIVO	2026-06-02 22:19:43.986863	2026-06-02 22:19:43.986863	0
4c2c76df-57f2-451f-b5b0-064c27d1fc76	93877655500001673	stress-38776555-1673@mediqueue.test	Paciente Stress 38776555-1673	55001673	ACTIVO	2026-06-02 22:19:48.801504	2026-06-02 22:19:48.801504	0
1a7283c4-a6f0-43f9-9247-3d969e19af0f	93877651500002142	stress-38776515-2142@mediqueue.test	Paciente Stress 38776515-2142	55002142	ACTIVO	2026-06-02 22:19:54.325189	2026-06-02 22:19:54.325189	0
9448b513-fe06-47b1-b7e8-b80ee7421608	93877652100002427	stress-38776521-2427@mediqueue.test	Paciente Stress 38776521-2427	55002427	ACTIVO	2026-06-02 22:19:59.614073	2026-06-02 22:19:59.614073	0
84dbdf31-1eff-4b2a-8e7c-5f332323f6c3	93877654600002393	stress-38776546-2393@mediqueue.test	Paciente Stress 38776546-2393	55002393	ACTIVO	2026-06-02 22:20:01.525723	2026-06-02 22:20:01.525723	0
d78b6c5a-0989-41be-9c08-ad0bf95562cb	93877656400002661	stress-38776564-2661@mediqueue.test	Paciente Stress 38776564-2661	55002661	ACTIVO	2026-06-02 22:20:01.933379	2026-06-02 22:20:01.933379	0
b4b7c762-dcb8-4a4b-af72-ca8b3cee47a1	93877650900003058	stress-38776509-3058@mediqueue.test	Paciente Stress 38776509-3058	55003058	ACTIVO	2026-06-02 22:20:02.727385	2026-06-02 22:20:02.727385	0
d89a6466-abdc-411b-95af-f05508aed720	93877653600003117	stress-38776536-3117@mediqueue.test	Paciente Stress 38776536-3117	55003117	ACTIVO	2026-06-02 22:20:02.998724	2026-06-02 22:20:02.998724	0
4ab59f11-6473-458e-9aeb-e5e3254b43c1	93877654700003358	stress-38776547-3358@mediqueue.test	Paciente Stress 38776547-3358	55003358	ACTIVO	2026-06-02 22:20:04.5838	2026-06-02 22:20:04.5838	0
622994e1-fe00-4972-97b6-936f1e23053b	93877654300003546	stress-38776543-3546@mediqueue.test	Paciente Stress 38776543-3546	55003546	ACTIVO	2026-06-02 22:20:05.655311	2026-06-02 22:20:05.655311	0
857c5d95-3cb9-4884-98e0-f516e29bedc1	93877655100003721	stress-38776551-3721@mediqueue.test	Paciente Stress 38776551-3721	55003721	ACTIVO	2026-06-02 22:20:06.694957	2026-06-02 22:20:06.694957	0
01cc1b66-7407-471f-af58-01169e0f1dd4	93877653400003860	stress-38776534-3860@mediqueue.test	Paciente Stress 38776534-3860	55003860	ACTIVO	2026-06-02 22:20:07.674225	2026-06-02 22:20:07.674225	0
ccc2a4db-65ba-48fe-8212-08e7833036c1	93877653500003952	stress-38776535-3952@mediqueue.test	Paciente Stress 38776535-3952	55003952	ACTIVO	2026-06-02 22:20:08.359844	2026-06-02 22:20:08.359844	0
02bad92c-47d7-4b35-b662-31fce8373b3c	93877654000003978	stress-38776540-3978@mediqueue.test	Paciente Stress 38776540-3978	55003978	ACTIVO	2026-06-02 22:20:08.53147	2026-06-02 22:20:08.53147	0
1cb79002-3c7d-4047-8de4-610352e51df6	93877651400004059	stress-38776514-4059@mediqueue.test	Paciente Stress 38776514-4059	55004059	ACTIVO	2026-06-02 22:20:09.188212	2026-06-02 22:20:09.188212	0
6f7accda-6f3b-4050-81c3-0f3c5458ee8c	93877654700004103	stress-38776547-4103@mediqueue.test	Paciente Stress 38776547-4103	55004103	ACTIVO	2026-06-02 22:20:09.501479	2026-06-02 22:20:09.501479	0
4d73d528-ba6b-4587-9fec-f98f317d8170	93877651400004468	stress-38776514-4468@mediqueue.test	Paciente Stress 38776514-4468	55004468	ACTIVO	2026-06-02 22:20:13.215347	2026-06-02 22:20:13.215347	0
6fa6ce39-6865-4615-8d0a-55f970d14d0d	93877652900004684	stress-38776529-4684@mediqueue.test	Paciente Stress 38776529-4684	55004684	ACTIVO	2026-06-02 22:20:15.599585	2026-06-02 22:20:15.599585	0
a97e2e45-7db7-4167-9a20-4446e2a0db51	93877655300004988	stress-38776553-4988@mediqueue.test	Paciente Stress 38776553-4988	55004988	ACTIVO	2026-06-02 22:20:20.657841	2026-06-02 22:20:20.657841	0
6f494ffb-b5ee-4dbb-9977-35b9e5ff6fee	93877656400005202	stress-38776564-5202@mediqueue.test	Paciente Stress 38776564-5202	55005202	ACTIVO	2026-06-02 22:20:23.021422	2026-06-02 22:20:23.021422	0
6d2e3ba0-c39b-44fb-a70e-58011703ba88	93877654800005231	stress-38776548-5231@mediqueue.test	Paciente Stress 38776548-5231	55005231	ACTIVO	2026-06-02 22:20:23.23129	2026-06-02 22:20:23.23129	0
72655475-5396-4b79-9243-b7a0f53b87cc	93877650900005360	stress-38776509-5360@mediqueue.test	Paciente Stress 38776509-5360	55005360	ACTIVO	2026-06-02 22:20:24.439826	2026-06-02 22:20:24.439826	0
a9877081-1d20-4f43-aba1-c340e4d0b7d3	93877653800005692	stress-38776538-5692@mediqueue.test	Paciente Stress 38776538-5692	55005692	ACTIVO	2026-06-02 22:20:27.524735	2026-06-02 22:20:27.524735	0
241c11ba-78f6-4cdf-818e-434c174381e1	93877651300005823	stress-38776513-5823@mediqueue.test	Paciente Stress 38776513-5823	55005823	ACTIVO	2026-06-02 22:20:28.775366	2026-06-02 22:20:28.775366	0
b90baa1e-41aa-4457-8ea8-3e71f6c1e815	93877655800006048	stress-38776558-6048@mediqueue.test	Paciente Stress 38776558-6048	55006048	ACTIVO	2026-06-02 22:20:31.790439	2026-06-02 22:20:31.790439	0
208c2de8-c4ec-426e-a76a-8439ab0f2d1b	93877651000006218	stress-38776510-6218@mediqueue.test	Paciente Stress 38776510-6218	55006218	ACTIVO	2026-06-02 22:20:32.846038	2026-06-02 22:20:32.846038	0
7f8ee0d0-6da7-4901-9613-8bcfa99c05ec	93877653600006468	stress-38776536-6468@mediqueue.test	Paciente Stress 38776536-6468	55006468	ACTIVO	2026-06-02 22:20:34.724127	2026-06-02 22:20:34.724127	0
e970cc6d-4062-48ca-97de-487afa55d186	93877653600006503	stress-38776536-6503@mediqueue.test	Paciente Stress 38776536-6503	55006503	ACTIVO	2026-06-02 22:20:35.00667	2026-06-02 22:20:35.00667	0
6cf859cf-070a-4a3d-8c5d-bdc09f3630aa	93877655200006717	stress-38776552-6717@mediqueue.test	Paciente Stress 38776552-6717	55006717	ACTIVO	2026-06-02 22:20:36.840671	2026-06-02 22:20:36.840671	0
771d9de1-b68b-4391-b315-30ddf7000c88	93877655700006824	stress-38776557-6824@mediqueue.test	Paciente Stress 38776557-6824	55006824	ACTIVO	2026-06-02 22:20:38.442405	2026-06-02 22:20:38.442405	0
0eb39123-af2b-401c-94b2-9873271d3efc	93778430600002361	stress-37784306-2361@mediqueue.test	Paciente Stress 37784306-2361	55002361	ACTIVO	2026-06-02 22:03:46.653043	2026-06-02 22:03:46.653043	0
30cd745e-51ef-421b-8e8c-06a6b37c122f	93778430300002590	stress-37784303-2590@mediqueue.test	Paciente Stress 37784303-2590	55002590	ACTIVO	2026-06-02 22:03:49.140882	2026-06-02 22:03:49.140882	0
fe7c0824-316f-467e-80fb-7a89ac9e3776	93778432400002708	stress-37784324-2708@mediqueue.test	Paciente Stress 37784324-2708	55002708	ACTIVO	2026-06-02 22:03:50.20315	2026-06-02 22:03:50.20315	0
13a53983-bd72-413f-9691-8d46f013c2ec	93778432700002943	stress-37784327-2943@mediqueue.test	Paciente Stress 37784327-2943	55002943	ACTIVO	2026-06-02 22:03:51.860071	2026-06-02 22:03:51.860071	0
ed64ac81-8ad0-4768-a3ec-a435bb53e0ff	93778431600003094	stress-37784316-3094@mediqueue.test	Paciente Stress 37784316-3094	55003094	ACTIVO	2026-06-02 22:03:54.543203	2026-06-02 22:03:54.543203	0
fc40dd9a-1581-4d0e-a7a5-d91724f30c31	93778429900003653	stress-37784299-3653@mediqueue.test	Paciente Stress 37784299-3653	55003653	ACTIVO	2026-06-02 22:03:59.774627	2026-06-02 22:03:59.774627	0
bdaec468-e899-40d1-9fa1-fab02862c5fd	93778432700003745	stress-37784327-3745@mediqueue.test	Paciente Stress 37784327-3745	55003745	ACTIVO	2026-06-02 22:04:00.606472	2026-06-02 22:04:00.606472	0
043e4f8e-6086-4528-9d66-129187f3b2b4	93778431900003813	stress-37784319-3813@mediqueue.test	Paciente Stress 37784319-3813	55003813	ACTIVO	2026-06-02 22:04:01.052829	2026-06-02 22:04:01.052829	0
2e782c75-d88f-4c8d-96c8-da3adacdea12	93778433600003822	stress-37784336-3822@mediqueue.test	Paciente Stress 37784336-3822	55003822	ACTIVO	2026-06-02 22:04:01.175076	2026-06-02 22:04:01.175076	0
cd66dc90-a76f-4b54-93ea-5e9cd59eb300	93778433600003865	stress-37784336-3865@mediqueue.test	Paciente Stress 37784336-3865	55003865	ACTIVO	2026-06-02 22:04:01.49584	2026-06-02 22:04:01.49584	0
9cede9a6-f1e7-482e-9df9-03dbcf6ded58	93778431300003903	stress-37784313-3903@mediqueue.test	Paciente Stress 37784313-3903	55003903	ACTIVO	2026-06-02 22:04:01.730272	2026-06-02 22:04:01.730272	0
7dfa5bff-62a9-446b-9b4a-e76f83106805	93778431800003979	stress-37784318-3979@mediqueue.test	Paciente Stress 37784318-3979	55003979	ACTIVO	2026-06-02 22:04:02.675671	2026-06-02 22:04:02.675671	0
413f81aa-74e4-4b83-8016-9b7a275bb955	93778430500004031	stress-37784305-4031@mediqueue.test	Paciente Stress 37784305-4031	55004031	ACTIVO	2026-06-02 22:04:02.966702	2026-06-02 22:04:02.966702	0
0071bcf6-d96f-4b73-8528-5ad307157a0a	93778434100004140	stress-37784341-4140@mediqueue.test	Paciente Stress 37784341-4140	55004140	ACTIVO	2026-06-02 22:04:04.058841	2026-06-02 22:04:04.058841	0
78d67d8b-dfa7-4f9b-9a71-064762b50fd8	93778434400004351	stress-37784344-4351@mediqueue.test	Paciente Stress 37784344-4351	55004351	ACTIVO	2026-06-02 22:04:06.143103	2026-06-02 22:04:06.143103	0
5ee685ca-6db2-41ae-b12e-f72dad751a3a	93778431900004445	stress-37784319-4445@mediqueue.test	Paciente Stress 37784319-4445	55004445	ACTIVO	2026-06-02 22:04:06.878127	2026-06-02 22:04:06.878127	0
febc9254-6a1f-457d-8643-9dc5bcabe6a7	93778431300004535	stress-37784313-4535@mediqueue.test	Paciente Stress 37784313-4535	55004535	ACTIVO	2026-06-02 22:04:07.678066	2026-06-02 22:04:07.678066	0
375d7283-e629-45d3-8276-6738e932cdfa	93877650900000079	stress-38776509-79@mediqueue.test	Paciente Stress 38776509-79	55000079	ACTIVO	2026-06-02 22:19:37.549424	2026-06-02 22:19:37.549424	0
68681444-f970-4fa6-860b-754c7173651e	93877651300000741	stress-38776513-741@mediqueue.test	Paciente Stress 38776513-741	55000741	ACTIVO	2026-06-02 22:19:41.677311	2026-06-02 22:19:41.677311	0
d03d44f7-4981-4d4c-a585-2435d84b8683	93877654700000907	stress-38776547-907@mediqueue.test	Paciente Stress 38776547-907	55000907	ACTIVO	2026-06-02 22:19:42.549663	2026-06-02 22:19:42.549663	0
efa2feb5-8560-4173-9af4-f7495056c61c	93877656000000964	stress-38776560-964@mediqueue.test	Paciente Stress 38776560-964	55000964	ACTIVO	2026-06-02 22:19:43.17247	2026-06-02 22:19:43.17247	0
1073e37c-5c5b-48c7-aff0-1fca3bf8ab11	93877653800001117	stress-38776538-1117@mediqueue.test	Paciente Stress 38776538-1117	55001117	ACTIVO	2026-06-02 22:19:43.603788	2026-06-02 22:19:43.603788	0
ef081540-8ce7-43bb-b919-690308ddf6e0	93877656100001147	stress-38776561-1147@mediqueue.test	Paciente Stress 38776561-1147	55001147	ACTIVO	2026-06-02 22:19:43.888824	2026-06-02 22:19:43.888824	0
6d3f02fd-a3bc-40c4-961b-170d6d13b7ec	93877655700001293	stress-38776557-1293@mediqueue.test	Paciente Stress 38776557-1293	55001293	ACTIVO	2026-06-02 22:19:44.718321	2026-06-02 22:19:44.718321	0
b0085746-f03c-4a19-a35f-c738b2a1a317	93877653600001483	stress-38776536-1483@mediqueue.test	Paciente Stress 38776536-1483	55001483	ACTIVO	2026-06-02 22:19:46.890824	2026-06-02 22:19:46.890824	0
bc8985b3-3c23-4349-86eb-fdf41bdde1c1	93877655600001688	stress-38776556-1688@mediqueue.test	Paciente Stress 38776556-1688	55001688	ACTIVO	2026-06-02 22:19:49.02082	2026-06-02 22:19:49.02082	0
081e3d67-e407-4fb7-bd7a-7e88e5951998	93877656000001745	stress-38776560-1745@mediqueue.test	Paciente Stress 38776560-1745	55001745	ACTIVO	2026-06-02 22:19:49.373624	2026-06-02 22:19:49.373624	0
175c60dd-c60a-44c6-b22e-849df641337d	93877653400002755	stress-38776534-2755@mediqueue.test	Paciente Stress 38776534-2755	55002755	ACTIVO	2026-06-02 22:20:01.340987	2026-06-02 22:20:01.340987	0
8cc790e0-130d-4beb-a71c-ef9c2ffe1c68	93877651100002677	stress-38776511-2677@mediqueue.test	Paciente Stress 38776511-2677	55002677	ACTIVO	2026-06-02 22:20:01.50982	2026-06-02 22:20:01.50982	0
ac51eaea-db79-4b4f-8b38-cae27cab3a8e	93877651300003032	stress-38776513-3032@mediqueue.test	Paciente Stress 38776513-3032	55003032	ACTIVO	2026-06-02 22:20:02.600892	2026-06-02 22:20:02.600892	0
ea52edc9-814b-47bf-8fcc-97859721df24	93877656500003232	stress-38776565-3232@mediqueue.test	Paciente Stress 38776565-3232	55003232	ACTIVO	2026-06-02 22:20:03.771373	2026-06-02 22:20:03.771373	0
994e2c6b-6ed9-46c6-a8e5-462fcbc00c73	93877650500003268	stress-38776505-3268@mediqueue.test	Paciente Stress 38776505-3268	55003268	ACTIVO	2026-06-02 22:20:03.95692	2026-06-02 22:20:03.95692	0
8f2d141d-f8b0-4730-9c80-8219671fa1b4	93877651500003317	stress-38776515-3317@mediqueue.test	Paciente Stress 38776515-3317	55003317	ACTIVO	2026-06-02 22:20:04.269778	2026-06-02 22:20:04.269778	0
67511530-7f8c-4aa5-a1f0-936b35c0aa7f	93877653400003575	stress-38776534-3575@mediqueue.test	Paciente Stress 38776534-3575	55003575	ACTIVO	2026-06-02 22:20:05.798442	2026-06-02 22:20:05.798442	0
2f2d7630-f7e4-42a8-adfa-7b8ee77df402	93877653300003772	stress-38776533-3772@mediqueue.test	Paciente Stress 38776533-3772	55003772	ACTIVO	2026-06-02 22:20:07.056791	2026-06-02 22:20:07.056791	0
c30c565c-5b12-4ed4-bc48-5a3987c7f750	93877651400003857	stress-38776514-3857@mediqueue.test	Paciente Stress 38776514-3857	55003857	ACTIVO	2026-06-02 22:20:07.651034	2026-06-02 22:20:07.651034	0
8f1424ee-3a30-4b7f-a2f4-72c7c0d9ce0b	93877653600004039	stress-38776536-4039@mediqueue.test	Paciente Stress 38776536-4039	55004039	ACTIVO	2026-06-02 22:20:09.069844	2026-06-02 22:20:09.069844	0
f345e9e0-1ef9-4f4c-bcca-aa5797e72466	93877656200004573	stress-38776562-4573@mediqueue.test	Paciente Stress 38776562-4573	55004573	ACTIVO	2026-06-02 22:20:14.648179	2026-06-02 22:20:14.648179	0
c260dcea-0bbe-4c1d-90b2-a7673b877bcf	93877654600004887	stress-38776546-4887@mediqueue.test	Paciente Stress 38776546-4887	55004887	ACTIVO	2026-06-02 22:20:18.445235	2026-06-02 22:20:18.445235	0
19b6e9aa-e815-4657-92fc-06376e2ad949	93877655900004962	stress-38776559-4962@mediqueue.test	Paciente Stress 38776559-4962	55004962	ACTIVO	2026-06-02 22:20:19.249737	2026-06-02 22:20:19.249737	0
d375d171-695e-4ab3-b30a-b6233daf2ea1	93877655000005203	stress-38776550-5203@mediqueue.test	Paciente Stress 38776550-5203	55005203	ACTIVO	2026-06-02 22:20:23.020793	2026-06-02 22:20:23.020793	0
5b65af52-fc15-46e4-a969-58c6830600e7	93877653600005370	stress-38776536-5370@mediqueue.test	Paciente Stress 38776536-5370	55005370	ACTIVO	2026-06-02 22:20:24.535919	2026-06-02 22:20:24.535919	0
158abc0e-dee6-4496-bbb7-fa7945bd99ea	93877655700005510	stress-38776557-5510@mediqueue.test	Paciente Stress 38776557-5510	55005510	ACTIVO	2026-06-02 22:20:25.959424	2026-06-02 22:20:25.959424	0
9d090aa8-c803-4325-8dcd-09f42dd8444a	93877654200005548	stress-38776542-5548@mediqueue.test	Paciente Stress 38776542-5548	55005548	ACTIVO	2026-06-02 22:20:26.259592	2026-06-02 22:20:26.259592	0
7ddfef30-0f04-407c-abae-de1fc2283a52	93877656100005586	stress-38776561-5586@mediqueue.test	Paciente Stress 38776561-5586	55005586	ACTIVO	2026-06-02 22:20:26.579478	2026-06-02 22:20:26.579478	0
a521ccac-a535-4c39-bba1-00061db0fe07	93877650700005661	stress-38776507-5661@mediqueue.test	Paciente Stress 38776507-5661	55005661	ACTIVO	2026-06-02 22:20:27.273844	2026-06-02 22:20:27.273844	0
36a404ec-51e0-4dcc-a8df-5550a87d5f75	93877654200005697	stress-38776542-5697@mediqueue.test	Paciente Stress 38776542-5697	55005697	ACTIVO	2026-06-02 22:20:27.52509	2026-06-02 22:20:27.52509	0
d3e1734c-eabd-41ee-88cf-b0f42e40f88a	93778432700002384	stress-37784327-2384@mediqueue.test	Paciente Stress 37784327-2384	55002384	ACTIVO	2026-06-02 22:03:46.900878	2026-06-02 22:03:46.900878	0
2af57651-8293-4394-b060-0c08c28537c3	93778434200002654	stress-37784342-2654@mediqueue.test	Paciente Stress 37784342-2654	55002654	ACTIVO	2026-06-02 22:03:49.751111	2026-06-02 22:03:49.751111	0
ce8bbdd1-cb97-4a6d-82dd-b6f22ee0c879	93778430600002920	stress-37784306-2920@mediqueue.test	Paciente Stress 37784306-2920	55002920	ACTIVO	2026-06-02 22:03:51.595528	2026-06-02 22:03:51.595528	0
f1ebf8f9-afba-4546-b0da-b4397d6f0ecc	93778433900003010	stress-37784339-3010@mediqueue.test	Paciente Stress 37784339-3010	55003010	ACTIVO	2026-06-02 22:03:52.748353	2026-06-02 22:03:52.748353	0
3b511d4e-4694-41a5-ac2e-bc315e5a3a58	93778430700003114	stress-37784307-3114@mediqueue.test	Paciente Stress 37784307-3114	55003114	ACTIVO	2026-06-02 22:03:54.94635	2026-06-02 22:03:54.94635	0
a40886d2-3020-4616-97ae-0661cf91782b	93778434200003160	stress-37784342-3160@mediqueue.test	Paciente Stress 37784342-3160	55003160	ACTIVO	2026-06-02 22:03:55.57674	2026-06-02 22:03:55.57674	0
4a724241-8408-4c1b-b80f-c8b866bb25fa	93778431600003239	stress-37784316-3239@mediqueue.test	Paciente Stress 37784316-3239	55003239	ACTIVO	2026-06-02 22:03:56.301578	2026-06-02 22:03:56.301578	0
4f9c2f16-8be0-4ceb-b0e4-d8a7d53c5e36	93778430900003429	stress-37784309-3429@mediqueue.test	Paciente Stress 37784309-3429	55003429	ACTIVO	2026-06-02 22:03:57.923029	2026-06-02 22:03:57.923029	0
5a7c47a2-6df0-4694-9122-30078a9dfac9	93778431900003457	stress-37784319-3457@mediqueue.test	Paciente Stress 37784319-3457	55003457	ACTIVO	2026-06-02 22:03:58.188462	2026-06-02 22:03:58.188462	0
bdc2d2ca-f85c-48a8-8396-90f2668825d3	93778430600003587	stress-37784306-3587@mediqueue.test	Paciente Stress 37784306-3587	55003587	ACTIVO	2026-06-02 22:03:59.238619	2026-06-02 22:03:59.238619	0
59d1df73-b3d4-4240-a8c6-4aebb58e2548	93778433000003690	stress-37784330-3690@mediqueue.test	Paciente Stress 37784330-3690	55003690	ACTIVO	2026-06-02 22:04:00.084382	2026-06-02 22:04:00.084382	0
a8e861a0-95fc-46b4-b67e-91de36faf333	93778431300003765	stress-37784313-3765@mediqueue.test	Paciente Stress 37784313-3765	55003765	ACTIVO	2026-06-02 22:04:00.678682	2026-06-02 22:04:00.678682	0
2919f734-e951-4f17-a0e0-f202ca198268	93778433900003878	stress-37784339-3878@mediqueue.test	Paciente Stress 37784339-3878	55003878	ACTIVO	2026-06-02 22:04:01.571323	2026-06-02 22:04:01.571323	0
e1127d57-3405-401d-8719-52931955db02	93778431000004120	stress-37784310-4120@mediqueue.test	Paciente Stress 37784310-4120	55004120	ACTIVO	2026-06-02 22:04:04.062281	2026-06-02 22:04:04.062281	0
25bc1de1-5cb6-4496-b4b7-08e4daf0073e	93778431500004255	stress-37784315-4255@mediqueue.test	Paciente Stress 37784315-4255	55004255	ACTIVO	2026-06-02 22:04:04.795675	2026-06-02 22:04:04.795675	0
87480a13-326c-46d1-9298-52c5a97abd74	93778434300004335	stress-37784343-4335@mediqueue.test	Paciente Stress 37784343-4335	55004335	ACTIVO	2026-06-02 22:04:05.991913	2026-06-02 22:04:05.991913	0
c3cf2c56-75ed-4aca-b414-77358f1012eb	93778433900004361	stress-37784339-4361@mediqueue.test	Paciente Stress 37784339-4361	55004361	ACTIVO	2026-06-02 22:04:06.283987	2026-06-02 22:04:06.283987	0
71104bd9-bc7e-40a7-84af-822d6a5dbce8	93778434600004549	stress-37784346-4549@mediqueue.test	Paciente Stress 37784346-4549	55004549	ACTIVO	2026-06-02 22:04:07.817963	2026-06-02 22:04:07.817963	0
f6e4398b-d6be-4b36-8dc3-801fb7750e2e	93877652100000066	stress-38776521-66@mediqueue.test	Paciente Stress 38776521-66	55000066	ACTIVO	2026-06-02 22:19:37.558775	2026-06-02 22:19:37.558775	0
f7bac303-3cfa-4c63-8995-da01ab9b34f0	93877654400000179	stress-38776544-179@mediqueue.test	Paciente Stress 38776544-179	55000179	ACTIVO	2026-06-02 22:19:38.218219	2026-06-02 22:19:38.218219	0
19b41f6c-a34a-4a62-80cd-621bdb14f058	93877654700000186	stress-38776547-186@mediqueue.test	Paciente Stress 38776547-186	55000186	ACTIVO	2026-06-02 22:19:38.459922	2026-06-02 22:19:38.459922	0
8cf1cf65-5d6e-4c83-8b55-072464711e93	93877653400000459	stress-38776534-459@mediqueue.test	Paciente Stress 38776534-459	55000459	ACTIVO	2026-06-02 22:19:39.024333	2026-06-02 22:19:39.024333	0
6e5b9a2d-aaf2-4c86-930d-53625d1fe097	93877653600000621	stress-38776536-621@mediqueue.test	Paciente Stress 38776536-621	55000621	ACTIVO	2026-06-02 22:19:41.314961	2026-06-02 22:19:41.314961	0
eced30a6-94e9-42db-b7cf-b6d81f0b62c7	93877655500000706	stress-38776555-706@mediqueue.test	Paciente Stress 38776555-706	55000706	ACTIVO	2026-06-02 22:19:41.760703	2026-06-02 22:19:41.760703	0
991fcf97-8923-41f3-9d09-9c8bcb303d78	93877655500001028	stress-38776555-1028@mediqueue.test	Paciente Stress 38776555-1028	55001028	ACTIVO	2026-06-02 22:19:43.287115	2026-06-02 22:19:43.287115	0
23f9edf6-58ab-4de9-b9dd-e8c2f1fa6faa	93877651500001306	stress-38776515-1306@mediqueue.test	Paciente Stress 38776515-1306	55001306	ACTIVO	2026-06-02 22:19:44.833206	2026-06-02 22:19:44.833206	0
64d71b09-72ea-4c45-9013-3cf600ac9d8e	93877655200001527	stress-38776552-1527@mediqueue.test	Paciente Stress 38776552-1527	55001527	ACTIVO	2026-06-02 22:19:47.059182	2026-06-02 22:19:47.059182	0
0ca44216-1f5a-4635-a7c7-93b1060eca98	93877655500001713	stress-38776555-1713@mediqueue.test	Paciente Stress 38776555-1713	55001713	ACTIVO	2026-06-02 22:19:49.210722	2026-06-02 22:19:49.210722	0
37fd1ae3-eb17-4fd2-956a-f76bacccdec7	93877653400001891	stress-38776534-1891@mediqueue.test	Paciente Stress 38776534-1891	55001891	ACTIVO	2026-06-02 22:19:52.149831	2026-06-02 22:19:52.149831	0
ada2a160-15d4-4eb2-be4d-15365d8b5a14	93877656100001932	stress-38776561-1932@mediqueue.test	Paciente Stress 38776561-1932	55001932	ACTIVO	2026-06-02 22:19:52.427908	2026-06-02 22:19:52.427908	0
1210ee1b-e6ac-4d65-9285-7f2a9df1f8e4	93877656100002014	stress-38776561-2014@mediqueue.test	Paciente Stress 38776561-2014	55002014	ACTIVO	2026-06-02 22:19:53.100949	2026-06-02 22:19:53.100949	0
57e2b89b-4285-4c57-9088-16a6119bebd9	93877655700002065	stress-38776557-2065@mediqueue.test	Paciente Stress 38776557-2065	55002065	ACTIVO	2026-06-02 22:19:53.864068	2026-06-02 22:19:53.864068	0
48d792ca-13b0-472c-b43e-dc1d09fc4de2	93877651300002167	stress-38776513-2167@mediqueue.test	Paciente Stress 38776513-2167	55002167	ACTIVO	2026-06-02 22:19:54.6108	2026-06-02 22:19:54.6108	0
5aa0f152-df19-4663-ac51-930f0eed9e57	93877653500002584	stress-38776535-2584@mediqueue.test	Paciente Stress 38776535-2584	55002584	ACTIVO	2026-06-02 22:20:01.655218	2026-06-02 22:20:01.655218	0
ace1a149-6bad-4244-8387-32ea53a51af0	93877653500002603	stress-38776535-2603@mediqueue.test	Paciente Stress 38776535-2603	55002603	ACTIVO	2026-06-02 22:20:02.093448	2026-06-02 22:20:02.093448	0
752aa4e4-7507-4655-9c99-15fead6d5edd	93877654100003118	stress-38776541-3118@mediqueue.test	Paciente Stress 38776541-3118	55003118	ACTIVO	2026-06-02 22:20:03.001686	2026-06-02 22:20:03.001686	0
622a05ea-f845-4ba8-8516-70b7da35669a	93877651100003541	stress-38776511-3541@mediqueue.test	Paciente Stress 38776511-3541	55003541	ACTIVO	2026-06-02 22:20:05.586824	2026-06-02 22:20:05.586824	0
724b20fc-f0f4-479b-a5e2-a36ce759388c	93877656300003663	stress-38776563-3663@mediqueue.test	Paciente Stress 38776563-3663	55003663	ACTIVO	2026-06-02 22:20:06.362155	2026-06-02 22:20:06.362155	0
404d949c-f66d-4580-9760-b9ce9f6de1d9	93877651400003761	stress-38776514-3761@mediqueue.test	Paciente Stress 38776514-3761	55003761	ACTIVO	2026-06-02 22:20:06.906678	2026-06-02 22:20:06.906678	0
dd5f5f51-17a6-4df4-9178-0403a6a0a08f	93877654200003938	stress-38776542-3938@mediqueue.test	Paciente Stress 38776542-3938	55003938	ACTIVO	2026-06-02 22:20:08.274363	2026-06-02 22:20:08.274363	0
f5abf2a9-2442-4bff-bb2f-b5ce169eb4a8	93877651300004115	stress-38776513-4115@mediqueue.test	Paciente Stress 38776513-4115	55004115	ACTIVO	2026-06-02 22:20:09.571189	2026-06-02 22:20:09.571189	0
3171c0a9-d985-443f-aa8a-7347dd0cfc44	93877651300004513	stress-38776513-4513@mediqueue.test	Paciente Stress 38776513-4513	55004513	ACTIVO	2026-06-02 22:20:14.286106	2026-06-02 22:20:14.286106	0
29de7ff5-0635-455f-adea-6d31c2b3be30	93877655900004689	stress-38776559-4689@mediqueue.test	Paciente Stress 38776559-4689	55004689	ACTIVO	2026-06-02 22:20:15.627301	2026-06-02 22:20:15.627301	0
7e5e1765-dc8b-48f1-ad28-d957bd5412b5	93877655400004792	stress-38776554-4792@mediqueue.test	Paciente Stress 38776554-4792	55004792	ACTIVO	2026-06-02 22:20:17.217237	2026-06-02 22:20:17.217237	0
93572f3d-bbb0-46ce-8ff7-6d279a2c9c65	93877654300005041	stress-38776543-5041@mediqueue.test	Paciente Stress 38776543-5041	55005041	ACTIVO	2026-06-02 22:20:21.21359	2026-06-02 22:20:21.21359	0
eccf2331-eb8b-4693-a1e1-8c2eff61a86a	93877655600005261	stress-38776556-5261@mediqueue.test	Paciente Stress 38776556-5261	55005261	ACTIVO	2026-06-02 22:20:23.472385	2026-06-02 22:20:23.472385	0
8eb3646b-757b-4b30-bc29-8c8d27332cd6	93877653800005422	stress-38776538-5422@mediqueue.test	Paciente Stress 38776538-5422	55005422	ACTIVO	2026-06-02 22:20:25.329057	2026-06-02 22:20:25.329057	0
ccdca962-7156-4038-bb71-0077e3298838	93778433000002386	stress-37784330-2386@mediqueue.test	Paciente Stress 37784330-2386	55002386	ACTIVO	2026-06-02 22:03:46.918966	2026-06-02 22:03:46.918966	0
71a6d63a-d436-460f-86a2-e70da1a0f68b	93778432200002416	stress-37784322-2416@mediqueue.test	Paciente Stress 37784322-2416	55002416	ACTIVO	2026-06-02 22:03:47.230808	2026-06-02 22:03:47.230808	0
acb5d02c-5693-4262-ab89-04feab6dd894	93778430500002579	stress-37784305-2579@mediqueue.test	Paciente Stress 37784305-2579	55002579	ACTIVO	2026-06-02 22:03:48.96225	2026-06-02 22:03:48.96225	0
2fbe1179-3e99-41a3-af90-569be14d127c	93778432300002593	stress-37784323-2593@mediqueue.test	Paciente Stress 37784323-2593	55002593	ACTIVO	2026-06-02 22:03:49.171515	2026-06-02 22:03:49.171515	0
627d3dd2-742c-4206-be43-871c85b93ccb	93778434600002871	stress-37784346-2871@mediqueue.test	Paciente Stress 37784346-2871	55002871	ACTIVO	2026-06-02 22:03:51.276809	2026-06-02 22:03:51.276809	0
8f47b23a-b10f-46e9-ac23-8f9232ded9a2	93778429900002925	stress-37784299-2925@mediqueue.test	Paciente Stress 37784299-2925	55002925	ACTIVO	2026-06-02 22:03:51.723348	2026-06-02 22:03:51.723348	0
9563f918-6d36-40e5-8b54-d27590ea5e3d	93778432000002941	stress-37784320-2941@mediqueue.test	Paciente Stress 37784320-2941	55002941	ACTIVO	2026-06-02 22:03:51.850589	2026-06-02 22:03:51.850589	0
b549f924-d558-496b-919b-8efe83ce568a	93778433900002990	stress-37784339-2990@mediqueue.test	Paciente Stress 37784339-2990	55002990	ACTIVO	2026-06-02 22:03:52.262289	2026-06-02 22:03:52.262289	0
752545a2-dd21-4523-89c1-129e674e2494	93778429900003297	stress-37784299-3297@mediqueue.test	Paciente Stress 37784299-3297	55003297	ACTIVO	2026-06-02 22:03:56.924668	2026-06-02 22:03:56.924668	0
75e64e1d-f8f8-4690-9c35-e6a51111875e	93778431000003316	stress-37784310-3316@mediqueue.test	Paciente Stress 37784310-3316	55003316	ACTIVO	2026-06-02 22:03:57.155275	2026-06-02 22:03:57.155275	0
7e210097-d422-477e-8e08-2a1fef06a4fd	93778430200003503	stress-37784302-3503@mediqueue.test	Paciente Stress 37784302-3503	55003503	ACTIVO	2026-06-02 22:03:58.458344	2026-06-02 22:03:58.458344	0
0b75b081-cf7b-4c0d-94a3-26ad6ed35c17	93778434300003647	stress-37784343-3647@mediqueue.test	Paciente Stress 37784343-3647	55003647	ACTIVO	2026-06-02 22:03:59.752136	2026-06-02 22:03:59.752136	0
0f0ee20f-f3c0-4916-97fc-47ae986fa9c2	93778434100003703	stress-37784341-3703@mediqueue.test	Paciente Stress 37784341-3703	55003703	ACTIVO	2026-06-02 22:04:00.230462	2026-06-02 22:04:00.230462	0
32d42eb8-4731-4959-ac54-c1d05c679273	93778429900003973	stress-37784299-3973@mediqueue.test	Paciente Stress 37784299-3973	55003973	ACTIVO	2026-06-02 22:04:02.519432	2026-06-02 22:04:02.519432	0
1b32f7f1-861e-4f3e-b704-5ed8f234fff9	93778431000003986	stress-37784310-3986@mediqueue.test	Paciente Stress 37784310-3986	55003986	ACTIVO	2026-06-02 22:04:02.692165	2026-06-02 22:04:02.692165	0
5e0ffb1b-c1a6-4a66-ad93-4ec01507493d	93778431500004051	stress-37784315-4051@mediqueue.test	Paciente Stress 37784315-4051	55004051	ACTIVO	2026-06-02 22:04:03.112498	2026-06-02 22:04:03.112498	0
b6c5717e-1109-4369-9898-120b20517b56	93778430600004230	stress-37784306-4230@mediqueue.test	Paciente Stress 37784306-4230	55004230	ACTIVO	2026-06-02 22:04:04.539543	2026-06-02 22:04:04.539543	0
daa5565f-619e-4e02-a940-da6fd9c5f73d	93778431900004324	stress-37784319-4324@mediqueue.test	Paciente Stress 37784319-4324	55004324	ACTIVO	2026-06-02 22:04:05.869843	2026-06-02 22:04:05.869843	0
c36db68b-4475-40d7-975b-eeac957ed8b3	93778430200004369	stress-37784302-4369@mediqueue.test	Paciente Stress 37784302-4369	55004369	ACTIVO	2026-06-02 22:04:06.283987	2026-06-02 22:04:06.283987	0
26cd3e59-2f8c-4a49-8871-712318de971f	93778433100004505	stress-37784331-4505@mediqueue.test	Paciente Stress 37784331-4505	55004505	ACTIVO	2026-06-02 22:04:07.338894	2026-06-02 22:04:07.338894	0
e9c6ccfd-4507-43eb-a284-ca767bda9889	93778429900004585	stress-37784299-4585@mediqueue.test	Paciente Stress 37784299-4585	55004585	ACTIVO	2026-06-02 22:04:08.043153	2026-06-02 22:04:08.043153	0
fc6bdb8d-5749-436d-8954-d43787249e32	93778431500004723	stress-37784315-4723@mediqueue.test	Paciente Stress 37784315-4723	55004723	ACTIVO	2026-06-02 22:04:09.254077	2026-06-02 22:04:09.254077	0
50e60c8c-76bb-4001-b30f-fc3137869d28	93778430600004791	stress-37784306-4791@mediqueue.test	Paciente Stress 37784306-4791	55004791	ACTIVO	2026-06-02 22:04:09.843636	2026-06-02 22:04:09.843636	0
a15e270d-7df2-42b0-bbcd-91b983dcd5bf	93778433000004937	stress-37784330-4937@mediqueue.test	Paciente Stress 37784330-4937	55004937	ACTIVO	2026-06-02 22:04:11.129829	2026-06-02 22:04:11.129829	0
968a5533-f444-4e4d-8d37-28755770116a	93877653400000216	stress-38776534-216@mediqueue.test	Paciente Stress 38776534-216	55000216	ACTIVO	2026-06-02 22:19:37.658363	2026-06-02 22:19:37.658363	0
c954095e-bf65-4d4a-a58c-70e44afc468c	93877652500000201	stress-38776525-201@mediqueue.test	Paciente Stress 38776525-201	55000201	ACTIVO	2026-06-02 22:19:37.814454	2026-06-02 22:19:37.814454	0
91cae4cf-02e0-462f-94bb-41a383a58315	93877655000000435	stress-38776550-435@mediqueue.test	Paciente Stress 38776550-435	55000435	ACTIVO	2026-06-02 22:19:39.022721	2026-06-02 22:19:39.022721	0
53d77a4b-7efe-47b0-b138-1dc4e91de827	93877656200000659	stress-38776562-659@mediqueue.test	Paciente Stress 38776562-659	55000659	ACTIVO	2026-06-02 22:19:41.651567	2026-06-02 22:19:41.651567	0
6ae4529c-a424-4e0e-ab69-035005d5cbe1	93877656200000700	stress-38776562-700@mediqueue.test	Paciente Stress 38776562-700	55000700	ACTIVO	2026-06-02 22:19:41.918729	2026-06-02 22:19:41.918729	0
99b8e355-7787-4737-931c-d499d6be3f67	93877653800000860	stress-38776538-860@mediqueue.test	Paciente Stress 38776538-860	55000860	ACTIVO	2026-06-02 22:19:42.427513	2026-06-02 22:19:42.427513	0
a8e4e54b-8943-4818-ac7d-70a8c66e6275	93877655700001047	stress-38776557-1047@mediqueue.test	Paciente Stress 38776557-1047	55001047	ACTIVO	2026-06-02 22:19:43.330542	2026-06-02 22:19:43.330542	0
0826471f-35d1-4f0a-8695-57155075f86e	93877655500001083	stress-38776555-1083@mediqueue.test	Paciente Stress 38776555-1083	55001083	ACTIVO	2026-06-02 22:19:43.48665	2026-06-02 22:19:43.48665	0
7e6b5777-d926-448f-ac44-89a1f15a1a91	93877650700001835	stress-38776507-1835@mediqueue.test	Paciente Stress 38776507-1835	55001835	ACTIVO	2026-06-02 22:19:51.366225	2026-06-02 22:19:51.366225	0
3b20ee2a-f0e4-4270-be83-9f3978c34cd5	93877653600002465	stress-38776536-2465@mediqueue.test	Paciente Stress 38776536-2465	55002465	ACTIVO	2026-06-02 22:19:59.13386	2026-06-02 22:19:59.13386	0
a6468666-f7b8-49ed-bb10-a12d7a09d785	93877652800002447	stress-38776528-2447@mediqueue.test	Paciente Stress 38776528-2447	55002447	ACTIVO	2026-06-02 22:20:00.683406	2026-06-02 22:20:00.683406	0
c0db3e93-8d2e-47cd-8ffd-77ad988b59e3	93877656000002466	stress-38776560-2466@mediqueue.test	Paciente Stress 38776560-2466	55002466	ACTIVO	2026-06-02 22:20:01.393744	2026-06-02 22:20:01.393744	0
1dbad4a9-e588-4a74-8400-4817132423a7	93877655200002848	stress-38776552-2848@mediqueue.test	Paciente Stress 38776552-2848	55002848	ACTIVO	2026-06-02 22:20:01.598212	2026-06-02 22:20:01.598212	0
c19e7514-8fcd-47f9-b997-83e2c78767d1	93877655800005144	stress-38776558-5144@mediqueue.test	Paciente Stress 38776558-5144	55005144	ACTIVO	2026-06-02 22:20:22.304765	2026-06-02 22:20:22.304765	0
d20ca3a1-5cfa-408d-979f-5075cfdeca2b	93877654200005199	stress-38776542-5199@mediqueue.test	Paciente Stress 38776542-5199	55005199	ACTIVO	2026-06-02 22:20:22.993128	2026-06-02 22:20:22.993128	0
c652c2ae-b01a-4900-82e5-7bc76ec22720	93877655000005233	stress-38776550-5233@mediqueue.test	Paciente Stress 38776550-5233	55005233	ACTIVO	2026-06-02 22:20:23.299986	2026-06-02 22:20:23.299986	0
0d077a09-9f7c-475f-832c-7f2e653629aa	93877656300005351	stress-38776563-5351@mediqueue.test	Paciente Stress 38776563-5351	55005351	ACTIVO	2026-06-02 22:20:24.40676	2026-06-02 22:20:24.40676	0
a191adab-98b3-4b0d-a373-bf4854b9a820	93877655500005533	stress-38776555-5533@mediqueue.test	Paciente Stress 38776555-5533	55005533	ACTIVO	2026-06-02 22:20:26.164001	2026-06-02 22:20:26.164001	0
9d412c1e-322f-44f1-b626-913a8bc090af	93877656300005671	stress-38776563-5671@mediqueue.test	Paciente Stress 38776563-5671	55005671	ACTIVO	2026-06-02 22:20:27.314648	2026-06-02 22:20:27.314648	0
2ef2c0c0-fd65-4fd3-9875-e989d915420b	93877655600005923	stress-38776556-5923@mediqueue.test	Paciente Stress 38776556-5923	55005923	ACTIVO	2026-06-02 22:20:29.980066	2026-06-02 22:20:29.980066	0
0fe39417-bd47-43e3-8d94-5d0d40203d18	93877654400006022	stress-38776544-6022@mediqueue.test	Paciente Stress 38776544-6022	55006022	ACTIVO	2026-06-02 22:20:30.754208	2026-06-02 22:20:30.754208	0
c318bbaa-1f1b-4735-9208-db0a991fdc8b	93877654500006402	stress-38776545-6402@mediqueue.test	Paciente Stress 38776545-6402	55006402	ACTIVO	2026-06-02 22:20:34.111799	2026-06-02 22:20:34.111799	0
489d8f28-cf9e-4cc1-9afd-ceb1eebb1d5f	93877650500007496	stress-38776505-7496@mediqueue.test	Paciente Stress 38776505-7496	55007496	ACTIVO	2026-06-02 22:20:43.842071	2026-06-02 22:20:43.842071	0
6d48e499-767c-4922-a1db-fefa0d552545	93778432200002392	stress-37784322-2392@mediqueue.test	Paciente Stress 37784322-2392	55002392	ACTIVO	2026-06-02 22:03:47.019754	2026-06-02 22:03:47.019754	0
6e373609-0f91-4b80-825e-b34d662e4663	93778434300002404	stress-37784343-2404@mediqueue.test	Paciente Stress 37784343-2404	55002404	ACTIVO	2026-06-02 22:03:47.142086	2026-06-02 22:03:47.142086	0
be3a347f-1dd0-4a16-834a-b50397879b67	93778434300002427	stress-37784343-2427@mediqueue.test	Paciente Stress 37784343-2427	55002427	ACTIVO	2026-06-02 22:03:47.417639	2026-06-02 22:03:47.417639	0
2bb50067-6da8-488c-94ba-e7d5e1dfc637	93778430500002547	stress-37784305-2547@mediqueue.test	Paciente Stress 37784305-2547	55002547	ACTIVO	2026-06-02 22:03:48.607799	2026-06-02 22:03:48.607799	0
845624e5-d12a-47cf-b259-1924e2855d7b	93778430600002601	stress-37784306-2601@mediqueue.test	Paciente Stress 37784306-2601	55002601	ACTIVO	2026-06-02 22:03:49.181623	2026-06-02 22:03:49.181623	0
93d9f6ba-529e-4685-b5fb-ab0b944f04d0	93778430200002628	stress-37784302-2628@mediqueue.test	Paciente Stress 37784302-2628	55002628	ACTIVO	2026-06-02 22:03:49.614893	2026-06-02 22:03:49.614893	0
c240436e-8e3c-4d90-839b-fb842de876d0	93778434100003181	stress-37784341-3181@mediqueue.test	Paciente Stress 37784341-3181	55003181	ACTIVO	2026-06-02 22:03:55.738218	2026-06-02 22:03:55.738218	0
32757274-0e63-44ab-810e-3c04c3af8f93	93778431500003238	stress-37784315-3238@mediqueue.test	Paciente Stress 37784315-3238	55003238	ACTIVO	2026-06-02 22:03:56.293019	2026-06-02 22:03:56.293019	0
348071ba-ece0-4b37-8c7d-fd9d3ad02c34	93778434300003700	stress-37784343-3700@mediqueue.test	Paciente Stress 37784343-3700	55003700	ACTIVO	2026-06-02 22:04:00.230469	2026-06-02 22:04:00.230469	0
1efb210d-b708-4fe1-9690-e871e8d74580	93778431300004008	stress-37784313-4008@mediqueue.test	Paciente Stress 37784313-4008	55004008	ACTIVO	2026-06-02 22:04:02.796066	2026-06-02 22:04:02.796066	0
abb46d35-c115-4fa9-ad62-75c748af97ad	93778432900004019	stress-37784329-4019@mediqueue.test	Paciente Stress 37784329-4019	55004019	ACTIVO	2026-06-02 22:04:02.905882	2026-06-02 22:04:02.905882	0
a450612d-2fad-43c0-a77f-ae7680a07a8b	93778432100004169	stress-37784321-4169@mediqueue.test	Paciente Stress 37784321-4169	55004169	ACTIVO	2026-06-02 22:04:04.115376	2026-06-02 22:04:04.115376	0
ff77de88-f597-402e-99b5-129604c95fe2	93778434200004282	stress-37784342-4282@mediqueue.test	Paciente Stress 37784342-4282	55004282	ACTIVO	2026-06-02 22:04:05.118716	2026-06-02 22:04:05.118716	0
b5d305c0-397c-49a9-ae53-1507eea196fe	93778431600004298	stress-37784316-4298@mediqueue.test	Paciente Stress 37784316-4298	55004298	ACTIVO	2026-06-02 22:04:05.374888	2026-06-02 22:04:05.374888	0
9e0122da-14d2-4d96-abef-cff04dcd5530	93778429900004484	stress-37784299-4484@mediqueue.test	Paciente Stress 37784299-4484	55004484	ACTIVO	2026-06-02 22:04:07.133204	2026-06-02 22:04:07.133204	0
30bfc956-024a-4607-bc27-cab3065b700e	93778431600004539	stress-37784316-4539@mediqueue.test	Paciente Stress 37784316-4539	55004539	ACTIVO	2026-06-02 22:04:07.701744	2026-06-02 22:04:07.701744	0
294b405d-9279-4dfb-9a26-b26999439532	93778434300004560	stress-37784343-4560@mediqueue.test	Paciente Stress 37784343-4560	55004560	ACTIVO	2026-06-02 22:04:07.837589	2026-06-02 22:04:07.837589	0
7d10a480-6bca-4932-a02a-a9a74c030f2d	93778429900004707	stress-37784299-4707@mediqueue.test	Paciente Stress 37784299-4707	55004707	ACTIVO	2026-06-02 22:04:09.194322	2026-06-02 22:04:09.194322	0
d5697d94-80f1-4360-9dca-b9a629a75c38	93778433100004825	stress-37784331-4825@mediqueue.test	Paciente Stress 37784331-4825	55004825	ACTIVO	2026-06-02 22:04:10.242784	2026-06-02 22:04:10.242784	0
67b7d2d9-ce50-4b84-bbfd-79752f292ef7	93778432800004964	stress-37784328-4964@mediqueue.test	Paciente Stress 37784328-4964	55004964	ACTIVO	2026-06-02 22:04:11.269232	2026-06-02 22:04:11.269232	0
04449891-d6a1-4b59-9fac-29c245c8fb02	93877650500000205	stress-38776505-205@mediqueue.test	Paciente Stress 38776505-205	55000205	ACTIVO	2026-06-02 22:19:37.760374	2026-06-02 22:19:37.760374	0
83f40a3a-88ab-42d3-a017-28852f76e4b2	93877650600000202	stress-38776506-202@mediqueue.test	Paciente Stress 38776506-202	55000202	ACTIVO	2026-06-02 22:19:38.294725	2026-06-02 22:19:38.294725	0
9eed3fbd-d468-48a9-86f4-de1bb9b97507	93877655700000505	stress-38776557-505@mediqueue.test	Paciente Stress 38776557-505	55000505	ACTIVO	2026-06-02 22:19:39.910441	2026-06-02 22:19:39.910441	0
a42bb179-654c-485b-afec-118e73e49027	93877653900000661	stress-38776539-661@mediqueue.test	Paciente Stress 38776539-661	55000661	ACTIVO	2026-06-02 22:19:41.928013	2026-06-02 22:19:41.928013	0
6bf80bc2-6226-4dbe-b9ff-674f33ea2f54	93877655500001531	stress-38776555-1531@mediqueue.test	Paciente Stress 38776555-1531	55001531	ACTIVO	2026-06-02 22:19:47.106475	2026-06-02 22:19:47.106475	0
9291797a-6016-4c2c-9a35-64948ceaeeb9	93877651300001795	stress-38776513-1795@mediqueue.test	Paciente Stress 38776513-1795	55001795	ACTIVO	2026-06-02 22:19:50.742149	2026-06-02 22:19:50.742149	0
4f0cd0da-560f-40b7-bfc8-8a77322af02b	93877652300002467	stress-38776523-2467@mediqueue.test	Paciente Stress 38776523-2467	55002467	ACTIVO	2026-06-02 22:20:00.95184	2026-06-02 22:20:00.95184	0
37e3f3db-cbd8-43d9-abe0-7309ea62a0df	93877652200002365	stress-38776522-2365@mediqueue.test	Paciente Stress 38776522-2365	55002365	ACTIVO	2026-06-02 22:20:01.298213	2026-06-02 22:20:01.298213	0
2b2a49e6-751d-4a66-9e8a-3d37c70d3460	93877655700002482	stress-38776557-2482@mediqueue.test	Paciente Stress 38776557-2482	55002482	ACTIVO	2026-06-02 22:20:01.798804	2026-06-02 22:20:01.798804	0
1a3154a8-e1d4-45bd-b06d-c2c7249b966c	93877655900002884	stress-38776559-2884@mediqueue.test	Paciente Stress 38776559-2884	55002884	ACTIVO	2026-06-02 22:20:02.189228	2026-06-02 22:20:02.189228	0
349efb44-5eeb-4857-838c-2908f188cb50	93877654200003370	stress-38776542-3370@mediqueue.test	Paciente Stress 38776542-3370	55003370	ACTIVO	2026-06-02 22:20:04.712095	2026-06-02 22:20:04.712095	0
f10f6544-8b3d-4656-837e-c61668c860b2	93877653600003762	stress-38776536-3762@mediqueue.test	Paciente Stress 38776536-3762	55003762	ACTIVO	2026-06-02 22:20:06.916948	2026-06-02 22:20:06.916948	0
0b914c2e-6ac2-4154-ba22-7d0530ffc03f	93877655900003982	stress-38776559-3982@mediqueue.test	Paciente Stress 38776559-3982	55003982	ACTIVO	2026-06-02 22:20:08.567719	2026-06-02 22:20:08.567719	0
c66597ab-9dbd-4f03-8a46-3496da876b1f	93877656300004067	stress-38776563-4067@mediqueue.test	Paciente Stress 38776563-4067	55004067	ACTIVO	2026-06-02 22:20:09.235292	2026-06-02 22:20:09.235292	0
773fd4df-9d79-4587-90e7-002a16364767	93877653500004209	stress-38776535-4209@mediqueue.test	Paciente Stress 38776535-4209	55004209	ACTIVO	2026-06-02 22:20:10.534913	2026-06-02 22:20:10.534913	0
805b599d-5436-473a-bc46-d86fa9d6e041	93877654200004614	stress-38776542-4614@mediqueue.test	Paciente Stress 38776542-4614	55004614	ACTIVO	2026-06-02 22:20:14.9889	2026-06-02 22:20:14.9889	0
e74f7882-e52f-4c57-a4b0-a5e35bb8cb85	93877652900004711	stress-38776529-4711@mediqueue.test	Paciente Stress 38776529-4711	55004711	ACTIVO	2026-06-02 22:20:15.847591	2026-06-02 22:20:15.847591	0
f8d068c9-9145-4e09-aec0-661f265794ff	93877654200004786	stress-38776542-4786@mediqueue.test	Paciente Stress 38776542-4786	55004786	ACTIVO	2026-06-02 22:20:17.169751	2026-06-02 22:20:17.169751	0
1ad4b389-6e37-445a-ac2d-362597ea71f4	93877656400004804	stress-38776564-4804@mediqueue.test	Paciente Stress 38776564-4804	55004804	ACTIVO	2026-06-02 22:20:17.32789	2026-06-02 22:20:17.32789	0
5ab3cf94-6485-4f22-9e1f-11a536c56338	93877651300005093	stress-38776513-5093@mediqueue.test	Paciente Stress 38776513-5093	55005093	ACTIVO	2026-06-02 22:20:21.598718	2026-06-02 22:20:21.598718	0
9a53bcc1-6d0e-44b0-bfda-dc45bdaf88e5	93877655700005129	stress-38776557-5129@mediqueue.test	Paciente Stress 38776557-5129	55005129	ACTIVO	2026-06-02 22:20:22.110297	2026-06-02 22:20:22.110297	0
252b09d3-e9e9-456d-83bb-fee22691bc7e	93877651300005188	stress-38776513-5188@mediqueue.test	Paciente Stress 38776513-5188	55005188	ACTIVO	2026-06-02 22:20:22.890813	2026-06-02 22:20:22.890813	0
d39bf116-a191-49d4-a55c-cedff8b7acd7	93877654600005347	stress-38776546-5347@mediqueue.test	Paciente Stress 38776546-5347	55005347	ACTIVO	2026-06-02 22:20:24.418441	2026-06-02 22:20:24.418441	0
cbe9e66d-ef26-4153-a0a4-378b3c1f6ed4	93877655400005405	stress-38776554-5405@mediqueue.test	Paciente Stress 38776554-5405	55005405	ACTIVO	2026-06-02 22:20:24.805649	2026-06-02 22:20:24.805649	0
73c0248e-ad32-4171-b8bd-901f49377ceb	93877655200005608	stress-38776552-5608@mediqueue.test	Paciente Stress 38776552-5608	55005608	ACTIVO	2026-06-02 22:20:26.824488	2026-06-02 22:20:26.824488	0
72f5c814-3bef-4032-8662-afca9844d671	93877653700005683	stress-38776537-5683@mediqueue.test	Paciente Stress 38776537-5683	55005683	ACTIVO	2026-06-02 22:20:27.460387	2026-06-02 22:20:27.460387	0
37c1fd95-031a-48f3-9adc-f802476e8658	93877654900005763	stress-38776549-5763@mediqueue.test	Paciente Stress 38776549-5763	55005763	ACTIVO	2026-06-02 22:20:28.16394	2026-06-02 22:20:28.16394	0
d8a173cc-95cd-4113-b6a7-843e5b32669a	93778430600002422	stress-37784306-2422@mediqueue.test	Paciente Stress 37784306-2422	55002422	ACTIVO	2026-06-02 22:03:47.363947	2026-06-02 22:03:47.363947	0
0ce5a2dc-cd06-4b8c-a18a-c683139417bd	93778434300002695	stress-37784343-2695@mediqueue.test	Paciente Stress 37784343-2695	55002695	ACTIVO	2026-06-02 22:03:50.238922	2026-06-02 22:03:50.238922	0
8a6b2f0f-e5e7-4503-a1be-3fc01e0cbc20	93778431600003667	stress-37784316-3667@mediqueue.test	Paciente Stress 37784316-3667	55003667	ACTIVO	2026-06-02 22:03:59.900817	2026-06-02 22:03:59.900817	0
d3735c16-e0ae-42e5-a938-ac6e2e53f492	93778434100003744	stress-37784341-3744@mediqueue.test	Paciente Stress 37784341-3744	55003744	ACTIVO	2026-06-02 22:04:00.655475	2026-06-02 22:04:00.655475	0
0c0e0cae-4ce7-4870-84a6-08efecfb4f14	93778429900004332	stress-37784299-4332@mediqueue.test	Paciente Stress 37784299-4332	55004332	ACTIVO	2026-06-02 22:04:06.009229	2026-06-02 22:04:06.009229	0
5e11d188-d3da-4c3c-b173-c076a437077b	93778430200004401	stress-37784302-4401@mediqueue.test	Paciente Stress 37784302-4401	55004401	ACTIVO	2026-06-02 22:04:06.564154	2026-06-02 22:04:06.564154	0
0ad8c97e-21d7-4791-a56e-b972d2b93f65	93877655600000103	stress-38776556-103@mediqueue.test	Paciente Stress 38776556-103	55000103	ACTIVO	2026-06-02 22:19:37.962327	2026-06-02 22:19:37.962327	0
aa6194e9-293a-4a02-971e-ea0331a50b99	93877654200000538	stress-38776542-538@mediqueue.test	Paciente Stress 38776542-538	55000538	ACTIVO	2026-06-02 22:19:39.992107	2026-06-02 22:19:39.992107	0
bdcc083b-52a6-4b8a-b178-665b72878ce7	93877653700000587	stress-38776537-587@mediqueue.test	Paciente Stress 38776537-587	55000587	ACTIVO	2026-06-02 22:19:41.115223	2026-06-02 22:19:41.115223	0
764fe6d8-7bbf-4264-a796-15a9aa0c07b6	93877651200000852	stress-38776512-852@mediqueue.test	Paciente Stress 38776512-852	55000852	ACTIVO	2026-06-02 22:19:42.54956	2026-06-02 22:19:42.54956	0
238343e6-ace6-407d-828a-6e4b4ae67e42	93877655900001189	stress-38776559-1189@mediqueue.test	Paciente Stress 38776559-1189	55001189	ACTIVO	2026-06-02 22:19:44.108681	2026-06-02 22:19:44.108681	0
a9a19fd1-20db-4a88-90f8-647dc1928060	93877655500001506	stress-38776555-1506@mediqueue.test	Paciente Stress 38776555-1506	55001506	ACTIVO	2026-06-02 22:19:46.891735	2026-06-02 22:19:46.891735	0
ed1c2041-ecc0-40df-8dd1-70a8ac75ea0f	93877655700001516	stress-38776557-1516@mediqueue.test	Paciente Stress 38776557-1516	55001516	ACTIVO	2026-06-02 22:19:47.022948	2026-06-02 22:19:47.022948	0
fb5c7f41-a5d5-4ae1-b66f-94fe0a9c53c9	93877655600002334	stress-38776556-2334@mediqueue.test	Paciente Stress 38776556-2334	55002334	ACTIVO	2026-06-02 22:20:00.276864	2026-06-02 22:20:00.276864	0
c2672ccb-78ef-493d-a20b-98b71279b793	93877651300002587	stress-38776513-2587@mediqueue.test	Paciente Stress 38776513-2587	55002587	ACTIVO	2026-06-02 22:20:01.391759	2026-06-02 22:20:01.391759	0
3fbc85f7-c62d-4b4e-91be-ed882740c526	93877651400002522	stress-38776514-2522@mediqueue.test	Paciente Stress 38776514-2522	55002522	ACTIVO	2026-06-02 22:20:01.525543	2026-06-02 22:20:01.525543	0
542e7df5-076b-40ee-bce7-8a00775fe203	93877654100002490	stress-38776541-2490@mediqueue.test	Paciente Stress 38776541-2490	55002490	ACTIVO	2026-06-02 22:20:01.655179	2026-06-02 22:20:01.655179	0
9b141375-e429-4dff-ba99-1c9aecd5f365	93877656200002298	stress-38776562-2298@mediqueue.test	Paciente Stress 38776562-2298	55002298	ACTIVO	2026-06-02 22:20:01.801535	2026-06-02 22:20:01.801535	0
7d03e642-1f37-49be-bac5-0e00a3ad4b59	93877655200002931	stress-38776552-2931@mediqueue.test	Paciente Stress 38776552-2931	55002931	ACTIVO	2026-06-02 22:20:02.2375	2026-06-02 22:20:02.2375	0
1b42dedc-2e97-4195-b239-758457e20723	93877652800004234	stress-38776528-4234@mediqueue.test	Paciente Stress 38776528-4234	55004234	ACTIVO	2026-06-02 22:20:10.841106	2026-06-02 22:20:10.841106	0
31c0bfdd-c6cc-4bc2-b0d9-9a97b7d3eb7a	93877653500004571	stress-38776535-4571@mediqueue.test	Paciente Stress 38776535-4571	55004571	ACTIVO	2026-06-02 22:20:14.675817	2026-06-02 22:20:14.675817	0
be3d1603-ea7b-47e3-ae1c-9bcf6a8932a9	93877655700005284	stress-38776557-5284@mediqueue.test	Paciente Stress 38776557-5284	55005284	ACTIVO	2026-06-02 22:20:23.669724	2026-06-02 22:20:23.669724	0
ec7dba63-90b4-4235-ab2c-eb612ce30e3c	93877653400006467	stress-38776534-6467@mediqueue.test	Paciente Stress 38776534-6467	55006467	ACTIVO	2026-06-02 22:20:34.772087	2026-06-02 22:20:34.772087	0
eac078f1-e9a0-4ea3-af98-6842d3e5d787	93877655600006534	stress-38776556-6534@mediqueue.test	Paciente Stress 38776556-6534	55006534	ACTIVO	2026-06-02 22:20:35.186041	2026-06-02 22:20:35.186041	0
4a758dcd-76cd-45ad-9b72-5a95ca4f1acc	93877655600006584	stress-38776556-6584@mediqueue.test	Paciente Stress 38776556-6584	55006584	ACTIVO	2026-06-02 22:20:35.475069	2026-06-02 22:20:35.475069	0
6945c9e7-dde5-42a2-a5b0-0a7e2ba273c5	93877654600007840	stress-38776546-7840@mediqueue.test	Paciente Stress 38776546-7840	55007840	ACTIVO	2026-06-02 22:21:08.882659	2026-06-02 22:21:08.882659	0
3d97229b-c260-4eb6-ac3f-5e88f76e3943	93877652300008131	stress-38776523-8131@mediqueue.test	Paciente Stress 38776523-8131	55008131	ACTIVO	2026-06-02 22:21:11.146824	2026-06-02 22:21:11.146824	0
642c7742-76de-484e-b818-8dacffe64bbf	93877655000008196	stress-38776550-8196@mediqueue.test	Paciente Stress 38776550-8196	55008196	ACTIVO	2026-06-02 22:21:12.103137	2026-06-02 22:21:12.103137	0
689dd50a-ff95-4cbd-99dc-a479966fd7d8	93877650700008309	stress-38776507-8309@mediqueue.test	Paciente Stress 38776507-8309	55008309	ACTIVO	2026-06-02 22:21:13.733174	2026-06-02 22:21:13.733174	0
5b21a82e-55dd-4b8f-a35b-fea251c09c1b	93877656400008346	stress-38776564-8346@mediqueue.test	Paciente Stress 38776564-8346	55008346	ACTIVO	2026-06-02 22:21:14.325377	2026-06-02 22:21:14.325377	0
4a4b74ba-9d04-44cf-9380-4008a176799b	93877651900008582	stress-38776519-8582@mediqueue.test	Paciente Stress 38776519-8582	55008582	ACTIVO	2026-06-02 22:21:17.79194	2026-06-02 22:21:17.79194	0
0694a3be-1b27-434d-a360-421968232e8e	93877651500008778	stress-38776515-8778@mediqueue.test	Paciente Stress 38776515-8778	55008778	ACTIVO	2026-06-02 22:21:19.464598	2026-06-02 22:21:19.464598	0
0a8fb38a-189d-47b6-9373-6b4798e289d8	93877656300008915	stress-38776563-8915@mediqueue.test	Paciente Stress 38776563-8915	55008915	ACTIVO	2026-06-02 22:21:20.485966	2026-06-02 22:21:20.485966	0
bcf27500-f6c8-4d76-aac8-69248bd947d2	93877655700009001	stress-38776557-9001@mediqueue.test	Paciente Stress 38776557-9001	55009001	ACTIVO	2026-06-02 22:21:21.22371	2026-06-02 22:21:21.22371	0
8d1c43b5-5644-4ee5-b02a-aced2af0850f	93877655600009380	stress-38776556-9380@mediqueue.test	Paciente Stress 38776556-9380	55009380	ACTIVO	2026-06-02 22:21:25.972614	2026-06-02 22:21:25.972614	0
499b120c-776e-4ada-b155-b1dfe58a6130	93877654600009443	stress-38776546-9443@mediqueue.test	Paciente Stress 38776546-9443	55009443	ACTIVO	2026-06-02 22:21:26.507445	2026-06-02 22:21:26.507445	0
b58afcdd-c5ac-4c09-8742-33a3880e34af	93877656100009470	stress-38776561-9470@mediqueue.test	Paciente Stress 38776561-9470	55009470	ACTIVO	2026-06-02 22:21:26.781094	2026-06-02 22:21:26.781094	0
660c27c3-89a7-429d-9abc-12657d3aa990	93877652300009491	stress-38776523-9491@mediqueue.test	Paciente Stress 38776523-9491	55009491	ACTIVO	2026-06-02 22:21:26.939905	2026-06-02 22:21:26.939905	0
2f294e61-a842-4bdd-b448-8f54f92cba58	93877654100009546	stress-38776541-9546@mediqueue.test	Paciente Stress 38776541-9546	55009546	ACTIVO	2026-06-02 22:21:27.390254	2026-06-02 22:21:27.390254	0
82d5831c-8e2d-4732-857c-981b6e1d9eca	93877650500009623	stress-38776505-9623@mediqueue.test	Paciente Stress 38776505-9623	55009623	ACTIVO	2026-06-02 22:21:27.962485	2026-06-02 22:21:27.962485	0
49efd39c-8077-46b5-a550-afd13fbc2e5c	93877651800009644	stress-38776518-9644@mediqueue.test	Paciente Stress 38776518-9644	55009644	ACTIVO	2026-06-02 22:21:28.14953	2026-06-02 22:21:28.14953	0
c925de35-9772-4d92-9ed4-201390a0ff79	93877651500009719	stress-38776515-9719@mediqueue.test	Paciente Stress 38776515-9719	55009719	ACTIVO	2026-06-02 22:22:07.371393	2026-06-02 22:22:07.371393	0
b1581f43-2c58-46a4-a075-12c25750a84c	93877651200009836	stress-38776512-9836@mediqueue.test	Paciente Stress 38776512-9836	55009836	ACTIVO	2026-06-02 22:22:07.571196	2026-06-02 22:22:07.571196	0
8f1f8d9e-4425-41fe-9553-dc33cf3f45d5	93969227700000045	stress-39692277-45@mediqueue.test	Paciente Stress 39692277-45	55000045	ACTIVO	2026-06-02 22:35:00.635418	2026-06-02 22:35:00.635418	0
bbdcb68a-b3af-464c-9f97-d6575795eaac	93969227200000042	stress-39692272-42@mediqueue.test	Paciente Stress 39692272-42	55000042	ACTIVO	2026-06-02 22:35:01.043092	2026-06-02 22:35:01.043092	0
165056d1-612b-4cac-ac6b-146c51e3f330	93969225000000447	stress-39692250-447@mediqueue.test	Paciente Stress 39692250-447	55000447	ACTIVO	2026-06-02 22:35:02.521892	2026-06-02 22:35:02.521892	0
6f4a32d5-f782-4b7b-8c90-231c7c5a413a	93969228100000483	stress-39692281-483@mediqueue.test	Paciente Stress 39692281-483	55000483	ACTIVO	2026-06-02 22:35:02.598326	2026-06-02 22:35:02.598326	0
5dca4d28-34fc-406b-8cc7-d64fd8025389	93778434300002532	stress-37784343-2532@mediqueue.test	Paciente Stress 37784343-2532	55002532	ACTIVO	2026-06-02 22:03:48.402605	2026-06-02 22:03:48.402605	0
57c7c006-9731-441d-bee2-a22f9a090290	93778430500002568	stress-37784305-2568@mediqueue.test	Paciente Stress 37784305-2568	55002568	ACTIVO	2026-06-02 22:03:48.922173	2026-06-02 22:03:48.922173	0
294035fe-af6a-4c11-984e-ec266d240c8e	93778433200002605	stress-37784332-2605@mediqueue.test	Paciente Stress 37784332-2605	55002605	ACTIVO	2026-06-02 22:03:49.181766	2026-06-02 22:03:49.181766	0
bd675095-9933-41e1-8bd9-0adb4b419d05	93778430500003036	stress-37784305-3036@mediqueue.test	Paciente Stress 37784305-3036	55003036	ACTIVO	2026-06-02 22:03:53.865151	2026-06-02 22:03:53.865151	0
00d382b6-92c5-4da4-baee-706a9811e373	93778431000003236	stress-37784310-3236@mediqueue.test	Paciente Stress 37784310-3236	55003236	ACTIVO	2026-06-02 22:03:56.248513	2026-06-02 22:03:56.248513	0
34040bf8-ec21-4425-a7f4-88e73ffabc4d	93778433000003428	stress-37784330-3428@mediqueue.test	Paciente Stress 37784330-3428	55003428	ACTIVO	2026-06-02 22:03:57.969161	2026-06-02 22:03:57.969161	0
24831502-d4a8-4c37-9914-4f12a0e3cf7d	93778431900003501	stress-37784319-3501@mediqueue.test	Paciente Stress 37784319-3501	55003501	ACTIVO	2026-06-02 22:03:58.54922	2026-06-02 22:03:58.54922	0
4cc1c54d-8314-451c-a967-b8b3c7328f1f	93778432100003557	stress-37784321-3557@mediqueue.test	Paciente Stress 37784321-3557	55003557	ACTIVO	2026-06-02 22:03:58.882676	2026-06-02 22:03:58.882676	0
7b5468d9-4a00-47df-bed3-50f8ccee7d9c	93778434200003804	stress-37784342-3804@mediqueue.test	Paciente Stress 37784342-3804	55003804	ACTIVO	2026-06-02 22:04:00.985895	2026-06-02 22:04:00.985895	0
796f2824-93ca-4686-9582-a43df3d3bc3c	93778431600003898	stress-37784316-3898@mediqueue.test	Paciente Stress 37784316-3898	55003898	ACTIVO	2026-06-02 22:04:01.716776	2026-06-02 22:04:01.716776	0
70ea2711-f5c6-47f1-abee-4f5dcd13fea3	93778431500004020	stress-37784315-4020@mediqueue.test	Paciente Stress 37784315-4020	55004020	ACTIVO	2026-06-02 22:04:02.928058	2026-06-02 22:04:02.928058	0
cae7cbfb-0783-42a8-9a91-fccf95a7d1aa	93778433200004101	stress-37784332-4101@mediqueue.test	Paciente Stress 37784332-4101	55004101	ACTIVO	2026-06-02 22:04:03.586368	2026-06-02 22:04:03.586368	0
61ac9cb6-c75e-4299-8ad7-2e71bde3c21a	93778434100004181	stress-37784341-4181@mediqueue.test	Paciente Stress 37784341-4181	55004181	ACTIVO	2026-06-02 22:04:04.186311	2026-06-02 22:04:04.186311	0
5f195911-f17c-4b24-b875-dc762f521ab0	93778432300004308	stress-37784323-4308@mediqueue.test	Paciente Stress 37784323-4308	55004308	ACTIVO	2026-06-02 22:04:05.491418	2026-06-02 22:04:05.491418	0
ca0ba8d3-315a-40fa-9f18-a8bc40d7ebd3	93778431200004339	stress-37784312-4339@mediqueue.test	Paciente Stress 37784312-4339	55004339	ACTIVO	2026-06-02 22:04:06.052125	2026-06-02 22:04:06.052125	0
4c9671c2-fdc3-4bb9-9090-bef5b97d082a	93778434300004685	stress-37784343-4685@mediqueue.test	Paciente Stress 37784343-4685	55004685	ACTIVO	2026-06-02 22:04:09.057309	2026-06-02 22:04:09.057309	0
a774c7dc-d6f1-425d-95b2-06cbc71bf9fb	93778434000004760	stress-37784340-4760@mediqueue.test	Paciente Stress 37784340-4760	55004760	ACTIVO	2026-06-02 22:04:09.501867	2026-06-02 22:04:09.501867	0
ad30c463-7d58-4eda-bd3b-992f5bec2839	93778430300004899	stress-37784303-4899@mediqueue.test	Paciente Stress 37784303-4899	55004899	ACTIVO	2026-06-02 22:04:10.875323	2026-06-02 22:04:10.875323	0
c104794f-a23d-4b4d-bf6e-f72e90caee1a	93877656200000215	stress-38776562-215@mediqueue.test	Paciente Stress 38776562-215	55000215	ACTIVO	2026-06-02 22:19:38.295343	2026-06-02 22:19:38.295343	0
4ebc1245-243c-4f19-8081-9dd10f561ad4	93877651300000366	stress-38776513-366@mediqueue.test	Paciente Stress 38776513-366	55000366	ACTIVO	2026-06-02 22:19:38.528884	2026-06-02 22:19:38.528884	0
e5f4736b-14e4-455f-9d15-f9a57f290e5c	93877650600000579	stress-38776506-579@mediqueue.test	Paciente Stress 38776506-579	55000579	ACTIVO	2026-06-02 22:19:41.11477	2026-06-02 22:19:41.11477	0
18329cbe-ea36-4b69-889d-69b854595326	93877650900000682	stress-38776509-682@mediqueue.test	Paciente Stress 38776509-682	55000682	ACTIVO	2026-06-02 22:19:41.626164	2026-06-02 22:19:41.626164	0
f537e46c-5dfa-47f0-989b-11e86a420698	93877654600000765	stress-38776546-765@mediqueue.test	Paciente Stress 38776546-765	55000765	ACTIVO	2026-06-02 22:19:41.984571	2026-06-02 22:19:41.984571	0
24511673-e351-4f98-b0c6-ec6e0395bbb7	93877653700001051	stress-38776537-1051@mediqueue.test	Paciente Stress 38776537-1051	55001051	ACTIVO	2026-06-02 22:19:43.390864	2026-06-02 22:19:43.390864	0
8e94c69b-c2a9-45da-a8ef-885c427fbc76	93877654300001172	stress-38776543-1172@mediqueue.test	Paciente Stress 38776543-1172	55001172	ACTIVO	2026-06-02 22:19:43.98061	2026-06-02 22:19:43.98061	0
5fca07da-a7d0-4e7d-8f30-5eb17ab858d9	93877653600001341	stress-38776536-1341@mediqueue.test	Paciente Stress 38776536-1341	55001341	ACTIVO	2026-06-02 22:19:45.216121	2026-06-02 22:19:45.216121	0
01f6c617-c5b4-445a-8e61-25d5c590685f	93877656200001458	stress-38776562-1458@mediqueue.test	Paciente Stress 38776562-1458	55001458	ACTIVO	2026-06-02 22:19:46.741145	2026-06-02 22:19:46.741145	0
747be64a-a4ec-4af5-af4a-053a897f8c0a	93877652400001538	stress-38776524-1538@mediqueue.test	Paciente Stress 38776524-1538	55001538	ACTIVO	2026-06-02 22:19:47.175027	2026-06-02 22:19:47.175027	0
1696fd8c-6331-4383-93b7-78cfc30de90b	93877655000001622	stress-38776550-1622@mediqueue.test	Paciente Stress 38776550-1622	55001622	ACTIVO	2026-06-02 22:19:48.308973	2026-06-02 22:19:48.308973	0
aec47bb5-85cc-40e7-9568-c8bce0b3e379	93877653500001768	stress-38776535-1768@mediqueue.test	Paciente Stress 38776535-1768	55001768	ACTIVO	2026-06-02 22:19:49.631648	2026-06-02 22:19:49.631648	0
2dfa8027-25c6-4eb9-9a9f-f3078819876d	93877651800001807	stress-38776518-1807@mediqueue.test	Paciente Stress 38776518-1807	55001807	ACTIVO	2026-06-02 22:19:50.835896	2026-06-02 22:19:50.835896	0
125d8467-e278-44ef-a525-bf1ff9778722	93877655900001903	stress-38776559-1903@mediqueue.test	Paciente Stress 38776559-1903	55001903	ACTIVO	2026-06-02 22:19:52.299126	2026-06-02 22:19:52.299126	0
b1e596b6-155a-4ea6-b0e4-c08b690f45aa	93877652300001998	stress-38776523-1998@mediqueue.test	Paciente Stress 38776523-1998	55001998	ACTIVO	2026-06-02 22:19:52.909664	2026-06-02 22:19:52.909664	0
9d972749-b0e0-4844-aacf-1a49290393d6	93877655900002039	stress-38776559-2039@mediqueue.test	Paciente Stress 38776559-2039	55002039	ACTIVO	2026-06-02 22:19:53.689511	2026-06-02 22:19:53.689511	0
173d89b8-d32e-4ec3-90ac-5327b7b4f499	93877651500002114	stress-38776515-2114@mediqueue.test	Paciente Stress 38776515-2114	55002114	ACTIVO	2026-06-02 22:19:54.116243	2026-06-02 22:19:54.116243	0
b3438017-1efd-4a15-b2c3-15bac8cc9ae1	93877654900002374	stress-38776549-2374@mediqueue.test	Paciente Stress 38776549-2374	55002374	ACTIVO	2026-06-02 22:19:59.222918	2026-06-02 22:19:59.222918	0
77153b9f-f445-475c-8b93-a0a6bc8710c9	93877653700002328	stress-38776537-2328@mediqueue.test	Paciente Stress 38776537-2328	55002328	ACTIVO	2026-06-02 22:19:59.520999	2026-06-02 22:19:59.520999	0
f7d0da7d-9909-47cf-b396-a3275293d838	93877652600002652	stress-38776526-2652@mediqueue.test	Paciente Stress 38776526-2652	55002652	ACTIVO	2026-06-02 22:20:01.731283	2026-06-02 22:20:01.731283	0
19cc914a-a8f4-49d2-be3e-12b5bd1a6a78	93877650700003070	stress-38776507-3070@mediqueue.test	Paciente Stress 38776507-3070	55003070	ACTIVO	2026-06-02 22:20:02.770196	2026-06-02 22:20:02.770196	0
7163830e-9ae5-4978-9c33-b4a70a16a20d	93877650900003122	stress-38776509-3122@mediqueue.test	Paciente Stress 38776509-3122	55003122	ACTIVO	2026-06-02 22:20:03.034293	2026-06-02 22:20:03.034293	0
f7e0297e-4584-4482-aa71-9745131e2892	93877652900003138	stress-38776529-3138@mediqueue.test	Paciente Stress 38776529-3138	55003138	ACTIVO	2026-06-02 22:20:03.182252	2026-06-02 22:20:03.182252	0
cde1fc56-30ef-44e4-99a1-43f88d4a49ac	93877652900003256	stress-38776529-3256@mediqueue.test	Paciente Stress 38776529-3256	55003256	ACTIVO	2026-06-02 22:20:03.896663	2026-06-02 22:20:03.896663	0
7f805821-f65e-4e49-82db-14c61a9cc1e8	93877651300003459	stress-38776513-3459@mediqueue.test	Paciente Stress 38776513-3459	55003459	ACTIVO	2026-06-02 22:20:05.105616	2026-06-02 22:20:05.105616	0
0b654149-9c46-473f-b21c-37d1bb3fca26	93877652900003503	stress-38776529-3503@mediqueue.test	Paciente Stress 38776529-3503	55003503	ACTIVO	2026-06-02 22:20:05.342539	2026-06-02 22:20:05.342539	0
69295da2-a3a0-4531-9984-3cfc988d327d	93877651800003612	stress-38776518-3612@mediqueue.test	Paciente Stress 38776518-3612	55003612	ACTIVO	2026-06-02 22:20:06.004859	2026-06-02 22:20:06.004859	0
3532edbe-a791-444f-9247-cdefeb69840e	93877651900003745	stress-38776519-3745@mediqueue.test	Paciente Stress 38776519-3745	55003745	ACTIVO	2026-06-02 22:20:06.841517	2026-06-02 22:20:06.841517	0
5d8c4543-7acf-4f01-9fe5-fbdcaa7ef549	93877656200003858	stress-38776562-3858@mediqueue.test	Paciente Stress 38776562-3858	55003858	ACTIVO	2026-06-02 22:20:07.662224	2026-06-02 22:20:07.662224	0
62869558-3f92-4409-a24a-b9d2c0d1c08f	93778434400002794	stress-37784344-2794@mediqueue.test	Paciente Stress 37784344-2794	55002794	ACTIVO	2026-06-02 22:03:50.953041	2026-06-02 22:03:50.953041	0
76592bd1-29c8-47c2-baf0-708bfc37a4af	93778430700003344	stress-37784307-3344@mediqueue.test	Paciente Stress 37784307-3344	55003344	ACTIVO	2026-06-02 22:03:57.308287	2026-06-02 22:03:57.308287	0
010b8383-1319-437d-806d-5d56158d26dd	93778433600003364	stress-37784336-3364@mediqueue.test	Paciente Stress 37784336-3364	55003364	ACTIVO	2026-06-02 22:03:57.462854	2026-06-02 22:03:57.462854	0
119927cb-ca4b-48ca-a58b-0b3c8b66639e	93778430200003470	stress-37784302-3470@mediqueue.test	Paciente Stress 37784302-3470	55003470	ACTIVO	2026-06-02 22:03:58.255795	2026-06-02 22:03:58.255795	0
c7665b80-57aa-43e2-be29-7edb1be527d5	93778430500003561	stress-37784305-3561@mediqueue.test	Paciente Stress 37784305-3561	55003561	ACTIVO	2026-06-02 22:03:59.032297	2026-06-02 22:03:59.032297	0
b42ebcb7-e914-4c24-bb39-1f632fc30d1a	93778430900004241	stress-37784309-4241@mediqueue.test	Paciente Stress 37784309-4241	55004241	ACTIVO	2026-06-02 22:04:04.656647	2026-06-02 22:04:04.656647	0
2f3508cc-33c6-4510-8357-7cff20bad45c	93778431500004285	stress-37784315-4285@mediqueue.test	Paciente Stress 37784315-4285	55004285	ACTIVO	2026-06-02 22:04:05.190893	2026-06-02 22:04:05.190893	0
d5d13339-f1ff-45d4-acef-16e5407e0c70	93778431400004338	stress-37784314-4338@mediqueue.test	Paciente Stress 37784314-4338	55004338	ACTIVO	2026-06-02 22:04:06.035484	2026-06-02 22:04:06.035484	0
ca517909-7f25-4b0c-b707-c369483a5b27	93778430300004376	stress-37784303-4376@mediqueue.test	Paciente Stress 37784303-4376	55004376	ACTIVO	2026-06-02 22:04:06.330388	2026-06-02 22:04:06.330388	0
9c6b2c5e-14ec-4df9-bb5a-176638981c85	93778433900004404	stress-37784339-4404@mediqueue.test	Paciente Stress 37784339-4404	55004404	ACTIVO	2026-06-02 22:04:06.54158	2026-06-02 22:04:06.54158	0
18109a66-319d-4144-9d9b-41ffd6f71459	93778431300004439	stress-37784313-4439@mediqueue.test	Paciente Stress 37784313-4439	55004439	ACTIVO	2026-06-02 22:04:06.829958	2026-06-02 22:04:06.829958	0
89aeccc9-6721-4fe8-9e43-cdd992d913c3	93778430600004518	stress-37784306-4518@mediqueue.test	Paciente Stress 37784306-4518	55004518	ACTIVO	2026-06-02 22:04:07.413715	2026-06-02 22:04:07.413715	0
94e4be87-0a64-4649-8f74-aceec1d41472	93778430300004642	stress-37784303-4642@mediqueue.test	Paciente Stress 37784303-4642	55004642	ACTIVO	2026-06-02 22:04:08.635415	2026-06-02 22:04:08.635415	0
5af602e0-ccb4-4ccc-92aa-cc9f9ee4ac28	93877653800000116	stress-38776538-116@mediqueue.test	Paciente Stress 38776538-116	55000116	ACTIVO	2026-06-02 22:19:38.322825	2026-06-02 22:19:38.322825	0
221e9587-3ccb-4595-9c4c-bfd4d1bde8dc	93877652900000309	stress-38776529-309@mediqueue.test	Paciente Stress 38776529-309	55000309	ACTIVO	2026-06-02 22:19:38.485205	2026-06-02 22:19:38.485205	0
de4fd466-0201-4adf-88d9-f78e4290f2aa	93877653700000392	stress-38776537-392@mediqueue.test	Paciente Stress 38776537-392	55000392	ACTIVO	2026-06-02 22:19:39.779819	2026-06-02 22:19:39.779819	0
98c37874-63be-4577-bff3-209af20bf5a1	93877650600000543	stress-38776506-543@mediqueue.test	Paciente Stress 38776506-543	55000543	ACTIVO	2026-06-02 22:19:39.941324	2026-06-02 22:19:39.941324	0
befbdaa9-de95-4d8c-a760-1d962399968b	93877655500000686	stress-38776555-686@mediqueue.test	Paciente Stress 38776555-686	55000686	ACTIVO	2026-06-02 22:19:41.779166	2026-06-02 22:19:41.779166	0
3b859b91-5f5f-47dd-99d7-65c5648fa7e3	93877653600001091	stress-38776536-1091@mediqueue.test	Paciente Stress 38776536-1091	55001091	ACTIVO	2026-06-02 22:19:43.516292	2026-06-02 22:19:43.516292	0
50cef018-2188-48ac-a208-324f3ba6f687	93877654200001110	stress-38776542-1110@mediqueue.test	Paciente Stress 38776542-1110	55001110	ACTIVO	2026-06-02 22:19:43.623877	2026-06-02 22:19:43.623877	0
743bac98-a974-4d30-82fe-e2a68254e267	93877655900001231	stress-38776559-1231@mediqueue.test	Paciente Stress 38776559-1231	55001231	ACTIVO	2026-06-02 22:19:44.354478	2026-06-02 22:19:44.354478	0
07dae21f-deb9-4fcc-8de1-e5ee3f401bb0	93877651500001339	stress-38776515-1339@mediqueue.test	Paciente Stress 38776515-1339	55001339	ACTIVO	2026-06-02 22:19:45.19937	2026-06-02 22:19:45.19937	0
c95aaae1-ef38-4c3d-870d-da60f4d65f59	93877655500001382	stress-38776555-1382@mediqueue.test	Paciente Stress 38776555-1382	55001382	ACTIVO	2026-06-02 22:19:45.480956	2026-06-02 22:19:45.480956	0
48d721c2-aa37-4667-bc9c-4698855349fe	93877655900001567	stress-38776559-1567@mediqueue.test	Paciente Stress 38776559-1567	55001567	ACTIVO	2026-06-02 22:19:47.559514	2026-06-02 22:19:47.559514	0
feea04a2-0c7c-455d-8117-e7a93f4cee75	93877651500001590	stress-38776515-1590@mediqueue.test	Paciente Stress 38776515-1590	55001590	ACTIVO	2026-06-02 22:19:47.889023	2026-06-02 22:19:47.889023	0
bd39bbe0-3e4f-43b3-b231-c673736cfab8	93877655800001663	stress-38776558-1663@mediqueue.test	Paciente Stress 38776558-1663	55001663	ACTIVO	2026-06-02 22:19:48.612254	2026-06-02 22:19:48.612254	0
87a2abef-bebe-418c-9ab1-345e82589b47	93877655500001750	stress-38776555-1750@mediqueue.test	Paciente Stress 38776555-1750	55001750	ACTIVO	2026-06-02 22:19:49.443674	2026-06-02 22:19:49.443674	0
f87272d2-008c-4d8a-b42f-30d337dff60f	93877654600001954	stress-38776546-1954@mediqueue.test	Paciente Stress 38776546-1954	55001954	ACTIVO	2026-06-02 22:19:52.57345	2026-06-02 22:19:52.57345	0
0418fe74-478d-4e5c-b3ca-9e022c42aa9f	93877655900002067	stress-38776559-2067@mediqueue.test	Paciente Stress 38776559-2067	55002067	ACTIVO	2026-06-02 22:19:53.936915	2026-06-02 22:19:53.936915	0
999615cc-e1a6-4d89-9f47-c7dfa19eb3d8	93877655600002116	stress-38776556-2116@mediqueue.test	Paciente Stress 38776556-2116	55002116	ACTIVO	2026-06-02 22:19:54.141179	2026-06-02 22:19:54.141179	0
97f140a4-104d-47a7-8814-643c4eab513f	93877651500002195	stress-38776515-2195@mediqueue.test	Paciente Stress 38776515-2195	55002195	ACTIVO	2026-06-02 22:19:54.846059	2026-06-02 22:19:54.846059	0
2b0b22cb-3463-4b75-a73b-585a69de57ec	93877655400002622	stress-38776554-2622@mediqueue.test	Paciente Stress 38776554-2622	55002622	ACTIVO	2026-06-02 22:20:01.485307	2026-06-02 22:20:01.485307	0
932d7e49-2817-4d8c-9217-623701849ffa	93877650600002744	stress-38776506-2744@mediqueue.test	Paciente Stress 38776506-2744	55002744	ACTIVO	2026-06-02 22:20:01.604258	2026-06-02 22:20:01.604258	0
bd7f9b7c-8efe-4731-a0dc-a882f7503f33	93877653700002983	stress-38776537-2983@mediqueue.test	Paciente Stress 38776537-2983	55002983	ACTIVO	2026-06-02 22:20:02.391511	2026-06-02 22:20:02.391511	0
045ba2b4-a903-4c73-bd67-326273d79fbb	93877655900003171	stress-38776559-3171@mediqueue.test	Paciente Stress 38776559-3171	55003171	ACTIVO	2026-06-02 22:20:03.45273	2026-06-02 22:20:03.45273	0
c6965f53-ee76-422c-9a5e-6d5517e2fd02	93877655500003277	stress-38776555-3277@mediqueue.test	Paciente Stress 38776555-3277	55003277	ACTIVO	2026-06-02 22:20:04.026097	2026-06-02 22:20:04.026097	0
a827f0f3-5493-45a5-8e94-563017ef2b57	93877656300003685	stress-38776563-3685@mediqueue.test	Paciente Stress 38776563-3685	55003685	ACTIVO	2026-06-02 22:20:06.512067	2026-06-02 22:20:06.512067	0
5ec231d9-de64-4b03-8630-7e18210feaac	93877655700003719	stress-38776557-3719@mediqueue.test	Paciente Stress 38776557-3719	55003719	ACTIVO	2026-06-02 22:20:06.6951	2026-06-02 22:20:06.6951	0
8fa951cc-631f-4ba1-9223-2680dbb80acd	93877655600003859	stress-38776556-3859@mediqueue.test	Paciente Stress 38776556-3859	55003859	ACTIVO	2026-06-02 22:20:07.670388	2026-06-02 22:20:07.670388	0
6909632b-8600-4eab-9881-e8634615dad8	93877652400003893	stress-38776524-3893@mediqueue.test	Paciente Stress 38776524-3893	55003893	ACTIVO	2026-06-02 22:20:07.882527	2026-06-02 22:20:07.882527	0
ae38c5d4-1e98-4e5e-bdbd-a3f7da3b24eb	93877653400004410	stress-38776534-4410@mediqueue.test	Paciente Stress 38776534-4410	55004410	ACTIVO	2026-06-02 22:20:12.892885	2026-06-02 22:20:12.892885	0
8d6dfb05-fac9-416d-9004-6766e5779a13	93877654700004449	stress-38776547-4449@mediqueue.test	Paciente Stress 38776547-4449	55004449	ACTIVO	2026-06-02 22:20:13.088325	2026-06-02 22:20:13.088325	0
617b87dd-9c53-4c6d-bcdd-c8f9fbd5ba28	93877655300004783	stress-38776553-4783@mediqueue.test	Paciente Stress 38776553-4783	55004783	ACTIVO	2026-06-02 22:20:17.097284	2026-06-02 22:20:17.097284	0
22110107-14a4-4ee1-b3b7-5ed64a3b3bbb	93877655400004815	stress-38776554-4815@mediqueue.test	Paciente Stress 38776554-4815	55004815	ACTIVO	2026-06-02 22:20:17.720037	2026-06-02 22:20:17.720037	0
507f1cc5-abf0-4132-b775-4ecc8df61ff9	93877655700004885	stress-38776557-4885@mediqueue.test	Paciente Stress 38776557-4885	55004885	ACTIVO	2026-06-02 22:20:18.437616	2026-06-02 22:20:18.437616	0
a24977f4-5dc7-494f-be5e-d4cb90cf7b57	93877655800005015	stress-38776558-5015@mediqueue.test	Paciente Stress 38776558-5015	55005015	ACTIVO	2026-06-02 22:20:20.909347	2026-06-02 22:20:20.909347	0
5419b6e6-d2c0-4898-9b55-f385b9c009dd	93877656300005176	stress-38776563-5176@mediqueue.test	Paciente Stress 38776563-5176	55005176	ACTIVO	2026-06-02 22:20:22.935269	2026-06-02 22:20:22.935269	0
45bcf9a8-7fe5-4ea6-bcec-015519b3afe2	93778430300003175	stress-37784303-3175@mediqueue.test	Paciente Stress 37784303-3175	55003175	ACTIVO	2026-06-02 22:03:55.686132	2026-06-02 22:03:55.686132	0
4c2f49e8-4390-424a-b1df-51b555f1c418	93778430300003748	stress-37784303-3748@mediqueue.test	Paciente Stress 37784303-3748	55003748	ACTIVO	2026-06-02 22:04:00.622318	2026-06-02 22:04:00.622318	0
1126bbf6-0fcb-447c-9754-d867bc856761	93778432800004164	stress-37784328-4164@mediqueue.test	Paciente Stress 37784328-4164	55004164	ACTIVO	2026-06-02 22:04:04.137739	2026-06-02 22:04:04.137739	0
5497c5a7-6aaa-44cc-a909-28c415372804	93778434400004274	stress-37784344-4274@mediqueue.test	Paciente Stress 37784344-4274	55004274	ACTIVO	2026-06-02 22:04:05.08743	2026-06-02 22:04:05.08743	0
f84aec9d-8471-4fff-87cd-7ffe356222bf	93778430500004551	stress-37784305-4551@mediqueue.test	Paciente Stress 37784305-4551	55004551	ACTIVO	2026-06-02 22:04:07.829145	2026-06-02 22:04:07.829145	0
3932d1c0-bb90-495e-a1d0-3f993df82528	93877655100000948	stress-38776551-948@mediqueue.test	Paciente Stress 38776551-948	55000948	ACTIVO	2026-06-02 22:19:43.018605	2026-06-02 22:19:43.018605	0
5a2e3f68-9440-469b-b7f5-9fe521d0a9d4	93877653600001462	stress-38776536-1462@mediqueue.test	Paciente Stress 38776536-1462	55001462	ACTIVO	2026-06-02 22:19:46.805732	2026-06-02 22:19:46.805732	0
ca528abe-1a7f-4814-b351-239cfb2cee78	93877651200001618	stress-38776512-1618@mediqueue.test	Paciente Stress 38776512-1618	55001618	ACTIVO	2026-06-02 22:19:48.330174	2026-06-02 22:19:48.330174	0
4474a3d6-1c39-4a58-ae66-7f9a1e7a4c33	93877653800001878	stress-38776538-1878@mediqueue.test	Paciente Stress 38776538-1878	55001878	ACTIVO	2026-06-02 22:19:51.765918	2026-06-02 22:19:51.765918	0
ebdf0c42-c726-4ba1-ab46-6e1a72a6e793	93877651300002046	stress-38776513-2046@mediqueue.test	Paciente Stress 38776513-2046	55002046	ACTIVO	2026-06-02 22:19:53.936693	2026-06-02 22:19:53.936693	0
392432e8-da39-4be6-8956-a288101f5e1e	93877651900002251	stress-38776519-2251@mediqueue.test	Paciente Stress 38776519-2251	55002251	ACTIVO	2026-06-02 22:19:58.817137	2026-06-02 22:19:58.817137	0
3fdf323e-d7fb-473b-a998-4e68acef6ba2	93877653800002426	stress-38776538-2426@mediqueue.test	Paciente Stress 38776538-2426	55002426	ACTIVO	2026-06-02 22:20:01.263443	2026-06-02 22:20:01.263443	0
c5176ea3-f981-4e5f-ad62-a8df12a44bf9	93877651400002806	stress-38776514-2806@mediqueue.test	Paciente Stress 38776514-2806	55002806	ACTIVO	2026-06-02 22:20:02.1488	2026-06-02 22:20:02.1488	0
ba8ef691-53a7-4ac7-8240-2f84a63de0d8	93877651500003912	stress-38776515-3912@mediqueue.test	Paciente Stress 38776515-3912	55003912	ACTIVO	2026-06-02 22:20:08.093793	2026-06-02 22:20:08.093793	0
884c4051-99ce-4c46-bf74-e1fd9ea11b5e	93877653800004198	stress-38776538-4198@mediqueue.test	Paciente Stress 38776538-4198	55004198	ACTIVO	2026-06-02 22:20:10.462953	2026-06-02 22:20:10.462953	0
a5b89663-1767-42b4-95c6-63cdcb6df899	93877653500004474	stress-38776535-4474@mediqueue.test	Paciente Stress 38776535-4474	55004474	ACTIVO	2026-06-02 22:20:13.293032	2026-06-02 22:20:13.293032	0
edefa1e5-9e08-4a44-b034-70dc6b9159e5	93877651900004489	stress-38776519-4489@mediqueue.test	Paciente Stress 38776519-4489	55004489	ACTIVO	2026-06-02 22:20:14.188455	2026-06-02 22:20:14.188455	0
e94aefeb-94e3-4d83-8111-a7613dc5b9bb	93877655500004877	stress-38776555-4877@mediqueue.test	Paciente Stress 38776555-4877	55004877	ACTIVO	2026-06-02 22:20:18.165281	2026-06-02 22:20:18.165281	0
c193535b-d0e1-4185-a4d2-5287dd5010d4	93877655900005260	stress-38776559-5260@mediqueue.test	Paciente Stress 38776559-5260	55005260	ACTIVO	2026-06-02 22:20:23.47607	2026-06-02 22:20:23.47607	0
6f9eb95e-dba1-4e30-81b4-63177b503e05	93877655600005411	stress-38776556-5411@mediqueue.test	Paciente Stress 38776556-5411	55005411	ACTIVO	2026-06-02 22:20:24.802858	2026-06-02 22:20:24.802858	0
b07c1956-61e9-4750-a926-706dafb8511f	93877652200005481	stress-38776522-5481@mediqueue.test	Paciente Stress 38776522-5481	55005481	ACTIVO	2026-06-02 22:20:25.654329	2026-06-02 22:20:25.654329	0
d46e5408-f8af-4aeb-adf8-d9f7ccc29d9d	93877653800005828	stress-38776538-5828@mediqueue.test	Paciente Stress 38776538-5828	55005828	ACTIVO	2026-06-02 22:20:28.884126	2026-06-02 22:20:28.884126	0
c4a5b97c-402e-4368-b5d7-38916797b3dd	93877655400005867	stress-38776554-5867@mediqueue.test	Paciente Stress 38776554-5867	55005867	ACTIVO	2026-06-02 22:20:29.686982	2026-06-02 22:20:29.686982	0
52816d96-76e7-4623-9bb7-e176e9f30fbd	93877655600006159	stress-38776556-6159@mediqueue.test	Paciente Stress 38776556-6159	55006159	ACTIVO	2026-06-02 22:20:32.546334	2026-06-02 22:20:32.546334	0
9a8cb804-fbee-42c3-9458-a38caff7e981	93877653700006311	stress-38776537-6311@mediqueue.test	Paciente Stress 38776537-6311	55006311	ACTIVO	2026-06-02 22:20:33.260598	2026-06-02 22:20:33.260598	0
7ee6f960-b8d1-496f-b8a0-ba67b1d7cf6d	93877655500006618	stress-38776555-6618@mediqueue.test	Paciente Stress 38776555-6618	55006618	ACTIVO	2026-06-02 22:20:35.825682	2026-06-02 22:20:35.825682	0
1b920a03-feb8-4a43-8513-06cd9727582a	93877656400006867	stress-38776564-6867@mediqueue.test	Paciente Stress 38776564-6867	55006867	ACTIVO	2026-06-02 22:20:38.772732	2026-06-02 22:20:38.772732	0
5e4cef57-aa02-4815-ba7e-6cffcad98424	93877651100006939	stress-38776511-6939@mediqueue.test	Paciente Stress 38776511-6939	55006939	ACTIVO	2026-06-02 22:20:39.198741	2026-06-02 22:20:39.198741	0
61689c3b-470a-48b8-b7a8-7801ef405b62	93877654500007499	stress-38776545-7499@mediqueue.test	Paciente Stress 38776545-7499	55007499	ACTIVO	2026-06-02 22:20:43.858026	2026-06-02 22:20:43.858026	0
813e5d46-f423-4599-a636-92bfdf37b759	93877655000007618	stress-38776550-7618@mediqueue.test	Paciente Stress 38776550-7618	55007618	ACTIVO	2026-06-02 22:20:44.762588	2026-06-02 22:20:44.762588	0
3e003b8f-9c46-4050-bb36-e2ca399f62ac	93877653400007648	stress-38776534-7648@mediqueue.test	Paciente Stress 38776534-7648	55007648	ACTIVO	2026-06-02 22:20:45.021324	2026-06-02 22:20:45.021324	0
2c5e1d5f-b593-4bbe-8cdb-9ff85c271054	93877656400007891	stress-38776564-7891@mediqueue.test	Paciente Stress 38776564-7891	55007891	ACTIVO	2026-06-02 22:21:09.165975	2026-06-02 22:21:09.165975	0
9aaaa84d-240a-4612-828b-0960bb455906	93877653900008182	stress-38776539-8182@mediqueue.test	Paciente Stress 38776539-8182	55008182	ACTIVO	2026-06-02 22:21:11.924247	2026-06-02 22:21:11.924247	0
8b1af547-554a-4ee8-a9b2-46c9bdfddfd4	93877652400008226	stress-38776524-8226@mediqueue.test	Paciente Stress 38776524-8226	55008226	ACTIVO	2026-06-02 22:21:12.580038	2026-06-02 22:21:12.580038	0
c44643c1-3ac3-4c69-b300-e3a85172885c	93877655700008292	stress-38776557-8292@mediqueue.test	Paciente Stress 38776557-8292	55008292	ACTIVO	2026-06-02 22:21:13.605182	2026-06-02 22:21:13.605182	0
9c26cc05-6257-418c-b3b1-c255a5a7e81e	93877653900008399	stress-38776539-8399@mediqueue.test	Paciente Stress 38776539-8399	55008399	ACTIVO	2026-06-02 22:21:15.134733	2026-06-02 22:21:15.134733	0
3e49514e-6b3f-4fbc-a26d-8e85583d649e	93877654700008457	stress-38776547-8457@mediqueue.test	Paciente Stress 38776547-8457	55008457	ACTIVO	2026-06-02 22:21:16.218693	2026-06-02 22:21:16.218693	0
66a332ea-c974-4d29-a7f6-2255456f0750	93877650600008491	stress-38776506-8491@mediqueue.test	Paciente Stress 38776506-8491	55008491	ACTIVO	2026-06-02 22:21:16.570636	2026-06-02 22:21:16.570636	0
91877ff9-2a81-4fcd-a75e-65de1b94e710	93877650600008505	stress-38776506-8505@mediqueue.test	Paciente Stress 38776506-8505	55008505	ACTIVO	2026-06-02 22:21:16.732096	2026-06-02 22:21:16.732096	0
1b05a2ae-0778-4beb-8464-c78611b75269	93877653600008558	stress-38776536-8558@mediqueue.test	Paciente Stress 38776536-8558	55008558	ACTIVO	2026-06-02 22:21:17.245207	2026-06-02 22:21:17.245207	0
1eb790d3-0508-4d85-b84a-3051442bf5ca	93877653400008696	stress-38776534-8696@mediqueue.test	Paciente Stress 38776534-8696	55008696	ACTIVO	2026-06-02 22:21:18.933785	2026-06-02 22:21:18.933785	0
dc09149c-3a9b-4510-8427-92af889742bc	93877653500008834	stress-38776535-8834@mediqueue.test	Paciente Stress 38776535-8834	55008834	ACTIVO	2026-06-02 22:21:19.885579	2026-06-02 22:21:19.885579	0
e02d20a2-2962-4a39-a16d-edecac8eac53	93877655800008856	stress-38776558-8856@mediqueue.test	Paciente Stress 38776558-8856	55008856	ACTIVO	2026-06-02 22:21:20.047958	2026-06-02 22:21:20.047958	0
d09f0ddf-6d5b-4cfc-bf67-6313c4b523e5	93877655900008899	stress-38776559-8899@mediqueue.test	Paciente Stress 38776559-8899	55008899	ACTIVO	2026-06-02 22:21:20.319253	2026-06-02 22:21:20.319253	0
b7e2300f-5972-40ba-aaf5-e21093a5a765	93877655500008934	stress-38776555-8934@mediqueue.test	Paciente Stress 38776555-8934	55008934	ACTIVO	2026-06-02 22:21:20.585497	2026-06-02 22:21:20.585497	0
bda47ab0-9e69-4140-bfa2-76f0d0300c01	93877651300009041	stress-38776513-9041@mediqueue.test	Paciente Stress 38776513-9041	55009041	ACTIVO	2026-06-02 22:21:21.591317	2026-06-02 22:21:21.591317	0
e803e4bf-ed75-432e-9255-ed5d26a03783	93877650700009238	stress-38776507-9238@mediqueue.test	Paciente Stress 38776507-9238	55009238	ACTIVO	2026-06-02 22:21:24.022051	2026-06-02 22:21:24.022051	0
f5d040b4-1a05-4090-91df-1372c91ed2aa	93856332200000019	stress-38563322-19@mediqueue.test	Paciente Stress 38563322-19	55000019	ACTIVO	2026-06-02 22:16:05.145976	2026-06-02 22:16:05.145976	0
df5db7b1-25c5-432b-956f-22b7a5c183cb	93856331300000692	stress-38563313-692@mediqueue.test	Paciente Stress 38563313-692	55000692	ACTIVO	2026-06-02 22:16:10.185213	2026-06-02 22:16:10.185213	0
cfdcfb68-1a6b-4753-b98f-e693d5f91e26	93856331700000714	stress-38563317-714@mediqueue.test	Paciente Stress 38563317-714	55000714	ACTIVO	2026-06-02 22:16:10.450479	2026-06-02 22:16:10.450479	0
fafdc4f7-214f-4443-a4d2-6a64f0796f8b	93856332500000840	stress-38563325-840@mediqueue.test	Paciente Stress 38563325-840	55000840	ACTIVO	2026-06-02 22:16:11.763335	2026-06-02 22:16:11.763335	0
4ef41cc4-2ff1-42fc-9bef-48231f2e51aa	93856333500000947	stress-38563335-947@mediqueue.test	Paciente Stress 38563335-947	55000947	ACTIVO	2026-06-02 22:16:12.807998	2026-06-02 22:16:12.807998	0
dce51dfe-759d-4303-b419-b3d95056ad20	93856332000001075	stress-38563320-1075@mediqueue.test	Paciente Stress 38563320-1075	55001075	ACTIVO	2026-06-02 22:16:14.617554	2026-06-02 22:16:14.617554	0
6b6a4466-4ded-479e-a54e-3c02002d804f	93856333700001305	stress-38563337-1305@mediqueue.test	Paciente Stress 38563337-1305	55001305	ACTIVO	2026-06-02 22:16:16.458665	2026-06-02 22:16:16.458665	0
44ad7bf3-30bc-4510-85da-e869cb7db9bc	93856333300001479	stress-38563333-1479@mediqueue.test	Paciente Stress 38563333-1479	55001479	ACTIVO	2026-06-02 22:16:18.076554	2026-06-02 22:16:18.076554	0
fb652433-3871-4437-9ae9-dd0dcb09c05c	93856332500001604	stress-38563325-1604@mediqueue.test	Paciente Stress 38563325-1604	55001604	ACTIVO	2026-06-02 22:16:21.169004	2026-06-02 22:16:21.169004	0
839ee19b-0502-4a02-bc1b-5a8ae273a053	93856332000001855	stress-38563320-1855@mediqueue.test	Paciente Stress 38563320-1855	55001855	ACTIVO	2026-06-02 22:16:21.911095	2026-06-02 22:16:21.911095	0
be7ba8e7-6f17-4b60-8c52-6bc44799e125	93856333400001828	stress-38563334-1828@mediqueue.test	Paciente Stress 38563334-1828	55001828	ACTIVO	2026-06-02 22:16:22.260889	2026-06-02 22:16:22.260889	0
0caadcf3-22e2-4e36-8054-3a8e307da61c	93856332000002431	stress-38563320-2431@mediqueue.test	Paciente Stress 38563320-2431	55002431	ACTIVO	2026-06-02 22:16:27.181851	2026-06-02 22:16:27.181851	0
f86df658-66f6-4bd9-9043-e0bee9a6c63d	93856333700003323	stress-38563337-3323@mediqueue.test	Paciente Stress 38563337-3323	55003323	ACTIVO	2026-06-02 22:16:33.066166	2026-06-02 22:16:33.066166	0
daa3646f-98c7-4e6c-9208-a43079c7b60a	93856332000003562	stress-38563320-3562@mediqueue.test	Paciente Stress 38563320-3562	55003562	ACTIVO	2026-06-02 22:16:34.642676	2026-06-02 22:16:34.642676	0
03c078ad-3e7b-42b4-9535-dd505cf03ed4	93856330900004469	stress-38563309-4469@mediqueue.test	Paciente Stress 38563309-4469	55004469	ACTIVO	2026-06-02 22:16:42.060124	2026-06-02 22:16:42.060124	0
363b9800-b998-45a7-ad60-3691e2af6130	93877655800003921	stress-38776558-3921@mediqueue.test	Paciente Stress 38776558-3921	55003921	ACTIVO	2026-06-02 22:20:08.158616	2026-06-02 22:20:08.158616	0
d0869bee-2732-45d2-b1ae-51782770c3c1	93877654700003958	stress-38776547-3958@mediqueue.test	Paciente Stress 38776547-3958	55003958	ACTIVO	2026-06-02 22:20:08.388309	2026-06-02 22:20:08.388309	0
2d89240a-613e-4a1d-be87-16b62a5638ba	93877656200003998	stress-38776562-3998@mediqueue.test	Paciente Stress 38776562-3998	55003998	ACTIVO	2026-06-02 22:20:08.711661	2026-06-02 22:20:08.711661	0
9f470550-0a54-48ff-a3c0-0dad57d99eb2	93877653500004042	stress-38776535-4042@mediqueue.test	Paciente Stress 38776535-4042	55004042	ACTIVO	2026-06-02 22:20:09.159729	2026-06-02 22:20:09.159729	0
61ce0ae6-a3f4-4c41-a592-c8bdb9251236	93877654600004271	stress-38776546-4271@mediqueue.test	Paciente Stress 38776546-4271	55004271	ACTIVO	2026-06-02 22:20:11.776781	2026-06-02 22:20:11.776781	0
188edf17-c5df-43a7-aee7-cce2cc8a3d98	93877653700004313	stress-38776537-4313@mediqueue.test	Paciente Stress 38776537-4313	55004313	ACTIVO	2026-06-02 22:20:12.107633	2026-06-02 22:20:12.107633	0
11f0e233-a158-4ebb-9648-00b0f1b36cee	93877652400004351	stress-38776524-4351@mediqueue.test	Paciente Stress 38776524-4351	55004351	ACTIVO	2026-06-02 22:20:12.320748	2026-06-02 22:20:12.320748	0
0bf12a97-e326-429c-96c0-aa8afb3288ac	93877655200004748	stress-38776552-4748@mediqueue.test	Paciente Stress 38776552-4748	55004748	ACTIVO	2026-06-02 22:20:16.191739	2026-06-02 22:20:16.191739	0
972b4fd8-ecc2-4df6-a67c-ac9c07926a7f	93877655800004914	stress-38776558-4914@mediqueue.test	Paciente Stress 38776558-4914	55004914	ACTIVO	2026-06-02 22:20:18.57802	2026-06-02 22:20:18.57802	0
bb7d7d65-1cf1-4313-b60e-97ba5075e3d2	93877655600005035	stress-38776556-5035@mediqueue.test	Paciente Stress 38776556-5035	55005035	ACTIVO	2026-06-02 22:20:21.076808	2026-06-02 22:20:21.076808	0
0e47592f-3024-4f71-a9aa-755563eb8724	93877656400005080	stress-38776564-5080@mediqueue.test	Paciente Stress 38776564-5080	55005080	ACTIVO	2026-06-02 22:20:21.380007	2026-06-02 22:20:21.380007	0
3939873e-28a1-4b79-83f1-965f13aa41b5	93877655200005226	stress-38776552-5226@mediqueue.test	Paciente Stress 38776552-5226	55005226	ACTIVO	2026-06-02 22:20:23.230292	2026-06-02 22:20:23.230292	0
fb756c84-ca9b-46d1-a679-794f95f1cdc5	93877655900005344	stress-38776559-5344@mediqueue.test	Paciente Stress 38776559-5344	55005344	ACTIVO	2026-06-02 22:20:24.27679	2026-06-02 22:20:24.27679	0
49c506c0-a371-424b-a5d9-f07c381ad2f8	93877651200005473	stress-38776512-5473@mediqueue.test	Paciente Stress 38776512-5473	55005473	ACTIVO	2026-06-02 22:20:25.632338	2026-06-02 22:20:25.632338	0
ac184b93-02d2-485c-a50e-ac6d127dc31e	93877651300005588	stress-38776513-5588@mediqueue.test	Paciente Stress 38776513-5588	55005588	ACTIVO	2026-06-02 22:20:26.677264	2026-06-02 22:20:26.677264	0
df2896a6-1e4f-48d7-8011-7d0812368629	93877652900005832	stress-38776529-5832@mediqueue.test	Paciente Stress 38776529-5832	55005832	ACTIVO	2026-06-02 22:20:28.938837	2026-06-02 22:20:28.938837	0
a9b62135-75df-44fb-b204-da0b0088bedf	93877653400005930	stress-38776534-5930@mediqueue.test	Paciente Stress 38776534-5930	55005930	ACTIVO	2026-06-02 22:20:30.034556	2026-06-02 22:20:30.034556	0
d67bc1a2-8af0-424c-8f37-e85cf3c49b2d	93877656200005964	stress-38776562-5964@mediqueue.test	Paciente Stress 38776562-5964	55005964	ACTIVO	2026-06-02 22:20:30.260033	2026-06-02 22:20:30.260033	0
8cee342f-a488-4533-99e1-d7b7433e2060	93877654300006089	stress-38776543-6089@mediqueue.test	Paciente Stress 38776543-6089	55006089	ACTIVO	2026-06-02 22:20:32.032693	2026-06-02 22:20:32.032693	0
b2df7fdc-b3ed-4333-a1a8-d4c2c21962d1	93877655700006265	stress-38776557-6265@mediqueue.test	Paciente Stress 38776557-6265	55006265	ACTIVO	2026-06-02 22:20:33.04714	2026-06-02 22:20:33.04714	0
9e14210b-571d-4ed3-b841-80a72575f37e	93877651900006844	stress-38776519-6844@mediqueue.test	Paciente Stress 38776519-6844	55006844	ACTIVO	2026-06-02 22:20:38.681914	2026-06-02 22:20:38.681914	0
52c4ddb5-7f76-4a9d-8ab6-f672a12a6b32	93877656100007091	stress-38776561-7091@mediqueue.test	Paciente Stress 38776561-7091	55007091	ACTIVO	2026-06-02 22:20:40.378674	2026-06-02 22:20:40.378674	0
b07e8371-ae70-4f3b-86c4-f9cd7602326c	93877652200007115	stress-38776522-7115@mediqueue.test	Paciente Stress 38776522-7115	55007115	ACTIVO	2026-06-02 22:20:40.555639	2026-06-02 22:20:40.555639	0
f1c3944e-cf5b-42b0-a334-441fb04c9d08	93877655400007201	stress-38776554-7201@mediqueue.test	Paciente Stress 38776554-7201	55007201	ACTIVO	2026-06-02 22:20:41.281743	2026-06-02 22:20:41.281743	0
8c512258-76e8-480e-b818-4a7b63fe0c3a	93877651300007268	stress-38776513-7268@mediqueue.test	Paciente Stress 38776513-7268	55007268	ACTIVO	2026-06-02 22:20:41.93484	2026-06-02 22:20:41.93484	0
ea5f5a49-51c8-4848-99e5-2e0deae333a6	93877654700007362	stress-38776547-7362@mediqueue.test	Paciente Stress 38776547-7362	55007362	ACTIVO	2026-06-02 22:20:42.704623	2026-06-02 22:20:42.704623	0
711a245a-0540-4262-9887-e4da09c65a48	93877654100007535	stress-38776541-7535@mediqueue.test	Paciente Stress 38776541-7535	55007535	ACTIVO	2026-06-02 22:20:44.208203	2026-06-02 22:20:44.208203	0
3ceacfd2-9dca-4484-b56f-0c183709f45d	93877655000007579	stress-38776550-7579@mediqueue.test	Paciente Stress 38776550-7579	55007579	ACTIVO	2026-06-02 22:20:44.498391	2026-06-02 22:20:44.498391	0
29fc5aad-369d-43d8-b86c-18ac24c1eb97	93877650600007625	stress-38776506-7625@mediqueue.test	Paciente Stress 38776506-7625	55007625	ACTIVO	2026-06-02 22:20:44.828213	2026-06-02 22:20:44.828213	0
647b28a5-0473-43d9-9e53-2e711057171c	93877651200007911	stress-38776512-7911@mediqueue.test	Paciente Stress 38776512-7911	55007911	ACTIVO	2026-06-02 22:21:09.304882	2026-06-02 22:21:09.304882	0
55e35c21-c785-4305-ae62-579d9feb5575	93877652800008109	stress-38776528-8109@mediqueue.test	Paciente Stress 38776528-8109	55008109	ACTIVO	2026-06-02 22:21:10.99484	2026-06-02 22:21:10.99484	0
091630cf-5577-4e33-bc66-26039607e088	93877651500008242	stress-38776515-8242@mediqueue.test	Paciente Stress 38776515-8242	55008242	ACTIVO	2026-06-02 22:21:12.756365	2026-06-02 22:21:12.756365	0
9a43615d-f3da-42f7-957b-8c50fb019c31	93856332500000006	stress-38563325-6@mediqueue.test	Paciente Stress 38563325-6	55000006	ACTIVO	2026-06-02 22:16:05.149602	2026-06-02 22:16:05.149602	0
da151001-d759-44be-826d-9e8098165d77	93856333400000299	stress-38563334-299@mediqueue.test	Paciente Stress 38563334-299	55000299	ACTIVO	2026-06-02 22:16:06.295189	2026-06-02 22:16:06.295189	0
5a76b64f-fc30-464a-84c2-0c0f77726846	93856332800000542	stress-38563328-542@mediqueue.test	Paciente Stress 38563328-542	55000542	ACTIVO	2026-06-02 22:16:08.631425	2026-06-02 22:16:08.631425	0
bd0d6ecf-40d6-4d04-be32-db88c02dd40c	93856332700000744	stress-38563327-744@mediqueue.test	Paciente Stress 38563327-744	55000744	ACTIVO	2026-06-02 22:16:10.840036	2026-06-02 22:16:10.840036	0
d995ce4d-65b1-4ec1-91bc-907d7551658b	93856330600000938	stress-38563306-938@mediqueue.test	Paciente Stress 38563306-938	55000938	ACTIVO	2026-06-02 22:16:12.777713	2026-06-02 22:16:12.777713	0
91b3c5b2-9b97-48a3-8315-d45a9e40875e	93856331600001162	stress-38563316-1162@mediqueue.test	Paciente Stress 38563316-1162	55001162	ACTIVO	2026-06-02 22:16:14.916477	2026-06-02 22:16:14.916477	0
dbc4657d-14d4-4b4e-aad1-f4bba4eaf30f	93856333800002132	stress-38563338-2132@mediqueue.test	Paciente Stress 38563338-2132	55002132	ACTIVO	2026-06-02 22:16:24.120267	2026-06-02 22:16:24.120267	0
f4bc700a-0a33-4c3c-9567-0f266c0d45c5	93856332000002173	stress-38563320-2173@mediqueue.test	Paciente Stress 38563320-2173	55002173	ACTIVO	2026-06-02 22:16:24.637817	2026-06-02 22:16:24.637817	0
f7115273-03e8-40c1-955a-fcb53baddd05	93856332000002322	stress-38563320-2322@mediqueue.test	Paciente Stress 38563320-2322	55002322	ACTIVO	2026-06-02 22:16:25.733423	2026-06-02 22:16:25.733423	0
d90186aa-d959-4006-b903-099f6e9f8b92	93856333300002521	stress-38563333-2521@mediqueue.test	Paciente Stress 38563333-2521	55002521	ACTIVO	2026-06-02 22:16:27.541146	2026-06-02 22:16:27.541146	0
624ddf8d-cf5b-406c-93c4-bbd0fed5a29f	93856333400002585	stress-38563334-2585@mediqueue.test	Paciente Stress 38563334-2585	55002585	ACTIVO	2026-06-02 22:16:27.921144	2026-06-02 22:16:27.921144	0
045feb19-91da-4608-bf62-f68c97b9061b	93856333400002695	stress-38563334-2695@mediqueue.test	Paciente Stress 38563334-2695	55002695	ACTIVO	2026-06-02 22:16:28.76213	2026-06-02 22:16:28.76213	0
e3f7dd3b-69ac-4db1-895c-b11037e8cacf	93856332000002931	stress-38563320-2931@mediqueue.test	Paciente Stress 38563320-2931	55002931	ACTIVO	2026-06-02 22:16:30.2421	2026-06-02 22:16:30.2421	0
34eef5c8-ecf5-41cd-9118-33bde550dfbe	93856330700003035	stress-38563307-3035@mediqueue.test	Paciente Stress 38563307-3035	55003035	ACTIVO	2026-06-02 22:16:30.824923	2026-06-02 22:16:30.824923	0
fd054319-812e-46eb-9071-2b0a5615dcbb	93856332000003259	stress-38563320-3259@mediqueue.test	Paciente Stress 38563320-3259	55003259	ACTIVO	2026-06-02 22:16:32.668293	2026-06-02 22:16:32.668293	0
5cbc79ec-676d-4299-bc00-b53a751a4be6	93856330600003317	stress-38563306-3317@mediqueue.test	Paciente Stress 38563306-3317	55003317	ACTIVO	2026-06-02 22:16:32.966797	2026-06-02 22:16:32.966797	0
a4cadd5e-8dee-403a-8387-1878ac4294bd	93856332000003648	stress-38563320-3648@mediqueue.test	Paciente Stress 38563320-3648	55003648	ACTIVO	2026-06-02 22:16:35.252081	2026-06-02 22:16:35.252081	0
2f9d32db-d658-4b82-81f1-e8a8ba926949	93856330900003735	stress-38563309-3735@mediqueue.test	Paciente Stress 38563309-3735	55003735	ACTIVO	2026-06-02 22:16:35.748398	2026-06-02 22:16:35.748398	0
c71c208d-513c-4c30-ac91-aa14986b7e21	93856332700004005	stress-38563327-4005@mediqueue.test	Paciente Stress 38563327-4005	55004005	ACTIVO	2026-06-02 22:16:37.721513	2026-06-02 22:16:37.721513	0
e96afa7a-cde5-42b5-bc90-a21967882b75	93856333500004266	stress-38563335-4266@mediqueue.test	Paciente Stress 38563335-4266	55004266	ACTIVO	2026-06-02 22:16:39.948644	2026-06-02 22:16:39.948644	0
a42f1ba5-0015-4a56-b750-2778d41cf515	93856331600004520	stress-38563316-4520@mediqueue.test	Paciente Stress 38563316-4520	55004520	ACTIVO	2026-06-02 22:16:42.323229	2026-06-02 22:16:42.323229	0
507f3535-8932-4374-a00c-6674d433d0a3	93856331600004803	stress-38563316-4803@mediqueue.test	Paciente Stress 38563316-4803	55004803	ACTIVO	2026-06-02 22:16:44.219041	2026-06-02 22:16:44.219041	0
859b6fe6-c6d6-4c32-9c21-0d70d63cdc53	93877653400005514	stress-38776534-5514@mediqueue.test	Paciente Stress 38776534-5514	55005514	ACTIVO	2026-06-02 22:20:25.98758	2026-06-02 22:20:25.98758	0
23c75d90-aaa9-43e3-ad11-b1f6c41cc3ec	93877653600005700	stress-38776536-5700@mediqueue.test	Paciente Stress 38776536-5700	55005700	ACTIVO	2026-06-02 22:20:27.588728	2026-06-02 22:20:27.588728	0
34f983f4-c10d-4e42-8bf1-2bd67877c30f	93877655600006155	stress-38776556-6155@mediqueue.test	Paciente Stress 38776556-6155	55006155	ACTIVO	2026-06-02 22:20:32.674132	2026-06-02 22:20:32.674132	0
2019d3b6-145a-4211-9b69-ef6c208daedb	93877656200006272	stress-38776562-6272@mediqueue.test	Paciente Stress 38776562-6272	55006272	ACTIVO	2026-06-02 22:20:33.057471	2026-06-02 22:20:33.057471	0
a89a3db8-f8ef-43d7-a151-306b2c4e6f8f	93877655900006501	stress-38776559-6501@mediqueue.test	Paciente Stress 38776559-6501	55006501	ACTIVO	2026-06-02 22:20:34.980655	2026-06-02 22:20:34.980655	0
ddc4c3f3-9579-4eae-9210-e7f6538453ab	93877652300006899	stress-38776523-6899@mediqueue.test	Paciente Stress 38776523-6899	55006899	ACTIVO	2026-06-02 22:20:38.930379	2026-06-02 22:20:38.930379	0
e3347b5f-fc14-4ce8-ab25-5b4f714cb584	93877652300006936	stress-38776523-6936@mediqueue.test	Paciente Stress 38776523-6936	55006936	ACTIVO	2026-06-02 22:20:39.179535	2026-06-02 22:20:39.179535	0
2c1090ef-42c7-4068-b4ab-fdc4dc5089e6	93877654700007058	stress-38776547-7058@mediqueue.test	Paciente Stress 38776547-7058	55007058	ACTIVO	2026-06-02 22:20:40.193175	2026-06-02 22:20:40.193175	0
9c33069c-2021-4ce1-875f-4d6629f64040	93877655500007364	stress-38776555-7364@mediqueue.test	Paciente Stress 38776555-7364	55007364	ACTIVO	2026-06-02 22:20:42.704802	2026-06-02 22:20:42.704802	0
dfc85452-c9d4-47d5-957e-20ad30803d53	93877653000007473	stress-38776530-7473@mediqueue.test	Paciente Stress 38776530-7473	55007473	ACTIVO	2026-06-02 22:20:43.633168	2026-06-02 22:20:43.633168	0
d6fcc262-a080-4411-b943-c6d4c1451fcc	93877654300007503	stress-38776543-7503@mediqueue.test	Paciente Stress 38776543-7503	55007503	ACTIVO	2026-06-02 22:20:43.883427	2026-06-02 22:20:43.883427	0
dcc1c187-c77a-4d67-b6d7-8b8376c67b31	93877650600007603	stress-38776506-7603@mediqueue.test	Paciente Stress 38776506-7603	55007603	ACTIVO	2026-06-02 22:20:44.670279	2026-06-02 22:20:44.670279	0
356f0415-d275-40a6-88cd-dabe03acb0a9	93877653700007691	stress-38776537-7691@mediqueue.test	Paciente Stress 38776537-7691	55007691	ACTIVO	2026-06-02 22:20:45.459456	2026-06-02 22:20:45.459456	0
7fc03877-0f4b-44c2-a85b-c34e2f822a30	93877652300008028	stress-38776523-8028@mediqueue.test	Paciente Stress 38776523-8028	55008028	ACTIVO	2026-06-02 22:21:10.089477	2026-06-02 22:21:10.089477	0
5b5f9ad3-678c-4303-a863-9d81442d4f5a	93877654500008254	stress-38776545-8254@mediqueue.test	Paciente Stress 38776545-8254	55008254	ACTIVO	2026-06-02 22:21:12.95376	2026-06-02 22:21:12.95376	0
603cb9a2-21f9-4a7b-b490-d658c278cd05	93877654300008666	stress-38776543-8666@mediqueue.test	Paciente Stress 38776543-8666	55008666	ACTIVO	2026-06-02 22:21:18.611753	2026-06-02 22:21:18.611753	0
e5545d37-9b2d-46ab-99cf-8bad5fdd6c3d	93877653400008725	stress-38776534-8725@mediqueue.test	Paciente Stress 38776534-8725	55008725	ACTIVO	2026-06-02 22:21:19.089786	2026-06-02 22:21:19.089786	0
953e8da0-789b-4fb5-9294-b865abbb6128	93877655900008917	stress-38776559-8917@mediqueue.test	Paciente Stress 38776559-8917	55008917	ACTIVO	2026-06-02 22:21:20.489648	2026-06-02 22:21:20.489648	0
32d38620-a282-4002-a3a4-de296406080d	93877650600008957	stress-38776506-8957@mediqueue.test	Paciente Stress 38776506-8957	55008957	ACTIVO	2026-06-02 22:21:20.805578	2026-06-02 22:21:20.805578	0
1df86a83-cf65-43d8-9ee9-f10ffc3eb875	93877655900008996	stress-38776559-8996@mediqueue.test	Paciente Stress 38776559-8996	55008996	ACTIVO	2026-06-02 22:21:21.177267	2026-06-02 22:21:21.177267	0
6de69d4d-10ff-46c2-900a-f4582aa277ee	93877655600009566	stress-38776556-9566@mediqueue.test	Paciente Stress 38776556-9566	55009566	ACTIVO	2026-06-02 22:21:27.547316	2026-06-02 22:21:27.547316	0
c93c06b4-211e-407a-8fdc-3776c78399b1	93877653400009840	stress-38776534-9840@mediqueue.test	Paciente Stress 38776534-9840	55009840	ACTIVO	2026-06-02 22:22:08.175505	2026-06-02 22:22:08.175505	0
674755aa-2b11-4363-8e15-ce7e1490e368	93877651400009947	stress-38776514-9947@mediqueue.test	Paciente Stress 38776514-9947	55009947	ACTIVO	2026-06-02 22:22:08.564145	2026-06-02 22:22:08.564145	0
b78c7768-805c-43ee-9237-053beedb7341	93969227800000336	stress-39692278-336@mediqueue.test	Paciente Stress 39692278-336	55000336	ACTIVO	2026-06-02 22:35:00.892653	2026-06-02 22:35:00.892653	0
9bb3b1f4-ba6e-4d26-96ea-29567de7043a	93969225500000312	stress-39692255-312@mediqueue.test	Paciente Stress 39692255-312	55000312	ACTIVO	2026-06-02 22:35:02.016736	2026-06-02 22:35:02.016736	0
c1d031a2-764b-4d21-b319-d8b1d8acbd95	93856333400000012	stress-38563334-12@mediqueue.test	Paciente Stress 38563334-12	55000012	ACTIVO	2026-06-02 22:16:05.149756	2026-06-02 22:16:05.149756	0
c264b28e-c241-4516-9c2b-7611e373357d	93856333600000214	stress-38563336-214@mediqueue.test	Paciente Stress 38563336-214	55000214	ACTIVO	2026-06-02 22:16:05.579222	2026-06-02 22:16:05.579222	0
45263c54-34a5-4c9c-ba2e-f94f8f67c3ce	93856333800000227	stress-38563338-227@mediqueue.test	Paciente Stress 38563338-227	55000227	ACTIVO	2026-06-02 22:16:05.789077	2026-06-02 22:16:05.789077	0
d57fe9a1-f805-400f-b3b8-7add94c7c27f	93856332700000464	stress-38563327-464@mediqueue.test	Paciente Stress 38563327-464	55000464	ACTIVO	2026-06-02 22:16:08.040231	2026-06-02 22:16:08.040231	0
071e3c6e-b9f5-4848-afd4-6ab471c8fdbd	93856331300000799	stress-38563313-799@mediqueue.test	Paciente Stress 38563313-799	55000799	ACTIVO	2026-06-02 22:16:11.373123	2026-06-02 22:16:11.373123	0
61f59980-8c7e-4099-a0d8-fe7b02405f75	93856331700000917	stress-38563317-917@mediqueue.test	Paciente Stress 38563317-917	55000917	ACTIVO	2026-06-02 22:16:12.581037	2026-06-02 22:16:12.581037	0
48ff2067-1835-4561-b042-87b306c57056	93856332100001041	stress-38563321-1041@mediqueue.test	Paciente Stress 38563321-1041	55001041	ACTIVO	2026-06-02 22:16:14.227167	2026-06-02 22:16:14.227167	0
236e3744-0ead-4733-9c68-8ca0d3eedc76	93856333700001147	stress-38563337-1147@mediqueue.test	Paciente Stress 38563337-1147	55001147	ACTIVO	2026-06-02 22:16:14.799894	2026-06-02 22:16:14.799894	0
99a0a8f1-05ec-454e-ae5f-01a844e40515	93856333400001413	stress-38563334-1413@mediqueue.test	Paciente Stress 38563334-1413	55001413	ACTIVO	2026-06-02 22:16:17.493478	2026-06-02 22:16:17.493478	0
689b719d-0ca6-4c83-b568-2ad5d76aa916	93856332500001471	stress-38563325-1471@mediqueue.test	Paciente Stress 38563325-1471	55001471	ACTIVO	2026-06-02 22:16:17.711059	2026-06-02 22:16:17.711059	0
7c102d66-99cb-4a72-961a-407548afc9f5	93856333400001899	stress-38563334-1899@mediqueue.test	Paciente Stress 38563334-1899	55001899	ACTIVO	2026-06-02 22:16:21.911504	2026-06-02 22:16:21.911504	0
3acc562a-e760-48bd-bade-2215297dad7d	93856330900001934	stress-38563309-1934@mediqueue.test	Paciente Stress 38563309-1934	55001934	ACTIVO	2026-06-02 22:16:22.332532	2026-06-02 22:16:22.332532	0
d43d080c-091c-4b10-8474-b9aa2a42d917	93856331300001770	stress-38563313-1770@mediqueue.test	Paciente Stress 38563313-1770	55001770	ACTIVO	2026-06-02 22:16:22.520933	2026-06-02 22:16:22.520933	0
5dbc51b8-2b56-4f0e-9c26-f1a67ecf83a9	93856331100002167	stress-38563311-2167@mediqueue.test	Paciente Stress 38563311-2167	55002167	ACTIVO	2026-06-02 22:16:24.492769	2026-06-02 22:16:24.492769	0
caff5b83-2e9f-410f-ad42-ef430a6cef07	93856333600002492	stress-38563336-2492@mediqueue.test	Paciente Stress 38563336-2492	55002492	ACTIVO	2026-06-02 22:16:27.389005	2026-06-02 22:16:27.389005	0
d05aedba-2b9a-4b9b-80ba-0878c3b6c519	93856332000002631	stress-38563320-2631@mediqueue.test	Paciente Stress 38563320-2631	55002631	ACTIVO	2026-06-02 22:16:28.204222	2026-06-02 22:16:28.204222	0
5ca4c65b-38c3-4e35-aadf-acd42a4a7e25	93856332400002706	stress-38563324-2706@mediqueue.test	Paciente Stress 38563324-2706	55002706	ACTIVO	2026-06-02 22:16:28.856176	2026-06-02 22:16:28.856176	0
36b811e2-a521-4389-a01d-651c5712d519	93856332000002729	stress-38563320-2729@mediqueue.test	Paciente Stress 38563320-2729	55002729	ACTIVO	2026-06-02 22:16:29.031424	2026-06-02 22:16:29.031424	0
4537de3e-2422-46ed-9197-90e0f532339c	93856333700002774	stress-38563337-2774@mediqueue.test	Paciente Stress 38563337-2774	55002774	ACTIVO	2026-06-02 22:16:29.222137	2026-06-02 22:16:29.222137	0
17f9b743-7841-4629-982c-0a271527e329	93856331600002941	stress-38563316-2941@mediqueue.test	Paciente Stress 38563316-2941	55002941	ACTIVO	2026-06-02 22:16:30.317426	2026-06-02 22:16:30.317426	0
cd2684d2-495f-438e-9b38-6df22d8e982b	93856332200003011	stress-38563322-3011@mediqueue.test	Paciente Stress 38563322-3011	55003011	ACTIVO	2026-06-02 22:16:30.659027	2026-06-02 22:16:30.659027	0
8846d124-a5c2-4d83-868d-79eed3346533	93856333300003129	stress-38563333-3129@mediqueue.test	Paciente Stress 38563333-3129	55003129	ACTIVO	2026-06-02 22:16:31.558218	2026-06-02 22:16:31.558218	0
9f7ca7b9-d510-4f35-8bf3-fe96dd07d862	93856332000003252	stress-38563320-3252@mediqueue.test	Paciente Stress 38563320-3252	55003252	ACTIVO	2026-06-02 22:16:32.577531	2026-06-02 22:16:32.577531	0
87784569-ef8d-420e-a24b-50bdf76bd4f7	93856333300003366	stress-38563333-3366@mediqueue.test	Paciente Stress 38563333-3366	55003366	ACTIVO	2026-06-02 22:16:33.402697	2026-06-02 22:16:33.402697	0
8b6b5a3d-25f5-405a-99d9-6336f810ef81	93856332000003691	stress-38563320-3691@mediqueue.test	Paciente Stress 38563320-3691	55003691	ACTIVO	2026-06-02 22:16:35.539535	2026-06-02 22:16:35.539535	0
817675a5-7fc5-4d38-a944-b4846fe746b7	93856330900003722	stress-38563309-3722@mediqueue.test	Paciente Stress 38563309-3722	55003722	ACTIVO	2026-06-02 22:16:35.6771	2026-06-02 22:16:35.6771	0
964de141-ffeb-421f-82d1-c7a977ab4d43	93856330900003762	stress-38563309-3762@mediqueue.test	Paciente Stress 38563309-3762	55003762	ACTIVO	2026-06-02 22:16:35.865729	2026-06-02 22:16:35.865729	0
67e3c056-ed75-43bb-b47c-76f4624e8d8d	93856330600003797	stress-38563306-3797@mediqueue.test	Paciente Stress 38563306-3797	55003797	ACTIVO	2026-06-02 22:16:36.120375	2026-06-02 22:16:36.120375	0
228ea2f8-3a17-496f-bf8d-9f56981b7ab0	93856331600003884	stress-38563316-3884@mediqueue.test	Paciente Stress 38563316-3884	55003884	ACTIVO	2026-06-02 22:16:36.622884	2026-06-02 22:16:36.622884	0
d9910695-f05d-4699-85e1-93cd250e7698	93856333800004123	stress-38563338-4123@mediqueue.test	Paciente Stress 38563338-4123	55004123	ACTIVO	2026-06-02 22:16:38.814952	2026-06-02 22:16:38.814952	0
7aeb4556-cea8-4766-81fb-e5a7e26ee014	93856331300004162	stress-38563313-4162@mediqueue.test	Paciente Stress 38563313-4162	55004162	ACTIVO	2026-06-02 22:16:39.159882	2026-06-02 22:16:39.159882	0
47ec5eba-029f-410a-b775-1ac28f73d6d3	93856331300004262	stress-38563313-4262@mediqueue.test	Paciente Stress 38563313-4262	55004262	ACTIVO	2026-06-02 22:16:39.927953	2026-06-02 22:16:39.927953	0
5c90e974-f888-4575-8c9a-a7a8bc7100f5	93856333700004284	stress-38563337-4284@mediqueue.test	Paciente Stress 38563337-4284	55004284	ACTIVO	2026-06-02 22:16:40.190962	2026-06-02 22:16:40.190962	0
7733cb4e-34f4-42bb-a21a-191db94c6152	93856332000004331	stress-38563320-4331@mediqueue.test	Paciente Stress 38563320-4331	55004331	ACTIVO	2026-06-02 22:16:40.668968	2026-06-02 22:16:40.668968	0
f1f386fa-d1d8-4947-b26f-de429c89246b	93856332000004514	stress-38563320-4514@mediqueue.test	Paciente Stress 38563320-4514	55004514	ACTIVO	2026-06-02 22:16:42.283458	2026-06-02 22:16:42.283458	0
484dceec-2a4e-4dc3-bb8e-9f9312829a1d	93856333800004559	stress-38563338-4559@mediqueue.test	Paciente Stress 38563338-4559	55004559	ACTIVO	2026-06-02 22:16:42.542043	2026-06-02 22:16:42.542043	0
79d6f9f7-ef65-4ff2-a767-cb661d7b8685	93856332700004747	stress-38563327-4747@mediqueue.test	Paciente Stress 38563327-4747	55004747	ACTIVO	2026-06-02 22:16:43.860105	2026-06-02 22:16:43.860105	0
e190ae70-eafe-494c-a691-004f0e135b08	93856332200004873	stress-38563322-4873@mediqueue.test	Paciente Stress 38563322-4873	55004873	ACTIVO	2026-06-02 22:16:44.686627	2026-06-02 22:16:44.686627	0
1e8a44e9-30ba-43ca-8c46-fc12b95c7c62	93856333500004917	stress-38563335-4917@mediqueue.test	Paciente Stress 38563335-4917	55004917	ACTIVO	2026-06-02 22:16:44.852011	2026-06-02 22:16:44.852011	0
ee354b14-1919-4940-926f-faf6cf3ebd54	93877655900005596	stress-38776559-5596@mediqueue.test	Paciente Stress 38776559-5596	55005596	ACTIVO	2026-06-02 22:20:26.777413	2026-06-02 22:20:26.777413	0
721077a5-9674-4d89-98e7-35ea91029382	93877654200005793	stress-38776542-5793@mediqueue.test	Paciente Stress 38776542-5793	55005793	ACTIVO	2026-06-02 22:20:28.533013	2026-06-02 22:20:28.533013	0
c7ceb24e-7ce3-44e2-91c3-96ce1e6a2a45	93877652800005942	stress-38776528-5942@mediqueue.test	Paciente Stress 38776528-5942	55005942	ACTIVO	2026-06-02 22:20:30.153188	2026-06-02 22:20:30.153188	0
8f71b707-0b26-453b-b159-9acb423e81d3	93877651300006243	stress-38776513-6243@mediqueue.test	Paciente Stress 38776513-6243	55006243	ACTIVO	2026-06-02 22:20:32.973904	2026-06-02 22:20:32.973904	0
93f92e13-cdf3-4933-a3ea-26b0fa13f972	93877655900006421	stress-38776559-6421@mediqueue.test	Paciente Stress 38776559-6421	55006421	ACTIVO	2026-06-02 22:20:34.298488	2026-06-02 22:20:34.298488	0
abda4311-637b-4b27-8f74-5b0e5b8a5684	93877655900006442	stress-38776559-6442@mediqueue.test	Paciente Stress 38776559-6442	55006442	ACTIVO	2026-06-02 22:20:34.529108	2026-06-02 22:20:34.529108	0
f4d9d090-09f6-4a67-a6a8-0ec8dc152e65	93877654100006600	stress-38776541-6600@mediqueue.test	Paciente Stress 38776541-6600	55006600	ACTIVO	2026-06-02 22:20:35.67248	2026-06-02 22:20:35.67248	0
dc8cc8f8-10bb-49f7-b735-07cfc6520125	93877652900006884	stress-38776529-6884@mediqueue.test	Paciente Stress 38776529-6884	55006884	ACTIVO	2026-06-02 22:20:38.878919	2026-06-02 22:20:38.878919	0
f765bbf0-a3c4-4106-a647-b4dcfede8a06	93856333400000018	stress-38563334-18@mediqueue.test	Paciente Stress 38563334-18	55000018	ACTIVO	2026-06-02 22:16:05.157122	2026-06-02 22:16:05.157122	0
4047a03c-7eac-4094-a8b9-57670944569d	93856330900000269	stress-38563309-269@mediqueue.test	Paciente Stress 38563309-269	55000269	ACTIVO	2026-06-02 22:16:06.084865	2026-06-02 22:16:06.084865	0
1de3d208-e66c-46c5-9059-3e0ee315f3b6	93856333700000315	stress-38563337-315@mediqueue.test	Paciente Stress 38563337-315	55000315	ACTIVO	2026-06-02 22:16:06.374449	2026-06-02 22:16:06.374449	0
48099467-f7f7-48d8-8eb2-681846b650e0	93856331600000388	stress-38563316-388@mediqueue.test	Paciente Stress 38563316-388	55000388	ACTIVO	2026-06-02 22:16:07.314678	2026-06-02 22:16:07.314678	0
6d33aeaa-7a9e-4ace-9e9d-ebe6a3e4f2eb	93856332000000493	stress-38563320-493@mediqueue.test	Paciente Stress 38563320-493	55000493	ACTIVO	2026-06-02 22:16:08.22808	2026-06-02 22:16:08.22808	0
74ffa730-6df7-43ea-ad68-591aace35092	93856331600000514	stress-38563316-514@mediqueue.test	Paciente Stress 38563316-514	55000514	ACTIVO	2026-06-02 22:16:08.429745	2026-06-02 22:16:08.429745	0
02f9e24b-05ae-4a23-a992-f2518a22f14d	93856330600000580	stress-38563306-580@mediqueue.test	Paciente Stress 38563306-580	55000580	ACTIVO	2026-06-02 22:16:09.063502	2026-06-02 22:16:09.063502	0
a87825d9-b0cb-4cec-805a-d27666c7a303	93856332700000693	stress-38563327-693@mediqueue.test	Paciente Stress 38563327-693	55000693	ACTIVO	2026-06-02 22:16:10.158699	2026-06-02 22:16:10.158699	0
0eb14f64-0426-42f3-b11f-bd822550085a	93856331200000742	stress-38563312-742@mediqueue.test	Paciente Stress 38563312-742	55000742	ACTIVO	2026-06-02 22:16:10.848404	2026-06-02 22:16:10.848404	0
448169cf-ca43-4053-88d7-0529dcbadceb	93856330700000825	stress-38563307-825@mediqueue.test	Paciente Stress 38563307-825	55000825	ACTIVO	2026-06-02 22:16:11.524856	2026-06-02 22:16:11.524856	0
cb4f60b1-58e3-4171-8c91-9c5b99724f57	93856332500000884	stress-38563325-884@mediqueue.test	Paciente Stress 38563325-884	55000884	ACTIVO	2026-06-02 22:16:12.036329	2026-06-02 22:16:12.036329	0
efa8bec4-f135-4bad-b885-20b5a19ffd7b	93856332100000935	stress-38563321-935@mediqueue.test	Paciente Stress 38563321-935	55000935	ACTIVO	2026-06-02 22:16:12.758827	2026-06-02 22:16:12.758827	0
88229890-6852-430d-b793-6cce9b1f7604	93856331700000998	stress-38563317-998@mediqueue.test	Paciente Stress 38563317-998	55000998	ACTIVO	2026-06-02 22:16:13.161524	2026-06-02 22:16:13.161524	0
6a5f63c5-f7c4-4fb6-b16b-1de604ebd3c9	93856331600001076	stress-38563316-1076@mediqueue.test	Paciente Stress 38563316-1076	55001076	ACTIVO	2026-06-02 22:16:14.356151	2026-06-02 22:16:14.356151	0
e072cda7-21ca-476d-86fd-c1cf05a34d0a	93856333400001112	stress-38563334-1112@mediqueue.test	Paciente Stress 38563334-1112	55001112	ACTIVO	2026-06-02 22:16:14.639292	2026-06-02 22:16:14.639292	0
3f99d7c9-3986-4f41-b613-0b0cb028034c	93856332100001953	stress-38563321-1953@mediqueue.test	Paciente Stress 38563321-1953	55001953	ACTIVO	2026-06-02 22:16:22.366861	2026-06-02 22:16:22.366861	0
f1348a47-68b2-4edd-8786-7b5aa837ce7a	93856332000002018	stress-38563320-2018@mediqueue.test	Paciente Stress 38563320-2018	55002018	ACTIVO	2026-06-02 22:16:22.873522	2026-06-02 22:16:22.873522	0
30031104-4202-4926-9e5b-f11e646799f0	93856331600002210	stress-38563316-2210@mediqueue.test	Paciente Stress 38563316-2210	55002210	ACTIVO	2026-06-02 22:16:24.872251	2026-06-02 22:16:24.872251	0
95a1dff5-a83d-4e8f-96d8-fe12261e8a67	93856331700002677	stress-38563317-2677@mediqueue.test	Paciente Stress 38563317-2677	55002677	ACTIVO	2026-06-02 22:16:28.535146	2026-06-02 22:16:28.535146	0
0d7c8a71-18d2-4067-9bb8-cdffd97b88ee	93856332000002736	stress-38563320-2736@mediqueue.test	Paciente Stress 38563320-2736	55002736	ACTIVO	2026-06-02 22:16:29.064532	2026-06-02 22:16:29.064532	0
74768c40-a984-40f9-811a-dbe9ca582f85	93856332700002812	stress-38563327-2812@mediqueue.test	Paciente Stress 38563327-2812	55002812	ACTIVO	2026-06-02 22:16:29.450427	2026-06-02 22:16:29.450427	0
83139076-62e5-403c-ad1e-0ea36012a0d9	93856333300003322	stress-38563333-3322@mediqueue.test	Paciente Stress 38563333-3322	55003322	ACTIVO	2026-06-02 22:16:33.034299	2026-06-02 22:16:33.034299	0
5446c6d2-8b7a-4b43-929e-34bd5c998c3c	93856332800003434	stress-38563328-3434@mediqueue.test	Paciente Stress 38563328-3434	55003434	ACTIVO	2026-06-02 22:16:33.804925	2026-06-02 22:16:33.804925	0
005cd3a7-4b61-4e49-a514-dd1c98dce512	93856333000003601	stress-38563330-3601@mediqueue.test	Paciente Stress 38563330-3601	55003601	ACTIVO	2026-06-02 22:16:34.868181	2026-06-02 22:16:34.868181	0
d2db4057-64da-41ff-b04b-21a4a8f9cdd8	93856333500003615	stress-38563335-3615@mediqueue.test	Paciente Stress 38563335-3615	55003615	ACTIVO	2026-06-02 22:16:34.999852	2026-06-02 22:16:34.999852	0
bed6f0f5-a502-469b-bca0-c5ddbb76129d	93856333600003683	stress-38563336-3683@mediqueue.test	Paciente Stress 38563336-3683	55003683	ACTIVO	2026-06-02 22:16:35.492018	2026-06-02 22:16:35.492018	0
1c1cb785-46a9-4a04-a2af-2c7201d62cd1	93856333400003818	stress-38563334-3818@mediqueue.test	Paciente Stress 38563334-3818	55003818	ACTIVO	2026-06-02 22:16:36.262717	2026-06-02 22:16:36.262717	0
b1f11ae6-2aa8-473a-8951-fdc6f3d29f5b	93856333300003869	stress-38563333-3869@mediqueue.test	Paciente Stress 38563333-3869	55003869	ACTIVO	2026-06-02 22:16:36.521422	2026-06-02 22:16:36.521422	0
721fc0b2-41fc-4de3-a008-495d6bbdb008	93856333400003933	stress-38563334-3933@mediqueue.test	Paciente Stress 38563334-3933	55003933	ACTIVO	2026-06-02 22:16:37.039025	2026-06-02 22:16:37.039025	0
9a949817-0a17-4ebc-9130-548718d37288	93856331600004200	stress-38563316-4200@mediqueue.test	Paciente Stress 38563316-4200	55004200	ACTIVO	2026-06-02 22:16:39.382539	2026-06-02 22:16:39.382539	0
d9dd029b-a555-4e72-a768-f772eeb8abfc	93856332700004286	stress-38563327-4286@mediqueue.test	Paciente Stress 38563327-4286	55004286	ACTIVO	2026-06-02 22:16:40.244577	2026-06-02 22:16:40.244577	0
57a0c80a-2930-4d42-84f3-6b62c79e70e1	93856332000004312	stress-38563320-4312@mediqueue.test	Paciente Stress 38563320-4312	55004312	ACTIVO	2026-06-02 22:16:40.490727	2026-06-02 22:16:40.490727	0
ddc48dbf-e58a-47ba-83a2-d8ba5ea0bdcf	93856332700004332	stress-38563327-4332@mediqueue.test	Paciente Stress 38563327-4332	55004332	ACTIVO	2026-06-02 22:16:40.823158	2026-06-02 22:16:40.823158	0
a2821c5b-a6f5-45f7-9f8f-195989db4770	93856330600004589	stress-38563306-4589@mediqueue.test	Paciente Stress 38563306-4589	55004589	ACTIVO	2026-06-02 22:16:42.757758	2026-06-02 22:16:42.757758	0
6f3b17fd-457b-4cbc-bbb3-623bf459d2d8	93856332200004935	stress-38563322-4935@mediqueue.test	Paciente Stress 38563322-4935	55004935	ACTIVO	2026-06-02 22:16:44.955527	2026-06-02 22:16:44.955527	0
7ad24edc-b9e6-4c68-9ad1-ac23c77e5d90	93877651300005803	stress-38776513-5803@mediqueue.test	Paciente Stress 38776513-5803	55005803	ACTIVO	2026-06-02 22:20:28.623147	2026-06-02 22:20:28.623147	0
24e20a20-b2bd-4f0d-84ea-405a67646349	93877653600006006	stress-38776536-6006@mediqueue.test	Paciente Stress 38776536-6006	55006006	ACTIVO	2026-06-02 22:20:30.614595	2026-06-02 22:20:30.614595	0
1dc263ba-5271-4c42-adb6-4e93c145bc90	93877654300006066	stress-38776543-6066@mediqueue.test	Paciente Stress 38776543-6066	55006066	ACTIVO	2026-06-02 22:20:31.799918	2026-06-02 22:20:31.799918	0
c0452cf4-19e1-44f8-bd5d-eb9114ef3b32	93877656200006281	stress-38776562-6281@mediqueue.test	Paciente Stress 38776562-6281	55006281	ACTIVO	2026-06-02 22:20:33.104196	2026-06-02 22:20:33.104196	0
9e34cd02-8028-4951-81cc-bb30be8c0d77	93877654600006458	stress-38776546-6458@mediqueue.test	Paciente Stress 38776546-6458	55006458	ACTIVO	2026-06-02 22:20:34.65322	2026-06-02 22:20:34.65322	0
d111e2f1-b3a8-4818-ae73-ea0ac67412f3	93877651400006643	stress-38776514-6643@mediqueue.test	Paciente Stress 38776514-6643	55006643	ACTIVO	2026-06-02 22:20:36.021843	2026-06-02 22:20:36.021843	0
fb02a0b6-b53f-4eb6-ac81-dc054d701c3b	93877651400006675	stress-38776514-6675@mediqueue.test	Paciente Stress 38776514-6675	55006675	ACTIVO	2026-06-02 22:20:36.261161	2026-06-02 22:20:36.261161	0
a1375e95-a1e6-4831-8099-d51d0a957db8	93877654500006736	stress-38776545-6736@mediqueue.test	Paciente Stress 38776545-6736	55006736	ACTIVO	2026-06-02 22:20:36.994044	2026-06-02 22:20:36.994044	0
530bca37-715b-4250-a9e0-c3f3c5d8f7bd	93877656100006760	stress-38776561-6760@mediqueue.test	Paciente Stress 38776561-6760	55006760	ACTIVO	2026-06-02 22:20:37.355082	2026-06-02 22:20:37.355082	0
948828d6-ce1a-4a84-ada1-58555d23b771	93877651900006789	stress-38776519-6789@mediqueue.test	Paciente Stress 38776519-6789	55006789	ACTIVO	2026-06-02 22:20:37.856791	2026-06-02 22:20:37.856791	0
c44697ba-2e12-4943-a0bb-a31b237e0baf	93877653600006957	stress-38776536-6957@mediqueue.test	Paciente Stress 38776536-6957	55006957	ACTIVO	2026-06-02 22:20:39.351163	2026-06-02 22:20:39.351163	0
662b5892-a7c5-4960-a87e-fb7cf6f3ecef	93877655600007104	stress-38776556-7104@mediqueue.test	Paciente Stress 38776556-7104	55007104	ACTIVO	2026-06-02 22:20:40.457398	2026-06-02 22:20:40.457398	0
aef5cf4f-ff5d-4d6c-b43d-3f9d41ab2280	93856332300000043	stress-38563323-43@mediqueue.test	Paciente Stress 38563323-43	55000043	ACTIVO	2026-06-02 22:16:05.168931	2026-06-02 22:16:05.168931	0
b69b6f5f-0d63-4f8e-b470-68a07abb071d	93856330900000987	stress-38563309-987@mediqueue.test	Paciente Stress 38563309-987	55000987	ACTIVO	2026-06-02 22:16:13.109827	2026-06-02 22:16:13.109827	0
a5171be4-8101-40e5-b58d-02aa436654de	93856332100001252	stress-38563321-1252@mediqueue.test	Paciente Stress 38563321-1252	55001252	ACTIVO	2026-06-02 22:16:15.520312	2026-06-02 22:16:15.520312	0
ab229808-8aa5-4c0a-9e03-fc6b5dbf050d	93856333400001836	stress-38563334-1836@mediqueue.test	Paciente Stress 38563334-1836	55001836	ACTIVO	2026-06-02 22:16:22.753648	2026-06-02 22:16:22.753648	0
8795e31f-49aa-4313-a798-6e2188820fdd	93856330700002380	stress-38563307-2380@mediqueue.test	Paciente Stress 38563307-2380	55002380	ACTIVO	2026-06-02 22:16:26.306712	2026-06-02 22:16:26.306712	0
73ba3a9f-fe7f-4935-aa10-c9e91353c50d	93856332600002831	stress-38563326-2831@mediqueue.test	Paciente Stress 38563326-2831	55002831	ACTIVO	2026-06-02 22:16:29.52832	2026-06-02 22:16:29.52832	0
ff936c32-2e5a-4fc5-9d19-9fd0c36048f9	93856333700003034	stress-38563337-3034@mediqueue.test	Paciente Stress 38563337-3034	55003034	ACTIVO	2026-06-02 22:16:30.824921	2026-06-02 22:16:30.824921	0
91250129-ab64-4d0f-a660-b3ed1b90bc67	93856332000003314	stress-38563320-3314@mediqueue.test	Paciente Stress 38563320-3314	55003314	ACTIVO	2026-06-02 22:16:32.94217	2026-06-02 22:16:32.94217	0
a6d770bb-4892-4df4-b654-17f756d3db02	93856331300003494	stress-38563313-3494@mediqueue.test	Paciente Stress 38563313-3494	55003494	ACTIVO	2026-06-02 22:16:34.321976	2026-06-02 22:16:34.321976	0
e43f52d0-fee2-4adc-92b9-ad57bee75eed	93856333300003813	stress-38563333-3813@mediqueue.test	Paciente Stress 38563333-3813	55003813	ACTIVO	2026-06-02 22:16:36.241231	2026-06-02 22:16:36.241231	0
602e079a-8dee-42d3-b184-a462f37bbda0	93856331300004025	stress-38563313-4025@mediqueue.test	Paciente Stress 38563313-4025	55004025	ACTIVO	2026-06-02 22:16:37.896322	2026-06-02 22:16:37.896322	0
031bd2c8-a431-4073-b5d5-6d382535979d	93856330900004507	stress-38563309-4507@mediqueue.test	Paciente Stress 38563309-4507	55004507	ACTIVO	2026-06-02 22:16:42.254266	2026-06-02 22:16:42.254266	0
4695c4d8-d819-4dd0-bcc5-bf705ececfb5	93856330600004632	stress-38563306-4632@mediqueue.test	Paciente Stress 38563306-4632	55004632	ACTIVO	2026-06-02 22:16:43.010041	2026-06-02 22:16:43.010041	0
937bf203-478e-46ef-b910-0a259c7b69c5	93856333500004691	stress-38563335-4691@mediqueue.test	Paciente Stress 38563335-4691	55004691	ACTIVO	2026-06-02 22:16:43.405199	2026-06-02 22:16:43.405199	0
bf8b757d-3d67-4f49-8137-0443b200d95e	93856333600004892	stress-38563336-4892@mediqueue.test	Paciente Stress 38563336-4892	55004892	ACTIVO	2026-06-02 22:16:44.770618	2026-06-02 22:16:44.770618	0
7ac4b4c0-c04b-47b6-8498-d3ea212757f1	93856333300004976	stress-38563333-4976@mediqueue.test	Paciente Stress 38563333-4976	55004976	ACTIVO	2026-06-02 22:16:45.278236	2026-06-02 22:16:45.278236	0
d3956aac-466a-41b9-a7cb-b4be5357da65	93877656300005968	stress-38776563-5968@mediqueue.test	Paciente Stress 38776563-5968	55005968	ACTIVO	2026-06-02 22:20:30.260126	2026-06-02 22:20:30.260126	0
b1f58e13-397a-4d59-a3a4-22e728db6f47	93877650700006232	stress-38776507-6232@mediqueue.test	Paciente Stress 38776507-6232	55006232	ACTIVO	2026-06-02 22:20:32.898628	2026-06-02 22:20:32.898628	0
f1c1e324-c74c-42e4-99b7-d2664a2604a8	93877651800006436	stress-38776518-6436@mediqueue.test	Paciente Stress 38776518-6436	55006436	ACTIVO	2026-06-02 22:20:34.463095	2026-06-02 22:20:34.463095	0
5819e6f3-1a85-46cd-a248-46ea7e337581	93877655700006631	stress-38776557-6631@mediqueue.test	Paciente Stress 38776557-6631	55006631	ACTIVO	2026-06-02 22:20:35.96988	2026-06-02 22:20:35.96988	0
adbab201-93eb-4ec2-b915-c021022b4dc5	93877653600006914	stress-38776536-6914@mediqueue.test	Paciente Stress 38776536-6914	55006914	ACTIVO	2026-06-02 22:20:39.03308	2026-06-02 22:20:39.03308	0
448ee1e9-d485-4360-89c5-b854b0b668f3	93877655500006973	stress-38776555-6973@mediqueue.test	Paciente Stress 38776555-6973	55006973	ACTIVO	2026-06-02 22:20:39.519211	2026-06-02 22:20:39.519211	0
7da04eaf-11d5-4f25-8ca3-a709c50ca9e3	93877656500007165	stress-38776565-7165@mediqueue.test	Paciente Stress 38776565-7165	55007165	ACTIVO	2026-06-02 22:20:41.016309	2026-06-02 22:20:41.016309	0
e02ab5f0-17f9-46b0-971d-c374277e256e	93877655900007379	stress-38776559-7379@mediqueue.test	Paciente Stress 38776559-7379	55007379	ACTIVO	2026-06-02 22:20:42.797093	2026-06-02 22:20:42.797093	0
83e7e8c6-d98b-4b1b-98d7-a7baddf675a5	93877654700007430	stress-38776547-7430@mediqueue.test	Paciente Stress 38776547-7430	55007430	ACTIVO	2026-06-02 22:20:43.229113	2026-06-02 22:20:43.229113	0
2363e0db-5935-4703-9495-4a8fe280481e	93877652300007641	stress-38776523-7641@mediqueue.test	Paciente Stress 38776523-7641	55007641	ACTIVO	2026-06-02 22:20:44.951714	2026-06-02 22:20:44.951714	0
ec3bf011-04ec-4651-91b2-d28a99268203	93877654300008074	stress-38776543-8074@mediqueue.test	Paciente Stress 38776543-8074	55008074	ACTIVO	2026-06-02 22:21:10.568049	2026-06-02 22:21:10.568049	0
7a0c70e6-bf0d-4b26-8653-793279d12ef7	93877655000008144	stress-38776550-8144@mediqueue.test	Paciente Stress 38776550-8144	55008144	ACTIVO	2026-06-02 22:21:11.202792	2026-06-02 22:21:11.202792	0
675bfcb1-5c76-482f-a707-b258b222a4f5	93877652400008251	stress-38776524-8251@mediqueue.test	Paciente Stress 38776524-8251	55008251	ACTIVO	2026-06-02 22:21:12.857553	2026-06-02 22:21:12.857553	0
2c5ce7ce-fa7a-480f-aa9f-41f82fe3b865	93877653900008282	stress-38776539-8282@mediqueue.test	Paciente Stress 38776539-8282	55008282	ACTIVO	2026-06-02 22:21:13.223755	2026-06-02 22:21:13.223755	0
380c958d-fbbd-493e-a7bc-56619b4eefa8	93877656100008313	stress-38776561-8313@mediqueue.test	Paciente Stress 38776561-8313	55008313	ACTIVO	2026-06-02 22:21:13.768086	2026-06-02 22:21:13.768086	0
40a9a3d9-f11f-41f5-8080-bcaecb6bc1f0	93877651300008342	stress-38776513-8342@mediqueue.test	Paciente Stress 38776513-8342	55008342	ACTIVO	2026-06-02 22:21:14.277646	2026-06-02 22:21:14.277646	0
9dd1a2b1-e278-49cf-8111-63409eb74d7b	93877656300008394	stress-38776563-8394@mediqueue.test	Paciente Stress 38776563-8394	55008394	ACTIVO	2026-06-02 22:21:15.133732	2026-06-02 22:21:15.133732	0
685c63b3-539f-4b36-9daf-aa77d4f761fb	93877652300008504	stress-38776523-8504@mediqueue.test	Paciente Stress 38776523-8504	55008504	ACTIVO	2026-06-02 22:21:16.66559	2026-06-02 22:21:16.66559	0
26abd354-012b-48ec-b9b0-e83eb65feaa1	93877653700008728	stress-38776537-8728@mediqueue.test	Paciente Stress 38776537-8728	55008728	ACTIVO	2026-06-02 22:21:19.120267	2026-06-02 22:21:19.120267	0
488d0b93-116d-4a31-8ca7-ec280db3207f	93877652900008911	stress-38776529-8911@mediqueue.test	Paciente Stress 38776529-8911	55008911	ACTIVO	2026-06-02 22:21:20.432223	2026-06-02 22:21:20.432223	0
39ade259-35e8-4ea9-aa73-9467507ff0a3	93877655500008951	stress-38776555-8951@mediqueue.test	Paciente Stress 38776555-8951	55008951	ACTIVO	2026-06-02 22:21:20.743887	2026-06-02 22:21:20.743887	0
32a924d3-6e69-4137-a0c6-0dddc4d3ec8d	93877655800008984	stress-38776558-8984@mediqueue.test	Paciente Stress 38776558-8984	55008984	ACTIVO	2026-06-02 22:21:21.062923	2026-06-02 22:21:21.062923	0
133c1aba-9fe5-4b50-8a8a-c4ed4ae1435b	93877655100009119	stress-38776551-9119@mediqueue.test	Paciente Stress 38776551-9119	55009119	ACTIVO	2026-06-02 22:21:22.533633	2026-06-02 22:21:22.533633	0
3cb4dd44-b309-46e6-af16-f4fc9fcdf9e0	93877652200009464	stress-38776522-9464@mediqueue.test	Paciente Stress 38776522-9464	55009464	ACTIVO	2026-06-02 22:21:26.772094	2026-06-02 22:21:26.772094	0
ba135d33-524e-431f-a017-eb470779470b	93877654600009625	stress-38776546-9625@mediqueue.test	Paciente Stress 38776546-9625	55009625	ACTIVO	2026-06-02 22:21:27.995256	2026-06-02 22:21:27.995256	0
e0b4d381-71a7-47ba-a7c4-418e6ee5a67d	93877651400009822	stress-38776514-9822@mediqueue.test	Paciente Stress 38776514-9822	55009822	ACTIVO	2026-06-02 22:22:07.597203	2026-06-02 22:22:07.597203	0
967ec779-253a-43bf-81bb-21510a45cf64	93877654200009872	stress-38776542-9872@mediqueue.test	Paciente Stress 38776542-9872	55009872	ACTIVO	2026-06-02 22:22:08.512326	2026-06-02 22:22:08.512326	0
caf09a7f-2816-430a-9381-f29cd879dffd	93969225700000179	stress-39692257-179@mediqueue.test	Paciente Stress 39692257-179	55000179	ACTIVO	2026-06-02 22:35:00.35646	2026-06-02 22:35:00.35646	0
3d58a32b-d199-44fa-9222-a6cdf9e1960f	93969227000000234	stress-39692270-234@mediqueue.test	Paciente Stress 39692270-234	55000234	ACTIVO	2026-06-02 22:35:00.618241	2026-06-02 22:35:00.618241	0
d2dcf441-e023-4bcc-b149-e46cf1401e47	93969226200000252	stress-39692262-252@mediqueue.test	Paciente Stress 39692262-252	55000252	ACTIVO	2026-06-02 22:35:00.833013	2026-06-02 22:35:00.833013	0
795fad5d-a91a-4d8e-9ced-235ce7e4185d	93969225600000037	stress-39692256-37@mediqueue.test	Paciente Stress 39692256-37	55000037	ACTIVO	2026-06-02 22:35:01.030927	2026-06-02 22:35:01.030927	0
3ff0d588-b76e-43cf-92a0-727686d88d92	93856331200000178	stress-38563312-178@mediqueue.test	Paciente Stress 38563312-178	55000178	ACTIVO	2026-06-02 22:16:05.219568	2026-06-02 22:16:05.219568	0
1809eaff-0a5c-471f-afb3-0f425c25d1c2	93856333400000782	stress-38563334-782@mediqueue.test	Paciente Stress 38563334-782	55000782	ACTIVO	2026-06-02 22:16:11.178147	2026-06-02 22:16:11.178147	0
bd47ecba-f10b-4452-b0d7-44e225886a1f	93856333300000927	stress-38563333-927@mediqueue.test	Paciente Stress 38563333-927	55000927	ACTIVO	2026-06-02 22:16:12.676294	2026-06-02 22:16:12.676294	0
282e6171-26e4-481e-a2e3-d28fb4cce733	93856333500000982	stress-38563335-982@mediqueue.test	Paciente Stress 38563335-982	55000982	ACTIVO	2026-06-02 22:16:13.011197	2026-06-02 22:16:13.011197	0
054cdd23-f1e7-4fe4-8602-37e5079d9d5b	93856333600001138	stress-38563336-1138@mediqueue.test	Paciente Stress 38563336-1138	55001138	ACTIVO	2026-06-02 22:16:14.661963	2026-06-02 22:16:14.661963	0
870425eb-ccf9-429a-8674-9254d8bd8afd	93856332100001356	stress-38563321-1356@mediqueue.test	Paciente Stress 38563321-1356	55001356	ACTIVO	2026-06-02 22:16:16.489542	2026-06-02 22:16:16.489542	0
07a5d34a-b642-480b-a07f-90efd2655eaa	93856332100001401	stress-38563321-1401@mediqueue.test	Paciente Stress 38563321-1401	55001401	ACTIVO	2026-06-02 22:16:17.472269	2026-06-02 22:16:17.472269	0
dabeac75-0215-4091-ab29-29192d8a0c97	93856333700001454	stress-38563337-1454@mediqueue.test	Paciente Stress 38563337-1454	55001454	ACTIVO	2026-06-02 22:16:17.701303	2026-06-02 22:16:17.701303	0
b16116c2-6acd-491e-b99b-f8b9b75a1d6a	93856332000001820	stress-38563320-1820@mediqueue.test	Paciente Stress 38563320-1820	55001820	ACTIVO	2026-06-02 22:16:22.484642	2026-06-02 22:16:22.484642	0
5bd3bdd2-2743-4581-a7b4-bc64daf5eb78	93856332800002054	stress-38563328-2054@mediqueue.test	Paciente Stress 38563328-2054	55002054	ACTIVO	2026-06-02 22:16:23.200146	2026-06-02 22:16:23.200146	0
af2049b2-be27-4d14-9833-d1c7d6eb2ca6	93856333500002149	stress-38563335-2149@mediqueue.test	Paciente Stress 38563335-2149	55002149	ACTIVO	2026-06-02 22:16:24.459706	2026-06-02 22:16:24.459706	0
613fb67e-5423-4cbf-8465-f60ea5356e86	93856333700002507	stress-38563337-2507@mediqueue.test	Paciente Stress 38563337-2507	55002507	ACTIVO	2026-06-02 22:16:27.453471	2026-06-02 22:16:27.453471	0
c2106d0f-765a-452e-9e69-08a2fa4d149f	93856333700002720	stress-38563337-2720@mediqueue.test	Paciente Stress 38563337-2720	55002720	ACTIVO	2026-06-02 22:16:28.917024	2026-06-02 22:16:28.917024	0
aa59a1d8-5baf-4986-b6f2-83e06461baa9	93856330600002920	stress-38563306-2920@mediqueue.test	Paciente Stress 38563306-2920	55002920	ACTIVO	2026-06-02 22:16:30.148178	2026-06-02 22:16:30.148178	0
6d675043-455d-4122-8dbe-716807c1bdb1	93856331700002944	stress-38563317-2944@mediqueue.test	Paciente Stress 38563317-2944	55002944	ACTIVO	2026-06-02 22:16:30.317471	2026-06-02 22:16:30.317471	0
7e06e71a-a3dd-4df7-be45-7947e424d7f5	93856333100003137	stress-38563331-3137@mediqueue.test	Paciente Stress 38563331-3137	55003137	ACTIVO	2026-06-02 22:16:31.644287	2026-06-02 22:16:31.644287	0
ca9d9743-ab47-4cb7-b70b-6ae99c21a8ed	93856333100003163	stress-38563331-3163@mediqueue.test	Paciente Stress 38563331-3163	55003163	ACTIVO	2026-06-02 22:16:31.89135	2026-06-02 22:16:31.89135	0
883b7b36-40bb-4c73-a3b6-a2dec6152a58	93856331300003180	stress-38563313-3180@mediqueue.test	Paciente Stress 38563313-3180	55003180	ACTIVO	2026-06-02 22:16:32.070453	2026-06-02 22:16:32.070453	0
9bbe748f-564a-4824-8a1f-bdeaab17bcb8	93856331600003236	stress-38563316-3236@mediqueue.test	Paciente Stress 38563316-3236	55003236	ACTIVO	2026-06-02 22:16:32.475297	2026-06-02 22:16:32.475297	0
a41dcaa2-fca3-411f-9dbe-f679b3db4fb4	93856332100003831	stress-38563321-3831@mediqueue.test	Paciente Stress 38563321-3831	55003831	ACTIVO	2026-06-02 22:16:36.28623	2026-06-02 22:16:36.28623	0
7b68e731-0523-4bc6-8904-0be7afc1a173	93856332600003875	stress-38563326-3875@mediqueue.test	Paciente Stress 38563326-3875	55003875	ACTIVO	2026-06-02 22:16:36.546198	2026-06-02 22:16:36.546198	0
9e4b9623-2fb0-4a8f-af92-b547e711d3c5	93856333000004112	stress-38563330-4112@mediqueue.test	Paciente Stress 38563330-4112	55004112	ACTIVO	2026-06-02 22:16:38.779809	2026-06-02 22:16:38.779809	0
5c5858a0-3270-44d9-8e2e-0253942e014a	93856333400004157	stress-38563334-4157@mediqueue.test	Paciente Stress 38563334-4157	55004157	ACTIVO	2026-06-02 22:16:39.160071	2026-06-02 22:16:39.160071	0
792fb8fa-e4ae-41f9-9139-4eb374aa0b24	93856331300004202	stress-38563313-4202@mediqueue.test	Paciente Stress 38563313-4202	55004202	ACTIVO	2026-06-02 22:16:39.406602	2026-06-02 22:16:39.406602	0
620c9b9b-f6a0-446a-b5dd-d5c2df7a7205	93856333700004301	stress-38563337-4301@mediqueue.test	Paciente Stress 38563337-4301	55004301	ACTIVO	2026-06-02 22:16:40.416211	2026-06-02 22:16:40.416211	0
ab3d67fc-8484-46d9-b7ff-ca3776b41deb	93856333600004685	stress-38563336-4685@mediqueue.test	Paciente Stress 38563336-4685	55004685	ACTIVO	2026-06-02 22:16:43.376565	2026-06-02 22:16:43.376565	0
6768c9f6-3f0b-4397-a869-ad95cb69b18a	93856331600004916	stress-38563316-4916@mediqueue.test	Paciente Stress 38563316-4916	55004916	ACTIVO	2026-06-02 22:16:44.832325	2026-06-02 22:16:44.832325	0
868803d5-5613-4781-b1ab-10a4350e901e	93877652200006850	stress-38776522-6850@mediqueue.test	Paciente Stress 38776522-6850	55006850	ACTIVO	2026-06-02 22:20:38.706567	2026-06-02 22:20:38.706567	0
13f57219-77bd-404e-b96b-aa97be1ac243	93877653400006929	stress-38776534-6929@mediqueue.test	Paciente Stress 38776534-6929	55006929	ACTIVO	2026-06-02 22:20:39.104649	2026-06-02 22:20:39.104649	0
44dd9cc7-b1db-496e-9d53-641ed30fa37a	93877652300007163	stress-38776523-7163@mediqueue.test	Paciente Stress 38776523-7163	55007163	ACTIVO	2026-06-02 22:20:40.993967	2026-06-02 22:20:40.993967	0
b317fa73-a307-4b18-8b2f-9c76074861d8	93877652900007361	stress-38776529-7361@mediqueue.test	Paciente Stress 38776529-7361	55007361	ACTIVO	2026-06-02 22:20:42.704682	2026-06-02 22:20:42.704682	0
bf3f69b2-0b51-4506-ad91-66bac8b1deea	93877653600007501	stress-38776536-7501@mediqueue.test	Paciente Stress 38776536-7501	55007501	ACTIVO	2026-06-02 22:20:43.882061	2026-06-02 22:20:43.882061	0
25fbba68-2fe2-4748-8573-dae0d0a9632e	93877656100008151	stress-38776561-8151@mediqueue.test	Paciente Stress 38776561-8151	55008151	ACTIVO	2026-06-02 22:21:11.224037	2026-06-02 22:21:11.224037	0
87cd8991-c7cd-446c-9295-9d8b052f0b91	93877651300008289	stress-38776513-8289@mediqueue.test	Paciente Stress 38776513-8289	55008289	ACTIVO	2026-06-02 22:21:13.584685	2026-06-02 22:21:13.584685	0
23e987ae-7a22-4597-a6c6-0d371901344d	93877655700008963	stress-38776557-8963@mediqueue.test	Paciente Stress 38776557-8963	55008963	ACTIVO	2026-06-02 22:21:20.85973	2026-06-02 22:21:20.85973	0
c0a6527b-f0c5-4bdd-84e8-548656bb6bc8	93877651800009018	stress-38776518-9018@mediqueue.test	Paciente Stress 38776518-9018	55009018	ACTIVO	2026-06-02 22:21:21.409354	2026-06-02 22:21:21.409354	0
9a4700e5-1ae7-40e5-ae1e-c80fee0e3538	93877654200009072	stress-38776542-9072@mediqueue.test	Paciente Stress 38776542-9072	55009072	ACTIVO	2026-06-02 22:21:21.880076	2026-06-02 22:21:21.880076	0
3b774751-40eb-4b49-a0d4-f867afafd0ee	93877653500009329	stress-38776535-9329@mediqueue.test	Paciente Stress 38776535-9329	55009329	ACTIVO	2026-06-02 22:21:25.321229	2026-06-02 22:21:25.321229	0
6370fc41-a4bb-4022-b8c5-6187b4c1f41d	93877652900009607	stress-38776529-9607@mediqueue.test	Paciente Stress 38776529-9607	55009607	ACTIVO	2026-06-02 22:21:27.853375	2026-06-02 22:21:27.853375	0
1ba614ce-a23f-4d31-ad8e-fee5eea3c415	93877655900009760	stress-38776559-9760@mediqueue.test	Paciente Stress 38776559-9760	55009760	ACTIVO	2026-06-02 22:22:07.575063	2026-06-02 22:22:07.575063	0
18b79091-66df-473b-95bb-673378f83e7c	93969227900000046	stress-39692279-46@mediqueue.test	Paciente Stress 39692279-46	55000046	ACTIVO	2026-06-02 22:35:00.362468	2026-06-02 22:35:00.362468	0
23785c09-04e1-41b5-ae6d-65418f10a089	93969227600000022	stress-39692276-22@mediqueue.test	Paciente Stress 39692276-22	55000022	ACTIVO	2026-06-02 22:35:01.042946	2026-06-02 22:35:01.042946	0
cf7a46b3-c1db-4ae9-a387-b0fa1949b272	93969225700000117	stress-39692257-117@mediqueue.test	Paciente Stress 39692257-117	55000117	ACTIVO	2026-06-02 22:35:01.366607	2026-06-02 22:35:01.366607	0
b9d49ac5-9035-4021-af09-65aeb50e7297	93969227500000507	stress-39692275-507@mediqueue.test	Paciente Stress 39692275-507	55000507	ACTIVO	2026-06-02 22:35:02.686609	2026-06-02 22:35:02.686609	0
da4801a1-9a27-47a4-8d1a-7715442aa98a	93969225600000537	stress-39692256-537@mediqueue.test	Paciente Stress 39692256-537	55000537	ACTIVO	2026-06-02 22:35:02.713688	2026-06-02 22:35:02.713688	0
ec6e80b1-2012-4c50-b9c8-23b09eaafcc7	93969226300000563	stress-39692263-563@mediqueue.test	Paciente Stress 39692263-563	55000563	ACTIVO	2026-06-02 22:35:03.16637	2026-06-02 22:35:03.16637	0
996ed0eb-a029-4800-8673-10904f383e08	93969228000000593	stress-39692280-593@mediqueue.test	Paciente Stress 39692280-593	55000593	ACTIVO	2026-06-02 22:35:03.368098	2026-06-02 22:35:03.368098	0
89f9c752-5626-4959-bb73-ae244075a626	93856333600000175	stress-38563336-175@mediqueue.test	Paciente Stress 38563336-175	55000175	ACTIVO	2026-06-02 22:16:05.317816	2026-06-02 22:16:05.317816	0
94ea8aac-40cc-437b-901f-4cae5984a02b	93856330900000316	stress-38563309-316@mediqueue.test	Paciente Stress 38563309-316	55000316	ACTIVO	2026-06-02 22:16:06.375744	2026-06-02 22:16:06.375744	0
06b3092b-b0f7-401c-8af2-ad1bdc2a5ac6	93856332800000553	stress-38563328-553@mediqueue.test	Paciente Stress 38563328-553	55000553	ACTIVO	2026-06-02 22:16:08.852563	2026-06-02 22:16:08.852563	0
6b338eda-dc67-4f37-9f8c-25690547f911	93856333300000928	stress-38563333-928@mediqueue.test	Paciente Stress 38563333-928	55000928	ACTIVO	2026-06-02 22:16:12.667636	2026-06-02 22:16:12.667636	0
23e88b96-cb3f-45bb-9dcc-6062d6f91475	93856331600001526	stress-38563316-1526@mediqueue.test	Paciente Stress 38563316-1526	55001526	ACTIVO	2026-06-02 22:16:18.277984	2026-06-02 22:16:18.277984	0
27a74cc5-4091-42e9-9950-9eafe8e8327a	93856330600001606	stress-38563306-1606@mediqueue.test	Paciente Stress 38563306-1606	55001606	ACTIVO	2026-06-02 22:16:21.164027	2026-06-02 22:16:21.164027	0
266203c7-e65e-4e24-bcf0-100c1abecded	93856333500001941	stress-38563335-1941@mediqueue.test	Paciente Stress 38563335-1941	55001941	ACTIVO	2026-06-02 22:16:22.680467	2026-06-02 22:16:22.680467	0
3034fe99-fa7f-469a-9b22-b67d11d17a91	93856330700003119	stress-38563307-3119@mediqueue.test	Paciente Stress 38563307-3119	55003119	ACTIVO	2026-06-02 22:16:31.453069	2026-06-02 22:16:31.453069	0
a3805f94-08ac-4fb3-af1b-024bf74afd41	93877655800007080	stress-38776558-7080@mediqueue.test	Paciente Stress 38776558-7080	55007080	ACTIVO	2026-06-02 22:20:40.296915	2026-06-02 22:20:40.296915	0
ee6d81d3-abfd-4eb3-9105-bade60a40d41	93877655900007194	stress-38776559-7194@mediqueue.test	Paciente Stress 38776559-7194	55007194	ACTIVO	2026-06-02 22:20:41.26312	2026-06-02 22:20:41.26312	0
903f8cc5-a598-44a5-80aa-456939c85388	93877654700007366	stress-38776547-7366@mediqueue.test	Paciente Stress 38776547-7366	55007366	ACTIVO	2026-06-02 22:20:42.725294	2026-06-02 22:20:42.725294	0
28fa469d-f4f5-4f00-b5dd-587412fc3474	93877650600007659	stress-38776506-7659@mediqueue.test	Paciente Stress 38776506-7659	55007659	ACTIVO	2026-06-02 22:20:45.150965	2026-06-02 22:20:45.150965	0
1531db5a-b160-4d5f-aa9f-522e68f0427a	93877656300008169	stress-38776563-8169@mediqueue.test	Paciente Stress 38776563-8169	55008169	ACTIVO	2026-06-02 22:21:11.568217	2026-06-02 22:21:11.568217	0
a248d56b-a7e1-41eb-ac24-673f8b6436bf	93877655800008541	stress-38776558-8541@mediqueue.test	Paciente Stress 38776558-8541	55008541	ACTIVO	2026-06-02 22:21:17.106352	2026-06-02 22:21:17.106352	0
6cd734db-7ed9-4a97-ab4a-0dd75d539a1e	93877651900008676	stress-38776519-8676@mediqueue.test	Paciente Stress 38776519-8676	55008676	ACTIVO	2026-06-02 22:21:18.72656	2026-06-02 22:21:18.72656	0
6b960d3f-038c-48e0-a730-f95f46cfdf70	93877655800008809	stress-38776558-8809@mediqueue.test	Paciente Stress 38776558-8809	55008809	ACTIVO	2026-06-02 22:21:19.693135	2026-06-02 22:21:19.693135	0
f4ea8233-f94e-4dc9-b4b6-f8fddfadb3e9	93877650600009028	stress-38776506-9028@mediqueue.test	Paciente Stress 38776506-9028	55009028	ACTIVO	2026-06-02 22:21:21.472795	2026-06-02 22:21:21.472795	0
478f85e8-0ec1-4354-bcab-f197c8b34909	93877652300009160	stress-38776523-9160@mediqueue.test	Paciente Stress 38776523-9160	55009160	ACTIVO	2026-06-02 22:21:22.921257	2026-06-02 22:21:22.921257	0
a6ac8519-5a87-4fca-92f3-6de123e2dd55	93877652500009231	stress-38776525-9231@mediqueue.test	Paciente Stress 38776525-9231	55009231	ACTIVO	2026-06-02 22:21:23.700579	2026-06-02 22:21:23.700579	0
1f45929b-9a68-4cae-980b-40afd97fba78	93877654600009754	stress-38776546-9754@mediqueue.test	Paciente Stress 38776546-9754	55009754	ACTIVO	2026-06-02 22:22:07.430498	2026-06-02 22:22:07.430498	0
0d36c104-b166-4809-9f7f-49644bd4d98a	93877656200009978	stress-38776562-9978@mediqueue.test	Paciente Stress 38776562-9978	55009978	ACTIVO	2026-06-02 22:22:08.573972	2026-06-02 22:22:08.573972	0
ddfa869a-32bf-433b-af22-1dc1fb7c6e5e	93969227200000098	stress-39692272-98@mediqueue.test	Paciente Stress 39692272-98	55000098	ACTIVO	2026-06-02 22:35:00.363571	2026-06-02 22:35:00.363571	0
81b22d58-9777-413e-b50e-b60f30710d07	93969226800000278	stress-39692268-278@mediqueue.test	Paciente Stress 39692268-278	55000278	ACTIVO	2026-06-02 22:35:00.826823	2026-06-02 22:35:00.826823	0
8a3f8b81-eab8-4e5e-bf73-9d0a935881b4	93969226700000009	stress-39692267-9@mediqueue.test	Paciente Stress 39692267-9	55000009	ACTIVO	2026-06-02 22:35:01.020623	2026-06-02 22:35:01.020623	0
c524720a-8459-4b9b-9ac5-d323dd66077a	93969227200000320	stress-39692272-320@mediqueue.test	Paciente Stress 39692272-320	55000320	ACTIVO	2026-06-02 22:35:01.414137	2026-06-02 22:35:01.414137	0
522c1566-8745-4934-9dcf-d28865e3e18a	93969226300000265	stress-39692263-265@mediqueue.test	Paciente Stress 39692263-265	55000265	ACTIVO	2026-06-02 22:35:02.354529	2026-06-02 22:35:02.354529	0
0324832d-2e90-4805-97ba-e9477cf704f0	93969227500000598	stress-39692275-598@mediqueue.test	Paciente Stress 39692275-598	55000598	ACTIVO	2026-06-02 22:35:03.472927	2026-06-02 22:35:03.472927	0
55043dd9-ae17-40f6-99c9-ce7f50f00e6b	93969227100000615	stress-39692271-615@mediqueue.test	Paciente Stress 39692271-615	55000615	ACTIVO	2026-06-02 22:35:03.584454	2026-06-02 22:35:03.584454	0
a7f35615-9b6b-4651-bad9-4bccccb3ff2e	93969227900000619	stress-39692279-619@mediqueue.test	Paciente Stress 39692279-619	55000619	ACTIVO	2026-06-02 22:35:03.641172	2026-06-02 22:35:03.641172	0
ea931171-b7da-40ff-8d37-364d02250075	93969227700000645	stress-39692277-645@mediqueue.test	Paciente Stress 39692277-645	55000645	ACTIVO	2026-06-02 22:35:03.972655	2026-06-02 22:35:03.972655	0
92a2c17e-d006-424d-9045-963cd5a4b84e	93969227500000657	stress-39692275-657@mediqueue.test	Paciente Stress 39692275-657	55000657	ACTIVO	2026-06-02 22:35:04.146854	2026-06-02 22:35:04.146854	0
1ccc893a-ac27-4f4d-8d0f-ab8e801003f2	93969226500000664	stress-39692265-664@mediqueue.test	Paciente Stress 39692265-664	55000664	ACTIVO	2026-06-02 22:35:04.205967	2026-06-02 22:35:04.205967	0
df541ac7-e231-475f-9400-7d02eb54ae2a	93969227300000684	stress-39692273-684@mediqueue.test	Paciente Stress 39692273-684	55000684	ACTIVO	2026-06-02 22:35:04.415388	2026-06-02 22:35:04.415388	0
65f69862-a775-4ab1-8cf9-651543de4100	93969227800000679	stress-39692278-679@mediqueue.test	Paciente Stress 39692278-679	55000679	ACTIVO	2026-06-02 22:35:04.43871	2026-06-02 22:35:04.43871	0
e3f62b6c-5f70-41d7-be8c-90c5d01fe228	93969227800000694	stress-39692278-694@mediqueue.test	Paciente Stress 39692278-694	55000694	ACTIVO	2026-06-02 22:35:04.560776	2026-06-02 22:35:04.560776	0
8b655f1a-b1bc-4b09-86fd-e2fab5c0459d	93969227300000692	stress-39692273-692@mediqueue.test	Paciente Stress 39692273-692	55000692	ACTIVO	2026-06-02 22:35:04.605584	2026-06-02 22:35:04.605584	0
5d1c56be-eb0e-4fc7-af7d-c5fa0a541096	93969226400000703	stress-39692264-703@mediqueue.test	Paciente Stress 39692264-703	55000703	ACTIVO	2026-06-02 22:35:04.728852	2026-06-02 22:35:04.728852	0
f2b878a2-163b-450e-a91c-dad042b9fd9d	93969228000000706	stress-39692280-706@mediqueue.test	Paciente Stress 39692280-706	55000706	ACTIVO	2026-06-02 22:35:04.782517	2026-06-02 22:35:04.782517	0
d01982e6-e1c1-4a2a-9d5e-3c678bfd8dfd	93969226300000721	stress-39692263-721@mediqueue.test	Paciente Stress 39692263-721	55000721	ACTIVO	2026-06-02 22:35:05.152975	2026-06-02 22:35:05.152975	0
4776a28b-48f1-4ebe-857e-3471b056ef16	93969226400000723	stress-39692264-723@mediqueue.test	Paciente Stress 39692264-723	55000723	ACTIVO	2026-06-02 22:35:05.158973	2026-06-02 22:35:05.158973	0
b7cdee5a-a7d8-4e32-a4f4-ab87f88e7bcc	93969228000000730	stress-39692280-730@mediqueue.test	Paciente Stress 39692280-730	55000730	ACTIVO	2026-06-02 22:35:05.243967	2026-06-02 22:35:05.243967	0
0ec9bb35-47fe-4d4f-9219-9854e8882efe	93969224700000724	stress-39692247-724@mediqueue.test	Paciente Stress 39692247-724	55000724	ACTIVO	2026-06-02 22:35:05.261574	2026-06-02 22:35:05.261574	0
3c85e365-dacc-46d7-b847-d6ccebda4937	93969227300000758	stress-39692273-758@mediqueue.test	Paciente Stress 39692273-758	55000758	ACTIVO	2026-06-02 22:35:05.624782	2026-06-02 22:35:05.624782	0
83ee8604-3f7c-44d0-91c7-61008730e6e3	93969228100000802	stress-39692281-802@mediqueue.test	Paciente Stress 39692281-802	55000802	ACTIVO	2026-06-02 22:35:06.087045	2026-06-02 22:35:06.087045	0
b161b993-8e19-4fa5-9561-185d5418f6ef	93969226300000833	stress-39692263-833@mediqueue.test	Paciente Stress 39692263-833	55000833	ACTIVO	2026-06-02 22:35:06.616895	2026-06-02 22:35:06.616895	0
6e932e15-6578-4c90-b65f-aef3935755d4	93969226300000851	stress-39692263-851@mediqueue.test	Paciente Stress 39692263-851	55000851	ACTIVO	2026-06-02 22:35:06.978358	2026-06-02 22:35:06.978358	0
03e5bad2-752c-4e5f-858f-d68fac55d81c	93969227200000862	stress-39692272-862@mediqueue.test	Paciente Stress 39692272-862	55000862	ACTIVO	2026-06-02 22:35:07.124864	2026-06-02 22:35:07.124864	0
bf6a867e-425f-493e-a23d-6472a32614bc	93856330700000182	stress-38563307-182@mediqueue.test	Paciente Stress 38563307-182	55000182	ACTIVO	2026-06-02 22:16:05.398455	2026-06-02 22:16:05.398455	0
33546b81-02db-42d7-ba05-f80de28722ec	93856333600000437	stress-38563336-437@mediqueue.test	Paciente Stress 38563336-437	55000437	ACTIVO	2026-06-02 22:16:07.847402	2026-06-02 22:16:07.847402	0
1c90e351-25f3-4dd0-bd24-72246139a4fa	93856330600000503	stress-38563306-503@mediqueue.test	Paciente Stress 38563306-503	55000503	ACTIVO	2026-06-02 22:16:08.323086	2026-06-02 22:16:08.323086	0
48c85593-494f-49ca-b627-9041db8b403e	93856333400000598	stress-38563334-598@mediqueue.test	Paciente Stress 38563334-598	55000598	ACTIVO	2026-06-02 22:16:09.220161	2026-06-02 22:16:09.220161	0
4d00b6a8-40e1-4ddd-9a5e-5681d003dfff	93856330900000872	stress-38563309-872@mediqueue.test	Paciente Stress 38563309-872	55000872	ACTIVO	2026-06-02 22:16:11.923955	2026-06-02 22:16:11.923955	0
be501d94-9af6-41cc-a517-edebc7972740	93856332800000885	stress-38563328-885@mediqueue.test	Paciente Stress 38563328-885	55000885	ACTIVO	2026-06-02 22:16:12.384055	2026-06-02 22:16:12.384055	0
1512299c-d40b-49e8-8b20-e282ef5917f2	93856331300000986	stress-38563313-986@mediqueue.test	Paciente Stress 38563313-986	55000986	ACTIVO	2026-06-02 22:16:13.042889	2026-06-02 22:16:13.042889	0
ae536b3d-0b4d-4ec3-9373-7eb68eb767af	93856333500001033	stress-38563335-1033@mediqueue.test	Paciente Stress 38563335-1033	55001033	ACTIVO	2026-06-02 22:16:14.203448	2026-06-02 22:16:14.203448	0
4f63b881-abca-49cf-bccb-7a3a2f902d4b	93856333400001058	stress-38563334-1058@mediqueue.test	Paciente Stress 38563334-1058	55001058	ACTIVO	2026-06-02 22:16:14.407878	2026-06-02 22:16:14.407878	0
83eb195d-9dd8-4089-b16b-1eff5b29838b	93856333800001231	stress-38563338-1231@mediqueue.test	Paciente Stress 38563338-1231	55001231	ACTIVO	2026-06-02 22:16:15.435122	2026-06-02 22:16:15.435122	0
f58ab57b-eb09-4c59-a12c-3fa47e14f2bb	93856333300001341	stress-38563333-1341@mediqueue.test	Paciente Stress 38563333-1341	55001341	ACTIVO	2026-06-02 22:16:16.478874	2026-06-02 22:16:16.478874	0
a3083aa9-217c-4813-b6ad-1072df00a2d1	93856331600001774	stress-38563316-1774@mediqueue.test	Paciente Stress 38563316-1774	55001774	ACTIVO	2026-06-02 22:16:21.840056	2026-06-02 22:16:21.840056	0
86809a44-f5a2-45f9-a65a-4d0ce229fd50	93856331700001859	stress-38563317-1859@mediqueue.test	Paciente Stress 38563317-1859	55001859	ACTIVO	2026-06-02 22:16:22.266621	2026-06-02 22:16:22.266621	0
635c754a-1c71-4db5-9ad0-27433b59ee68	93856331300001854	stress-38563313-1854@mediqueue.test	Paciente Stress 38563313-1854	55001854	ACTIVO	2026-06-02 22:16:22.484686	2026-06-02 22:16:22.484686	0
f153b04d-fde8-443b-9e18-3494f0cc5ff4	93856332800001999	stress-38563328-1999@mediqueue.test	Paciente Stress 38563328-1999	55001999	ACTIVO	2026-06-02 22:16:22.823369	2026-06-02 22:16:22.823369	0
4e1dbb01-7b76-4c4e-a15a-6d9a7b2465d8	93856332100002103	stress-38563321-2103@mediqueue.test	Paciente Stress 38563321-2103	55002103	ACTIVO	2026-06-02 22:16:23.697701	2026-06-02 22:16:23.697701	0
63fd8096-51de-49d1-9c19-1b14511619f5	93856331600002247	stress-38563316-2247@mediqueue.test	Paciente Stress 38563316-2247	55002247	ACTIVO	2026-06-02 22:16:25.360565	2026-06-02 22:16:25.360565	0
bfdcf1c0-72b9-472f-9f2c-0687b7d240cb	93856332000002911	stress-38563320-2911@mediqueue.test	Paciente Stress 38563320-2911	55002911	ACTIVO	2026-06-02 22:16:30.077785	2026-06-02 22:16:30.077785	0
873555d0-62df-4fe8-852f-0dcf83dfa50a	93856330900002996	stress-38563309-2996@mediqueue.test	Paciente Stress 38563309-2996	55002996	ACTIVO	2026-06-02 22:16:30.577025	2026-06-02 22:16:30.577025	0
8ae59440-0cb9-468e-80d5-68185df764bf	93856333400003048	stress-38563334-3048@mediqueue.test	Paciente Stress 38563334-3048	55003048	ACTIVO	2026-06-02 22:16:30.94867	2026-06-02 22:16:30.94867	0
87f6e472-43e5-4e89-9480-c6110d19ada4	93856332200003244	stress-38563322-3244@mediqueue.test	Paciente Stress 38563322-3244	55003244	ACTIVO	2026-06-02 22:16:32.523252	2026-06-02 22:16:32.523252	0
1ea99206-19d9-4bbe-9cca-4da1126d16d6	93856332800003405	stress-38563328-3405@mediqueue.test	Paciente Stress 38563328-3405	55003405	ACTIVO	2026-06-02 22:16:33.6085	2026-06-02 22:16:33.6085	0
59ccec01-045a-44b6-915f-89c9ccb6dc1d	93856330900003431	stress-38563309-3431@mediqueue.test	Paciente Stress 38563309-3431	55003431	ACTIVO	2026-06-02 22:16:33.767727	2026-06-02 22:16:33.767727	0
a8989597-6bc4-4e3a-8c38-262df84232b7	93856331600003486	stress-38563316-3486@mediqueue.test	Paciente Stress 38563316-3486	55003486	ACTIVO	2026-06-02 22:16:34.221503	2026-06-02 22:16:34.221503	0
16a88cc6-04d2-46e3-9137-ca1e9c27e5d6	93856333600003600	stress-38563336-3600@mediqueue.test	Paciente Stress 38563336-3600	55003600	ACTIVO	2026-06-02 22:16:34.838107	2026-06-02 22:16:34.838107	0
5cc0b2c9-73be-4198-91b4-c210c3d3cf06	93856331200003810	stress-38563312-3810@mediqueue.test	Paciente Stress 38563312-3810	55003810	ACTIVO	2026-06-02 22:16:36.185889	2026-06-02 22:16:36.185889	0
5fcf551c-3c5a-43a7-a9c9-4d64d0ef6f28	93856333400003904	stress-38563334-3904@mediqueue.test	Paciente Stress 38563334-3904	55003904	ACTIVO	2026-06-02 22:16:36.791547	2026-06-02 22:16:36.791547	0
71a90727-4ed7-4089-b872-a464a3572441	93856331600004015	stress-38563316-4015@mediqueue.test	Paciente Stress 38563316-4015	55004015	ACTIVO	2026-06-02 22:16:37.800366	2026-06-02 22:16:37.800366	0
ff5045a5-e434-4305-9d09-6a36972052d2	93856331200004103	stress-38563312-4103@mediqueue.test	Paciente Stress 38563312-4103	55004103	ACTIVO	2026-06-02 22:16:38.63799	2026-06-02 22:16:38.63799	0
348f6dda-c539-4c0f-8af7-889350b280e9	93856332200004138	stress-38563322-4138@mediqueue.test	Paciente Stress 38563322-4138	55004138	ACTIVO	2026-06-02 22:16:38.999536	2026-06-02 22:16:38.999536	0
a4886b06-137b-41a6-acc2-55caac0065f5	93856330600004360	stress-38563306-4360@mediqueue.test	Paciente Stress 38563306-4360	55004360	ACTIVO	2026-06-02 22:16:41.137669	2026-06-02 22:16:41.137669	0
01e57988-6ea3-45b6-ab1a-d9424c2dd650	93856332000004390	stress-38563320-4390@mediqueue.test	Paciente Stress 38563320-4390	55004390	ACTIVO	2026-06-02 22:16:41.305344	2026-06-02 22:16:41.305344	0
c5b8044e-4452-47e0-9687-c14d8eb7ebcd	93856333400004926	stress-38563334-4926@mediqueue.test	Paciente Stress 38563334-4926	55004926	ACTIVO	2026-06-02 22:16:44.898804	2026-06-02 22:16:44.898804	0
ad2ebfc0-2df3-495f-a53e-47c96bde79e1	93877654300007214	stress-38776543-7214@mediqueue.test	Paciente Stress 38776543-7214	55007214	ACTIVO	2026-06-02 22:20:41.434464	2026-06-02 22:20:41.434464	0
50c35260-6de1-4075-b0a3-9c6ebc00b36c	93877655300007327	stress-38776553-7327@mediqueue.test	Paciente Stress 38776553-7327	55007327	ACTIVO	2026-06-02 22:20:42.434625	2026-06-02 22:20:42.434625	0
663e49ed-c1ee-4f1a-9351-7a0eae6844dd	93877652300007410	stress-38776523-7410@mediqueue.test	Paciente Stress 38776523-7410	55007410	ACTIVO	2026-06-02 22:20:43.079746	2026-06-02 22:20:43.079746	0
28963cba-2d70-438e-adda-9af2727bd32d	93877654300007459	stress-38776543-7459@mediqueue.test	Paciente Stress 38776543-7459	55007459	ACTIVO	2026-06-02 22:20:43.576028	2026-06-02 22:20:43.576028	0
7fc190b0-f0ce-4dfe-b944-65e4cd806464	93877650600008451	stress-38776506-8451@mediqueue.test	Paciente Stress 38776506-8451	55008451	ACTIVO	2026-06-02 22:21:16.19902	2026-06-02 22:21:16.19902	0
424ccb2f-37dd-4e50-af57-029327995d9d	93877654300008680	stress-38776543-8680@mediqueue.test	Paciente Stress 38776543-8680	55008680	ACTIVO	2026-06-02 22:21:18.788204	2026-06-02 22:21:18.788204	0
2e6d4ee6-03dd-4cde-b21d-49a2902ba981	93877656300009016	stress-38776563-9016@mediqueue.test	Paciente Stress 38776563-9016	55009016	ACTIVO	2026-06-02 22:21:21.412734	2026-06-02 22:21:21.412734	0
f5d5974a-f57a-4b79-9ac3-bc9a09ca2b56	93877655000009122	stress-38776550-9122@mediqueue.test	Paciente Stress 38776550-9122	55009122	ACTIVO	2026-06-02 22:21:22.512782	2026-06-02 22:21:22.512782	0
5d71c30a-9b72-4eab-b8e4-b37ec3175407	93877653400009259	stress-38776534-9259@mediqueue.test	Paciente Stress 38776534-9259	55009259	ACTIVO	2026-06-02 22:21:24.248042	2026-06-02 22:21:24.248042	0
399b517f-c713-4e37-a570-c409599ed3b4	93877656400009352	stress-38776564-9352@mediqueue.test	Paciente Stress 38776564-9352	55009352	ACTIVO	2026-06-02 22:21:25.528169	2026-06-02 22:21:25.528169	0
0f15e06e-4907-4179-ac60-aa06183c56d8	93877653700009469	stress-38776537-9469@mediqueue.test	Paciente Stress 38776537-9469	55009469	ACTIVO	2026-06-02 22:21:26.861492	2026-06-02 22:21:26.861492	0
dfb6f245-69be-475d-ae74-219335fd72fa	93969226300000126	stress-39692263-126@mediqueue.test	Paciente Stress 39692263-126	55000126	ACTIVO	2026-06-02 22:35:00.366535	2026-06-02 22:35:00.366535	0
315fe003-749f-4d78-8618-a6335ae1a809	93969225700000349	stress-39692257-349@mediqueue.test	Paciente Stress 39692257-349	55000349	ACTIVO	2026-06-02 22:35:01.415724	2026-06-02 22:35:01.415724	0
4fe357d2-071a-49a9-9ea7-d18bd23d228d	93969227800000508	stress-39692278-508@mediqueue.test	Paciente Stress 39692278-508	55000508	ACTIVO	2026-06-02 22:35:02.627149	2026-06-02 22:35:02.627149	0
66fc927a-58d8-4eec-b64d-4d69206fe794	93778434000001064	stress-37784340-1064@mediqueue.test	Paciente Stress 37784340-1064	55001064	ACTIVO	2026-06-02 22:03:28.484036	2026-06-02 22:03:28.484036	0
47754249-4465-47f9-8e32-238af58be6c6	93778429900001203	stress-37784299-1203@mediqueue.test	Paciente Stress 37784299-1203	55001203	ACTIVO	2026-06-02 22:03:29.772362	2026-06-02 22:03:29.772362	0
ffec004f-5e88-45a5-b296-504279953061	93778431600001320	stress-37784316-1320@mediqueue.test	Paciente Stress 37784316-1320	55001320	ACTIVO	2026-06-02 22:03:31.058479	2026-06-02 22:03:31.058479	0
78d2c848-0b1c-48b6-9d81-fa8ae87483bf	93778434100001694	stress-37784341-1694@mediqueue.test	Paciente Stress 37784341-1694	55001694	ACTIVO	2026-06-02 22:03:39.213232	2026-06-02 22:03:39.213232	0
e51b29df-e7c0-421d-9e7c-fe645d87c4d4	93778434300002071	stress-37784343-2071@mediqueue.test	Paciente Stress 37784343-2071	55002071	ACTIVO	2026-06-02 22:03:43.129854	2026-06-02 22:03:43.129854	0
f1aa452c-86f0-43d6-ad81-d80c58cb1a65	93979298000000238	stress-39792980-238@mediqueue.test	Paciente Stress 39792980-238	55000238	ACTIVO	2026-06-02 22:36:36.606709	2026-06-02 22:36:36.606709	0
91d89ee1-22db-40ac-bfa5-b422d821fb6e	93979306000000486	stress-39793060-486@mediqueue.test	Paciente Stress 39793060-486	55000486	ACTIVO	2026-06-02 22:36:37.540378	2026-06-02 22:36:37.540378	0
6dd47c84-6330-4ce7-9915-b53e7764a8a0	93979296900000466	stress-39792969-466@mediqueue.test	Paciente Stress 39792969-466	55000466	ACTIVO	2026-06-02 22:36:37.885904	2026-06-02 22:36:37.885904	0
05763747-a306-48fd-ac7f-bf4d9a384577	93979300500000699	stress-39793005-699@mediqueue.test	Paciente Stress 39793005-699	55000699	ACTIVO	2026-06-02 22:36:39.445998	2026-06-02 22:36:39.445998	0
c0691200-1c28-4e3f-ac21-286133db8610	93979297400002254	stress-39792974-2254@mediqueue.test	Paciente Stress 39792974-2254	55002254	ACTIVO	2026-06-02 22:36:54.000145	2026-06-02 22:36:54.000145	0
11b067c2-4749-42f1-9edc-eddf414a266c	93979296300002503	stress-39792963-2503@mediqueue.test	Paciente Stress 39792963-2503	55002503	ACTIVO	2026-06-02 22:36:56.399161	2026-06-02 22:36:56.399161	0
f053896b-a920-44c3-b689-283f68381509	93979299900002881	stress-39792999-2881@mediqueue.test	Paciente Stress 39792999-2881	55002881	ACTIVO	2026-06-02 22:37:08.880601	2026-06-02 22:37:08.880601	0
eec0ab88-284e-45eb-aef1-848744ee5644	93979305900003461	stress-39793059-3461@mediqueue.test	Paciente Stress 39793059-3461	55003461	ACTIVO	2026-06-02 22:37:13.711058	2026-06-02 22:37:13.711058	0
ae86c3b3-19d2-4770-b2ab-c7c0c942f775	93979298400003614	stress-39792984-3614@mediqueue.test	Paciente Stress 39792984-3614	55003614	ACTIVO	2026-06-02 22:37:15.00247	2026-06-02 22:37:15.00247	0
a23d31b6-f98d-4619-9a2c-886c5e48e55e	93979304200004000	stress-39793042-4000@mediqueue.test	Paciente Stress 39793042-4000	55004000	ACTIVO	2026-06-02 22:37:18.282666	2026-06-02 22:37:18.282666	0
9c5c358e-add8-4eae-a356-e4bb50effe76	93979300200004045	stress-39793002-4045@mediqueue.test	Paciente Stress 39793002-4045	55004045	ACTIVO	2026-06-02 22:37:18.603322	2026-06-02 22:37:18.603322	0
94d661d4-2eef-4649-b7d5-5be8059d08b3	93979300600004141	stress-39793006-4141@mediqueue.test	Paciente Stress 39793006-4141	55004141	ACTIVO	2026-06-02 22:37:19.154206	2026-06-02 22:37:19.154206	0
e8b40f36-87d8-4448-b287-7e4accd2582d	94045695300007442	stress-40456953-7442@mediqueue.test	Paciente Stress 40456953-7442	55007442	ACTIVO	2026-06-02 22:48:48.8429	2026-06-02 22:48:48.8429	0
f16e9616-92d4-4ef6-9113-be61988852c1	94045691800007661	stress-40456918-7661@mediqueue.test	Paciente Stress 40456918-7661	55007661	ACTIVO	2026-06-02 22:49:26.25423	2026-06-02 22:49:26.25423	0
149bd671-7c17-4b1a-976e-9ed4306257c4	94045694300007703	stress-40456943-7703@mediqueue.test	Paciente Stress 40456943-7703	55007703	ACTIVO	2026-06-02 22:49:27.717469	2026-06-02 22:49:27.717469	0
5c28b5fa-0064-433b-bb0b-c34bef65269d	94045694600007695	stress-40456946-7695@mediqueue.test	Paciente Stress 40456946-7695	55007695	ACTIVO	2026-06-02 22:49:28.046877	2026-06-02 22:49:28.046877	0
c764100b-469c-4918-9f7f-93eb45ba3853	94045695900007909	stress-40456959-7909@mediqueue.test	Paciente Stress 40456959-7909	55007909	ACTIVO	2026-06-02 22:49:29.525553	2026-06-02 22:49:29.525553	0
d9224e0d-6279-43e6-94b4-f6daf94c9a55	94045695800007862	stress-40456958-7862@mediqueue.test	Paciente Stress 40456958-7862	55007862	ACTIVO	2026-06-02 22:49:30.087585	2026-06-02 22:49:30.087585	0
0ab336a6-abbf-4e92-8ebd-cc5a9c76373b	94045693000008349	stress-40456930-8349@mediqueue.test	Paciente Stress 40456930-8349	55008349	ACTIVO	2026-06-02 22:49:32.518495	2026-06-02 22:49:32.518495	0
948143b3-fbd2-4eac-acdc-9f0c9f5397b7	94045695300009328	stress-40456953-9328@mediqueue.test	Paciente Stress 40456953-9328	55009328	ACTIVO	2026-06-02 22:49:41.586353	2026-06-02 22:49:41.586353	0
68232a0a-7aea-4a49-9b56-a2362bea8c50	94045692200009405	stress-40456922-9405@mediqueue.test	Paciente Stress 40456922-9405	55009405	ACTIVO	2026-06-02 22:49:42.629567	2026-06-02 22:49:42.629567	0
4aa894fd-cec7-4eef-9a24-7ba80c4e60eb	94045694900009670	stress-40456949-9670@mediqueue.test	Paciente Stress 40456949-9670	55009670	ACTIVO	2026-06-02 22:49:45.050243	2026-06-02 22:49:45.050243	0
6de8c79a-e49e-4a3d-b5d9-14861ebd2b46	94045695700009731	stress-40456957-9731@mediqueue.test	Paciente Stress 40456957-9731	55009731	ACTIVO	2026-06-02 22:51:03.110306	2026-06-02 22:51:03.110306	0
cda80709-64be-40f5-9807-0218f80d0c0e	94045696100009841	stress-40456961-9841@mediqueue.test	Paciente Stress 40456961-9841	55009841	ACTIVO	2026-06-02 22:51:05.947806	2026-06-02 22:51:05.947806	0
73921a0c-9310-4ce5-a864-4606bb8c4fad	94070642300000028	stress-40706423-28@mediqueue.test	Paciente Stress 40706423-28	55000028	ACTIVO	2026-06-02 22:51:49.69267	2026-06-02 22:51:49.69267	0
de779131-d876-4838-b7e7-22cadd1c2f54	94070644200000144	stress-40706442-144@mediqueue.test	Paciente Stress 40706442-144	55000144	ACTIVO	2026-06-02 22:51:52.343393	2026-06-02 22:51:52.343393	0
cb608519-eb41-415a-8062-352dc316cfde	94070647200000423	stress-40706472-423@mediqueue.test	Paciente Stress 40706472-423	55000423	ACTIVO	2026-06-02 22:51:52.594784	2026-06-02 22:51:52.594784	0
fb987959-811b-4616-a6d9-9cbe5621d8a7	94070642400000714	stress-40706424-714@mediqueue.test	Paciente Stress 40706424-714	55000714	ACTIVO	2026-06-02 22:51:53.39852	2026-06-02 22:51:53.39852	0
414f21c6-0b8d-4195-bd14-9b58f6507b86	94070641700000744	stress-40706417-744@mediqueue.test	Paciente Stress 40706417-744	55000744	ACTIVO	2026-06-02 22:51:53.637781	2026-06-02 22:51:53.637781	0
82ebfd7a-a01e-4ea9-bb31-c90c1c46bf0a	94070642400000869	stress-40706424-869@mediqueue.test	Paciente Stress 40706424-869	55000869	ACTIVO	2026-06-02 22:51:55.036952	2026-06-02 22:51:55.036952	0
c56cea65-e1db-4b21-9a40-7ae2474aae44	94070648300001535	stress-40706483-1535@mediqueue.test	Paciente Stress 40706483-1535	55001535	ACTIVO	2026-06-02 22:52:01.845033	2026-06-02 22:52:01.845033	0
199de974-bb8a-4bd6-ae04-1a454afc1166	94070646300001609	stress-40706463-1609@mediqueue.test	Paciente Stress 40706463-1609	55001609	ACTIVO	2026-06-02 22:52:02.367626	2026-06-02 22:52:02.367626	0
cd942bba-dae4-4fd5-81f4-12e29833c2bb	94070643000001769	stress-40706430-1769@mediqueue.test	Paciente Stress 40706430-1769	55001769	ACTIVO	2026-06-02 22:52:04.078678	2026-06-02 22:52:04.078678	0
4890c3d8-3046-4797-adcb-44de84b2a7cf	94070649200001982	stress-40706492-1982@mediqueue.test	Paciente Stress 40706492-1982	55001982	ACTIVO	2026-06-02 22:53:13.94839	2026-06-02 22:53:13.94839	0
dceab5c6-dfa9-474a-bc41-35278882c0d9	94070642400002383	stress-40706424-2383@mediqueue.test	Paciente Stress 40706424-2383	55002383	ACTIVO	2026-06-02 22:53:15.856287	2026-06-02 22:53:15.856287	0
55e5b3c6-541f-4d02-9752-5bb6e1628408	94070642600002216	stress-40706426-2216@mediqueue.test	Paciente Stress 40706426-2216	55002216	ACTIVO	2026-06-02 22:53:16.321161	2026-06-02 22:53:16.321161	0
177de413-e2c7-4204-9052-20a82de02c1b	94070643700002447	stress-40706437-2447@mediqueue.test	Paciente Stress 40706437-2447	55002447	ACTIVO	2026-06-02 22:53:16.969326	2026-06-02 22:53:16.969326	0
e9cb3cb9-73ff-48f2-887c-f799e69840e0	94070649000002560	stress-40706490-2560@mediqueue.test	Paciente Stress 40706490-2560	55002560	ACTIVO	2026-06-02 22:53:17.75323	2026-06-02 22:53:17.75323	0
eb33e324-3332-4710-b471-2263d5aa6f3f	94070643000002590	stress-40706430-2590@mediqueue.test	Paciente Stress 40706430-2590	55002590	ACTIVO	2026-06-02 22:53:18.055473	2026-06-02 22:53:18.055473	0
42e18a95-1e24-4d3b-9032-186bbcc33b4f	94070642500002991	stress-40706425-2991@mediqueue.test	Paciente Stress 40706425-2991	55002991	ACTIVO	2026-06-02 22:53:21.390949	2026-06-02 22:53:21.390949	0
6830939e-46d1-45d4-9768-c6107e364d37	94070646000003285	stress-40706460-3285@mediqueue.test	Paciente Stress 40706460-3285	55003285	ACTIVO	2026-06-02 22:53:24.59233	2026-06-02 22:53:24.59233	0
39f5e09c-6a30-482c-b799-e7da78d54612	94070643400003449	stress-40706434-3449@mediqueue.test	Paciente Stress 40706434-3449	55003449	ACTIVO	2026-06-02 22:53:26.009097	2026-06-02 22:53:26.009097	0
28ff2bf2-6517-4515-9c9e-0fd9084358d4	93969227800000888	stress-39692278-888@mediqueue.test	Paciente Stress 39692278-888	55000888	ACTIVO	2026-06-02 22:35:07.431038	2026-06-02 22:35:07.431038	0
3d8a6390-802d-430b-bd7c-166b309a581e	93969227900001258	stress-39692279-1258@mediqueue.test	Paciente Stress 39692279-1258	55001258	ACTIVO	2026-06-02 22:35:10.923793	2026-06-02 22:35:10.923793	0
90ce4bd5-c396-4b94-839e-128d87f9ce03	93969226300001451	stress-39692263-1451@mediqueue.test	Paciente Stress 39692263-1451	55001451	ACTIVO	2026-06-02 22:35:12.882653	2026-06-02 22:35:12.882653	0
afe7ea3f-4e0b-46ce-bbcb-40531d75beb3	93969226000001605	stress-39692260-1605@mediqueue.test	Paciente Stress 39692260-1605	55001605	ACTIVO	2026-06-02 22:35:14.151192	2026-06-02 22:35:14.151192	0
ba472dee-b4d8-4617-a5ce-215958e7566e	93969227700001652	stress-39692277-1652@mediqueue.test	Paciente Stress 39692277-1652	55001652	ACTIVO	2026-06-02 22:35:14.479137	2026-06-02 22:35:14.479137	0
f9849a7a-0cb1-4de6-a6ff-db7b207d3abc	93969226300002238	stress-39692263-2238@mediqueue.test	Paciente Stress 39692263-2238	55002238	ACTIVO	2026-06-02 22:35:20.293736	2026-06-02 22:35:20.293736	0
e718f12b-4c2d-4f63-88f9-4654641f3ebe	93969225700002788	stress-39692257-2788@mediqueue.test	Paciente Stress 39692257-2788	55002788	ACTIVO	2026-06-02 22:35:25.320897	2026-06-02 22:35:25.320897	0
1245ddb7-1ed5-4c73-a1fb-224ad0ce7e01	93969227800003068	stress-39692278-3068@mediqueue.test	Paciente Stress 39692278-3068	55003068	ACTIVO	2026-06-02 22:35:27.752625	2026-06-02 22:35:27.752625	0
25fa95c0-c7e9-4206-b208-b29606857dc0	93969226900003099	stress-39692269-3099@mediqueue.test	Paciente Stress 39692269-3099	55003099	ACTIVO	2026-06-02 22:35:28.171934	2026-06-02 22:35:28.171934	0
e234bdd5-2e82-4c55-b8f3-c8caab15eb01	93969226800003136	stress-39692268-3136@mediqueue.test	Paciente Stress 39692268-3136	55003136	ACTIVO	2026-06-02 22:35:28.496285	2026-06-02 22:35:28.496285	0
572318e6-abcf-4175-b5db-7a5550cf64a2	93969225300003302	stress-39692253-3302@mediqueue.test	Paciente Stress 39692253-3302	55003302	ACTIVO	2026-06-02 22:35:29.932033	2026-06-02 22:35:29.932033	0
f5b15c1f-5cf2-4e10-b4a2-f6fa978fc28b	93969226300003318	stress-39692263-3318@mediqueue.test	Paciente Stress 39692263-3318	55003318	ACTIVO	2026-06-02 22:35:30.093869	2026-06-02 22:35:30.093869	0
c170a374-636e-43bc-bcda-a3c285407c53	93969225400003448	stress-39692254-3448@mediqueue.test	Paciente Stress 39692254-3448	55003448	ACTIVO	2026-06-02 22:35:31.508789	2026-06-02 22:35:31.508789	0
74f1838e-6ee9-45cd-8d2d-44d64643c316	93969225200003620	stress-39692252-3620@mediqueue.test	Paciente Stress 39692252-3620	55003620	ACTIVO	2026-06-02 22:35:32.91331	2026-06-02 22:35:32.91331	0
717e7d24-0c4d-4eb8-b69c-b96020f3f69c	93969226300003657	stress-39692263-3657@mediqueue.test	Paciente Stress 39692263-3657	55003657	ACTIVO	2026-06-02 22:35:33.268078	2026-06-02 22:35:33.268078	0
5450a1ed-2b3f-4aae-a634-c595f80a08ec	93969226500003769	stress-39692265-3769@mediqueue.test	Paciente Stress 39692265-3769	55003769	ACTIVO	2026-06-02 22:35:34.332058	2026-06-02 22:35:34.332058	0
5430a0bd-9eac-41e5-b0c2-c3baa687d215	93969227400004490	stress-39692274-4490@mediqueue.test	Paciente Stress 39692274-4490	55004490	ACTIVO	2026-06-02 22:35:39.907444	2026-06-02 22:35:39.907444	0
93d7a4a5-8bc9-41dd-b895-b095dadc0ac9	93979300400000330	stress-39793004-330@mediqueue.test	Paciente Stress 39793004-330	55000330	ACTIVO	2026-06-02 22:36:36.918545	2026-06-02 22:36:36.918545	0
2dbaad50-264c-4bce-9fe5-06ca1473d96f	93979304300000585	stress-39793043-585@mediqueue.test	Paciente Stress 39793043-585	55000585	ACTIVO	2026-06-02 22:36:38.238604	2026-06-02 22:36:38.238604	0
f4ebb55e-8fd2-4a44-8448-f0cd00d99459	93979297900000673	stress-39792979-673@mediqueue.test	Paciente Stress 39792979-673	55000673	ACTIVO	2026-06-02 22:36:38.853024	2026-06-02 22:36:38.853024	0
546193af-f95d-4e12-84ac-a3b0a9d06b27	93979295800000786	stress-39792958-786@mediqueue.test	Paciente Stress 39792958-786	55000786	ACTIVO	2026-06-02 22:36:39.782112	2026-06-02 22:36:39.782112	0
0ab62406-c297-41c1-be4b-c41f17afd64d	93979300400001141	stress-39793004-1141@mediqueue.test	Paciente Stress 39793004-1141	55001141	ACTIVO	2026-06-02 22:36:43.169868	2026-06-02 22:36:43.169868	0
2803e454-2ed5-49eb-936b-3dce37e052fc	93979304000001203	stress-39793040-1203@mediqueue.test	Paciente Stress 39793040-1203	55001203	ACTIVO	2026-06-02 22:36:43.825915	2026-06-02 22:36:43.825915	0
46ae8a59-4a2c-4b4b-a23c-19f00184d4eb	93979306100001382	stress-39793061-1382@mediqueue.test	Paciente Stress 39793061-1382	55001382	ACTIVO	2026-06-02 22:36:45.722637	2026-06-02 22:36:45.722637	0
d1c3f536-6f39-496d-957b-1e019b8a5424	93979302900001552	stress-39793029-1552@mediqueue.test	Paciente Stress 39793029-1552	55001552	ACTIVO	2026-06-02 22:36:47.95924	2026-06-02 22:36:47.95924	0
84a95220-2ff3-4364-845f-43beb1bfa829	93979300100001905	stress-39793001-1905@mediqueue.test	Paciente Stress 39793001-1905	55001905	ACTIVO	2026-06-02 22:36:51.376897	2026-06-02 22:36:51.376897	0
2364f322-2683-4173-afd8-129f45939466	93979299400002470	stress-39792994-2470@mediqueue.test	Paciente Stress 39792994-2470	55002470	ACTIVO	2026-06-02 22:36:56.190143	2026-06-02 22:36:56.190143	0
cd435759-5dc1-44cf-a584-9957749c8bb9	94045691300007445	stress-40456913-7445@mediqueue.test	Paciente Stress 40456913-7445	55007445	ACTIVO	2026-06-02 22:48:48.894403	2026-06-02 22:48:48.894403	0
8ccd379a-3f72-44d7-941d-7931c8e77c4b	94045693100007512	stress-40456931-7512@mediqueue.test	Paciente Stress 40456931-7512	55007512	ACTIVO	2026-06-02 22:48:49.420048	2026-06-02 22:48:49.420048	0
b57d1c8a-dab7-4d21-8c61-37fe32dd0560	94045695600007530	stress-40456956-7530@mediqueue.test	Paciente Stress 40456956-7530	55007530	ACTIVO	2026-06-02 22:48:49.568593	2026-06-02 22:48:49.568593	0
d59130e8-7454-4d6c-bd5d-330946532ea8	94045694900007576	stress-40456949-7576@mediqueue.test	Paciente Stress 40456949-7576	55007576	ACTIVO	2026-06-02 22:48:50.143702	2026-06-02 22:48:50.143702	0
9297e79e-8dbb-4fcb-a38a-f61a7b642754	94045692100007665	stress-40456921-7665@mediqueue.test	Paciente Stress 40456921-7665	55007665	ACTIVO	2026-06-02 22:49:26.528471	2026-06-02 22:49:26.528471	0
19b6bb4c-f3db-4f13-87f2-40d2dd592946	94045692900007801	stress-40456929-7801@mediqueue.test	Paciente Stress 40456929-7801	55007801	ACTIVO	2026-06-02 22:49:27.15204	2026-06-02 22:49:27.15204	0
091674e3-5eda-4a74-bb7d-3b6b029d4e36	94045692700008023	stress-40456927-8023@mediqueue.test	Paciente Stress 40456927-8023	55008023	ACTIVO	2026-06-02 22:49:30.277127	2026-06-02 22:49:30.277127	0
c5f1c275-e44f-4b78-98e5-4a18a63aa934	94045693600007943	stress-40456936-7943@mediqueue.test	Paciente Stress 40456936-7943	55007943	ACTIVO	2026-06-02 22:49:30.341895	2026-06-02 22:49:30.341895	0
c4e98111-6b1d-4b8c-92bf-e0f605c52133	94045696300007809	stress-40456963-7809@mediqueue.test	Paciente Stress 40456963-7809	55007809	ACTIVO	2026-06-02 22:49:30.430542	2026-06-02 22:49:30.430542	0
1c4d131e-6bbb-4d7d-a5b8-70ebd2838b6c	94045694200008045	stress-40456942-8045@mediqueue.test	Paciente Stress 40456942-8045	55008045	ACTIVO	2026-06-02 22:49:30.545922	2026-06-02 22:49:30.545922	0
0d97bf28-698f-4bdd-b33f-fc5a8fcfd3b8	94045695600008127	stress-40456956-8127@mediqueue.test	Paciente Stress 40456956-8127	55008127	ACTIVO	2026-06-02 22:49:30.682269	2026-06-02 22:49:30.682269	0
9f30f9ac-e3b0-4ee9-9e1f-4b4cf4f251d9	94045691800008092	stress-40456918-8092@mediqueue.test	Paciente Stress 40456918-8092	55008092	ACTIVO	2026-06-02 22:49:31.108468	2026-06-02 22:49:31.108468	0
3fd769d1-9170-4843-a80f-8e8c23ad0b15	94045696300008209	stress-40456963-8209@mediqueue.test	Paciente Stress 40456963-8209	55008209	ACTIVO	2026-06-02 22:49:31.214379	2026-06-02 22:49:31.214379	0
976b9ebd-ede7-4f46-a602-63974a3b5523	94045691500008459	stress-40456915-8459@mediqueue.test	Paciente Stress 40456915-8459	55008459	ACTIVO	2026-06-02 22:49:33.558	2026-06-02 22:49:33.558	0
9ef5cf2f-de67-42d9-8d42-2aa18bc0c674	94045691300008609	stress-40456913-8609@mediqueue.test	Paciente Stress 40456913-8609	55008609	ACTIVO	2026-06-02 22:49:35.098678	2026-06-02 22:49:35.098678	0
df83b818-b76f-4c65-9274-56235e957060	94045692800008773	stress-40456928-8773@mediqueue.test	Paciente Stress 40456928-8773	55008773	ACTIVO	2026-06-02 22:49:36.50243	2026-06-02 22:49:36.50243	0
bcf5707b-0a07-45a6-af76-839497666f23	94045694300008807	stress-40456943-8807@mediqueue.test	Paciente Stress 40456943-8807	55008807	ACTIVO	2026-06-02 22:49:36.811813	2026-06-02 22:49:36.811813	0
dc2573b8-879b-4a57-a1f9-c7dd123dbffe	94045695300008937	stress-40456953-8937@mediqueue.test	Paciente Stress 40456953-8937	55008937	ACTIVO	2026-06-02 22:49:38.050426	2026-06-02 22:49:38.050426	0
5fe5eb28-934c-4b99-9954-2e977cf50033	94045696600009089	stress-40456966-9089@mediqueue.test	Paciente Stress 40456966-9089	55009089	ACTIVO	2026-06-02 22:49:39.332912	2026-06-02 22:49:39.332912	0
9dda7512-448f-4a17-896f-6bdc32e06f88	94045691200009147	stress-40456912-9147@mediqueue.test	Paciente Stress 40456912-9147	55009147	ACTIVO	2026-06-02 22:49:39.920942	2026-06-02 22:49:39.920942	0
7f9b7ff0-7878-4d74-920b-5988c70f5b2b	93969226300000901	stress-39692263-901@mediqueue.test	Paciente Stress 39692263-901	55000901	ACTIVO	2026-06-02 22:35:07.475893	2026-06-02 22:35:07.475893	0
e88db56c-d3e4-438c-ab98-c936a733c52c	93969226200001228	stress-39692262-1228@mediqueue.test	Paciente Stress 39692262-1228	55001228	ACTIVO	2026-06-02 22:35:10.632977	2026-06-02 22:35:10.632977	0
213723c2-2c83-4e31-aacb-2b477ba1d2eb	93969227300001736	stress-39692273-1736@mediqueue.test	Paciente Stress 39692273-1736	55001736	ACTIVO	2026-06-02 22:35:15.296891	2026-06-02 22:35:15.296891	0
4d068614-ed58-4f8b-be96-73ece63616ef	93969226300001757	stress-39692263-1757@mediqueue.test	Paciente Stress 39692263-1757	55001757	ACTIVO	2026-06-02 22:35:15.498112	2026-06-02 22:35:15.498112	0
5d114cd3-fc09-4a3f-878d-9918a0ec7fa0	93969227100002134	stress-39692271-2134@mediqueue.test	Paciente Stress 39692271-2134	55002134	ACTIVO	2026-06-02 22:35:19.28853	2026-06-02 22:35:19.28853	0
dae8b0ba-7f66-41ba-b4ce-0012b6a84317	93969225000002481	stress-39692250-2481@mediqueue.test	Paciente Stress 39692250-2481	55002481	ACTIVO	2026-06-02 22:35:22.507697	2026-06-02 22:35:22.507697	0
73f520f5-1fff-476e-b817-1e79923cf8c7	93969227300002923	stress-39692273-2923@mediqueue.test	Paciente Stress 39692273-2923	55002923	ACTIVO	2026-06-02 22:35:26.582487	2026-06-02 22:35:26.582487	0
3b6942d2-bf15-4467-8ada-b9a742e9e5f0	93969224700003097	stress-39692247-3097@mediqueue.test	Paciente Stress 39692247-3097	55003097	ACTIVO	2026-06-02 22:35:28.180296	2026-06-02 22:35:28.180296	0
0c90503e-4d0e-4f7b-a20f-65607dc8878e	93969226900003217	stress-39692269-3217@mediqueue.test	Paciente Stress 39692269-3217	55003217	ACTIVO	2026-06-02 22:35:29.26407	2026-06-02 22:35:29.26407	0
455db850-96b5-4200-84ee-69f56a3344a4	93969228100003486	stress-39692281-3486@mediqueue.test	Paciente Stress 39692281-3486	55003486	ACTIVO	2026-06-02 22:35:31.732247	2026-06-02 22:35:31.732247	0
5fc90813-ef0b-4bfd-a946-06e4ba9d74b5	93969228000004014	stress-39692280-4014@mediqueue.test	Paciente Stress 39692280-4014	55004014	ACTIVO	2026-06-02 22:35:36.237871	2026-06-02 22:35:36.237871	0
68109857-3093-4410-8c7a-f5e1541c3413	93969227900004052	stress-39692279-4052@mediqueue.test	Paciente Stress 39692279-4052	55004052	ACTIVO	2026-06-02 22:35:36.557066	2026-06-02 22:35:36.557066	0
4998ace5-4dbc-4aab-8c23-8a7262e70780	93969227200004343	stress-39692272-4343@mediqueue.test	Paciente Stress 39692272-4343	55004343	ACTIVO	2026-06-02 22:35:38.732049	2026-06-02 22:35:38.732049	0
b86a058a-0b0c-4a47-bea6-e6db915a9cc3	93969226400004501	stress-39692264-4501@mediqueue.test	Paciente Stress 39692264-4501	55004501	ACTIVO	2026-06-02 22:35:40.000597	2026-06-02 22:35:40.000597	0
694c1f79-f2fc-4739-85c2-cd944da3dc56	93969226900004781	stress-39692269-4781@mediqueue.test	Paciente Stress 39692269-4781	55004781	ACTIVO	2026-06-02 22:35:42.440025	2026-06-02 22:35:42.440025	0
40c5240a-e807-4d91-a2df-54cd3b43610b	93979297900000583	stress-39792979-583@mediqueue.test	Paciente Stress 39792979-583	55000583	ACTIVO	2026-06-02 22:36:38.062872	2026-06-02 22:36:38.062872	0
89049f05-7898-4002-947f-fd8d57d86959	93979298600000653	stress-39792986-653@mediqueue.test	Paciente Stress 39792986-653	55000653	ACTIVO	2026-06-02 22:36:38.801499	2026-06-02 22:36:38.801499	0
3643f455-32cd-4cc0-b830-9815f7f5ec96	93979295900000780	stress-39792959-780@mediqueue.test	Paciente Stress 39792959-780	55000780	ACTIVO	2026-06-02 22:36:39.728307	2026-06-02 22:36:39.728307	0
21eb7ffe-d0e8-4753-b1ea-e18b5e7296e2	93979295900000877	stress-39792959-877@mediqueue.test	Paciente Stress 39792959-877	55000877	ACTIVO	2026-06-02 22:36:40.892615	2026-06-02 22:36:40.892615	0
b60e6c90-5d68-4249-bbb5-3dcc9f86d465	93979302900001225	stress-39793029-1225@mediqueue.test	Paciente Stress 39793029-1225	55001225	ACTIVO	2026-06-02 22:36:44.044027	2026-06-02 22:36:44.044027	0
2cf9fbd3-e931-49bd-bc9c-a1394c48475e	93979305600001422	stress-39793056-1422@mediqueue.test	Paciente Stress 39793056-1422	55001422	ACTIVO	2026-06-02 22:36:46.355118	2026-06-02 22:36:46.355118	0
4c9ae394-e946-45e1-af10-aeaa33293391	93979294900001467	stress-39792949-1467@mediqueue.test	Paciente Stress 39792949-1467	55001467	ACTIVO	2026-06-02 22:36:46.747706	2026-06-02 22:36:46.747706	0
d689413e-aba7-44f2-9e5b-ca42f52f6304	93979302600001504	stress-39793026-1504@mediqueue.test	Paciente Stress 39793026-1504	55001504	ACTIVO	2026-06-02 22:36:47.161003	2026-06-02 22:36:47.161003	0
fe531825-4888-4b12-a4e8-bd76481b1f23	93979298400001569	stress-39792984-1569@mediqueue.test	Paciente Stress 39792984-1569	55001569	ACTIVO	2026-06-02 22:36:48.212718	2026-06-02 22:36:48.212718	0
0211e78e-ad30-43f0-8431-41052afed05c	93979298000001643	stress-39792980-1643@mediqueue.test	Paciente Stress 39792980-1643	55001643	ACTIVO	2026-06-02 22:36:49.048212	2026-06-02 22:36:49.048212	0
c1836099-002c-4bcd-89f6-e4c39b42488d	93979302600001718	stress-39793026-1718@mediqueue.test	Paciente Stress 39793026-1718	55001718	ACTIVO	2026-06-02 22:36:49.638465	2026-06-02 22:36:49.638465	0
69801750-8564-40ef-b8db-6a2d8188bd5d	93979298900001862	stress-39792989-1862@mediqueue.test	Paciente Stress 39792989-1862	55001862	ACTIVO	2026-06-02 22:36:50.927469	2026-06-02 22:36:50.927469	0
b6e488a4-e619-4bef-942e-0b96b6faf11b	93979303000002120	stress-39793030-2120@mediqueue.test	Paciente Stress 39793030-2120	55002120	ACTIVO	2026-06-02 22:36:53.01298	2026-06-02 22:36:53.01298	0
63a23412-b5a5-4a67-b589-290dddf60f1d	93979300100002314	stress-39793001-2314@mediqueue.test	Paciente Stress 39793001-2314	55002314	ACTIVO	2026-06-02 22:36:54.712481	2026-06-02 22:36:54.712481	0
e3a87e58-2f74-4d60-831e-65b97d76bff7	93979297700002372	stress-39792977-2372@mediqueue.test	Paciente Stress 39792977-2372	55002372	ACTIVO	2026-06-02 22:36:55.225191	2026-06-02 22:36:55.225191	0
3ed4ed93-56e9-48af-8605-2e6398da8a38	93979297900002413	stress-39792979-2413@mediqueue.test	Paciente Stress 39792979-2413	55002413	ACTIVO	2026-06-02 22:36:55.472553	2026-06-02 22:36:55.472553	0
d13f3d12-2e0b-4f1e-bfae-53fdb1103e12	93979301700002749	stress-39793017-2749@mediqueue.test	Paciente Stress 39793017-2749	55002749	ACTIVO	2026-06-02 22:37:07.691926	2026-06-02 22:37:07.691926	0
9b8dee9a-36a6-4eda-85e6-76396f9c118e	93979300300002787	stress-39793003-2787@mediqueue.test	Paciente Stress 39793003-2787	55002787	ACTIVO	2026-06-02 22:37:07.943262	2026-06-02 22:37:07.943262	0
e4542b07-ef99-4873-a577-0d29fe6c24e3	93979297800002928	stress-39792978-2928@mediqueue.test	Paciente Stress 39792978-2928	55002928	ACTIVO	2026-06-02 22:37:09.201825	2026-06-02 22:37:09.201825	0
032a874c-8c1e-48dd-9a4e-a17e8b9e314b	93979297400002994	stress-39792974-2994@mediqueue.test	Paciente Stress 39792974-2994	55002994	ACTIVO	2026-06-02 22:37:09.829098	2026-06-02 22:37:09.829098	0
0130600d-e97b-4957-94c1-8b371ca2d2a1	93979300500003304	stress-39793005-3304@mediqueue.test	Paciente Stress 39793005-3304	55003304	ACTIVO	2026-06-02 22:37:12.671056	2026-06-02 22:37:12.671056	0
25b3f75e-9eb9-42d0-ab31-68034723e4d2	93979298000003451	stress-39792980-3451@mediqueue.test	Paciente Stress 39792980-3451	55003451	ACTIVO	2026-06-02 22:37:13.66138	2026-06-02 22:37:13.66138	0
f686fd66-dad5-4989-a8b7-b5557c6488a9	93979305600003486	stress-39793056-3486@mediqueue.test	Paciente Stress 39793056-3486	55003486	ACTIVO	2026-06-02 22:37:13.948217	2026-06-02 22:37:13.948217	0
2efed511-2972-4df7-bbcd-4f46efc608ab	93979306000003867	stress-39793060-3867@mediqueue.test	Paciente Stress 39793060-3867	55003867	ACTIVO	2026-06-02 22:37:17.345091	2026-06-02 22:37:17.345091	0
b695262f-bef9-447a-a6ef-d00d0aa12cbc	93979301600004213	stress-39793016-4213@mediqueue.test	Paciente Stress 39793016-4213	55004213	ACTIVO	2026-06-02 22:37:19.856784	2026-06-02 22:37:19.856784	0
0abf0661-0650-4177-9efe-5c6a53c2a786	93979296300004313	stress-39792963-4313@mediqueue.test	Paciente Stress 39792963-4313	55004313	ACTIVO	2026-06-02 22:37:20.772196	2026-06-02 22:37:20.772196	0
82c8c39a-20e4-4899-af26-b1d33df6dd49	93979299900004375	stress-39792999-4375@mediqueue.test	Paciente Stress 39792999-4375	55004375	ACTIVO	2026-06-02 22:37:21.307073	2026-06-02 22:37:21.307073	0
ffd856ba-47f0-4930-93dd-06a6c1f96d59	94045693100007461	stress-40456931-7461@mediqueue.test	Paciente Stress 40456931-7461	55007461	ACTIVO	2026-06-02 22:48:49.032391	2026-06-02 22:48:49.032391	0
7790b269-531a-4581-bdec-c4967051d3aa	94045694100007702	stress-40456941-7702@mediqueue.test	Paciente Stress 40456941-7702	55007702	ACTIVO	2026-06-02 22:49:26.734484	2026-06-02 22:49:26.734484	0
3aa84442-28e2-4f02-a9eb-759d8a4c79a5	94045692100007877	stress-40456921-7877@mediqueue.test	Paciente Stress 40456921-7877	55007877	ACTIVO	2026-06-02 22:49:27.651539	2026-06-02 22:49:27.651539	0
c81a64b7-547e-4b50-8d9c-cd10d8b0bb70	94045695500008194	stress-40456955-8194@mediqueue.test	Paciente Stress 40456955-8194	55008194	ACTIVO	2026-06-02 22:49:31.280744	2026-06-02 22:49:31.280744	0
a266bf34-8ba6-4a0d-aec2-33287e8c9daa	94045693400008225	stress-40456934-8225@mediqueue.test	Paciente Stress 40456934-8225	55008225	ACTIVO	2026-06-02 22:49:31.387635	2026-06-02 22:49:31.387635	0
933af12f-85bf-40d0-99d4-3a8600b509f4	93969224700000907	stress-39692247-907@mediqueue.test	Paciente Stress 39692247-907	55000907	ACTIVO	2026-06-02 22:35:07.522268	2026-06-02 22:35:07.522268	0
19673f27-3402-4d06-9b32-a1ee1a1353b2	93969225700000965	stress-39692257-965@mediqueue.test	Paciente Stress 39692257-965	55000965	ACTIVO	2026-06-02 22:35:08.080441	2026-06-02 22:35:08.080441	0
a1d22c09-36fa-4451-806c-f6a89475aefd	93969225300001123	stress-39692253-1123@mediqueue.test	Paciente Stress 39692253-1123	55001123	ACTIVO	2026-06-02 22:35:09.52866	2026-06-02 22:35:09.52866	0
82a95b8f-154e-4d24-aa43-1b89a4e881cc	93969226900001158	stress-39692269-1158@mediqueue.test	Paciente Stress 39692269-1158	55001158	ACTIVO	2026-06-02 22:35:09.850864	2026-06-02 22:35:09.850864	0
a6bf5eb6-4cc5-476a-b051-88ef0531b85f	93969226500001187	stress-39692265-1187@mediqueue.test	Paciente Stress 39692265-1187	55001187	ACTIVO	2026-06-02 22:35:10.06575	2026-06-02 22:35:10.06575	0
edc0de6f-b4a0-46ae-a69e-b3b5d7b14855	93969226300001237	stress-39692263-1237@mediqueue.test	Paciente Stress 39692263-1237	55001237	ACTIVO	2026-06-02 22:35:10.705234	2026-06-02 22:35:10.705234	0
e05db41f-9eeb-4c40-99fd-29c4b2bddb96	93969226300001385	stress-39692263-1385@mediqueue.test	Paciente Stress 39692263-1385	55001385	ACTIVO	2026-06-02 22:35:12.203336	2026-06-02 22:35:12.203336	0
d1b3741e-1c07-4b0b-abc1-40baf5fd747d	93969226400001481	stress-39692264-1481@mediqueue.test	Paciente Stress 39692264-1481	55001481	ACTIVO	2026-06-02 22:35:13.121112	2026-06-02 22:35:13.121112	0
6b93fe9e-badc-4eaa-ad21-f1893cb05ef7	93969227700001602	stress-39692277-1602@mediqueue.test	Paciente Stress 39692277-1602	55001602	ACTIVO	2026-06-02 22:35:14.091922	2026-06-02 22:35:14.091922	0
99420676-d949-47f4-82e1-23da215f60e0	93969227000001725	stress-39692270-1725@mediqueue.test	Paciente Stress 39692270-1725	55001725	ACTIVO	2026-06-02 22:35:15.199786	2026-06-02 22:35:15.199786	0
982411ee-8ecd-4808-91b3-9ca2c65c0f6f	93969227900001886	stress-39692279-1886@mediqueue.test	Paciente Stress 39692279-1886	55001886	ACTIVO	2026-06-02 22:35:16.692376	2026-06-02 22:35:16.692376	0
7a61f090-7c8b-4a0f-8e1d-dbdfb4ba867e	93969226400002138	stress-39692264-2138@mediqueue.test	Paciente Stress 39692264-2138	55002138	ACTIVO	2026-06-02 22:35:19.322608	2026-06-02 22:35:19.322608	0
f7fe7248-004a-484a-a719-5d7e3bc70144	93969227600002184	stress-39692276-2184@mediqueue.test	Paciente Stress 39692276-2184	55002184	ACTIVO	2026-06-02 22:35:19.805927	2026-06-02 22:35:19.805927	0
18b19510-e9fd-4b96-94dc-4a3cd7e4446e	93969224700002221	stress-39692247-2221@mediqueue.test	Paciente Stress 39692247-2221	55002221	ACTIVO	2026-06-02 22:35:20.097786	2026-06-02 22:35:20.097786	0
477b866a-62d0-410b-9319-da85c9af09e7	93969227900002254	stress-39692279-2254@mediqueue.test	Paciente Stress 39692279-2254	55002254	ACTIVO	2026-06-02 22:35:20.400934	2026-06-02 22:35:20.400934	0
8b1e1d39-4dfe-4f81-aa67-63b536c44c89	93969224700002335	stress-39692247-2335@mediqueue.test	Paciente Stress 39692247-2335	55002335	ACTIVO	2026-06-02 22:35:21.326323	2026-06-02 22:35:21.326323	0
484c3ecb-d6cf-4afc-962f-a9a5448cd416	93969225000002389	stress-39692250-2389@mediqueue.test	Paciente Stress 39692250-2389	55002389	ACTIVO	2026-06-02 22:35:21.779803	2026-06-02 22:35:21.779803	0
dea5a25f-383c-4e71-9c74-fb0358d8cc3b	93969227700002796	stress-39692277-2796@mediqueue.test	Paciente Stress 39692277-2796	55002796	ACTIVO	2026-06-02 22:35:25.392521	2026-06-02 22:35:25.392521	0
ee4bc1c6-4a12-4dcc-bb69-a82443cbcc8c	93969227800002888	stress-39692278-2888@mediqueue.test	Paciente Stress 39692278-2888	55002888	ACTIVO	2026-06-02 22:35:26.296954	2026-06-02 22:35:26.296954	0
8d1a9e8b-078e-4825-ac48-187999ad1532	93969227200002987	stress-39692272-2987@mediqueue.test	Paciente Stress 39692272-2987	55002987	ACTIVO	2026-06-02 22:35:27.061428	2026-06-02 22:35:27.061428	0
2e88405d-57e6-4649-84d2-e88bdfb8025f	93969226400003055	stress-39692264-3055@mediqueue.test	Paciente Stress 39692264-3055	55003055	ACTIVO	2026-06-02 22:35:27.574172	2026-06-02 22:35:27.574172	0
79a63aec-49d4-4bf9-8526-8d283a8f7d71	93969228000003140	stress-39692280-3140@mediqueue.test	Paciente Stress 39692280-3140	55003140	ACTIVO	2026-06-02 22:35:28.54611	2026-06-02 22:35:28.54611	0
bc4288ff-a5cb-4260-b68a-d80f40d9aed3	93969224700003339	stress-39692247-3339@mediqueue.test	Paciente Stress 39692247-3339	55003339	ACTIVO	2026-06-02 22:35:30.249505	2026-06-02 22:35:30.249505	0
54be9217-9cf8-429d-b149-b105b288140b	93969226200003530	stress-39692262-3530@mediqueue.test	Paciente Stress 39692262-3530	55003530	ACTIVO	2026-06-02 22:35:32.073353	2026-06-02 22:35:32.073353	0
29c38a61-cb68-4870-bbcc-0fdf61f93d74	93969225500003561	stress-39692255-3561@mediqueue.test	Paciente Stress 39692255-3561	55003561	ACTIVO	2026-06-02 22:35:32.476191	2026-06-02 22:35:32.476191	0
2d3180ac-271b-4995-b875-4053b2a583bc	93969227700003713	stress-39692277-3713@mediqueue.test	Paciente Stress 39692277-3713	55003713	ACTIVO	2026-06-02 22:35:33.755192	2026-06-02 22:35:33.755192	0
ce1858b2-86f4-4467-97e8-df2bec970791	93969227100003804	stress-39692271-3804@mediqueue.test	Paciente Stress 39692271-3804	55003804	ACTIVO	2026-06-02 22:35:34.620257	2026-06-02 22:35:34.620257	0
42a01f6e-5a47-4bd4-b5fb-846ac86dfb41	93969226000004578	stress-39692260-4578@mediqueue.test	Paciente Stress 39692260-4578	55004578	ACTIVO	2026-06-02 22:35:40.739926	2026-06-02 22:35:40.739926	0
1f833556-0959-41e4-a6f3-39a18f262ae4	93969227000004661	stress-39692270-4661@mediqueue.test	Paciente Stress 39692270-4661	55004661	ACTIVO	2026-06-02 22:35:41.597183	2026-06-02 22:35:41.597183	0
a45fc168-c973-479a-8007-76d7185cf52e	93969226400004788	stress-39692264-4788@mediqueue.test	Paciente Stress 39692264-4788	55004788	ACTIVO	2026-06-02 22:35:42.442988	2026-06-02 22:35:42.442988	0
2820c491-155e-47bc-b288-57cf665fc1cf	93969226200004827	stress-39692262-4827@mediqueue.test	Paciente Stress 39692262-4827	55004827	ACTIVO	2026-06-02 22:35:42.671541	2026-06-02 22:35:42.671541	0
921ea358-ee79-420b-ad5e-d2a49e0bac8b	93969227400004903	stress-39692274-4903@mediqueue.test	Paciente Stress 39692274-4903	55004903	ACTIVO	2026-06-02 22:35:43.281915	2026-06-02 22:35:43.281915	0
2b2490d6-4f34-4821-a7ab-c616a433f3f2	93979297500004282	stress-39792975-4282@mediqueue.test	Paciente Stress 39792975-4282	55004282	ACTIVO	2026-06-02 22:37:20.435464	2026-06-02 22:37:20.435464	0
484fb96b-14e2-46fa-ac8e-51c7666b77e8	94045692500007524	stress-40456925-7524@mediqueue.test	Paciente Stress 40456925-7524	55007524	ACTIVO	2026-06-02 22:48:49.475885	2026-06-02 22:48:49.475885	0
2413267a-d37d-4946-b747-631bc7a30906	94045696600007731	stress-40456966-7731@mediqueue.test	Paciente Stress 40456966-7731	55007731	ACTIVO	2026-06-02 22:49:28.161593	2026-06-02 22:49:28.161593	0
82f9c199-499a-426b-bbbb-cc636bb011bd	94045696400007888	stress-40456964-7888@mediqueue.test	Paciente Stress 40456964-7888	55007888	ACTIVO	2026-06-02 22:49:29.168921	2026-06-02 22:49:29.168921	0
0bf7d79c-cceb-4b16-a2e9-eecb96eb28d5	94045695500007764	stress-40456955-7764@mediqueue.test	Paciente Stress 40456955-7764	55007764	ACTIVO	2026-06-02 22:49:30.384825	2026-06-02 22:49:30.384825	0
360990e6-3510-4c26-8798-6b6668d89798	94045695000007676	stress-40456950-7676@mediqueue.test	Paciente Stress 40456950-7676	55007676	ACTIVO	2026-06-02 22:49:30.550438	2026-06-02 22:49:30.550438	0
83104c1b-f180-4020-8d10-6b47d7ed9f3b	94045692900008161	stress-40456929-8161@mediqueue.test	Paciente Stress 40456929-8161	55008161	ACTIVO	2026-06-02 22:49:30.711798	2026-06-02 22:49:30.711798	0
a8b2ed64-b6e3-4945-b7cc-99b013742caf	94045696400008145	stress-40456964-8145@mediqueue.test	Paciente Stress 40456964-8145	55008145	ACTIVO	2026-06-02 22:49:30.895774	2026-06-02 22:49:30.895774	0
fa2613e4-73da-4353-a4b7-e6234625cab4	94045696200008253	stress-40456962-8253@mediqueue.test	Paciente Stress 40456962-8253	55008253	ACTIVO	2026-06-02 22:49:31.387667	2026-06-02 22:49:31.387667	0
ae7eb137-3743-428f-935a-2124c792d0ad	94045694000008371	stress-40456940-8371@mediqueue.test	Paciente Stress 40456940-8371	55008371	ACTIVO	2026-06-02 22:49:32.707236	2026-06-02 22:49:32.707236	0
229940fb-fd2e-45c1-849b-3317f400df73	94045696600008862	stress-40456966-8862@mediqueue.test	Paciente Stress 40456966-8862	55008862	ACTIVO	2026-06-02 22:49:37.246779	2026-06-02 22:49:37.246779	0
819053ac-2b3a-47dc-bbda-4d20a85bff3f	94045696400008965	stress-40456964-8965@mediqueue.test	Paciente Stress 40456964-8965	55008965	ACTIVO	2026-06-02 22:49:38.210243	2026-06-02 22:49:38.210243	0
cd93eb62-ec0f-42d2-9b32-0966275a7774	94045696900009201	stress-40456969-9201@mediqueue.test	Paciente Stress 40456969-9201	55009201	ACTIVO	2026-06-02 22:49:40.542687	2026-06-02 22:49:40.542687	0
dced6db8-18f7-49be-89d8-539319eda5e0	94045691800009313	stress-40456918-9313@mediqueue.test	Paciente Stress 40456918-9313	55009313	ACTIVO	2026-06-02 22:49:41.436743	2026-06-02 22:49:41.436743	0
a9dbadbc-582a-4b7d-a6f7-e1118c430008	94045692300009429	stress-40456923-9429@mediqueue.test	Paciente Stress 40456923-9429	55009429	ACTIVO	2026-06-02 22:49:42.957392	2026-06-02 22:49:42.957392	0
721e7df6-f197-49f2-af6a-5d8fc9b70621	93969224700000908	stress-39692247-908@mediqueue.test	Paciente Stress 39692247-908	55000908	ACTIVO	2026-06-02 22:35:07.53639	2026-06-02 22:35:07.53639	0
8a36763c-9954-4a14-ae81-f84642eefb62	93969226200001127	stress-39692262-1127@mediqueue.test	Paciente Stress 39692262-1127	55001127	ACTIVO	2026-06-02 22:35:09.5284	2026-06-02 22:35:09.5284	0
f01a89ca-6cd2-4f7a-8d91-eb2bbc3a8475	93969225400001378	stress-39692254-1378@mediqueue.test	Paciente Stress 39692254-1378	55001378	ACTIVO	2026-06-02 22:35:12.090409	2026-06-02 22:35:12.090409	0
c2628dcc-6843-4453-9b09-82be942fc8a8	93969226900001398	stress-39692269-1398@mediqueue.test	Paciente Stress 39692269-1398	55001398	ACTIVO	2026-06-02 22:35:12.29879	2026-06-02 22:35:12.29879	0
5fdf3442-9382-406b-bf67-68518b333434	93969227000001761	stress-39692270-1761@mediqueue.test	Paciente Stress 39692270-1761	55001761	ACTIVO	2026-06-02 22:35:15.48721	2026-06-02 22:35:15.48721	0
9b9f454f-7ef4-461f-a6fc-d572d9edc762	93969228000002501	stress-39692280-2501@mediqueue.test	Paciente Stress 39692280-2501	55002501	ACTIVO	2026-06-02 22:35:22.75949	2026-06-02 22:35:22.75949	0
e0277aef-7b34-4aae-8f93-4590b93bdc5e	93969228000002549	stress-39692280-2549@mediqueue.test	Paciente Stress 39692280-2549	55002549	ACTIVO	2026-06-02 22:35:23.080326	2026-06-02 22:35:23.080326	0
d8aed131-e291-45bb-a82e-1e91ef021743	93969225300002806	stress-39692253-2806@mediqueue.test	Paciente Stress 39692253-2806	55002806	ACTIVO	2026-06-02 22:35:25.451275	2026-06-02 22:35:25.451275	0
837d8c9a-9659-4942-a1c0-0841b55640ab	93969225400002963	stress-39692254-2963@mediqueue.test	Paciente Stress 39692254-2963	55002963	ACTIVO	2026-06-02 22:35:26.939161	2026-06-02 22:35:26.939161	0
51e847c3-a7b6-4392-98b8-bb63efcc3e75	93969226900003142	stress-39692269-3142@mediqueue.test	Paciente Stress 39692269-3142	55003142	ACTIVO	2026-06-02 22:35:28.633788	2026-06-02 22:35:28.633788	0
49571a4a-7495-46ad-962f-c324066bf237	93969225200003354	stress-39692252-3354@mediqueue.test	Paciente Stress 39692252-3354	55003354	ACTIVO	2026-06-02 22:35:30.345141	2026-06-02 22:35:30.345141	0
03bbf8be-524b-4727-820d-70ca8bc97ad6	93969226400003370	stress-39692264-3370@mediqueue.test	Paciente Stress 39692264-3370	55003370	ACTIVO	2026-06-02 22:35:30.570813	2026-06-02 22:35:30.570813	0
2873c7a5-6d3d-4efa-b284-bbafe28e6a4f	93969225400003422	stress-39692254-3422@mediqueue.test	Paciente Stress 39692254-3422	55003422	ACTIVO	2026-06-02 22:35:31.086603	2026-06-02 22:35:31.086603	0
1176faf7-9a7f-4896-b010-0bbd3b3d2de7	93969227700003477	stress-39692277-3477@mediqueue.test	Paciente Stress 39692277-3477	55003477	ACTIVO	2026-06-02 22:35:31.705369	2026-06-02 22:35:31.705369	0
2609e7ae-3a0b-46d6-afc6-8e955813f591	93969227300003536	stress-39692273-3536@mediqueue.test	Paciente Stress 39692273-3536	55003536	ACTIVO	2026-06-02 22:35:32.146505	2026-06-02 22:35:32.146505	0
1297fc55-5a19-4a9d-bb79-657e620c538d	93969225500003634	stress-39692255-3634@mediqueue.test	Paciente Stress 39692255-3634	55003634	ACTIVO	2026-06-02 22:35:33.025432	2026-06-02 22:35:33.025432	0
6f42b6a9-eefd-4943-a712-306fd44163a6	93969225800003670	stress-39692258-3670@mediqueue.test	Paciente Stress 39692258-3670	55003670	ACTIVO	2026-06-02 22:35:33.268825	2026-06-02 22:35:33.268825	0
fc8544be-88e9-4045-a761-168221973583	93969227800003915	stress-39692278-3915@mediqueue.test	Paciente Stress 39692278-3915	55003915	ACTIVO	2026-06-02 22:35:35.51084	2026-06-02 22:35:35.51084	0
0ad2c15e-ccb0-46f3-ba3d-4b92d665318a	93969226300004184	stress-39692263-4184@mediqueue.test	Paciente Stress 39692263-4184	55004184	ACTIVO	2026-06-02 22:35:37.549994	2026-06-02 22:35:37.549994	0
37f881ca-ecb5-4976-8e5e-806ad673a7a2	93969227800004265	stress-39692278-4265@mediqueue.test	Paciente Stress 39692278-4265	55004265	ACTIVO	2026-06-02 22:35:38.094868	2026-06-02 22:35:38.094868	0
3419b0da-7246-4898-b30b-c34dca14474a	93969226500004389	stress-39692265-4389@mediqueue.test	Paciente Stress 39692265-4389	55004389	ACTIVO	2026-06-02 22:35:39.015089	2026-06-02 22:35:39.015089	0
094891b9-6966-4b96-966e-5a89e41c1a04	93969225400004458	stress-39692254-4458@mediqueue.test	Paciente Stress 39692254-4458	55004458	ACTIVO	2026-06-02 22:35:39.579773	2026-06-02 22:35:39.579773	0
97abff5f-a31a-47cb-857f-92b1eb538365	93969228000004478	stress-39692280-4478@mediqueue.test	Paciente Stress 39692280-4478	55004478	ACTIVO	2026-06-02 22:35:39.818683	2026-06-02 22:35:39.818683	0
56cd1e05-f920-4a87-a4f8-346996a336b0	93969225700004863	stress-39692257-4863@mediqueue.test	Paciente Stress 39692257-4863	55004863	ACTIVO	2026-06-02 22:35:43.01485	2026-06-02 22:35:43.01485	0
3de3673e-affe-4870-96f1-20a34ba89d0a	93969226100004967	stress-39692261-4967@mediqueue.test	Paciente Stress 39692261-4967	55004967	ACTIVO	2026-06-02 22:35:43.920612	2026-06-02 22:35:43.920612	0
0a0f1982-d5c5-4904-804f-4cf5f4dda774	93979297800004432	stress-39792978-4432@mediqueue.test	Paciente Stress 39792978-4432	55004432	ACTIVO	2026-06-02 22:38:31.962476	2026-06-02 22:38:31.962476	0
52a46c82-36c0-4e2f-8829-dc638d0a0ce7	93979302900004423	stress-39793029-4423@mediqueue.test	Paciente Stress 39793029-4423	55004423	ACTIVO	2026-06-02 22:38:32.848879	2026-06-02 22:38:32.848879	0
ccecf3b2-85e7-4392-b694-7ec05fc6c01a	93979300000004602	stress-39793000-4602@mediqueue.test	Paciente Stress 39793000-4602	55004602	ACTIVO	2026-06-02 22:38:33.476194	2026-06-02 22:38:33.476194	0
4e48db83-bf04-4774-bda6-90e9bc65615c	93979297600004543	stress-39792976-4543@mediqueue.test	Paciente Stress 39792976-4543	55004543	ACTIVO	2026-06-02 22:38:33.750354	2026-06-02 22:38:33.750354	0
178c85bc-54e6-45fa-bd08-f5336fad6379	93979305900004766	stress-39793059-4766@mediqueue.test	Paciente Stress 39793059-4766	55004766	ACTIVO	2026-06-02 22:38:34.62808	2026-06-02 22:38:34.62808	0
4e89c1c3-0b50-4b44-9fd5-21f2ff5a746a	93979300600004814	stress-39793006-4814@mediqueue.test	Paciente Stress 39793006-4814	55004814	ACTIVO	2026-06-02 22:38:34.855449	2026-06-02 22:38:34.855449	0
fa729bb2-0b22-4d6c-9635-4ab3c0a6f080	93979300100004942	stress-39793001-4942@mediqueue.test	Paciente Stress 39793001-4942	55004942	ACTIVO	2026-06-02 22:38:34.986301	2026-06-02 22:38:34.986301	0
869ae0a9-7f13-4317-9ebb-088f711d84fe	93979298000005226	stress-39792980-5226@mediqueue.test	Paciente Stress 39792980-5226	55005226	ACTIVO	2026-06-02 22:38:37.555648	2026-06-02 22:38:37.555648	0
406a9d17-cef0-459b-a2c2-8c275ea3b64b	93979305800005296	stress-39793058-5296@mediqueue.test	Paciente Stress 39793058-5296	55005296	ACTIVO	2026-06-02 22:38:38.100591	2026-06-02 22:38:38.100591	0
b3aed436-5961-451f-85ca-47e97a014c28	93979300000005376	stress-39793000-5376@mediqueue.test	Paciente Stress 39793000-5376	55005376	ACTIVO	2026-06-02 22:38:38.787785	2026-06-02 22:38:38.787785	0
58241de6-a7c8-4f43-b134-b48b2fa6530e	93979297700005550	stress-39792977-5550@mediqueue.test	Paciente Stress 39792977-5550	55005550	ACTIVO	2026-06-02 22:38:40.566046	2026-06-02 22:38:40.566046	0
339d1041-d32d-4ad7-8a3b-c75eda79d3fb	93979300000005628	stress-39793000-5628@mediqueue.test	Paciente Stress 39793000-5628	55005628	ACTIVO	2026-06-02 22:38:41.283828	2026-06-02 22:38:41.283828	0
443c53ab-9003-40dc-9ac6-3d82f9a4c65c	93979297900005726	stress-39792979-5726@mediqueue.test	Paciente Stress 39792979-5726	55005726	ACTIVO	2026-06-02 22:38:42.348515	2026-06-02 22:38:42.348515	0
5fc5417a-c688-4dc8-ad74-69309f5a6ed3	93979297600005759	stress-39792976-5759@mediqueue.test	Paciente Stress 39792976-5759	55005759	ACTIVO	2026-06-02 22:38:42.614013	2026-06-02 22:38:42.614013	0
a20b418c-0143-40b3-829b-0e7deafbc72d	93979299800005961	stress-39792998-5961@mediqueue.test	Paciente Stress 39792998-5961	55005961	ACTIVO	2026-06-02 22:38:44.432882	2026-06-02 22:38:44.432882	0
5c57cbd8-e1b7-4b23-bb20-456e5cd1d70f	93979300700006023	stress-39793007-6023@mediqueue.test	Paciente Stress 39793007-6023	55006023	ACTIVO	2026-06-02 22:38:44.968485	2026-06-02 22:38:44.968485	0
fa191de0-972b-4085-9287-9a92f23769ff	93979297600006182	stress-39792976-6182@mediqueue.test	Paciente Stress 39792976-6182	55006182	ACTIVO	2026-06-02 22:38:46.53574	2026-06-02 22:38:46.53574	0
8bf7aecd-9dd7-438d-9509-e1fdcee63110	93979304300006209	stress-39793043-6209@mediqueue.test	Paciente Stress 39793043-6209	55006209	ACTIVO	2026-06-02 22:38:46.81526	2026-06-02 22:38:46.81526	0
26e92f2c-f5f7-4019-a794-29c150532c9f	93979304300006224	stress-39793043-6224@mediqueue.test	Paciente Stress 39793043-6224	55006224	ACTIVO	2026-06-02 22:38:46.994545	2026-06-02 22:38:46.994545	0
a1968a08-9d7a-46f6-958f-2fddf01f3748	93979300700006628	stress-39793007-6628@mediqueue.test	Paciente Stress 39793007-6628	55006628	ACTIVO	2026-06-02 22:40:35.552097	2026-06-02 22:40:35.552097	0
0d6c8030-3a5e-44e2-9dd1-d38d48e79e3a	93979298000006722	stress-39792980-6722@mediqueue.test	Paciente Stress 39792980-6722	55006722	ACTIVO	2026-06-02 22:40:35.989134	2026-06-02 22:40:35.989134	0
1f22ae17-c60d-431d-a49f-0f1d2f3d3cd4	93979300600006530	stress-39793006-6530@mediqueue.test	Paciente Stress 39793006-6530	55006530	ACTIVO	2026-06-02 22:40:36.237414	2026-06-02 22:40:36.237414	0
2c67b03e-2687-44c5-8f38-671163d2f890	93969227400000911	stress-39692274-911@mediqueue.test	Paciente Stress 39692274-911	55000911	ACTIVO	2026-06-02 22:35:07.558167	2026-06-02 22:35:07.558167	0
205526af-d2e3-447c-b22e-11a93a7861cd	93969226000001136	stress-39692260-1136@mediqueue.test	Paciente Stress 39692260-1136	55001136	ACTIVO	2026-06-02 22:35:09.584335	2026-06-02 22:35:09.584335	0
a4f5ebf1-f861-4c85-a11a-1ec9bd093c5b	93969227700001230	stress-39692277-1230@mediqueue.test	Paciente Stress 39692277-1230	55001230	ACTIVO	2026-06-02 22:35:10.633228	2026-06-02 22:35:10.633228	0
4a08e0e9-df85-47fa-8829-483f8dd57477	93969227700001499	stress-39692277-1499@mediqueue.test	Paciente Stress 39692277-1499	55001499	ACTIVO	2026-06-02 22:35:13.285255	2026-06-02 22:35:13.285255	0
31d0557d-175b-4607-9952-c32a3d1071c9	93969225300001630	stress-39692253-1630@mediqueue.test	Paciente Stress 39692253-1630	55001630	ACTIVO	2026-06-02 22:35:14.297765	2026-06-02 22:35:14.297765	0
77cafd45-c95a-45a9-a334-fbce97051dd2	93969226700001773	stress-39692267-1773@mediqueue.test	Paciente Stress 39692267-1773	55001773	ACTIVO	2026-06-02 22:35:15.55434	2026-06-02 22:35:15.55434	0
b4e7d694-557a-4896-9b24-36fcffcd80f3	93969227900001926	stress-39692279-1926@mediqueue.test	Paciente Stress 39692279-1926	55001926	ACTIVO	2026-06-02 22:35:17.001489	2026-06-02 22:35:17.001489	0
6ee7fd79-fa47-4f2c-857e-ba51efbeb303	93969225600001978	stress-39692256-1978@mediqueue.test	Paciente Stress 39692256-1978	55001978	ACTIVO	2026-06-02 22:35:17.625985	2026-06-02 22:35:17.625985	0
87330e05-9610-44e8-acd3-17bbb9bb0098	93969225800002298	stress-39692258-2298@mediqueue.test	Paciente Stress 39692258-2298	55002298	ACTIVO	2026-06-02 22:35:20.914203	2026-06-02 22:35:20.914203	0
b582cc28-4148-4d23-9ed8-79fccdb3bd32	93969226800002337	stress-39692268-2337@mediqueue.test	Paciente Stress 39692268-2337	55002337	ACTIVO	2026-06-02 22:35:21.308631	2026-06-02 22:35:21.308631	0
2a48b007-e1e9-48e0-aca9-9ecab2aa8ac7	93969227800002641	stress-39692278-2641@mediqueue.test	Paciente Stress 39692278-2641	55002641	ACTIVO	2026-06-02 22:35:23.897445	2026-06-02 22:35:23.897445	0
e9a315fe-a91d-4e73-a66f-932fc7e18ec8	93969226900002676	stress-39692269-2676@mediqueue.test	Paciente Stress 39692269-2676	55002676	ACTIVO	2026-06-02 22:35:24.212964	2026-06-02 22:35:24.212964	0
fba09757-fae1-477a-ab33-45596abdecbf	93969227400002959	stress-39692274-2959@mediqueue.test	Paciente Stress 39692274-2959	55002959	ACTIVO	2026-06-02 22:35:26.890619	2026-06-02 22:35:26.890619	0
09b97d2b-f710-432e-8c2d-b2bcca876635	93969226500003105	stress-39692265-3105@mediqueue.test	Paciente Stress 39692265-3105	55003105	ACTIVO	2026-06-02 22:35:28.187027	2026-06-02 22:35:28.187027	0
68212b48-746e-45df-93a0-865c47bb5463	93969225400003279	stress-39692254-3279@mediqueue.test	Paciente Stress 39692254-3279	55003279	ACTIVO	2026-06-02 22:35:29.75542	2026-06-02 22:35:29.75542	0
e2a591d2-e6d7-4eef-8948-1116a3226b94	93969226300003344	stress-39692263-3344@mediqueue.test	Paciente Stress 39692263-3344	55003344	ACTIVO	2026-06-02 22:35:30.294237	2026-06-02 22:35:30.294237	0
15e10a3f-e539-4492-84d0-399a4525af3e	93969227800003506	stress-39692278-3506@mediqueue.test	Paciente Stress 39692278-3506	55003506	ACTIVO	2026-06-02 22:35:31.854369	2026-06-02 22:35:31.854369	0
3a0b0faa-6531-4d69-95bd-896df0883834	93969227300003555	stress-39692273-3555@mediqueue.test	Paciente Stress 39692273-3555	55003555	ACTIVO	2026-06-02 22:35:32.424543	2026-06-02 22:35:32.424543	0
c215e06e-0569-4d01-be05-c09ed87b3674	93969225500003754	stress-39692255-3754@mediqueue.test	Paciente Stress 39692255-3754	55003754	ACTIVO	2026-06-02 22:35:34.160344	2026-06-02 22:35:34.160344	0
a2c109f7-8ba4-46ea-a00a-bbc918463066	93969228000003789	stress-39692280-3789@mediqueue.test	Paciente Stress 39692280-3789	55003789	ACTIVO	2026-06-02 22:35:34.465025	2026-06-02 22:35:34.465025	0
297dcf14-5322-4012-9668-f1eeac57e0ea	93969226500004415	stress-39692265-4415@mediqueue.test	Paciente Stress 39692265-4415	55004415	ACTIVO	2026-06-02 22:35:39.239025	2026-06-02 22:35:39.239025	0
fc333631-ac08-49d6-9edb-930c6a5b03b3	93969225000004472	stress-39692250-4472@mediqueue.test	Paciente Stress 39692250-4472	55004472	ACTIVO	2026-06-02 22:35:39.74173	2026-06-02 22:35:39.74173	0
bc33723a-2735-4de9-803b-171f9023e380	93969226700004632	stress-39692267-4632@mediqueue.test	Paciente Stress 39692267-4632	55004632	ACTIVO	2026-06-02 22:35:41.277488	2026-06-02 22:35:41.277488	0
9219a750-790b-419e-b75c-f86841f979d0	93969227100004652	stress-39692271-4652@mediqueue.test	Paciente Stress 39692271-4652	55004652	ACTIVO	2026-06-02 22:35:41.511885	2026-06-02 22:35:41.511885	0
cfab60ea-e397-4dcd-9e0a-08deb04a895c	93969227800004911	stress-39692278-4911@mediqueue.test	Paciente Stress 39692278-4911	55004911	ACTIVO	2026-06-02 22:35:43.28661	2026-06-02 22:35:43.28661	0
47a0dde4-9283-49fd-bd2d-9e38351bc7c6	93969225000004932	stress-39692250-4932@mediqueue.test	Paciente Stress 39692250-4932	55004932	ACTIVO	2026-06-02 22:35:43.565383	2026-06-02 22:35:43.565383	0
ea2b194b-9190-498a-8d3c-48f5e0b39a5c	93969227900004959	stress-39692279-4959@mediqueue.test	Paciente Stress 39692279-4959	55004959	ACTIVO	2026-06-02 22:35:43.832858	2026-06-02 22:35:43.832858	0
4d040713-ed8e-417b-97f1-fa2aa5a3baca	93979299100004510	stress-39792991-4510@mediqueue.test	Paciente Stress 39792991-4510	55004510	ACTIVO	2026-06-02 22:38:32.423605	2026-06-02 22:38:32.423605	0
617049c8-6aee-4fdf-90fc-9a490da28a70	93979299700004723	stress-39792997-4723@mediqueue.test	Paciente Stress 39792997-4723	55004723	ACTIVO	2026-06-02 22:38:33.558642	2026-06-02 22:38:33.558642	0
fa992d51-93d3-40f9-ac79-bc0dc83ee01a	93979305900004443	stress-39793059-4443@mediqueue.test	Paciente Stress 39793059-4443	55004443	ACTIVO	2026-06-02 22:38:34.271973	2026-06-02 22:38:34.271973	0
eedb7e58-cecb-4acd-96bc-b75efe98e7cb	93979300500004849	stress-39793005-4849@mediqueue.test	Paciente Stress 39793005-4849	55004849	ACTIVO	2026-06-02 22:38:34.774752	2026-06-02 22:38:34.774752	0
7e207b46-c22e-4105-bbc6-4efa10a8348f	93979297000005141	stress-39792970-5141@mediqueue.test	Paciente Stress 39792970-5141	55005141	ACTIVO	2026-06-02 22:38:36.812448	2026-06-02 22:38:36.812448	0
e58badc9-f0a6-4716-9713-bb41c1aa1c5f	93979297700005529	stress-39792977-5529@mediqueue.test	Paciente Stress 39792977-5529	55005529	ACTIVO	2026-06-02 22:38:40.315669	2026-06-02 22:38:40.315669	0
1c3ee19b-0243-45e0-8d5d-f4ad76a6207e	93979298600005698	stress-39792986-5698@mediqueue.test	Paciente Stress 39792986-5698	55005698	ACTIVO	2026-06-02 22:38:42.07696	2026-06-02 22:38:42.07696	0
ca85a379-29a8-4f31-85d9-c886be54724e	93979297600005727	stress-39792976-5727@mediqueue.test	Paciente Stress 39792976-5727	55005727	ACTIVO	2026-06-02 22:38:42.34187	2026-06-02 22:38:42.34187	0
1c28a3f1-43b4-49ff-84a0-4c15d219a2e6	93979297600005852	stress-39792976-5852@mediqueue.test	Paciente Stress 39792976-5852	55005852	ACTIVO	2026-06-02 22:38:43.403744	2026-06-02 22:38:43.403744	0
048ba3ee-6798-4255-a616-28664f82924e	93979302100006358	stress-39793021-6358@mediqueue.test	Paciente Stress 39793021-6358	55006358	ACTIVO	2026-06-02 22:38:48.295368	2026-06-02 22:38:48.295368	0
48049c7c-5337-4b3c-b3ef-0c44d14db0cd	93979302900006688	stress-39793029-6688@mediqueue.test	Paciente Stress 39793029-6688	55006688	ACTIVO	2026-06-02 22:40:36.449249	2026-06-02 22:40:36.449249	0
144a939e-a873-4e4c-ad54-2b68a9a24dd8	93979302700006750	stress-39793027-6750@mediqueue.test	Paciente Stress 39793027-6750	55006750	ACTIVO	2026-06-02 22:40:36.90185	2026-06-02 22:40:36.90185	0
af2b720c-62b5-45fe-88b1-3104563bfd3c	93979300000006732	stress-39793000-6732@mediqueue.test	Paciente Stress 39793000-6732	55006732	ACTIVO	2026-06-02 22:40:37.100469	2026-06-02 22:40:37.100469	0
b86319b5-8433-46c6-838b-8a2352975bba	93979305900006882	stress-39793059-6882@mediqueue.test	Paciente Stress 39793059-6882	55006882	ACTIVO	2026-06-02 22:40:37.230717	2026-06-02 22:40:37.230717	0
4c59c674-e7c8-4a08-a6f8-b0a5a431e9bb	93979302200007851	stress-39793022-7851@mediqueue.test	Paciente Stress 39793022-7851	55007851	ACTIVO	2026-06-02 22:40:44.302346	2026-06-02 22:40:44.302346	0
9b1d4084-392a-4ca2-829d-93b25cf5d017	93979301500008253	stress-39793015-8253@mediqueue.test	Paciente Stress 39793015-8253	55008253	ACTIVO	2026-06-02 22:40:47.307327	2026-06-02 22:40:47.307327	0
90c7fc7c-59ff-4c05-9098-eb18e02e7c73	93979297700008445	stress-39792977-8445@mediqueue.test	Paciente Stress 39792977-8445	55008445	ACTIVO	2026-06-02 22:40:49.071093	2026-06-02 22:40:49.071093	0
0e60979c-b8ba-4f77-bd69-37b83acc1911	93979297900008658	stress-39792979-8658@mediqueue.test	Paciente Stress 39792979-8658	55008658	ACTIVO	2026-06-02 22:41:45.389573	2026-06-02 22:41:45.389573	0
f6f98425-b73c-4502-a302-7c0bacd27a7e	93979306100008769	stress-39793061-8769@mediqueue.test	Paciente Stress 39793061-8769	55008769	ACTIVO	2026-06-02 22:41:45.998561	2026-06-02 22:41:45.998561	0
c3d21d5c-03d3-42cf-81f9-63a6c5602739	93979299800008798	stress-39792998-8798@mediqueue.test	Paciente Stress 39792998-8798	55008798	ACTIVO	2026-06-02 22:41:46.142662	2026-06-02 22:41:46.142662	0
0e140965-5a12-443e-ac94-1345e3b2cf49	93969225900000943	stress-39692259-943@mediqueue.test	Paciente Stress 39692259-943	55000943	ACTIVO	2026-06-02 22:35:07.825754	2026-06-02 22:35:07.825754	0
2332ef6a-bc0a-4cdf-b784-186044622ae1	93969225700001000	stress-39692257-1000@mediqueue.test	Paciente Stress 39692257-1000	55001000	ACTIVO	2026-06-02 22:35:08.448279	2026-06-02 22:35:08.448279	0
84ffad55-ac12-42d7-87fd-0899d9fe36f4	93969227300001078	stress-39692273-1078@mediqueue.test	Paciente Stress 39692273-1078	55001078	ACTIVO	2026-06-02 22:35:09.208061	2026-06-02 22:35:09.208061	0
917b7142-7714-428d-8fd8-db34cd50801e	93969225900001221	stress-39692259-1221@mediqueue.test	Paciente Stress 39692259-1221	55001221	ACTIVO	2026-06-02 22:35:10.523571	2026-06-02 22:35:10.523571	0
62d53a0a-48c8-4071-bab1-1d8ac345610a	93969228000001256	stress-39692280-1256@mediqueue.test	Paciente Stress 39692280-1256	55001256	ACTIVO	2026-06-02 22:35:10.919058	2026-06-02 22:35:10.919058	0
a8232cf0-72ff-4295-be27-747fa499f544	93969227900001276	stress-39692279-1276@mediqueue.test	Paciente Stress 39692279-1276	55001276	ACTIVO	2026-06-02 22:35:11.205476	2026-06-02 22:35:11.205476	0
279b2301-a378-419f-b368-900d3e7a87c8	93969226500001331	stress-39692265-1331@mediqueue.test	Paciente Stress 39692265-1331	55001331	ACTIVO	2026-06-02 22:35:11.598533	2026-06-02 22:35:11.598533	0
9cf113d3-442d-4bc8-befc-81a8af947220	93969226200001430	stress-39692262-1430@mediqueue.test	Paciente Stress 39692262-1430	55001430	ACTIVO	2026-06-02 22:35:12.535505	2026-06-02 22:35:12.535505	0
2ac8877e-b156-424e-af4f-d90e53af5407	93969227600001645	stress-39692276-1645@mediqueue.test	Paciente Stress 39692276-1645	55001645	ACTIVO	2026-06-02 22:35:14.387176	2026-06-02 22:35:14.387176	0
09251048-c386-4cc7-9b4a-b0b423c8f9dd	93969227400001906	stress-39692274-1906@mediqueue.test	Paciente Stress 39692274-1906	55001906	ACTIVO	2026-06-02 22:35:16.880957	2026-06-02 22:35:16.880957	0
42a57483-7ae5-4b15-a4a2-634864230efd	93969226400002008	stress-39692264-2008@mediqueue.test	Paciente Stress 39692264-2008	55002008	ACTIVO	2026-06-02 22:35:17.992695	2026-06-02 22:35:17.992695	0
f6665997-d1d2-4080-b51d-11d8cadcc3a9	93969224700002200	stress-39692247-2200@mediqueue.test	Paciente Stress 39692247-2200	55002200	ACTIVO	2026-06-02 22:35:19.936892	2026-06-02 22:35:19.936892	0
99271e29-d76a-4435-bf33-766a009834f6	93969225300002400	stress-39692253-2400@mediqueue.test	Paciente Stress 39692253-2400	55002400	ACTIVO	2026-06-02 22:35:21.859853	2026-06-02 22:35:21.859853	0
ae7795d2-3bc9-4b25-a34e-68dff88c9680	93969226900002469	stress-39692269-2469@mediqueue.test	Paciente Stress 39692269-2469	55002469	ACTIVO	2026-06-02 22:35:22.448079	2026-06-02 22:35:22.448079	0
3605889e-dfaa-4bf6-9f24-19d4381eaf9b	93969227700002688	stress-39692277-2688@mediqueue.test	Paciente Stress 39692277-2688	55002688	ACTIVO	2026-06-02 22:35:24.379805	2026-06-02 22:35:24.379805	0
eed67964-ee25-4feb-bac9-e1363a5ee5e5	93969226400002708	stress-39692264-2708@mediqueue.test	Paciente Stress 39692264-2708	55002708	ACTIVO	2026-06-02 22:35:24.66718	2026-06-02 22:35:24.66718	0
88d1d0e0-8005-42b9-bea9-c01fe270ace5	93969227900002857	stress-39692279-2857@mediqueue.test	Paciente Stress 39692279-2857	55002857	ACTIVO	2026-06-02 22:35:26.05729	2026-06-02 22:35:26.05729	0
31399b2b-17c4-4497-b87b-176ad0d0acc3	93969228100002957	stress-39692281-2957@mediqueue.test	Paciente Stress 39692281-2957	55002957	ACTIVO	2026-06-02 22:35:26.891921	2026-06-02 22:35:26.891921	0
dff958df-b5db-41e0-9f10-c6e60df2b77c	93969225700003073	stress-39692257-3073@mediqueue.test	Paciente Stress 39692257-3073	55003073	ACTIVO	2026-06-02 22:35:27.77157	2026-06-02 22:35:27.77157	0
dc2cd739-1b6a-42de-9f7f-539e5c4964d0	93969228000003346	stress-39692280-3346@mediqueue.test	Paciente Stress 39692280-3346	55003346	ACTIVO	2026-06-02 22:35:30.312542	2026-06-02 22:35:30.312542	0
f91068dc-feb1-4310-bfa3-b6a769a02d24	93969226300003361	stress-39692263-3361@mediqueue.test	Paciente Stress 39692263-3361	55003361	ACTIVO	2026-06-02 22:35:30.469138	2026-06-02 22:35:30.469138	0
6e2c5be7-fd86-4b3a-a310-2956cfb0330b	93969227200003545	stress-39692272-3545@mediqueue.test	Paciente Stress 39692272-3545	55003545	ACTIVO	2026-06-02 22:35:32.298962	2026-06-02 22:35:32.298962	0
949bc160-2c46-4165-9fd5-c0fa0ab45177	93969226500003710	stress-39692265-3710@mediqueue.test	Paciente Stress 39692265-3710	55003710	ACTIVO	2026-06-02 22:35:33.755112	2026-06-02 22:35:33.755112	0
fc523d46-b600-4ddd-9445-43850256852f	93969226500003805	stress-39692265-3805@mediqueue.test	Paciente Stress 39692265-3805	55003805	ACTIVO	2026-06-02 22:35:34.639539	2026-06-02 22:35:34.639539	0
af973c44-34aa-484e-b9ca-ed8da8fc1627	93969226700003837	stress-39692267-3837@mediqueue.test	Paciente Stress 39692267-3837	55003837	ACTIVO	2026-06-02 22:35:34.888148	2026-06-02 22:35:34.888148	0
5aaf735f-1ce8-4527-bd3c-c840d28ea58d	93969225900003928	stress-39692259-3928@mediqueue.test	Paciente Stress 39692259-3928	55003928	ACTIVO	2026-06-02 22:35:35.610927	2026-06-02 22:35:35.610927	0
82e35681-3709-4ae8-a2e5-4bcf4c7f6a37	93969224700004066	stress-39692247-4066@mediqueue.test	Paciente Stress 39692247-4066	55004066	ACTIVO	2026-06-02 22:35:36.633017	2026-06-02 22:35:36.633017	0
4313a3a5-c16e-4b8b-b39f-02f95d98e42c	93969226300004130	stress-39692263-4130@mediqueue.test	Paciente Stress 39692263-4130	55004130	ACTIVO	2026-06-02 22:35:37.210044	2026-06-02 22:35:37.210044	0
ae2b85d4-6bbe-4cdc-a41b-7247161abffc	93969227700004484	stress-39692277-4484@mediqueue.test	Paciente Stress 39692277-4484	55004484	ACTIVO	2026-06-02 22:35:39.832201	2026-06-02 22:35:39.832201	0
75e36f4e-b99b-4d0b-a16c-fbaa7edc2380	93969226200004802	stress-39692262-4802@mediqueue.test	Paciente Stress 39692262-4802	55004802	ACTIVO	2026-06-02 22:35:42.521529	2026-06-02 22:35:42.521529	0
eae2b113-60b4-4ef8-ba5f-c4b4fbc10c32	93969225700004834	stress-39692257-4834@mediqueue.test	Paciente Stress 39692257-4834	55004834	ACTIVO	2026-06-02 22:35:42.752878	2026-06-02 22:35:42.752878	0
34481750-25d3-4bd3-a6de-b7bccd44c89c	93979301400004416	stress-39793014-4416@mediqueue.test	Paciente Stress 39793014-4416	55004416	ACTIVO	2026-06-02 22:38:32.469535	2026-06-02 22:38:32.469535	0
f0aff978-3c53-4b27-88b9-b863baa6a5b8	93979297000004530	stress-39792970-4530@mediqueue.test	Paciente Stress 39792970-4530	55004530	ACTIVO	2026-06-02 22:38:32.718606	2026-06-02 22:38:32.718606	0
aab02182-5d2e-4153-88b1-9083155b1114	93979300500004533	stress-39793005-4533@mediqueue.test	Paciente Stress 39793005-4533	55004533	ACTIVO	2026-06-02 22:38:33.191504	2026-06-02 22:38:33.191504	0
c30f4eec-86c7-45c4-a3ce-eb9846b22b39	93979302700004452	stress-39793027-4452@mediqueue.test	Paciente Stress 39793027-4452	55004452	ACTIVO	2026-06-02 22:38:33.365446	2026-06-02 22:38:33.365446	0
2f2f62c9-d39f-4637-a7bd-5c8af68a0391	93979302300004637	stress-39793023-4637@mediqueue.test	Paciente Stress 39793023-4637	55004637	ACTIVO	2026-06-02 22:38:33.594851	2026-06-02 22:38:33.594851	0
1521fbfd-bc67-4fa3-9feb-bcb9ff92bb36	93979298600004771	stress-39792986-4771@mediqueue.test	Paciente Stress 39792986-4771	55004771	ACTIVO	2026-06-02 22:38:34.49274	2026-06-02 22:38:34.49274	0
bda88fb6-7e42-447f-8a81-9d32eb815ad3	93979302300005062	stress-39793023-5062@mediqueue.test	Paciente Stress 39793023-5062	55005062	ACTIVO	2026-06-02 22:38:36.23193	2026-06-02 22:38:36.23193	0
e118cc8d-dd2c-4fa9-81a3-1c4935bf786c	93979300600005092	stress-39793006-5092@mediqueue.test	Paciente Stress 39793006-5092	55005092	ACTIVO	2026-06-02 22:38:36.342485	2026-06-02 22:38:36.342485	0
02ef56bc-faaf-4979-9362-dca40d488fdd	93979296300005108	stress-39792963-5108@mediqueue.test	Paciente Stress 39792963-5108	55005108	ACTIVO	2026-06-02 22:38:36.526474	2026-06-02 22:38:36.526474	0
3ab6489e-334e-4c51-8b0f-5a9a7cc8fc5f	93979297900005123	stress-39792979-5123@mediqueue.test	Paciente Stress 39792979-5123	55005123	ACTIVO	2026-06-02 22:38:36.703883	2026-06-02 22:38:36.703883	0
bd247156-762c-4f26-91cd-733e25a92a5e	93979305600005173	stress-39793056-5173@mediqueue.test	Paciente Stress 39793056-5173	55005173	ACTIVO	2026-06-02 22:38:37.146393	2026-06-02 22:38:37.146393	0
c8ecdd84-cd3f-4c41-8686-be3cfad5f010	93979298500005614	stress-39792985-5614@mediqueue.test	Paciente Stress 39792985-5614	55005614	ACTIVO	2026-06-02 22:38:41.208268	2026-06-02 22:38:41.208268	0
ade95794-a841-466e-8ad5-401148f424f2	93979302100005748	stress-39793021-5748@mediqueue.test	Paciente Stress 39793021-5748	55005748	ACTIVO	2026-06-02 22:38:42.508158	2026-06-02 22:38:42.508158	0
a972daaf-057e-498f-9fdf-d412740ab5ef	93979301500005822	stress-39793015-5822@mediqueue.test	Paciente Stress 39793015-5822	55005822	ACTIVO	2026-06-02 22:38:43.059866	2026-06-02 22:38:43.059866	0
6dbe9d36-0ea7-435c-b20d-cb9749b7189a	93979298700005864	stress-39792987-5864@mediqueue.test	Paciente Stress 39792987-5864	55005864	ACTIVO	2026-06-02 22:38:43.471211	2026-06-02 22:38:43.471211	0
491a9e05-007c-4763-9a7d-e49af9658ddc	93979300000005895	stress-39793000-5895@mediqueue.test	Paciente Stress 39793000-5895	55005895	ACTIVO	2026-06-02 22:38:43.781118	2026-06-02 22:38:43.781118	0
461d29bd-075b-4a76-aa3e-505570671333	93969227700000963	stress-39692277-963@mediqueue.test	Paciente Stress 39692277-963	55000963	ACTIVO	2026-06-02 22:35:08.103196	2026-06-02 22:35:08.103196	0
a70985a7-e203-42dd-bdfc-85141c9f1c66	93969225700001036	stress-39692257-1036@mediqueue.test	Paciente Stress 39692257-1036	55001036	ACTIVO	2026-06-02 22:35:08.851949	2026-06-02 22:35:08.851949	0
2bbe6c41-2c7f-4a90-b83e-ac90c20081b4	93969227900001206	stress-39692279-1206@mediqueue.test	Paciente Stress 39692279-1206	55001206	ACTIVO	2026-06-02 22:35:10.316434	2026-06-02 22:35:10.316434	0
9f8c46e8-402a-4b5c-80b6-6454583ae33c	93969224700001513	stress-39692247-1513@mediqueue.test	Paciente Stress 39692247-1513	55001513	ACTIVO	2026-06-02 22:35:13.452468	2026-06-02 22:35:13.452468	0
c2ea33fd-d76c-4032-b57f-3b42f4f4301f	93969225000002068	stress-39692250-2068@mediqueue.test	Paciente Stress 39692250-2068	55002068	ACTIVO	2026-06-02 22:35:18.775974	2026-06-02 22:35:18.775974	0
a3110ab3-60e1-442e-b6c6-2d633ff887cf	93969226200002206	stress-39692262-2206@mediqueue.test	Paciente Stress 39692262-2206	55002206	ACTIVO	2026-06-02 22:35:20.021317	2026-06-02 22:35:20.021317	0
cc41488a-443c-489a-a565-92c173c7d11f	93969225800002270	stress-39692258-2270@mediqueue.test	Paciente Stress 39692258-2270	55002270	ACTIVO	2026-06-02 22:35:20.546035	2026-06-02 22:35:20.546035	0
09c140c7-9719-47c1-bece-dc5327a85d58	93969226200002583	stress-39692262-2583@mediqueue.test	Paciente Stress 39692262-2583	55002583	ACTIVO	2026-06-02 22:35:23.341997	2026-06-02 22:35:23.341997	0
18801c44-bef9-473f-a3c0-28b20fd7f660	93969226100003159	stress-39692261-3159@mediqueue.test	Paciente Stress 39692261-3159	55003159	ACTIVO	2026-06-02 22:35:28.765571	2026-06-02 22:35:28.765571	0
491d4826-20d3-4375-8a4a-03a7bd34e0bb	93969227500003337	stress-39692275-3337@mediqueue.test	Paciente Stress 39692275-3337	55003337	ACTIVO	2026-06-02 22:35:30.250443	2026-06-02 22:35:30.250443	0
42c9083d-1698-46df-973e-892219803fa7	93969227200003504	stress-39692272-3504@mediqueue.test	Paciente Stress 39692272-3504	55003504	ACTIVO	2026-06-02 22:35:31.812089	2026-06-02 22:35:31.812089	0
426c530e-26fb-4fd5-8f08-8b3e62f6e5ab	93969227200003629	stress-39692272-3629@mediqueue.test	Paciente Stress 39692272-3629	55003629	ACTIVO	2026-06-02 22:35:32.986442	2026-06-02 22:35:32.986442	0
dcb93b86-7ba5-430a-a575-d7dd782d1655	93969226500003736	stress-39692265-3736@mediqueue.test	Paciente Stress 39692265-3736	55003736	ACTIVO	2026-06-02 22:35:34.078739	2026-06-02 22:35:34.078739	0
78c55ece-bd7d-4c5e-99ef-fbeca43fbded	93969228000004070	stress-39692280-4070@mediqueue.test	Paciente Stress 39692280-4070	55004070	ACTIVO	2026-06-02 22:35:36.634434	2026-06-02 22:35:36.634434	0
ec689b15-b6dd-407a-bf85-5677c0682499	93969226800004709	stress-39692268-4709@mediqueue.test	Paciente Stress 39692268-4709	55004709	ACTIVO	2026-06-02 22:35:41.876753	2026-06-02 22:35:41.876753	0
ebf251dd-365f-40a8-99d1-66cf1c62c8d7	93969225200004840	stress-39692252-4840@mediqueue.test	Paciente Stress 39692252-4840	55004840	ACTIVO	2026-06-02 22:35:42.827854	2026-06-02 22:35:42.827854	0
3751c898-d7f7-4595-b755-5c1ec9603684	93969225200004881	stress-39692252-4881@mediqueue.test	Paciente Stress 39692252-4881	55004881	ACTIVO	2026-06-02 22:35:43.072449	2026-06-02 22:35:43.072449	0
c40035fe-9001-47c2-9eb5-71520bac9b25	93969226300004934	stress-39692263-4934@mediqueue.test	Paciente Stress 39692263-4934	55004934	ACTIVO	2026-06-02 22:35:43.585571	2026-06-02 22:35:43.585571	0
6bc129a3-1ac6-4920-9b63-2e840b87b91d	93979302600004411	stress-39793026-4411@mediqueue.test	Paciente Stress 39793026-4411	55004411	ACTIVO	2026-06-02 22:38:32.828884	2026-06-02 22:38:32.828884	0
4eee5fc8-8a79-4ff5-a678-3e1e084840e9	93979306000004545	stress-39793060-4545@mediqueue.test	Paciente Stress 39793060-4545	55004545	ACTIVO	2026-06-02 22:38:33.867589	2026-06-02 22:38:33.867589	0
6b4d9f62-d34e-443b-84a7-27e203ab05a8	93979295700004824	stress-39792957-4824@mediqueue.test	Paciente Stress 39792957-4824	55004824	ACTIVO	2026-06-02 22:38:34.545978	2026-06-02 22:38:34.545978	0
2f57b217-f8bb-4ade-a2d6-10cc0909abbd	93979301500005188	stress-39793015-5188@mediqueue.test	Paciente Stress 39793015-5188	55005188	ACTIVO	2026-06-02 22:38:37.261184	2026-06-02 22:38:37.261184	0
cb906eb9-2ce9-4260-80a8-48580d1ab716	93979305600005386	stress-39793056-5386@mediqueue.test	Paciente Stress 39793056-5386	55005386	ACTIVO	2026-06-02 22:38:38.893863	2026-06-02 22:38:38.893863	0
12449d8b-103d-4f32-a58f-d65764c5b37d	93979301600005595	stress-39793016-5595@mediqueue.test	Paciente Stress 39793016-5595	55005595	ACTIVO	2026-06-02 22:38:41.071423	2026-06-02 22:38:41.071423	0
7be82d07-7412-430d-b4fb-72c5623f18ae	93979299700005657	stress-39792997-5657@mediqueue.test	Paciente Stress 39792997-5657	55005657	ACTIVO	2026-06-02 22:38:41.529869	2026-06-02 22:38:41.529869	0
c673db10-72a0-4825-83f9-452498614690	93979298300005879	stress-39792983-5879@mediqueue.test	Paciente Stress 39792983-5879	55005879	ACTIVO	2026-06-02 22:38:43.665314	2026-06-02 22:38:43.665314	0
20748bc4-0b95-4092-938c-520c0966b787	93979300500005986	stress-39793005-5986@mediqueue.test	Paciente Stress 39793005-5986	55005986	ACTIVO	2026-06-02 22:38:44.638458	2026-06-02 22:38:44.638458	0
46c7b3e4-92dc-43cf-85f3-53c357b193ac	93979304000006135	stress-39793040-6135@mediqueue.test	Paciente Stress 39793040-6135	55006135	ACTIVO	2026-06-02 22:38:46.143549	2026-06-02 22:38:46.143549	0
d43a8aa7-1a38-4f98-99f8-19c63849299d	93979302600006282	stress-39793026-6282@mediqueue.test	Paciente Stress 39793026-6282	55006282	ACTIVO	2026-06-02 22:38:47.481274	2026-06-02 22:38:47.481274	0
58874c42-f1b5-4412-8180-249ed328c793	93979306300006368	stress-39793063-6368@mediqueue.test	Paciente Stress 39793063-6368	55006368	ACTIVO	2026-06-02 22:38:48.38477	2026-06-02 22:38:48.38477	0
105c51b0-a4cf-4312-a18b-191f81584865	93979306100006605	stress-39793061-6605@mediqueue.test	Paciente Stress 39793061-6605	55006605	ACTIVO	2026-06-02 22:40:35.405003	2026-06-02 22:40:35.405003	0
9cb6f1bd-f53c-46cf-a418-f7a34f47e43e	93979302600006589	stress-39793026-6589@mediqueue.test	Paciente Stress 39793026-6589	55006589	ACTIVO	2026-06-02 22:40:35.956716	2026-06-02 22:40:35.956716	0
701b4b25-fad2-49f2-a80b-10dc9e1fe158	93979306000007282	stress-39793060-7282@mediqueue.test	Paciente Stress 39793060-7282	55007282	ACTIVO	2026-06-02 22:40:39.634624	2026-06-02 22:40:39.634624	0
a74e1715-0936-4311-b87d-d6034e013368	93979298000007503	stress-39792980-7503@mediqueue.test	Paciente Stress 39792980-7503	55007503	ACTIVO	2026-06-02 22:40:41.529233	2026-06-02 22:40:41.529233	0
2267d315-170b-4132-8b0c-ef5cf2da0caa	93979300500008143	stress-39793005-8143@mediqueue.test	Paciente Stress 39793005-8143	55008143	ACTIVO	2026-06-02 22:40:46.338351	2026-06-02 22:40:46.338351	0
3a90ae62-104d-4f43-b3cd-79af76687a06	93979302400008614	stress-39793024-8614@mediqueue.test	Paciente Stress 39793024-8614	55008614	ACTIVO	2026-06-02 22:41:45.688344	2026-06-02 22:41:45.688344	0
a8b912ea-f1d2-4f0e-9316-d516ca073e84	93979306300008842	stress-39793063-8842@mediqueue.test	Paciente Stress 39793063-8842	55008842	ACTIVO	2026-06-02 22:41:46.216273	2026-06-02 22:41:46.216273	0
e8415b80-39e0-40bb-8250-edb6b9655e1b	94045691800007568	stress-40456918-7568@mediqueue.test	Paciente Stress 40456918-7568	55007568	ACTIVO	2026-06-02 22:48:50.116813	2026-06-02 22:48:50.116813	0
af6a9ae2-0d7c-483f-92f9-3b01bacbf4c8	94045692500007606	stress-40456925-7606@mediqueue.test	Paciente Stress 40456925-7606	55007606	ACTIVO	2026-06-02 22:48:50.418108	2026-06-02 22:48:50.418108	0
e9123733-1ecf-4b40-9ede-3bd5e181a311	94045692200007836	stress-40456922-7836@mediqueue.test	Paciente Stress 40456922-7836	55007836	ACTIVO	2026-06-02 22:49:28.658499	2026-06-02 22:49:28.658499	0
03f08c73-5520-46b8-a076-043ab087caf8	94045695600007831	stress-40456956-7831@mediqueue.test	Paciente Stress 40456956-7831	55007831	ACTIVO	2026-06-02 22:49:29.882501	2026-06-02 22:49:29.882501	0
a1396ed1-146c-4f4e-a965-c37b1f3e3d1e	94045695900008026	stress-40456959-8026@mediqueue.test	Paciente Stress 40456959-8026	55008026	ACTIVO	2026-06-02 22:49:30.568831	2026-06-02 22:49:30.568831	0
a047e044-e05a-4c54-9782-5b3284d4fd17	94045696200008041	stress-40456962-8041@mediqueue.test	Paciente Stress 40456962-8041	55008041	ACTIVO	2026-06-02 22:49:30.830968	2026-06-02 22:49:30.830968	0
dd38a093-432f-4aee-9d31-560750750482	94045694700008259	stress-40456947-8259@mediqueue.test	Paciente Stress 40456947-8259	55008259	ACTIVO	2026-06-02 22:49:31.55709	2026-06-02 22:49:31.55709	0
cd917deb-2ebe-469c-9bf7-053b9fb9617e	94045695300008287	stress-40456953-8287@mediqueue.test	Paciente Stress 40456953-8287	55008287	ACTIVO	2026-06-02 22:49:31.678048	2026-06-02 22:49:31.678048	0
5f5d0af7-e98e-4093-aa7e-644e670e4c81	94045693800008448	stress-40456938-8448@mediqueue.test	Paciente Stress 40456938-8448	55008448	ACTIVO	2026-06-02 22:49:33.519005	2026-06-02 22:49:33.519005	0
919e7287-3ba5-4507-b03e-c7f9d09c688e	94045694000008490	stress-40456940-8490@mediqueue.test	Paciente Stress 40456940-8490	55008490	ACTIVO	2026-06-02 22:49:33.995602	2026-06-02 22:49:33.995602	0
af2c9625-3c99-44a2-a091-9858d60a4cad	93969227800001208	stress-39692278-1208@mediqueue.test	Paciente Stress 39692278-1208	55001208	ACTIVO	2026-06-02 22:35:10.320059	2026-06-02 22:35:10.320059	0
fb6c4baf-3c2d-45ba-b3d5-1722dbe886ab	93969227700001537	stress-39692277-1537@mediqueue.test	Paciente Stress 39692277-1537	55001537	ACTIVO	2026-06-02 22:35:13.663838	2026-06-02 22:35:13.663838	0
88941dd1-b129-48e5-82c4-362cb25c5b14	93969225300001629	stress-39692253-1629@mediqueue.test	Paciente Stress 39692253-1629	55001629	ACTIVO	2026-06-02 22:35:14.31938	2026-06-02 22:35:14.31938	0
e6363013-9fe8-4c3b-8e2a-bfacd25c0a91	93969227900001760	stress-39692279-1760@mediqueue.test	Paciente Stress 39692279-1760	55001760	ACTIVO	2026-06-02 22:35:15.460348	2026-06-02 22:35:15.460348	0
67796ba5-fa0a-4b3f-a9f5-60b574dc5f01	93969227300001776	stress-39692273-1776@mediqueue.test	Paciente Stress 39692273-1776	55001776	ACTIVO	2026-06-02 22:35:15.592487	2026-06-02 22:35:15.592487	0
9b10a39b-9870-4591-b37d-7701375f2d48	93969225300002129	stress-39692253-2129@mediqueue.test	Paciente Stress 39692253-2129	55002129	ACTIVO	2026-06-02 22:35:19.222469	2026-06-02 22:35:19.222469	0
0ff6128d-4fe4-4089-ba46-2c6cf3f9e511	93969227800002316	stress-39692278-2316@mediqueue.test	Paciente Stress 39692278-2316	55002316	ACTIVO	2026-06-02 22:35:21.171267	2026-06-02 22:35:21.171267	0
25c7ea57-673f-45bc-a4c0-379afebcc7f3	93969225700002485	stress-39692257-2485@mediqueue.test	Paciente Stress 39692257-2485	55002485	ACTIVO	2026-06-02 22:35:22.603137	2026-06-02 22:35:22.603137	0
332011f2-b880-408f-b257-831a46e5cb41	93969228000002592	stress-39692280-2592@mediqueue.test	Paciente Stress 39692280-2592	55002592	ACTIVO	2026-06-02 22:35:23.481562	2026-06-02 22:35:23.481562	0
0f48e644-1883-4ea4-b666-fbea24f9e8ed	93969227900002793	stress-39692279-2793@mediqueue.test	Paciente Stress 39692279-2793	55002793	ACTIVO	2026-06-02 22:35:25.40124	2026-06-02 22:35:25.40124	0
7fe710c4-16e0-472a-b43f-4b2533dd179c	93969225700002855	stress-39692257-2855@mediqueue.test	Paciente Stress 39692257-2855	55002855	ACTIVO	2026-06-02 22:35:26.022397	2026-06-02 22:35:26.022397	0
e73dac14-ad31-4180-a585-cf7205567ea0	93969225500003129	stress-39692255-3129@mediqueue.test	Paciente Stress 39692255-3129	55003129	ACTIVO	2026-06-02 22:35:28.43501	2026-06-02 22:35:28.43501	0
72e08841-b005-4655-940b-58b97ee5cfd4	93969226900003197	stress-39692269-3197@mediqueue.test	Paciente Stress 39692269-3197	55003197	ACTIVO	2026-06-02 22:35:29.06298	2026-06-02 22:35:29.06298	0
2648414c-4967-4c20-9d6d-7d401fe329fa	93969226300003294	stress-39692263-3294@mediqueue.test	Paciente Stress 39692263-3294	55003294	ACTIVO	2026-06-02 22:35:29.885103	2026-06-02 22:35:29.885103	0
a833b87c-ca45-4b75-ad76-b3e423c2bf12	93969225700003426	stress-39692257-3426@mediqueue.test	Paciente Stress 39692257-3426	55003426	ACTIVO	2026-06-02 22:35:31.115853	2026-06-02 22:35:31.115853	0
b6b8f7e7-c9a4-4e6b-92d9-24c4a0cf334f	93969225700003662	stress-39692257-3662@mediqueue.test	Paciente Stress 39692257-3662	55003662	ACTIVO	2026-06-02 22:35:33.269511	2026-06-02 22:35:33.269511	0
b7e93c7b-b2cf-4245-bf67-2d4fcbe74205	93969225500003780	stress-39692255-3780@mediqueue.test	Paciente Stress 39692255-3780	55003780	ACTIVO	2026-06-02 22:35:34.412832	2026-06-02 22:35:34.412832	0
65177363-408e-4b13-a9f8-222f78307d0d	93969228000004110	stress-39692280-4110@mediqueue.test	Paciente Stress 39692280-4110	55004110	ACTIVO	2026-06-02 22:35:36.975515	2026-06-02 22:35:36.975515	0
988f3a17-0e6c-45ba-87bb-fa185f99dbf9	93969228000004305	stress-39692280-4305@mediqueue.test	Paciente Stress 39692280-4305	55004305	ACTIVO	2026-06-02 22:35:38.426043	2026-06-02 22:35:38.426043	0
83004870-21b4-4bf0-b1aa-74c0ecb0b438	93969225000004519	stress-39692250-4519@mediqueue.test	Paciente Stress 39692250-4519	55004519	ACTIVO	2026-06-02 22:35:40.083861	2026-06-02 22:35:40.083861	0
08d1001d-20b9-43ef-9ba8-d3c3cce8102e	93969226400004770	stress-39692264-4770@mediqueue.test	Paciente Stress 39692264-4770	55004770	ACTIVO	2026-06-02 22:35:42.312739	2026-06-02 22:35:42.312739	0
2ddea9e5-e4ae-4217-850d-4f14494bf8dd	93969226300004969	stress-39692263-4969@mediqueue.test	Paciente Stress 39692263-4969	55004969	ACTIVO	2026-06-02 22:35:43.992422	2026-06-02 22:35:43.992422	0
1bf46829-af33-4d65-8a3d-3c47e39e9bee	93979295300004415	stress-39792953-4415@mediqueue.test	Paciente Stress 39792953-4415	55004415	ACTIVO	2026-06-02 22:38:32.958919	2026-06-02 22:38:32.958919	0
dbedba8e-fa3a-4815-9642-8f8505ad50fc	93979303900004873	stress-39793039-4873@mediqueue.test	Paciente Stress 39793039-4873	55004873	ACTIVO	2026-06-02 22:38:34.608339	2026-06-02 22:38:34.608339	0
1c71b841-b45b-4583-a408-8a65833834e0	93979299700005200	stress-39792997-5200@mediqueue.test	Paciente Stress 39792997-5200	55005200	ACTIVO	2026-06-02 22:38:37.295989	2026-06-02 22:38:37.295989	0
2df16e12-2dbd-480a-803b-b2b951a28768	93979302400005225	stress-39793024-5225@mediqueue.test	Paciente Stress 39793024-5225	55005225	ACTIVO	2026-06-02 22:38:37.55591	2026-06-02 22:38:37.55591	0
d99855de-4f31-4b7d-9af4-2e02b1316e70	93979297700005390	stress-39792977-5390@mediqueue.test	Paciente Stress 39792977-5390	55005390	ACTIVO	2026-06-02 22:38:39.028359	2026-06-02 22:38:39.028359	0
14e02942-3b45-4fd9-ba9f-790b82f38e9f	93979301400005666	stress-39793014-5666@mediqueue.test	Paciente Stress 39793014-5666	55005666	ACTIVO	2026-06-02 22:38:41.701889	2026-06-02 22:38:41.701889	0
6e7ed534-83d1-4725-b19a-2a4710294842	93979297900005780	stress-39792979-5780@mediqueue.test	Paciente Stress 39792979-5780	55005780	ACTIVO	2026-06-02 22:38:42.790388	2026-06-02 22:38:42.790388	0
b62a8d07-a685-46e5-aa5f-3d4b6a06ad16	93979297700005881	stress-39792977-5881@mediqueue.test	Paciente Stress 39792977-5881	55005881	ACTIVO	2026-06-02 22:38:43.628353	2026-06-02 22:38:43.628353	0
6157b93e-659a-407f-972b-37e9bbb6a18c	93979298000006018	stress-39792980-6018@mediqueue.test	Paciente Stress 39792980-6018	55006018	ACTIVO	2026-06-02 22:38:44.90206	2026-06-02 22:38:44.90206	0
7888d9de-309e-4a25-833c-d16c4f04a1c8	93979306100006132	stress-39793061-6132@mediqueue.test	Paciente Stress 39793061-6132	55006132	ACTIVO	2026-06-02 22:38:46.092823	2026-06-02 22:38:46.092823	0
d50520f8-7ec7-4bdf-9f08-7f5e73299fa9	93979300300006158	stress-39793003-6158@mediqueue.test	Paciente Stress 39793003-6158	55006158	ACTIVO	2026-06-02 22:38:46.361354	2026-06-02 22:38:46.361354	0
6870ac09-aea5-40a1-adf6-9250eb4a7dc1	93979298000006861	stress-39792980-6861@mediqueue.test	Paciente Stress 39792980-6861	55006861	ACTIVO	2026-06-02 22:40:37.087964	2026-06-02 22:40:37.087964	0
a6e1c39d-975f-4083-90c8-2f74222491b5	93979297900007117	stress-39792979-7117@mediqueue.test	Paciente Stress 39792979-7117	55007117	ACTIVO	2026-06-02 22:40:38.534591	2026-06-02 22:40:38.534591	0
28eea221-f571-4fd3-bf8d-de013d1e4406	93979300000007375	stress-39793000-7375@mediqueue.test	Paciente Stress 39793000-7375	55007375	ACTIVO	2026-06-02 22:40:40.316005	2026-06-02 22:40:40.316005	0
b5837e21-1d35-467c-be5a-d89b53cc2bdc	93979297400007463	stress-39792974-7463@mediqueue.test	Paciente Stress 39792974-7463	55007463	ACTIVO	2026-06-02 22:40:41.139414	2026-06-02 22:40:41.139414	0
df0b1ebd-c0d4-4267-b3f6-67c0f8529d3d	93979296900007699	stress-39792969-7699@mediqueue.test	Paciente Stress 39792969-7699	55007699	ACTIVO	2026-06-02 22:40:43.221064	2026-06-02 22:40:43.221064	0
a4b6fa05-84ae-4784-bf53-6b985fcd12dd	93979305900007772	stress-39793059-7772@mediqueue.test	Paciente Stress 39793059-7772	55007772	ACTIVO	2026-06-02 22:40:43.749533	2026-06-02 22:40:43.749533	0
ddbf3ac0-5131-4a3d-9741-2de2806e4442	93979297700007830	stress-39792977-7830@mediqueue.test	Paciente Stress 39792977-7830	55007830	ACTIVO	2026-06-02 22:40:44.112325	2026-06-02 22:40:44.112325	0
aa8f2c8f-ce1c-4fdf-b798-b6c2d430717f	93979300500008115	stress-39793005-8115@mediqueue.test	Paciente Stress 39793005-8115	55008115	ACTIVO	2026-06-02 22:40:46.104036	2026-06-02 22:40:46.104036	0
23a0a6a6-47ec-43c2-b72a-7d1f80b342ea	93979300500008278	stress-39793005-8278@mediqueue.test	Paciente Stress 39793005-8278	55008278	ACTIVO	2026-06-02 22:40:47.513056	2026-06-02 22:40:47.513056	0
e43b5b2d-9740-4cf5-996e-82534aa3f752	93979297600008474	stress-39792976-8474@mediqueue.test	Paciente Stress 39792976-8474	55008474	ACTIVO	2026-06-02 22:40:49.42114	2026-06-02 22:40:49.42114	0
83003418-3095-49d8-b5f9-236e3732949b	93979306100008501	stress-39793061-8501@mediqueue.test	Paciente Stress 39793061-8501	55008501	ACTIVO	2026-06-02 22:41:45.190805	2026-06-02 22:41:45.190805	0
3f39dbc9-2e5a-4cae-afe8-120bd26a1038	93979297900008756	stress-39792979-8756@mediqueue.test	Paciente Stress 39792979-8756	55008756	ACTIVO	2026-06-02 22:41:45.91472	2026-06-02 22:41:45.91472	0
cacf781b-e8be-4d74-bdea-656332d51992	93979298300008726	stress-39792983-8726@mediqueue.test	Paciente Stress 39792983-8726	55008726	ACTIVO	2026-06-02 22:41:46.105326	2026-06-02 22:41:46.105326	0
9b68ab6c-e453-422f-a937-9edb7f9a4659	94045694700008100	stress-40456947-8100@mediqueue.test	Paciente Stress 40456947-8100	55008100	ACTIVO	2026-06-02 22:49:31.022478	2026-06-02 22:49:31.022478	0
659be3b2-80c5-4b50-8454-a58ce99b6c34	93969227900002478	stress-39692279-2478@mediqueue.test	Paciente Stress 39692279-2478	55002478	ACTIVO	2026-06-02 22:35:22.510721	2026-06-02 22:35:22.510721	0
1ec76d0e-2571-4509-b4ba-536b4429bb1e	93969228000002596	stress-39692280-2596@mediqueue.test	Paciente Stress 39692280-2596	55002596	ACTIVO	2026-06-02 22:35:23.548778	2026-06-02 22:35:23.548778	0
d9fda73d-0b12-49a0-a3d2-ec844b876976	93969227600002945	stress-39692276-2945@mediqueue.test	Paciente Stress 39692276-2945	55002945	ACTIVO	2026-06-02 22:35:26.765208	2026-06-02 22:35:26.765208	0
5db04f45-80cb-47a8-a94a-4482c1fae421	93969226500003135	stress-39692265-3135@mediqueue.test	Paciente Stress 39692265-3135	55003135	ACTIVO	2026-06-02 22:35:28.54609	2026-06-02 22:35:28.54609	0
e5960d57-0d0d-4a60-9f0a-62d1b19a2de2	93969226700003275	stress-39692267-3275@mediqueue.test	Paciente Stress 39692267-3275	55003275	ACTIVO	2026-06-02 22:35:29.752938	2026-06-02 22:35:29.752938	0
c3393737-2831-4b4d-b5f2-abe6427a235d	93969224700003407	stress-39692247-3407@mediqueue.test	Paciente Stress 39692247-3407	55003407	ACTIVO	2026-06-02 22:35:30.942444	2026-06-02 22:35:30.942444	0
86a3c8a3-b27c-4908-9853-621b56a99f20	93969226200003767	stress-39692262-3767@mediqueue.test	Paciente Stress 39692262-3767	55003767	ACTIVO	2026-06-02 22:35:34.274427	2026-06-02 22:35:34.274427	0
9da1cd8f-c6ca-4841-b982-1ae4f8753fbb	93969226500004035	stress-39692265-4035@mediqueue.test	Paciente Stress 39692265-4035	55004035	ACTIVO	2026-06-02 22:35:36.486668	2026-06-02 22:35:36.486668	0
c63b7b2e-f1d4-4560-84d5-882bb4b4bda9	93969227900004393	stress-39692279-4393@mediqueue.test	Paciente Stress 39692279-4393	55004393	ACTIVO	2026-06-02 22:35:39.01283	2026-06-02 22:35:39.01283	0
acc8a464-a881-475f-a750-001f84e22de0	93979302300004548	stress-39793023-4548@mediqueue.test	Paciente Stress 39793023-4548	55004548	ACTIVO	2026-06-02 22:38:33.143035	2026-06-02 22:38:33.143035	0
209c82a6-0c5e-423e-86fe-18f1032f2296	93979298400004467	stress-39792984-4467@mediqueue.test	Paciente Stress 39792984-4467	55004467	ACTIVO	2026-06-02 22:38:33.321391	2026-06-02 22:38:33.321391	0
c3bc2d7d-c86c-4c53-bba6-00705229afdc	93979298300004772	stress-39792983-4772@mediqueue.test	Paciente Stress 39792983-4772	55004772	ACTIVO	2026-06-02 22:38:34.051061	2026-06-02 22:38:34.051061	0
d8b4c892-05e2-4c37-8036-b1ebcd99b41c	93979300700004869	stress-39793007-4869@mediqueue.test	Paciente Stress 39793007-4869	55004869	ACTIVO	2026-06-02 22:38:34.838961	2026-06-02 22:38:34.838961	0
7d7f9a65-e1a9-4a9e-8787-2c6e9f3c9ee7	93979297400004916	stress-39792974-4916@mediqueue.test	Paciente Stress 39792974-4916	55004916	ACTIVO	2026-06-02 22:38:34.954122	2026-06-02 22:38:34.954122	0
68f98d5c-06dd-49c2-94b6-7c16822373c4	93979300700004971	stress-39793007-4971@mediqueue.test	Paciente Stress 39793007-4971	55004971	ACTIVO	2026-06-02 22:38:35.346132	2026-06-02 22:38:35.346132	0
4d2a7e71-4231-423e-9d2b-75ff045a3b25	93979295800005078	stress-39792958-5078@mediqueue.test	Paciente Stress 39792958-5078	55005078	ACTIVO	2026-06-02 22:38:36.29897	2026-06-02 22:38:36.29897	0
b13ae664-0060-423f-b334-23a2fb288940	93979302400005269	stress-39793024-5269@mediqueue.test	Paciente Stress 39793024-5269	55005269	ACTIVO	2026-06-02 22:38:37.904411	2026-06-02 22:38:37.904411	0
60a6abe4-e7bf-4800-abd9-e951799b3921	93979306100005478	stress-39793061-5478@mediqueue.test	Paciente Stress 39793061-5478	55005478	ACTIVO	2026-06-02 22:38:39.876521	2026-06-02 22:38:39.876521	0
e7dbe976-d69c-4b22-ae0a-4cbb2aadbe12	93979295400005880	stress-39792954-5880@mediqueue.test	Paciente Stress 39792954-5880	55005880	ACTIVO	2026-06-02 22:38:43.625236	2026-06-02 22:38:43.625236	0
e4f966e4-1c8e-4b5e-ae6e-32e1c7c274cd	93979300000006127	stress-39793000-6127@mediqueue.test	Paciente Stress 39793000-6127	55006127	ACTIVO	2026-06-02 22:38:46.093608	2026-06-02 22:38:46.093608	0
da7a0e94-b580-4493-b2fe-a0112b2e9c6c	93979297700006359	stress-39792977-6359@mediqueue.test	Paciente Stress 39792977-6359	55006359	ACTIVO	2026-06-02 22:38:48.318693	2026-06-02 22:38:48.318693	0
50c59be6-f1fd-45de-a37c-b0ef3bf920cb	93979304600007133	stress-39793046-7133@mediqueue.test	Paciente Stress 39793046-7133	55007133	ACTIVO	2026-06-02 22:40:38.726473	2026-06-02 22:40:38.726473	0
95ba9db9-1aa1-4cad-ba5e-94d79d0bd29c	93979306100007272	stress-39793061-7272@mediqueue.test	Paciente Stress 39793061-7272	55007272	ACTIVO	2026-06-02 22:40:39.516653	2026-06-02 22:40:39.516653	0
da7e6d72-e4d3-4091-91b4-726ff0a7480e	93979306000007676	stress-39793060-7676@mediqueue.test	Paciente Stress 39793060-7676	55007676	ACTIVO	2026-06-02 22:40:43.025876	2026-06-02 22:40:43.025876	0
3bee56bd-88ac-48c7-8f2e-e33b67b6fb58	94045693100008251	stress-40456931-8251@mediqueue.test	Paciente Stress 40456931-8251	55008251	ACTIVO	2026-06-02 22:49:31.28584	2026-06-02 22:49:31.28584	0
311a10a0-8584-4d8e-954c-53876561920f	94045693100008439	stress-40456931-8439@mediqueue.test	Paciente Stress 40456931-8439	55008439	ACTIVO	2026-06-02 22:49:33.299426	2026-06-02 22:49:33.299426	0
fac7b975-a92e-4b09-9689-66981282c225	94045693100008493	stress-40456931-8493@mediqueue.test	Paciente Stress 40456931-8493	55008493	ACTIVO	2026-06-02 22:49:33.91734	2026-06-02 22:49:33.91734	0
d37d58fa-b192-44a3-bbfc-75cad1a48fd2	94045695200008664	stress-40456952-8664@mediqueue.test	Paciente Stress 40456952-8664	55008664	ACTIVO	2026-06-02 22:49:35.650336	2026-06-02 22:49:35.650336	0
8cb0df21-80a2-4008-b1fb-d9916747a284	94045692900008692	stress-40456929-8692@mediqueue.test	Paciente Stress 40456929-8692	55008692	ACTIVO	2026-06-02 22:49:35.860594	2026-06-02 22:49:35.860594	0
b01cf33d-c00d-473f-94ad-31ed315a5082	94045692100008845	stress-40456921-8845@mediqueue.test	Paciente Stress 40456921-8845	55008845	ACTIVO	2026-06-02 22:49:37.113506	2026-06-02 22:49:37.113506	0
81a887f0-3361-42f3-ac7c-ae1ad02cfcd6	94045696900009234	stress-40456969-9234@mediqueue.test	Paciente Stress 40456969-9234	55009234	ACTIVO	2026-06-02 22:49:40.766199	2026-06-02 22:49:40.766199	0
a7f5db39-4ba2-457a-841c-925eba7e110b	94045696400009253	stress-40456964-9253@mediqueue.test	Paciente Stress 40456964-9253	55009253	ACTIVO	2026-06-02 22:49:41.091623	2026-06-02 22:49:41.091623	0
5c022934-82c4-4cbe-a1ee-476298f9930e	94045693200009515	stress-40456932-9515@mediqueue.test	Paciente Stress 40456932-9515	55009515	ACTIVO	2026-06-02 22:49:43.615142	2026-06-02 22:49:43.615142	0
2962da44-6911-46e6-81ae-9100a170d795	94045692900009713	stress-40456929-9713@mediqueue.test	Paciente Stress 40456929-9713	55009713	ACTIVO	2026-06-02 22:51:03.528937	2026-06-02 22:51:03.528937	0
7d08044d-ba21-4456-b6cd-12890df83bd9	94045692800009837	stress-40456928-9837@mediqueue.test	Paciente Stress 40456928-9837	55009837	ACTIVO	2026-06-02 22:51:05.74555	2026-06-02 22:51:05.74555	0
eb4a3eed-c0a6-4dcd-b397-f30f3d8b1c77	94070648400000030	stress-40706484-30@mediqueue.test	Paciente Stress 40706484-30	55000030	ACTIVO	2026-06-02 22:51:47.850325	2026-06-02 22:51:47.850325	0
59f2975b-d58c-4c3c-954c-da6dbc210c84	94070646000000067	stress-40706460-67@mediqueue.test	Paciente Stress 40706460-67	55000067	ACTIVO	2026-06-02 22:51:49.319693	2026-06-02 22:51:49.319693	0
f9a47cc3-1c35-4d48-8cb7-80497854cff4	94070644800000429	stress-40706448-429@mediqueue.test	Paciente Stress 40706448-429	55000429	ACTIVO	2026-06-02 22:51:50.821795	2026-06-02 22:51:50.821795	0
84da6abd-6152-44b7-88a2-c330e8819adf	94070647200000370	stress-40706472-370@mediqueue.test	Paciente Stress 40706472-370	55000370	ACTIVO	2026-06-02 22:51:50.949004	2026-06-02 22:51:50.949004	0
9ba6bff7-ffd1-4e6b-acf5-31fcf35e4ec0	94070644900000255	stress-40706449-255@mediqueue.test	Paciente Stress 40706449-255	55000255	ACTIVO	2026-06-02 22:51:51.409771	2026-06-02 22:51:51.409771	0
c4c1ca7c-39fb-4a8d-8c0c-be79715713a4	94070648400000710	stress-40706484-710@mediqueue.test	Paciente Stress 40706484-710	55000710	ACTIVO	2026-06-02 22:51:53.269118	2026-06-02 22:51:53.269118	0
b55385bd-dd45-414a-963a-fdea0198a4dd	94070642500000778	stress-40706425-778@mediqueue.test	Paciente Stress 40706425-778	55000778	ACTIVO	2026-06-02 22:51:53.880167	2026-06-02 22:51:53.880167	0
5a43783c-eea8-4ad2-9239-81807317ac7e	94070648000000839	stress-40706480-839@mediqueue.test	Paciente Stress 40706480-839	55000839	ACTIVO	2026-06-02 22:51:54.878557	2026-06-02 22:51:54.878557	0
286277e5-f4f9-4427-9e9a-bf8bf67f865e	94070649000000881	stress-40706490-881@mediqueue.test	Paciente Stress 40706490-881	55000881	ACTIVO	2026-06-02 22:51:55.138188	2026-06-02 22:51:55.138188	0
f0a0abf2-fa19-4d82-886a-db65f959ba04	94070649000000911	stress-40706490-911@mediqueue.test	Paciente Stress 40706490-911	55000911	ACTIVO	2026-06-02 22:51:55.475736	2026-06-02 22:51:55.475736	0
ecaee7b2-739d-4fdf-84b4-0c6465ffb3dc	94070644200001123	stress-40706442-1123@mediqueue.test	Paciente Stress 40706442-1123	55001123	ACTIVO	2026-06-02 22:51:57.996307	2026-06-02 22:51:57.996307	0
30782c2f-9eba-4747-b784-6340df1ce6a2	94070643900001661	stress-40706439-1661@mediqueue.test	Paciente Stress 40706439-1661	55001661	ACTIVO	2026-06-02 22:52:03.028906	2026-06-02 22:52:03.028906	0
7a091da1-d08d-4e78-a8df-534484164313	93979302300004473	stress-39793023-4473@mediqueue.test	Paciente Stress 39793023-4473	55004473	ACTIVO	2026-06-02 22:38:33.632944	2026-06-02 22:38:33.632944	0
9e594a87-b4de-4345-b016-f1382e96fd9d	93979300100004733	stress-39793001-4733@mediqueue.test	Paciente Stress 39793001-4733	55004733	ACTIVO	2026-06-02 22:38:34.363852	2026-06-02 22:38:34.363852	0
00b76a24-b20e-4507-a46e-b48dc07f77f5	93979299600004822	stress-39792996-4822@mediqueue.test	Paciente Stress 39792996-4822	55004822	ACTIVO	2026-06-02 22:38:34.685274	2026-06-02 22:38:34.685274	0
746d9355-223c-421a-9794-bc70c7f81f02	93979298500004905	stress-39792985-4905@mediqueue.test	Paciente Stress 39792985-4905	55004905	ACTIVO	2026-06-02 22:38:34.887214	2026-06-02 22:38:34.887214	0
905ae953-d461-44a2-b716-3431a9ecef07	93979297900005683	stress-39792979-5683@mediqueue.test	Paciente Stress 39792979-5683	55005683	ACTIVO	2026-06-02 22:38:41.947981	2026-06-02 22:38:41.947981	0
d0da9b8e-dc15-4c77-bccf-7246e1c6eef3	93979296000006022	stress-39792960-6022@mediqueue.test	Paciente Stress 39792960-6022	55006022	ACTIVO	2026-06-02 22:38:44.954062	2026-06-02 22:38:44.954062	0
2820c4ca-11e8-4281-b3a3-6c393dddf756	93979296400006833	stress-39792964-6833@mediqueue.test	Paciente Stress 39792964-6833	55006833	ACTIVO	2026-06-02 22:40:36.169368	2026-06-02 22:40:36.169368	0
83426d9a-5df9-4900-a1c3-85a56978f971	93979304300006768	stress-39793043-6768@mediqueue.test	Paciente Stress 39793043-6768	55006768	ACTIVO	2026-06-02 22:40:36.33061	2026-06-02 22:40:36.33061	0
777ad6a4-e663-4091-8550-51f77b23ef0c	93979305900006776	stress-39793059-6776@mediqueue.test	Paciente Stress 39793059-6776	55006776	ACTIVO	2026-06-02 22:40:36.965955	2026-06-02 22:40:36.965955	0
29fd0d92-b610-44b4-91a3-552490fb50e2	93979306100007061	stress-39793061-7061@mediqueue.test	Paciente Stress 39793061-7061	55007061	ACTIVO	2026-06-02 22:40:38.102777	2026-06-02 22:40:38.102777	0
3b2fdae5-473e-4b48-9b09-fa17b0d8bd0c	93979306300008504	stress-39793063-8504@mediqueue.test	Paciente Stress 39793063-8504	55008504	ACTIVO	2026-06-02 22:41:45.455066	2026-06-02 22:41:45.455066	0
25146375-f154-4b26-a20c-432dddfe9d8b	94045695400008282	stress-40456954-8282@mediqueue.test	Paciente Stress 40456954-8282	55008282	ACTIVO	2026-06-02 22:49:31.65837	2026-06-02 22:49:31.65837	0
c5b7ddb9-54a9-4cbd-8f45-f9dde64f699f	94045695900008487	stress-40456959-8487@mediqueue.test	Paciente Stress 40456959-8487	55008487	ACTIVO	2026-06-02 22:49:33.822495	2026-06-02 22:49:33.822495	0
2e18c421-88ca-4c8c-95c9-1d8a8aa96bbe	94045692000008540	stress-40456920-8540@mediqueue.test	Paciente Stress 40456920-8540	55008540	ACTIVO	2026-06-02 22:49:34.245716	2026-06-02 22:49:34.245716	0
f98e6f42-e4e9-4aa4-bba0-38acede4c4a4	94045691800008837	stress-40456918-8837@mediqueue.test	Paciente Stress 40456918-8837	55008837	ACTIVO	2026-06-02 22:49:37.051646	2026-06-02 22:49:37.051646	0
facb8f8f-5ffe-4fea-8657-d80969845376	94045691200009113	stress-40456912-9113@mediqueue.test	Paciente Stress 40456912-9113	55009113	ACTIVO	2026-06-02 22:49:39.628801	2026-06-02 22:49:39.628801	0
54e817da-3580-4ed1-856d-92d122fcd74b	94045694700009208	stress-40456947-9208@mediqueue.test	Paciente Stress 40456947-9208	55009208	ACTIVO	2026-06-02 22:49:40.535079	2026-06-02 22:49:40.535079	0
9fc3042e-8d0a-427d-95a9-60db0bd11e32	94045696400009256	stress-40456964-9256@mediqueue.test	Paciente Stress 40456964-9256	55009256	ACTIVO	2026-06-02 22:49:40.939977	2026-06-02 22:49:40.939977	0
b8988c69-8467-4dd3-8525-fc9610a5caae	94045695100009289	stress-40456951-9289@mediqueue.test	Paciente Stress 40456951-9289	55009289	ACTIVO	2026-06-02 22:49:41.242579	2026-06-02 22:49:41.242579	0
4c801a56-bd3d-40b5-aa6e-263b9b528f63	94045693100009850	stress-40456931-9850@mediqueue.test	Paciente Stress 40456931-9850	55009850	ACTIVO	2026-06-02 22:51:05.756008	2026-06-02 22:51:05.756008	0
3a687215-f099-4b4e-bf2a-1191b52a7a20	94070643500000127	stress-40706435-127@mediqueue.test	Paciente Stress 40706435-127	55000127	ACTIVO	2026-06-02 22:51:49.44474	2026-06-02 22:51:49.44474	0
603e77ee-7a02-469f-b074-1dd740b32c34	94070643000000774	stress-40706430-774@mediqueue.test	Paciente Stress 40706430-774	55000774	ACTIVO	2026-06-02 22:51:53.797659	2026-06-02 22:51:53.797659	0
7dfcd487-deb4-4ea7-ba14-0b35bd1e3b80	94070647600001653	stress-40706476-1653@mediqueue.test	Paciente Stress 40706476-1653	55001653	ACTIVO	2026-06-02 22:52:02.978241	2026-06-02 22:52:02.978241	0
86b11e35-cf15-432c-bf10-aa159c7d2103	94070645200001752	stress-40706452-1752@mediqueue.test	Paciente Stress 40706452-1752	55001752	ACTIVO	2026-06-02 22:52:03.874582	2026-06-02 22:52:03.874582	0
9201af0a-fa16-4630-81f6-3c04ac11de4d	94070647000001951	stress-40706470-1951@mediqueue.test	Paciente Stress 40706470-1951	55001951	ACTIVO	2026-06-02 22:53:12.476414	2026-06-02 22:53:12.476414	0
ca123a84-7240-42a2-ba77-1bd10deb33d2	94070645200002071	stress-40706452-2071@mediqueue.test	Paciente Stress 40706452-2071	55002071	ACTIVO	2026-06-02 22:53:13.479871	2026-06-02 22:53:13.479871	0
2bb3fedc-b275-4971-9415-9744f45f4a58	94070647000002163	stress-40706470-2163@mediqueue.test	Paciente Stress 40706470-2163	55002163	ACTIVO	2026-06-02 22:53:13.885254	2026-06-02 22:53:13.885254	0
6a37de98-7ac5-4063-87ba-03423d4841f4	94070645100001909	stress-40706451-1909@mediqueue.test	Paciente Stress 40706451-1909	55001909	ACTIVO	2026-06-02 22:53:14.835752	2026-06-02 22:53:14.835752	0
a4ad13a9-2d43-4392-9fae-44d8774f789f	94070644600002379	stress-40706446-2379@mediqueue.test	Paciente Stress 40706446-2379	55002379	ACTIVO	2026-06-02 22:53:15.910463	2026-06-02 22:53:15.910463	0
d9831bfa-5457-4631-97bf-55b6b50f8789	94070642200002387	stress-40706422-2387@mediqueue.test	Paciente Stress 40706422-2387	55002387	ACTIVO	2026-06-02 22:53:15.989191	2026-06-02 22:53:15.989191	0
b984eb7d-d285-45f5-bc90-a40ac996716b	94070649000002406	stress-40706490-2406@mediqueue.test	Paciente Stress 40706490-2406	55002406	ACTIVO	2026-06-02 22:53:16.433349	2026-06-02 22:53:16.433349	0
69586b4e-d91e-4bbc-8c2a-177828b029c4	94070645900002476	stress-40706459-2476@mediqueue.test	Paciente Stress 40706459-2476	55002476	ACTIVO	2026-06-02 22:53:16.513314	2026-06-02 22:53:16.513314	0
1ac881e0-06c6-4758-9141-4cf41ea22166	94070645300002280	stress-40706453-2280@mediqueue.test	Paciente Stress 40706453-2280	55002280	ACTIVO	2026-06-02 22:53:16.575144	2026-06-02 22:53:16.575144	0
280ba54f-9148-4a3e-b3ff-49cd2422f8a7	94070646400002497	stress-40706464-2497@mediqueue.test	Paciente Stress 40706464-2497	55002497	ACTIVO	2026-06-02 22:53:17.89722	2026-06-02 22:53:17.89722	0
fe021dde-ee2e-43f5-83f7-beafb7fdb21e	94070642400002600	stress-40706424-2600@mediqueue.test	Paciente Stress 40706424-2600	55002600	ACTIVO	2026-06-02 22:53:17.991408	2026-06-02 22:53:17.991408	0
554c081b-6d3e-4c85-90fc-8d706a96b0cd	94070644100002501	stress-40706441-2501@mediqueue.test	Paciente Stress 40706441-2501	55002501	ACTIVO	2026-06-02 22:53:18.099088	2026-06-02 22:53:18.099088	0
77a27f07-c61e-4e28-88e9-5c0695d4674b	94070648300002614	stress-40706483-2614@mediqueue.test	Paciente Stress 40706483-2614	55002614	ACTIVO	2026-06-02 22:53:18.211467	2026-06-02 22:53:18.211467	0
4da99c79-8b10-4418-9a04-7e584996748d	94070641500002877	stress-40706415-2877@mediqueue.test	Paciente Stress 40706415-2877	55002877	ACTIVO	2026-06-02 22:53:20.348542	2026-06-02 22:53:20.348542	0
13406be3-516d-4585-a7d5-3978de1d6ca7	94070647200003025	stress-40706472-3025@mediqueue.test	Paciente Stress 40706472-3025	55003025	ACTIVO	2026-06-02 22:53:21.699635	2026-06-02 22:53:21.699635	0
6b51d821-d577-496b-b33c-fc04dcd2aaab	94070649000003550	stress-40706490-3550@mediqueue.test	Paciente Stress 40706490-3550	55003550	ACTIVO	2026-06-02 22:53:27.076878	2026-06-02 22:53:27.076878	0
dc35e1ba-9182-4730-98b4-ed19a2cde5a7	94070648700003572	stress-40706487-3572@mediqueue.test	Paciente Stress 40706487-3572	55003572	ACTIVO	2026-06-02 22:53:27.286909	2026-06-02 22:53:27.286909	0
10bd669f-1f82-4014-baee-7d331c897a7a	94070642500003692	stress-40706425-3692@mediqueue.test	Paciente Stress 40706425-3692	55003692	ACTIVO	2026-06-02 22:53:28.31367	2026-06-02 22:53:28.31367	0
b219e714-dddc-490a-93da-1c378d33301e	94070647600003728	stress-40706476-3728@mediqueue.test	Paciente Stress 40706476-3728	55003728	ACTIVO	2026-06-02 22:53:28.660459	2026-06-02 22:53:28.660459	0
b72ff301-6eb7-4bc5-b9a5-625fdd112318	94070646400003744	stress-40706464-3744@mediqueue.test	Paciente Stress 40706464-3744	55003744	ACTIVO	2026-06-02 22:53:28.813432	2026-06-02 22:53:28.813432	0
b87353e2-9dbf-4c55-b0b7-9b0dc32e908a	94173199100000026	stress-41731991-26@mediqueue.test	Paciente Stress 41731991-26	55000026	ACTIVO	2026-06-02 23:08:53.33058	2026-06-02 23:08:53.33058	0
0e7aba59-c680-41b1-9709-3a4213495998	94173205600000597	stress-41732056-597@mediqueue.test	Paciente Stress 41732056-597	55000597	ACTIVO	2026-06-02 23:08:59.094698	2026-06-02 23:08:59.094698	0
fbc2a3f7-7a44-40e5-9b92-dc653d63b11a	94173203100000446	stress-41732031-446@mediqueue.test	Paciente Stress 41732031-446	55000446	ACTIVO	2026-06-02 23:08:59.196503	2026-06-02 23:08:59.196503	0
ae5381ef-b559-44ae-ab46-c6460a4414a4	93979300600004731	stress-39793006-4731@mediqueue.test	Paciente Stress 39793006-4731	55004731	ACTIVO	2026-06-02 22:38:33.714925	2026-06-02 22:38:33.714925	0
2e75868e-1f7f-45aa-a723-319f14fd5858	93979297700004706	stress-39792977-4706@mediqueue.test	Paciente Stress 39792977-4706	55004706	ACTIVO	2026-06-02 22:38:34.058979	2026-06-02 22:38:34.058979	0
a29afd2b-3fef-4f49-9765-b85d8b7cc33c	93979302600005073	stress-39793026-5073@mediqueue.test	Paciente Stress 39793026-5073	55005073	ACTIVO	2026-06-02 22:38:36.284017	2026-06-02 22:38:36.284017	0
06b67e94-9a19-4d59-8eac-411604aa598f	93979295200005186	stress-39792952-5186@mediqueue.test	Paciente Stress 39792952-5186	55005186	ACTIVO	2026-06-02 22:38:37.241212	2026-06-02 22:38:37.241212	0
2a90cd4a-2b78-47ed-acbe-5f88d53fa4c9	93979299300005234	stress-39792993-5234@mediqueue.test	Paciente Stress 39792993-5234	55005234	ACTIVO	2026-06-02 22:38:37.634865	2026-06-02 22:38:37.634865	0
38f34cf6-7d66-42bf-bb62-81adb0662585	93979300700005518	stress-39793007-5518@mediqueue.test	Paciente Stress 39793007-5518	55005518	ACTIVO	2026-06-02 22:38:40.300994	2026-06-02 22:38:40.300994	0
f9626f85-c659-435f-855d-bf7448abd1a8	93979302200005760	stress-39793022-5760@mediqueue.test	Paciente Stress 39793022-5760	55005760	ACTIVO	2026-06-02 22:38:42.613511	2026-06-02 22:38:42.613511	0
1cc3b5a7-a20b-48a9-9f5a-4b6f368941a7	93979296000005794	stress-39792960-5794@mediqueue.test	Paciente Stress 39792960-5794	55005794	ACTIVO	2026-06-02 22:38:42.865766	2026-06-02 22:38:42.865766	0
a92346a6-5249-4700-ae02-5c2b24fd6a96	93979299900006104	stress-39792999-6104@mediqueue.test	Paciente Stress 39792999-6104	55006104	ACTIVO	2026-06-02 22:38:45.908122	2026-06-02 22:38:45.908122	0
51f505f4-e46f-4078-93bb-92a9df2d831a	93979295700006166	stress-39792957-6166@mediqueue.test	Paciente Stress 39792957-6166	55006166	ACTIVO	2026-06-02 22:38:46.454865	2026-06-02 22:38:46.454865	0
7348cd48-5e06-4285-85eb-284eef467bc7	93979300400006300	stress-39793004-6300@mediqueue.test	Paciente Stress 39793004-6300	55006300	ACTIVO	2026-06-02 22:38:47.750867	2026-06-02 22:38:47.750867	0
c25cb372-525a-454b-a3cb-bd648be9de7f	93979300500006338	stress-39793005-6338@mediqueue.test	Paciente Stress 39793005-6338	55006338	ACTIVO	2026-06-02 22:38:48.13228	2026-06-02 22:38:48.13228	0
ff54d933-dc77-4c7a-aac4-7edfcb8e259d	93979296900006466	stress-39792969-6466@mediqueue.test	Paciente Stress 39792969-6466	55006466	ACTIVO	2026-06-02 22:40:33.942328	2026-06-02 22:40:33.942328	0
bd78df12-d511-4246-bb81-70f2eefba959	93979300000006764	stress-39793000-6764@mediqueue.test	Paciente Stress 39793000-6764	55006764	ACTIVO	2026-06-02 22:40:36.907503	2026-06-02 22:40:36.907503	0
74ed886e-2770-4e9c-98dd-b442379c09eb	93979294800007122	stress-39792948-7122@mediqueue.test	Paciente Stress 39792948-7122	55007122	ACTIVO	2026-06-02 22:40:38.566792	2026-06-02 22:40:38.566792	0
59e49f7b-c8df-4435-81fb-a34d44d9b19d	93979298700007313	stress-39792987-7313@mediqueue.test	Paciente Stress 39792987-7313	55007313	ACTIVO	2026-06-02 22:40:39.924106	2026-06-02 22:40:39.924106	0
b5c977ff-9ae5-463f-9e38-0508bde5c387	93979298100007381	stress-39792981-7381@mediqueue.test	Paciente Stress 39792981-7381	55007381	ACTIVO	2026-06-02 22:40:40.404651	2026-06-02 22:40:40.404651	0
3c6acd71-f3a2-4de1-b5c8-25e7caab24b9	93979304500007799	stress-39793045-7799@mediqueue.test	Paciente Stress 39793045-7799	55007799	ACTIVO	2026-06-02 22:40:43.934828	2026-06-02 22:40:43.934828	0
94b9eab0-674c-4384-8451-131317cd07c6	93979305900008184	stress-39793059-8184@mediqueue.test	Paciente Stress 39793059-8184	55008184	ACTIVO	2026-06-02 22:40:46.804327	2026-06-02 22:40:46.804327	0
a545f46d-b093-4c0e-97c1-500758f4b86a	93979296000008243	stress-39792960-8243@mediqueue.test	Paciente Stress 39792960-8243	55008243	ACTIVO	2026-06-02 22:40:47.233168	2026-06-02 22:40:47.233168	0
5107753b-18c5-4b38-bee4-0bc1eb12c3be	93979296300008578	stress-39792963-8578@mediqueue.test	Paciente Stress 39792963-8578	55008578	ACTIVO	2026-06-02 22:41:45.602702	2026-06-02 22:41:45.602702	0
1862bece-723a-42f3-9789-f345dc8912c5	94045696100009106	stress-40456961-9106@mediqueue.test	Paciente Stress 40456961-9106	55009106	ACTIVO	2026-06-02 22:49:39.526871	2026-06-02 22:49:39.526871	0
9b1d46b9-3095-40b6-a55d-7c5f9f82185c	94045692300009602	stress-40456923-9602@mediqueue.test	Paciente Stress 40456923-9602	55009602	ACTIVO	2026-06-02 22:49:44.323948	2026-06-02 22:49:44.323948	0
fe84e066-e52e-4814-a577-3954929e0dc0	94045692900009671	stress-40456929-9671@mediqueue.test	Paciente Stress 40456929-9671	55009671	ACTIVO	2026-06-02 22:49:45.057276	2026-06-02 22:49:45.057276	0
ad0ceeeb-28fd-45ea-aca2-f69d35c81275	94045695900009738	stress-40456959-9738@mediqueue.test	Paciente Stress 40456959-9738	55009738	ACTIVO	2026-06-02 22:51:03.107099	2026-06-02 22:51:03.107099	0
da5edda7-cfd3-4f79-a6b0-b6662401650e	94070645900000069	stress-40706459-69@mediqueue.test	Paciente Stress 40706459-69	55000069	ACTIVO	2026-06-02 22:51:47.505584	2026-06-02 22:51:47.505584	0
f977cdbe-12ea-42db-9a5d-9f21f044ac4e	94070646600000189	stress-40706466-189@mediqueue.test	Paciente Stress 40706466-189	55000189	ACTIVO	2026-06-02 22:51:51.261524	2026-06-02 22:51:51.261524	0
7f6efc87-7fe6-4d86-af06-24e4c99ce76a	94070648600000096	stress-40706486-96@mediqueue.test	Paciente Stress 40706486-96	55000096	ACTIVO	2026-06-02 22:51:51.435113	2026-06-02 22:51:51.435113	0
715302b6-c3a3-47d6-b260-b042c00c6c1f	94070643400000446	stress-40706434-446@mediqueue.test	Paciente Stress 40706434-446	55000446	ACTIVO	2026-06-02 22:51:52.315448	2026-06-02 22:51:52.315448	0
4c8240d8-e27d-4c6a-bb35-b5eb53d6761d	94070642400000583	stress-40706424-583@mediqueue.test	Paciente Stress 40706424-583	55000583	ACTIVO	2026-06-02 22:51:52.472514	2026-06-02 22:51:52.472514	0
58d2ddd3-bee5-488a-86ae-7e07bf6a80e3	94070642500000831	stress-40706425-831@mediqueue.test	Paciente Stress 40706425-831	55000831	ACTIVO	2026-06-02 22:51:54.553981	2026-06-02 22:51:54.553981	0
06d5739f-d033-4399-aad8-6b5cd71f0e85	94070644100000927	stress-40706441-927@mediqueue.test	Paciente Stress 40706441-927	55000927	ACTIVO	2026-06-02 22:51:55.590946	2026-06-02 22:51:55.590946	0
e39625db-c28a-4f22-8562-bd04492fcb81	94070645300000981	stress-40706453-981@mediqueue.test	Paciente Stress 40706453-981	55000981	ACTIVO	2026-06-02 22:51:56.32	2026-06-02 22:51:56.32	0
7285bf6b-a573-4bad-ac70-9d2a889c1147	94070642300001047	stress-40706423-1047@mediqueue.test	Paciente Stress 40706423-1047	55001047	ACTIVO	2026-06-02 22:51:57.229777	2026-06-02 22:51:57.229777	0
4dd0e9b3-974a-4178-95a7-9fb38283a713	94070647600001112	stress-40706476-1112@mediqueue.test	Paciente Stress 40706476-1112	55001112	ACTIVO	2026-06-02 22:51:57.835778	2026-06-02 22:51:57.835778	0
444f5e08-ad3f-4829-878a-e29bd03b65e6	94070648500001397	stress-40706485-1397@mediqueue.test	Paciente Stress 40706485-1397	55001397	ACTIVO	2026-06-02 22:52:00.541199	2026-06-02 22:52:00.541199	0
5a47f380-0942-4b08-978e-27d9974baed7	94070645200001736	stress-40706452-1736@mediqueue.test	Paciente Stress 40706452-1736	55001736	ACTIVO	2026-06-02 22:52:03.642677	2026-06-02 22:52:03.642677	0
3f94b91f-00d1-411f-b5d7-3c735a9be4f1	94070645900001930	stress-40706459-1930@mediqueue.test	Paciente Stress 40706459-1930	55001930	ACTIVO	2026-06-02 22:53:10.862674	2026-06-02 22:53:10.862674	0
dc81d3a1-9d89-416e-a7e5-db2066b9122e	94070646500001975	stress-40706465-1975@mediqueue.test	Paciente Stress 40706465-1975	55001975	ACTIVO	2026-06-02 22:53:11.43043	2026-06-02 22:53:11.43043	0
0e0acea8-1b5b-467e-8246-51a3acebf13f	94070648700002051	stress-40706487-2051@mediqueue.test	Paciente Stress 40706487-2051	55002051	ACTIVO	2026-06-02 22:53:11.815783	2026-06-02 22:53:11.815783	0
65b6404e-ded5-413e-8c6d-706ad943543a	94070645100002692	stress-40706451-2692@mediqueue.test	Paciente Stress 40706451-2692	55002692	ACTIVO	2026-06-02 22:53:18.542226	2026-06-02 22:53:18.542226	0
425c1d1d-33cb-4b25-9488-f64572cd7424	94070646200002865	stress-40706462-2865@mediqueue.test	Paciente Stress 40706462-2865	55002865	ACTIVO	2026-06-02 22:53:20.267458	2026-06-02 22:53:20.267458	0
13cb6f94-f04c-432c-aecf-069a5a8bb84d	94070648700003156	stress-40706487-3156@mediqueue.test	Paciente Stress 40706487-3156	55003156	ACTIVO	2026-06-02 22:53:23.184401	2026-06-02 22:53:23.184401	0
b2812685-95b9-4dd3-b685-93450c80f85c	94070642600003446	stress-40706426-3446@mediqueue.test	Paciente Stress 40706426-3446	55003446	ACTIVO	2026-06-02 22:53:25.978422	2026-06-02 22:53:25.978422	0
db599336-9e31-4c3d-80f4-c2d71fefa577	94070647900003719	stress-40706479-3719@mediqueue.test	Paciente Stress 40706479-3719	55003719	ACTIVO	2026-06-02 22:53:28.673028	2026-06-02 22:53:28.673028	0
17b6519d-9aa2-41d8-8750-8a6e90287783	94070645400004000	stress-40706454-4000@mediqueue.test	Paciente Stress 40706454-4000	55004000	ACTIVO	2026-06-02 22:53:30.95598	2026-06-02 22:53:30.95598	0
9a586c36-036a-4053-93a4-79dd8bbbcf12	94173205400000353	stress-41732054-353@mediqueue.test	Paciente Stress 41732054-353	55000353	ACTIVO	2026-06-02 23:08:56.003389	2026-06-02 23:08:56.003389	0
38aa5d90-fdcb-4643-a93b-19b7f6c1a63f	93979305600004741	stress-39793056-4741@mediqueue.test	Paciente Stress 39793056-4741	55004741	ACTIVO	2026-06-02 22:38:34.287876	2026-06-02 22:38:34.287876	0
963ec305-4011-4cf5-b219-735f059039ac	93979299400004978	stress-39792994-4978@mediqueue.test	Paciente Stress 39792994-4978	55004978	ACTIVO	2026-06-02 22:38:35.386981	2026-06-02 22:38:35.386981	0
66288efd-af1c-456d-82fe-df16c7d1da2c	93979294800005111	stress-39792948-5111@mediqueue.test	Paciente Stress 39792948-5111	55005111	ACTIVO	2026-06-02 22:38:36.526651	2026-06-02 22:38:36.526651	0
95df86fb-8bbc-4713-9394-554ae13f0c99	93979294800005126	stress-39792948-5126@mediqueue.test	Paciente Stress 39792948-5126	55005126	ACTIVO	2026-06-02 22:38:36.753674	2026-06-02 22:38:36.753674	0
3d7e6c4f-fbda-4cb2-b923-9d8b5069df8d	93979300100005503	stress-39793001-5503@mediqueue.test	Paciente Stress 39793001-5503	55005503	ACTIVO	2026-06-02 22:38:40.125301	2026-06-02 22:38:40.125301	0
dee30d4a-4c34-43ec-9d9d-c51dc3574805	93979297000005693	stress-39792970-5693@mediqueue.test	Paciente Stress 39792970-5693	55005693	ACTIVO	2026-06-02 22:38:41.980198	2026-06-02 22:38:41.980198	0
91a0e640-f877-4b83-9a5c-91cb831d933d	93979300100005706	stress-39793001-5706@mediqueue.test	Paciente Stress 39793001-5706	55005706	ACTIVO	2026-06-02 22:38:42.159558	2026-06-02 22:38:42.159558	0
74e26a7a-fdcf-46c3-be2d-cc5a19ec5f8c	93979303900005909	stress-39793039-5909@mediqueue.test	Paciente Stress 39793039-5909	55005909	ACTIVO	2026-06-02 22:38:43.894491	2026-06-02 22:38:43.894491	0
60439684-3541-4a8e-b734-26b7b59b323b	93979295800006439	stress-39792958-6439@mediqueue.test	Paciente Stress 39792958-6439	55006439	ACTIVO	2026-06-02 22:40:33.286666	2026-06-02 22:40:33.286666	0
5f01f696-01d1-42df-a5ae-dfb12ab11de5	93979302900006726	stress-39793029-6726@mediqueue.test	Paciente Stress 39793029-6726	55006726	ACTIVO	2026-06-02 22:40:35.310396	2026-06-02 22:40:35.310396	0
02883c72-5602-43d2-b1cd-689360a1db8f	93979302600007244	stress-39793026-7244@mediqueue.test	Paciente Stress 39793026-7244	55007244	ACTIVO	2026-06-02 22:40:39.368459	2026-06-02 22:40:39.368459	0
f5e69ee6-44f7-4c3a-8cdd-89a62610cac6	93979299900007287	stress-39792999-7287@mediqueue.test	Paciente Stress 39792999-7287	55007287	ACTIVO	2026-06-02 22:40:39.562582	2026-06-02 22:40:39.562582	0
5b6597c7-b1e5-43f5-b306-4ea4f97ae599	93979301700007297	stress-39793017-7297@mediqueue.test	Paciente Stress 39793017-7297	55007297	ACTIVO	2026-06-02 22:40:39.743052	2026-06-02 22:40:39.743052	0
567ddc55-91e8-4d15-beeb-b3192e661dbd	93979304300007399	stress-39793043-7399@mediqueue.test	Paciente Stress 39793043-7399	55007399	ACTIVO	2026-06-02 22:40:40.514231	2026-06-02 22:40:40.514231	0
e32ddb83-f547-4f1b-b0e1-30f5d087be33	93979304600007609	stress-39793046-7609@mediqueue.test	Paciente Stress 39793046-7609	55007609	ACTIVO	2026-06-02 22:40:42.505663	2026-06-02 22:40:42.505663	0
111522e1-a252-47a6-9862-e9dec3168cc4	93979299700007892	stress-39792997-7892@mediqueue.test	Paciente Stress 39792997-7892	55007892	ACTIVO	2026-06-02 22:40:44.479204	2026-06-02 22:40:44.479204	0
600609d4-6672-46cf-950b-f0fd3dd814d6	93979297700008008	stress-39792977-8008@mediqueue.test	Paciente Stress 39792977-8008	55008008	ACTIVO	2026-06-02 22:40:45.262128	2026-06-02 22:40:45.262128	0
c132c5a7-88d7-4441-b5ab-70c2450027ad	93979301700008249	stress-39793017-8249@mediqueue.test	Paciente Stress 39793017-8249	55008249	ACTIVO	2026-06-02 22:40:47.311805	2026-06-02 22:40:47.311805	0
ccc318cd-7438-4dd8-9714-609d938af4b4	93979297200008476	stress-39792972-8476@mediqueue.test	Paciente Stress 39792972-8476	55008476	ACTIVO	2026-06-02 22:41:44.178213	2026-06-02 22:41:44.178213	0
cda5afef-fdf5-4918-a114-9af1ae92df73	93979305600008727	stress-39793056-8727@mediqueue.test	Paciente Stress 39793056-8727	55008727	ACTIVO	2026-06-02 22:41:46.083744	2026-06-02 22:41:46.083744	0
6549b4c2-a657-4b93-a187-1f5b8a0b02ef	94045693500009122	stress-40456935-9122@mediqueue.test	Paciente Stress 40456935-9122	55009122	ACTIVO	2026-06-02 22:49:39.619837	2026-06-02 22:49:39.619837	0
c86b9bb6-8784-4b4f-b721-bdf4725e53c9	94045693100009290	stress-40456931-9290@mediqueue.test	Paciente Stress 40456931-9290	55009290	ACTIVO	2026-06-02 22:49:41.243366	2026-06-02 22:49:41.243366	0
ae18d6e3-c252-4af9-bc8c-874e6d94c437	94045692300009394	stress-40456923-9394@mediqueue.test	Paciente Stress 40456923-9394	55009394	ACTIVO	2026-06-02 22:49:42.266613	2026-06-02 22:49:42.266613	0
bebbee19-169f-4e5c-a659-49a936c7b4b2	94045694900009797	stress-40456949-9797@mediqueue.test	Paciente Stress 40456949-9797	55009797	ACTIVO	2026-06-02 22:51:05.508449	2026-06-02 22:51:05.508449	0
bb1c727a-4ba8-4a4d-837a-df744ae0907d	94070645600000089	stress-40706456-89@mediqueue.test	Paciente Stress 40706456-89	55000089	ACTIVO	2026-06-02 22:51:49.035552	2026-06-02 22:51:49.035552	0
01864be1-ae96-4771-adb0-8be077f18a02	94070645100000174	stress-40706451-174@mediqueue.test	Paciente Stress 40706451-174	55000174	ACTIVO	2026-06-02 22:51:50.201411	2026-06-02 22:51:50.201411	0
e80bc4bc-d75a-4353-9735-cdfe9c9ded1e	94070642500000274	stress-40706425-274@mediqueue.test	Paciente Stress 40706425-274	55000274	ACTIVO	2026-06-02 22:51:50.678787	2026-06-02 22:51:50.678787	0
af067946-3526-40ef-a261-43a292c0cb91	94070645000000149	stress-40706450-149@mediqueue.test	Paciente Stress 40706450-149	55000149	ACTIVO	2026-06-02 22:51:50.799072	2026-06-02 22:51:50.799072	0
b69b9d73-d613-4c43-9350-2e5bca808fbc	94070644600000123	stress-40706446-123@mediqueue.test	Paciente Stress 40706446-123	55000123	ACTIVO	2026-06-02 22:51:50.898349	2026-06-02 22:51:50.898349	0
4956795f-a6c9-4145-a5d0-0108f2d8697e	94070641800000562	stress-40706418-562@mediqueue.test	Paciente Stress 40706418-562	55000562	ACTIVO	2026-06-02 22:51:52.403191	2026-06-02 22:51:52.403191	0
d9cbdff9-21b8-458e-b01f-9016efe3bff8	94070642400000665	stress-40706424-665@mediqueue.test	Paciente Stress 40706424-665	55000665	ACTIVO	2026-06-02 22:51:52.641209	2026-06-02 22:51:52.641209	0
f0f23682-425a-4425-b127-f268b893cf84	94070645400000581	stress-40706454-581@mediqueue.test	Paciente Stress 40706454-581	55000581	ACTIVO	2026-06-02 22:51:52.730084	2026-06-02 22:51:52.730084	0
d7c60c58-768d-441e-af58-97c101be9872	94070642400000822	stress-40706424-822@mediqueue.test	Paciente Stress 40706424-822	55000822	ACTIVO	2026-06-02 22:51:54.37799	2026-06-02 22:51:54.37799	0
2cf1ceed-9378-4b2d-8c5c-993dda67f964	94070648000000858	stress-40706480-858@mediqueue.test	Paciente Stress 40706480-858	55000858	ACTIVO	2026-06-02 22:51:54.905208	2026-06-02 22:51:54.905208	0
0517f5ec-aa03-44c7-8c03-b35391abb45a	94070643500001099	stress-40706435-1099@mediqueue.test	Paciente Stress 40706435-1099	55001099	ACTIVO	2026-06-02 22:51:57.703916	2026-06-02 22:51:57.703916	0
46aca090-1079-4eb5-8e07-5170c29a7c1c	94070646700001371	stress-40706467-1371@mediqueue.test	Paciente Stress 40706467-1371	55001371	ACTIVO	2026-06-02 22:52:00.2547	2026-06-02 22:52:00.2547	0
9a615542-1988-4be7-ae98-d0df6b29c71d	94070646400001399	stress-40706464-1399@mediqueue.test	Paciente Stress 40706464-1399	55001399	ACTIVO	2026-06-02 22:52:00.510747	2026-06-02 22:52:00.510747	0
aefb1c29-bb5a-4d7a-a486-f327aed39def	94070645100001604	stress-40706451-1604@mediqueue.test	Paciente Stress 40706451-1604	55001604	ACTIVO	2026-06-02 22:52:02.363319	2026-06-02 22:52:02.363319	0
aa20139a-5ae7-4dfd-b9f0-f98f9f8d1101	94070643600001655	stress-40706436-1655@mediqueue.test	Paciente Stress 40706436-1655	55001655	ACTIVO	2026-06-02 22:52:02.992651	2026-06-02 22:52:02.992651	0
ca6d5998-6544-4276-bcb3-244249917974	94070647200002227	stress-40706472-2227@mediqueue.test	Paciente Stress 40706472-2227	55002227	ACTIVO	2026-06-02 22:53:14.256156	2026-06-02 22:53:14.256156	0
849c3b59-f351-4992-8855-2c5e8355a699	94070647000002319	stress-40706470-2319@mediqueue.test	Paciente Stress 40706470-2319	55002319	ACTIVO	2026-06-02 22:53:15.629968	2026-06-02 22:53:15.629968	0
e709858e-7d6b-4331-bd35-e4ea53b2c8ab	94070643700002268	stress-40706437-2268@mediqueue.test	Paciente Stress 40706437-2268	55002268	ACTIVO	2026-06-02 22:53:15.749512	2026-06-02 22:53:15.749512	0
d25543db-edf3-4a5a-824d-f98a65dea0ac	94070644700003270	stress-40706447-3270@mediqueue.test	Paciente Stress 40706447-3270	55003270	ACTIVO	2026-06-02 22:53:24.478356	2026-06-02 22:53:24.478356	0
283e0cbe-bbec-4435-b15b-a4ab7fccedb1	94070646900003724	stress-40706469-3724@mediqueue.test	Paciente Stress 40706469-3724	55003724	ACTIVO	2026-06-02 22:53:28.747313	2026-06-02 22:53:28.747313	0
bfd2412e-a487-4063-a0a6-c8d37b4a424d	94173204000000230	stress-41732040-230@mediqueue.test	Paciente Stress 41732040-230	55000230	ACTIVO	2026-06-02 23:08:56.114471	2026-06-02 23:08:56.114471	0
dd541354-41bc-4883-8486-1cde19623bb7	94173204000000227	stress-41732040-227@mediqueue.test	Paciente Stress 41732040-227	55000227	ACTIVO	2026-06-02 23:08:56.954869	2026-06-02 23:08:56.954869	0
a9d627eb-0cab-4018-8baf-fd28db558363	94173206200000216	stress-41732062-216@mediqueue.test	Paciente Stress 41732062-216	55000216	ACTIVO	2026-06-02 23:08:57.968122	2026-06-02 23:08:57.968122	0
281a3bef-f9dc-4738-9ba0-1da24a37f576	93979298000004758	stress-39792980-4758@mediqueue.test	Paciente Stress 39792980-4758	55004758	ACTIVO	2026-06-02 22:38:34.551765	2026-06-02 22:38:34.551765	0
3c3202db-9d3d-4e83-a0d6-d20d9fcfdaa3	93979300000005194	stress-39793000-5194@mediqueue.test	Paciente Stress 39793000-5194	55005194	ACTIVO	2026-06-02 22:38:37.2549	2026-06-02 22:38:37.2549	0
56faa2de-3a09-49a3-9301-1955d824ee26	93979299700005221	stress-39792997-5221@mediqueue.test	Paciente Stress 39792997-5221	55005221	ACTIVO	2026-06-02 22:38:37.487513	2026-06-02 22:38:37.487513	0
72765f5b-8bb8-478b-8eea-c473824d35e9	93979295300005308	stress-39792953-5308@mediqueue.test	Paciente Stress 39792953-5308	55005308	ACTIVO	2026-06-02 22:38:38.264108	2026-06-02 22:38:38.264108	0
8cf3126e-c8d5-4459-898b-6a93a5001116	93979304200005605	stress-39793042-5605@mediqueue.test	Paciente Stress 39793042-5605	55005605	ACTIVO	2026-06-02 22:38:41.149684	2026-06-02 22:38:41.149684	0
82ba273a-8e35-4539-a080-2667fffacc46	93979298600005793	stress-39792986-5793@mediqueue.test	Paciente Stress 39792986-5793	55005793	ACTIVO	2026-06-02 22:38:42.897606	2026-06-02 22:38:42.897606	0
0bcff76a-f238-4a79-bc7f-db86368272a6	93979302800005871	stress-39793028-5871@mediqueue.test	Paciente Stress 39793028-5871	55005871	ACTIVO	2026-06-02 22:38:43.58247	2026-06-02 22:38:43.58247	0
ff9046d0-3ca0-478d-8021-7268bb3d39a5	93979302900006216	stress-39793029-6216@mediqueue.test	Paciente Stress 39793029-6216	55006216	ACTIVO	2026-06-02 22:38:46.944037	2026-06-02 22:38:46.944037	0
767c6dbc-7263-41b5-97eb-829a1a2dbffb	93979300000006664	stress-39793000-6664@mediqueue.test	Paciente Stress 39793000-6664	55006664	ACTIVO	2026-06-02 22:40:34.814535	2026-06-02 22:40:34.814535	0
05600608-4f9d-4c69-a375-a3a71ed84361	93979300100006609	stress-39793001-6609@mediqueue.test	Paciente Stress 39793001-6609	55006609	ACTIVO	2026-06-02 22:40:36.121701	2026-06-02 22:40:36.121701	0
afba419a-db47-410c-b52b-8e8ff4d0c066	93979297900006770	stress-39792979-6770@mediqueue.test	Paciente Stress 39792979-6770	55006770	ACTIVO	2026-06-02 22:40:36.973417	2026-06-02 22:40:36.973417	0
9357ac84-60b8-4288-8375-8d3dfb331d17	93979304300006968	stress-39793043-6968@mediqueue.test	Paciente Stress 39793043-6968	55006968	ACTIVO	2026-06-02 22:40:37.79776	2026-06-02 22:40:37.79776	0
a8fc6af6-048a-4ca9-81e4-20cdceef8ec3	93979300200007200	stress-39793002-7200@mediqueue.test	Paciente Stress 39793002-7200	55007200	ACTIVO	2026-06-02 22:40:39.086239	2026-06-02 22:40:39.086239	0
49f6ca3e-7f5e-4b67-87b3-c757b0d1ffeb	93979296300007279	stress-39792963-7279@mediqueue.test	Paciente Stress 39792963-7279	55007279	ACTIVO	2026-06-02 22:40:39.595355	2026-06-02 22:40:39.595355	0
029899ee-482a-46b5-afc8-4b114e49e440	93979294800007499	stress-39792948-7499@mediqueue.test	Paciente Stress 39792948-7499	55007499	ACTIVO	2026-06-02 22:40:41.432792	2026-06-02 22:40:41.432792	0
59414ab0-3825-4db4-8225-7094b1acc67e	93979301700007737	stress-39793017-7737@mediqueue.test	Paciente Stress 39793017-7737	55007737	ACTIVO	2026-06-02 22:40:43.520973	2026-06-02 22:40:43.520973	0
924081d3-b6da-4e36-8a57-b72e6e460712	93979295800007767	stress-39792958-7767@mediqueue.test	Paciente Stress 39792958-7767	55007767	ACTIVO	2026-06-02 22:40:43.714944	2026-06-02 22:40:43.714944	0
f782e422-40f6-43e0-b997-471254371566	93979305900007865	stress-39793059-7865@mediqueue.test	Paciente Stress 39793059-7865	55007865	ACTIVO	2026-06-02 22:40:44.354688	2026-06-02 22:40:44.354688	0
de9aa63a-a8ba-4a5b-8aed-acb6063e9386	93979302200008177	stress-39793022-8177@mediqueue.test	Paciente Stress 39793022-8177	55008177	ACTIVO	2026-06-02 22:40:46.780651	2026-06-02 22:40:46.780651	0
db02adeb-3ae6-46a8-a3fe-f099e595793f	93979306100008685	stress-39793061-8685@mediqueue.test	Paciente Stress 39793061-8685	55008685	ACTIVO	2026-06-02 22:41:46.14376	2026-06-02 22:41:46.14376	0
afcd15e5-abcb-49ff-ac01-d99493485643	94045696400009172	stress-40456964-9172@mediqueue.test	Paciente Stress 40456964-9172	55009172	ACTIVO	2026-06-02 22:49:40.217804	2026-06-02 22:49:40.217804	0
3f089660-ac23-40d7-9036-de5e8f26d331	94045696600009218	stress-40456966-9218@mediqueue.test	Paciente Stress 40456966-9218	55009218	ACTIVO	2026-06-02 22:49:40.610321	2026-06-02 22:49:40.610321	0
d7aef0e9-df4d-4aee-9aa2-890dcd315007	94045691300009299	stress-40456913-9299@mediqueue.test	Paciente Stress 40456913-9299	55009299	ACTIVO	2026-06-02 22:49:41.331814	2026-06-02 22:49:41.331814	0
b14e2a26-f8d9-4be4-92c9-2bdbd2981cca	94045692700009359	stress-40456927-9359@mediqueue.test	Paciente Stress 40456927-9359	55009359	ACTIVO	2026-06-02 22:49:41.925511	2026-06-02 22:49:41.925511	0
15b47899-2c28-4551-9a58-b19fa78df721	94045694900009614	stress-40456949-9614@mediqueue.test	Paciente Stress 40456949-9614	55009614	ACTIVO	2026-06-02 22:49:44.431978	2026-06-02 22:49:44.431978	0
9f8afc16-a46b-494f-af81-3c55b6896d82	94045692800009924	stress-40456928-9924@mediqueue.test	Paciente Stress 40456928-9924	55009924	ACTIVO	2026-06-02 22:51:05.782459	2026-06-02 22:51:05.782459	0
65327ae3-bfe4-4459-bffa-a4f13fc83d16	94070641500000021	stress-40706415-21@mediqueue.test	Paciente Stress 40706415-21	55000021	ACTIVO	2026-06-02 22:51:47.491876	2026-06-02 22:51:47.491876	0
29a6ad68-8c66-4402-83d0-d6a81e6f1cb9	94070647200000204	stress-40706472-204@mediqueue.test	Paciente Stress 40706472-204	55000204	ACTIVO	2026-06-02 22:51:50.730877	2026-06-02 22:51:50.730877	0
29878850-d653-4b24-ac37-7e2a6d3c5622	94070648300000264	stress-40706483-264@mediqueue.test	Paciente Stress 40706483-264	55000264	ACTIVO	2026-06-02 22:51:51.239697	2026-06-02 22:51:51.239697	0
3260cce4-163d-4d1c-b9cb-8f8e5ee16bfe	94070646100000335	stress-40706461-335@mediqueue.test	Paciente Stress 40706461-335	55000335	ACTIVO	2026-06-02 22:51:51.626657	2026-06-02 22:51:51.626657	0
8759d779-50fa-4396-bee3-9de70ad6a875	94070648400000340	stress-40706484-340@mediqueue.test	Paciente Stress 40706484-340	55000340	ACTIVO	2026-06-02 22:51:52.304803	2026-06-02 22:51:52.304803	0
3e7ca8e8-e48a-4516-bdf3-03d6aa4e454e	94070644600001064	stress-40706446-1064@mediqueue.test	Paciente Stress 40706446-1064	55001064	ACTIVO	2026-06-02 22:51:57.364405	2026-06-02 22:51:57.364405	0
021c7369-f59d-4bd2-b587-687ed2e85c62	94070644600001084	stress-40706446-1084@mediqueue.test	Paciente Stress 40706446-1084	55001084	ACTIVO	2026-06-02 22:51:57.597524	2026-06-02 22:51:57.597524	0
a8bc5623-4867-4098-a806-a9cefd64042d	94070645200001657	stress-40706452-1657@mediqueue.test	Paciente Stress 40706452-1657	55001657	ACTIVO	2026-06-02 22:52:02.992697	2026-06-02 22:52:02.992697	0
16b2bc96-18cc-4287-8d94-0b8d1c59dfc4	94070644600001732	stress-40706446-1732@mediqueue.test	Paciente Stress 40706446-1732	55001732	ACTIVO	2026-06-02 22:52:03.576432	2026-06-02 22:52:03.576432	0
0c706f2a-f96b-4266-886c-d18ee9d10d85	94070641700001743	stress-40706417-1743@mediqueue.test	Paciente Stress 40706417-1743	55001743	ACTIVO	2026-06-02 22:52:03.716063	2026-06-02 22:52:03.716063	0
149c18b4-6bea-4a0d-a05d-09aa82ca1584	94070642400001825	stress-40706424-1825@mediqueue.test	Paciente Stress 40706424-1825	55001825	ACTIVO	2026-06-02 22:52:04.698592	2026-06-02 22:52:04.698592	0
373f0ed2-317f-43bc-ab14-17aea6c772de	94070648500001844	stress-40706485-1844@mediqueue.test	Paciente Stress 40706485-1844	55001844	ACTIVO	2026-06-02 22:52:04.921415	2026-06-02 22:52:04.921415	0
7bd5d466-5c37-496c-aada-b73590314133	94070647300002003	stress-40706473-2003@mediqueue.test	Paciente Stress 40706473-2003	55002003	ACTIVO	2026-06-02 22:53:12.999268	2026-06-02 22:53:12.999268	0
bc974378-9fcd-4506-943e-ce67534f7534	94070648700002184	stress-40706487-2184@mediqueue.test	Paciente Stress 40706487-2184	55002184	ACTIVO	2026-06-02 22:53:15.716852	2026-06-02 22:53:15.716852	0
7a78f7c7-238e-4e07-8a8b-3d717edaf82d	94070646300002021	stress-40706463-2021@mediqueue.test	Paciente Stress 40706463-2021	55002021	ACTIVO	2026-06-02 22:53:15.838554	2026-06-02 22:53:15.838554	0
9daef9d8-2218-4f4d-b097-9b6056ef561e	94070645900002581	stress-40706459-2581@mediqueue.test	Paciente Stress 40706459-2581	55002581	ACTIVO	2026-06-02 22:53:18.163334	2026-06-02 22:53:18.163334	0
7c9c7820-1028-491d-871f-4f1b924446d1	94070645100002726	stress-40706451-2726@mediqueue.test	Paciente Stress 40706451-2726	55002726	ACTIVO	2026-06-02 22:53:18.687697	2026-06-02 22:53:18.687697	0
4c2550cd-f4d4-4f4e-889b-217c2ff79360	94070648600002780	stress-40706486-2780@mediqueue.test	Paciente Stress 40706486-2780	55002780	ACTIVO	2026-06-02 22:53:19.312542	2026-06-02 22:53:19.312542	0
23855111-2daf-438e-824c-4c5b9b0a601f	94070641500002825	stress-40706415-2825@mediqueue.test	Paciente Stress 40706415-2825	55002825	ACTIVO	2026-06-02 22:53:19.919757	2026-06-02 22:53:19.919757	0
0fa21da6-e0ec-4d36-8848-3176e0cbc456	94070648600002907	stress-40706486-2907@mediqueue.test	Paciente Stress 40706486-2907	55002907	ACTIVO	2026-06-02 22:53:20.542949	2026-06-02 22:53:20.542949	0
71fb47a6-ca3c-4c94-9d47-f21eef126823	94070648600002925	stress-40706486-2925@mediqueue.test	Paciente Stress 40706486-2925	55002925	ACTIVO	2026-06-02 22:53:20.78221	2026-06-02 22:53:20.78221	0
9c2437f1-38ea-484b-adc3-3f2d0fb87dfe	93979295700006108	stress-39792957-6108@mediqueue.test	Paciente Stress 39792957-6108	55006108	ACTIVO	2026-06-02 22:38:45.958915	2026-06-02 22:38:45.958915	0
80fa701d-ba35-4279-907c-ca1e51f781c6	93979295700006661	stress-39792957-6661@mediqueue.test	Paciente Stress 39792957-6661	55006661	ACTIVO	2026-06-02 22:40:35.628682	2026-06-02 22:40:35.628682	0
f5ff1375-0b0a-476e-b668-294e2949aeb3	93979298600006929	stress-39792986-6929@mediqueue.test	Paciente Stress 39792986-6929	55006929	ACTIVO	2026-06-02 22:40:37.685385	2026-06-02 22:40:37.685385	0
364fe3e1-6818-4191-9a49-929156c24169	93979298400007060	stress-39792984-7060@mediqueue.test	Paciente Stress 39792984-7060	55007060	ACTIVO	2026-06-02 22:40:38.100993	2026-06-02 22:40:38.100993	0
2f11819e-e846-4dbf-819e-7c89893fd271	93979297800007179	stress-39792978-7179@mediqueue.test	Paciente Stress 39792978-7179	55007179	ACTIVO	2026-06-02 22:40:39.030071	2026-06-02 22:40:39.030071	0
23b4026f-1a18-4d81-b9fb-79a7b6bac818	93979302800007299	stress-39793028-7299@mediqueue.test	Paciente Stress 39793028-7299	55007299	ACTIVO	2026-06-02 22:40:39.747035	2026-06-02 22:40:39.747035	0
54751600-9c98-4bca-99de-bf98fe9f8758	93979302800007352	stress-39793028-7352@mediqueue.test	Paciente Stress 39793028-7352	55007352	ACTIVO	2026-06-02 22:40:40.201196	2026-06-02 22:40:40.201196	0
6e8dcf90-e9c5-4cbd-998a-ad444d3ac79f	93979300300007430	stress-39793003-7430@mediqueue.test	Paciente Stress 39793003-7430	55007430	ACTIVO	2026-06-02 22:40:40.855217	2026-06-02 22:40:40.855217	0
940adad1-42d0-4a4d-9269-1196aa18c154	93979302400007921	stress-39793024-7921@mediqueue.test	Paciente Stress 39793024-7921	55007921	ACTIVO	2026-06-02 22:40:44.674955	2026-06-02 22:40:44.674955	0
ca12a831-de66-4ee9-aae4-d0274aa9173c	93979302100007963	stress-39793021-7963@mediqueue.test	Paciente Stress 39793021-7963	55007963	ACTIVO	2026-06-02 22:40:44.973625	2026-06-02 22:40:44.973625	0
362ff871-feb9-4b4a-b8bb-e63766b8dec1	93979297900007993	stress-39792979-7993@mediqueue.test	Paciente Stress 39792979-7993	55007993	ACTIVO	2026-06-02 22:40:45.159196	2026-06-02 22:40:45.159196	0
b1b8b5c9-fa4f-4f67-9312-a89c4d1c2f11	93979294400008168	stress-39792944-8168@mediqueue.test	Paciente Stress 39792944-8168	55008168	ACTIVO	2026-06-02 22:40:46.679103	2026-06-02 22:40:46.679103	0
899e847d-186b-4aa2-8941-f14581b3ac42	93979300000008266	stress-39793000-8266@mediqueue.test	Paciente Stress 39793000-8266	55008266	ACTIVO	2026-06-02 22:40:47.418077	2026-06-02 22:40:47.418077	0
4fa9d571-c837-41d7-acc2-03ff85c14fd6	93979304500008285	stress-39793045-8285@mediqueue.test	Paciente Stress 39793045-8285	55008285	ACTIVO	2026-06-02 22:40:47.605001	2026-06-02 22:40:47.605001	0
c2bbfd8f-cd9b-4c6f-95ba-77bb394615cb	93979297900008346	stress-39792979-8346@mediqueue.test	Paciente Stress 39792979-8346	55008346	ACTIVO	2026-06-02 22:40:48.118105	2026-06-02 22:40:48.118105	0
4901a0a7-8234-4d50-a2d1-84b820784199	93979302900008554	stress-39793029-8554@mediqueue.test	Paciente Stress 39793029-8554	55008554	ACTIVO	2026-06-02 22:41:45.1224	2026-06-02 22:41:45.1224	0
93fc30e8-aba4-4cb4-84b0-629841800afd	93979298600008630	stress-39792986-8630@mediqueue.test	Paciente Stress 39792986-8630	55008630	ACTIVO	2026-06-02 22:41:45.688245	2026-06-02 22:41:45.688245	0
ba3fb49d-b56b-46a0-b4f8-6b32f0697997	93979297800008593	stress-39792978-8593@mediqueue.test	Paciente Stress 39792978-8593	55008593	ACTIVO	2026-06-02 22:41:45.874409	2026-06-02 22:41:45.874409	0
1b75b513-58ec-49db-bb69-29a8bfa04ff5	94045694700009316	stress-40456947-9316@mediqueue.test	Paciente Stress 40456947-9316	55009316	ACTIVO	2026-06-02 22:49:41.445052	2026-06-02 22:49:41.445052	0
db02e560-bcac-4f74-a0d8-89244aaa7b2e	94045695300009447	stress-40456953-9447@mediqueue.test	Paciente Stress 40456953-9447	55009447	ACTIVO	2026-06-02 22:49:43.089125	2026-06-02 22:49:43.089125	0
8c438cd4-672a-4b57-92eb-8a2b37b2d769	94045695000009557	stress-40456950-9557@mediqueue.test	Paciente Stress 40456950-9557	55009557	ACTIVO	2026-06-02 22:49:43.896309	2026-06-02 22:49:43.896309	0
a639fe2b-5ed9-47c7-94bd-b871e2929666	94045695800009603	stress-40456958-9603@mediqueue.test	Paciente Stress 40456958-9603	55009603	ACTIVO	2026-06-02 22:49:44.336704	2026-06-02 22:49:44.336704	0
7ed435b1-9175-4d97-a129-9ec651e14d58	94045696600009729	stress-40456966-9729@mediqueue.test	Paciente Stress 40456966-9729	55009729	ACTIVO	2026-06-02 22:51:03.598041	2026-06-02 22:51:03.598041	0
c607d272-bf54-4cbf-98dd-9c06afe30f6f	94070644700000068	stress-40706447-68@mediqueue.test	Paciente Stress 40706447-68	55000068	ACTIVO	2026-06-02 22:51:50.9342	2026-06-02 22:51:50.9342	0
d2e8ece6-bad6-4b8f-9d18-a6612b057bce	94070644300000456	stress-40706443-456@mediqueue.test	Paciente Stress 40706443-456	55000456	ACTIVO	2026-06-02 22:51:51.862714	2026-06-02 22:51:51.862714	0
961d55e0-10d2-4dfc-8389-a9706c6a2e07	94070642300000404	stress-40706423-404@mediqueue.test	Paciente Stress 40706423-404	55000404	ACTIVO	2026-06-02 22:51:52.125114	2026-06-02 22:51:52.125114	0
c8f47c27-f29a-405a-8a5c-ca9e889a5ada	94070647000000442	stress-40706470-442@mediqueue.test	Paciente Stress 40706470-442	55000442	ACTIVO	2026-06-02 22:51:52.272381	2026-06-02 22:51:52.272381	0
484d719b-4161-474d-b090-6fc1d6df562b	94070648500000662	stress-40706485-662@mediqueue.test	Paciente Stress 40706485-662	55000662	ACTIVO	2026-06-02 22:51:52.67982	2026-06-02 22:51:52.67982	0
b59e1621-de88-42d0-87e0-bbc6a2fc2caa	94070643500000496	stress-40706435-496@mediqueue.test	Paciente Stress 40706435-496	55000496	ACTIVO	2026-06-02 22:51:52.774325	2026-06-02 22:51:52.774325	0
e2ef29ee-67f2-4efc-809c-70ac2b19747c	94070648600001201	stress-40706486-1201@mediqueue.test	Paciente Stress 40706486-1201	55001201	ACTIVO	2026-06-02 22:51:58.62609	2026-06-02 22:51:58.62609	0
d7cd2078-4b18-41f6-b293-0fd2615dd6e5	94070646400001386	stress-40706464-1386@mediqueue.test	Paciente Stress 40706464-1386	55001386	ACTIVO	2026-06-02 22:52:00.391197	2026-06-02 22:52:00.391197	0
e290b464-00f2-49d0-b24e-b77689017f77	94070646100001714	stress-40706461-1714@mediqueue.test	Paciente Stress 40706461-1714	55001714	ACTIVO	2026-06-02 22:52:03.42077	2026-06-02 22:52:03.42077	0
615dda1e-5514-4232-b108-35f88b15f9e3	94070646100001738	stress-40706461-1738@mediqueue.test	Paciente Stress 40706461-1738	55001738	ACTIVO	2026-06-02 22:52:03.642297	2026-06-02 22:52:03.642297	0
6dbc740f-20d9-4806-a6af-698965e3b6ee	94070646100001747	stress-40706461-1747@mediqueue.test	Paciente Stress 40706461-1747	55001747	ACTIVO	2026-06-02 22:52:03.808935	2026-06-02 22:52:03.808935	0
96a65b2a-2018-46a8-8318-6de2ec135877	94070648500001848	stress-40706485-1848@mediqueue.test	Paciente Stress 40706485-1848	55001848	ACTIVO	2026-06-02 22:52:05.00381	2026-06-02 22:52:05.00381	0
dc3beb3f-491a-440b-8524-6f0811d232ca	94070645700001872	stress-40706457-1872@mediqueue.test	Paciente Stress 40706457-1872	55001872	ACTIVO	2026-06-02 22:53:10.443732	2026-06-02 22:53:10.443732	0
46fdf92e-8456-4f9e-9bec-b583e3a0490e	94070644100001903	stress-40706441-1903@mediqueue.test	Paciente Stress 40706441-1903	55001903	ACTIVO	2026-06-02 22:53:13.386804	2026-06-02 22:53:13.386804	0
a4d23735-c96e-4d9b-9b8c-72e537b0975b	94070648700002052	stress-40706487-2052@mediqueue.test	Paciente Stress 40706487-2052	55002052	ACTIVO	2026-06-02 22:53:14.389401	2026-06-02 22:53:14.389401	0
0353d621-913b-48fa-ac78-c58c1f0f569d	94070644800002369	stress-40706448-2369@mediqueue.test	Paciente Stress 40706448-2369	55002369	ACTIVO	2026-06-02 22:53:15.765111	2026-06-02 22:53:15.765111	0
63bbef24-3955-4d7a-bed4-dbd48a680abf	94070648600002389	stress-40706486-2389@mediqueue.test	Paciente Stress 40706486-2389	55002389	ACTIVO	2026-06-02 22:53:15.964326	2026-06-02 22:53:15.964326	0
4db143c5-a9f6-40b1-883c-fb0ddd903854	94070645100002554	stress-40706451-2554@mediqueue.test	Paciente Stress 40706451-2554	55002554	ACTIVO	2026-06-02 22:53:18.086586	2026-06-02 22:53:18.086586	0
69ff4459-a7a4-4568-bce1-521b78c422fa	94070644100002589	stress-40706441-2589@mediqueue.test	Paciente Stress 40706441-2589	55002589	ACTIVO	2026-06-02 22:53:18.260876	2026-06-02 22:53:18.260876	0
b30d3d77-4f51-4fcd-94e8-7f3a244f91de	94070643700003196	stress-40706437-3196@mediqueue.test	Paciente Stress 40706437-3196	55003196	ACTIVO	2026-06-02 22:53:23.57695	2026-06-02 22:53:23.57695	0
0a0a4b6e-ee4d-4668-a75e-0d6475a9d060	94070645800003358	stress-40706458-3358@mediqueue.test	Paciente Stress 40706458-3358	55003358	ACTIVO	2026-06-02 22:53:25.173812	2026-06-02 22:53:25.173812	0
b97c47cb-8a5e-435f-9c2c-b758c6766555	94070646900003544	stress-40706469-3544@mediqueue.test	Paciente Stress 40706469-3544	55003544	ACTIVO	2026-06-02 22:53:27.057773	2026-06-02 22:53:27.057773	0
ada0d743-d64e-48a1-9e6d-f59d13cd0ebe	94070641500003629	stress-40706415-3629@mediqueue.test	Paciente Stress 40706415-3629	55003629	ACTIVO	2026-06-02 22:53:27.811588	2026-06-02 22:53:27.811588	0
b37480d5-08ed-4958-866c-cb5e88028464	94070643500003682	stress-40706435-3682@mediqueue.test	Paciente Stress 40706435-3682	55003682	ACTIVO	2026-06-02 22:53:28.303288	2026-06-02 22:53:28.303288	0
a61090ba-6dc6-412d-b99f-9ffdc94f221a	93979295800006823	stress-39792958-6823@mediqueue.test	Paciente Stress 39792958-6823	55006823	ACTIVO	2026-06-02 22:40:37.110836	2026-06-02 22:40:37.110836	0
c179fbbd-da22-4be2-8360-283117dbcd28	93979295900006902	stress-39792959-6902@mediqueue.test	Paciente Stress 39792959-6902	55006902	ACTIVO	2026-06-02 22:40:37.558305	2026-06-02 22:40:37.558305	0
072b65b2-9aad-446e-b919-a55f051ae7b1	93979296900007188	stress-39792969-7188@mediqueue.test	Paciente Stress 39792969-7188	55007188	ACTIVO	2026-06-02 22:40:39.031377	2026-06-02 22:40:39.031377	0
e68fd5c2-e4f2-45e8-9673-97f1cad7ba96	93979301700007281	stress-39793017-7281@mediqueue.test	Paciente Stress 39793017-7281	55007281	ACTIVO	2026-06-02 22:40:39.53913	2026-06-02 22:40:39.53913	0
ee234a54-eafc-4a0c-bd2a-62e8d605d21c	93979295800007303	stress-39792958-7303@mediqueue.test	Paciente Stress 39792958-7303	55007303	ACTIVO	2026-06-02 22:40:39.742764	2026-06-02 22:40:39.742764	0
d4a10c6d-e4dd-41d2-9c07-bb44a619665c	93979302200007707	stress-39793022-7707@mediqueue.test	Paciente Stress 39793022-7707	55007707	ACTIVO	2026-06-02 22:40:43.244096	2026-06-02 22:40:43.244096	0
5826cc9c-b190-4df5-916a-191cbd889288	93979297000007778	stress-39792970-7778@mediqueue.test	Paciente Stress 39792970-7778	55007778	ACTIVO	2026-06-02 22:40:43.835174	2026-06-02 22:40:43.835174	0
18285595-c286-468d-9ea6-5638b61b4c41	93979302200007907	stress-39793022-7907@mediqueue.test	Paciente Stress 39793022-7907	55007907	ACTIVO	2026-06-02 22:40:44.61176	2026-06-02 22:40:44.61176	0
f2b1e96e-c7f9-4eeb-8e0c-15fb867ce443	93979295700008613	stress-39792957-8613@mediqueue.test	Paciente Stress 39792957-8613	55008613	ACTIVO	2026-06-02 22:41:45.744892	2026-06-02 22:41:45.744892	0
7ae495b1-1fdd-4971-81f1-174102bbc620	94045694900009606	stress-40456949-9606@mediqueue.test	Paciente Stress 40456949-9606	55009606	ACTIVO	2026-06-02 22:49:44.349233	2026-06-02 22:49:44.349233	0
7bdfe115-fdde-4cf5-81ab-6e0f042e8450	94045696100009689	stress-40456961-9689@mediqueue.test	Paciente Stress 40456961-9689	55009689	ACTIVO	2026-06-02 22:49:45.1957	2026-06-02 22:49:45.1957	0
defdaea9-ed29-4dce-b6e7-99ef9b071234	94045691800009784	stress-40456918-9784@mediqueue.test	Paciente Stress 40456918-9784	55009784	ACTIVO	2026-06-02 22:51:05.591344	2026-06-02 22:51:05.591344	0
0015331f-a1ed-4640-a0a5-36409bf69060	94045694600009801	stress-40456946-9801@mediqueue.test	Paciente Stress 40456946-9801	55009801	ACTIVO	2026-06-02 22:51:05.644712	2026-06-02 22:51:05.644712	0
dedea4bf-a59b-4a53-9d50-99df8e749f63	94045693600009875	stress-40456936-9875@mediqueue.test	Paciente Stress 40456936-9875	55009875	ACTIVO	2026-06-02 22:51:05.713298	2026-06-02 22:51:05.713298	0
63507a73-a8c5-4e62-b251-5d985d418cf5	94070642600000381	stress-40706426-381@mediqueue.test	Paciente Stress 40706426-381	55000381	ACTIVO	2026-06-02 22:51:51.010324	2026-06-02 22:51:51.010324	0
5bab10fe-c163-439b-9745-0e36b61647b6	94070643900000112	stress-40706439-112@mediqueue.test	Paciente Stress 40706439-112	55000112	ACTIVO	2026-06-02 22:51:51.475742	2026-06-02 22:51:51.475742	0
a2340f2e-5ae3-4168-8b39-83b0c13b31bf	94070641500000532	stress-40706415-532@mediqueue.test	Paciente Stress 40706415-532	55000532	ACTIVO	2026-06-02 22:51:52.014008	2026-06-02 22:51:52.014008	0
a3f92b96-58b8-4233-9418-5c7471924abc	94070646100000654	stress-40706461-654@mediqueue.test	Paciente Stress 40706461-654	55000654	ACTIVO	2026-06-02 22:51:52.790189	2026-06-02 22:51:52.790189	0
9eb6aa6e-cbfa-436e-87c4-3dbea08f1ff0	94070645800000947	stress-40706458-947@mediqueue.test	Paciente Stress 40706458-947	55000947	ACTIVO	2026-06-02 22:51:55.89535	2026-06-02 22:51:55.89535	0
3b3f28e2-6795-425b-8d9b-380da7a9bd60	94070648400001004	stress-40706484-1004@mediqueue.test	Paciente Stress 40706484-1004	55001004	ACTIVO	2026-06-02 22:51:56.506646	2026-06-02 22:51:56.506646	0
8ddc3249-571d-401f-bf55-c7d54bbdf4f3	94070644600001043	stress-40706446-1043@mediqueue.test	Paciente Stress 40706446-1043	55001043	ACTIVO	2026-06-02 22:51:57.212367	2026-06-02 22:51:57.212367	0
4def5416-6d57-4a5f-8325-3c08630010eb	94070645400001160	stress-40706454-1160@mediqueue.test	Paciente Stress 40706454-1160	55001160	ACTIVO	2026-06-02 22:51:58.319851	2026-06-02 22:51:58.319851	0
39e6c0a5-b046-4f83-af9d-2698a48967d7	94070645000001314	stress-40706450-1314@mediqueue.test	Paciente Stress 40706450-1314	55001314	ACTIVO	2026-06-02 22:51:59.786912	2026-06-02 22:51:59.786912	0
c403151c-ebbe-45f8-98f0-69a7444448c7	94070645800001427	stress-40706458-1427@mediqueue.test	Paciente Stress 40706458-1427	55001427	ACTIVO	2026-06-02 22:52:00.731286	2026-06-02 22:52:00.731286	0
1fc592b0-4f16-4805-a30e-ed089daa2d30	94070647200001512	stress-40706472-1512@mediqueue.test	Paciente Stress 40706472-1512	55001512	ACTIVO	2026-06-02 22:52:01.66627	2026-06-02 22:52:01.66627	0
2b545831-bc7d-4ea4-8dc0-a2141f2d8fed	94070642200001660	stress-40706422-1660@mediqueue.test	Paciente Stress 40706422-1660	55001660	ACTIVO	2026-06-02 22:52:03.044914	2026-06-02 22:52:03.044914	0
8a4dee24-239c-4a2e-9e80-f366a89aa157	94070642500002366	stress-40706425-2366@mediqueue.test	Paciente Stress 40706425-2366	55002366	ACTIVO	2026-06-02 22:53:15.766152	2026-06-02 22:53:15.766152	0
0aabda2f-351e-4cb8-b4c2-34362f6602a1	94070644300002312	stress-40706443-2312@mediqueue.test	Paciente Stress 40706443-2312	55002312	ACTIVO	2026-06-02 22:53:16.494279	2026-06-02 22:53:16.494279	0
b4fc3579-bf08-4d72-a3a2-caa76577705f	94070647200002862	stress-40706472-2862@mediqueue.test	Paciente Stress 40706472-2862	55002862	ACTIVO	2026-06-02 22:53:20.247937	2026-06-02 22:53:20.247937	0
8c47a6c7-e6b0-4dfe-b51a-c512ce417e16	94070646500003401	stress-40706465-3401@mediqueue.test	Paciente Stress 40706465-3401	55003401	ACTIVO	2026-06-02 22:53:25.504155	2026-06-02 22:53:25.504155	0
d858f37e-28b0-474b-9ef1-1b3822b476a2	94070642500003587	stress-40706425-3587@mediqueue.test	Paciente Stress 40706425-3587	55003587	ACTIVO	2026-06-02 22:53:27.475945	2026-06-02 22:53:27.475945	0
4cb8a832-4c7f-4c05-b9ee-834b1015e84b	94070641500003620	stress-40706415-3620@mediqueue.test	Paciente Stress 40706415-3620	55003620	ACTIVO	2026-06-02 22:53:27.736476	2026-06-02 22:53:27.736476	0
69a40db4-87a7-42a3-87a2-06ba6d9671b4	94070645400003797	stress-40706454-3797@mediqueue.test	Paciente Stress 40706454-3797	55003797	ACTIVO	2026-06-02 22:53:29.258456	2026-06-02 22:53:29.258456	0
e55d929d-8539-48d1-9df1-69f3fb0a9a9b	94173203000000412	stress-41732030-412@mediqueue.test	Paciente Stress 41732030-412	55000412	ACTIVO	2026-06-02 23:08:56.192876	2026-06-02 23:08:56.192876	0
1f12b26a-c0aa-43c3-b593-be46bcd05b6c	94173201500000110	stress-41732015-110@mediqueue.test	Paciente Stress 41732015-110	55000110	ACTIVO	2026-06-02 23:08:57.58041	2026-06-02 23:08:57.58041	0
65b5cb12-0c37-4188-ae01-6fc6e80d29c9	94173205600000277	stress-41732056-277@mediqueue.test	Paciente Stress 41732056-277	55000277	ACTIVO	2026-06-02 23:08:57.671311	2026-06-02 23:08:57.671311	0
3aca7288-9abe-42ed-9462-57e7154a2bbf	94173205800000631	stress-41732058-631@mediqueue.test	Paciente Stress 41732058-631	55000631	ACTIVO	2026-06-02 23:08:59.408186	2026-06-02 23:08:59.408186	0
5465d30c-7b9a-4523-a9e0-68d774f2ab85	94173203300000537	stress-41732033-537@mediqueue.test	Paciente Stress 41732033-537	55000537	ACTIVO	2026-06-02 23:09:00.248481	2026-06-02 23:09:00.248481	0
6a336a63-8bb9-4fd6-b036-b0c2e6ffbbf3	94173197700000678	stress-41731977-678@mediqueue.test	Paciente Stress 41731977-678	55000678	ACTIVO	2026-06-02 23:09:00.407516	2026-06-02 23:09:00.407516	0
3a26e203-70cb-4e84-b28c-018128eac90f	94173206100001093	stress-41732061-1093@mediqueue.test	Paciente Stress 41732061-1093	55001093	ACTIVO	2026-06-02 23:09:02.868164	2026-06-02 23:09:02.868164	0
95d0ae35-1001-4fca-b1fa-372d6d8c4dad	94173199100001147	stress-41731991-1147@mediqueue.test	Paciente Stress 41731991-1147	55001147	ACTIVO	2026-06-02 23:09:03.13809	2026-06-02 23:09:03.13809	0
d6e0ca31-9bc9-4f47-888c-f106429ad862	94173206100001224	stress-41732061-1224@mediqueue.test	Paciente Stress 41732061-1224	55001224	ACTIVO	2026-06-02 23:09:03.888524	2026-06-02 23:09:03.888524	0
80367c57-03e1-4a17-9811-dd8c5b6e5059	94173203100001484	stress-41732031-1484@mediqueue.test	Paciente Stress 41732031-1484	55001484	ACTIVO	2026-06-02 23:09:06.991532	2026-06-02 23:09:06.991532	0
070378ad-1820-43e6-bae9-042c5b49a171	94173203500001515	stress-41732035-1515@mediqueue.test	Paciente Stress 41732035-1515	55001515	ACTIVO	2026-06-02 23:09:07.17821	2026-06-02 23:09:07.17821	0
8c5b339c-f869-417e-b07e-f2a694501c87	94173203200001601	stress-41732032-1601@mediqueue.test	Paciente Stress 41732032-1601	55001601	ACTIVO	2026-06-02 23:09:07.977733	2026-06-02 23:09:07.977733	0
d5d9d802-a2f6-47a7-a1a1-fcb51a49e5b1	94173201500001616	stress-41732015-1616@mediqueue.test	Paciente Stress 41732015-1616	55001616	ACTIVO	2026-06-02 23:09:08.112961	2026-06-02 23:09:08.112961	0
8ae86eb4-d81d-45d4-91f3-6aa32fd0ffae	94173203200001758	stress-41732032-1758@mediqueue.test	Paciente Stress 41732032-1758	55001758	ACTIVO	2026-06-02 23:09:09.519484	2026-06-02 23:09:09.519484	0
5dfd960a-d450-4a07-859e-571514878546	93979305800008772	stress-39793058-8772@mediqueue.test	Paciente Stress 39793058-8772	55008772	ACTIVO	2026-06-02 22:41:46.271683	2026-06-02 22:41:46.271683	0
d943dedc-9a30-428a-99b7-bb25b58f0000	93979302400008879	stress-39793024-8879@mediqueue.test	Paciente Stress 39793024-8879	55008879	ACTIVO	2026-06-02 22:41:46.350334	2026-06-02 22:41:46.350334	0
e9f5f347-9172-4b47-ab17-22eb30c04ba4	93979295700008902	stress-39792957-8902@mediqueue.test	Paciente Stress 39792957-8902	55008902	ACTIVO	2026-06-02 22:41:46.745975	2026-06-02 22:41:46.745975	0
7771248b-793e-466e-8c2d-ac4d7a348a9f	93979306000008978	stress-39793060-8978@mediqueue.test	Paciente Stress 39793060-8978	55008978	ACTIVO	2026-06-02 22:41:46.892279	2026-06-02 22:41:46.892279	0
76590542-649a-4570-b751-7e646cdb7241	93979298100009033	stress-39792981-9033@mediqueue.test	Paciente Stress 39792981-9033	55009033	ACTIVO	2026-06-02 22:41:47.329493	2026-06-02 22:41:47.329493	0
c5cd2e1e-99b2-4a2e-ae53-6a5da765be64	93979299900009377	stress-39792999-9377@mediqueue.test	Paciente Stress 39792999-9377	55009377	ACTIVO	2026-06-02 22:41:49.946952	2026-06-02 22:41:49.946952	0
c0085269-18d8-419e-a841-e7f5f33eb71e	94045693500000029	stress-40456935-29@mediqueue.test	Paciente Stress 40456935-29	55000029	ACTIVO	2026-06-02 22:47:39.933533	2026-06-02 22:47:39.933533	0
c7f49671-c0ce-47db-ab19-9972e71e27c7	94045693000000263	stress-40456930-263@mediqueue.test	Paciente Stress 40456930-263	55000263	ACTIVO	2026-06-02 22:47:40.780592	2026-06-02 22:47:40.780592	0
84165f11-acce-49f2-a377-07086fe5f838	94045692700000521	stress-40456927-521@mediqueue.test	Paciente Stress 40456927-521	55000521	ACTIVO	2026-06-02 22:47:41.499821	2026-06-02 22:47:41.499821	0
5a1b96a3-ba45-47e5-a008-3ed91a10bc3d	94045693600001000	stress-40456936-1000@mediqueue.test	Paciente Stress 40456936-1000	55001000	ACTIVO	2026-06-02 22:47:46.031425	2026-06-02 22:47:46.031425	0
b558c43f-64ef-43b9-a87b-cd296042223c	94045696500001161	stress-40456965-1161@mediqueue.test	Paciente Stress 40456965-1161	55001161	ACTIVO	2026-06-02 22:47:47.233128	2026-06-02 22:47:47.233128	0
7d9827ab-ab1a-41b4-8e28-9343d756f6aa	94045694300001229	stress-40456943-1229@mediqueue.test	Paciente Stress 40456943-1229	55001229	ACTIVO	2026-06-02 22:47:48.020673	2026-06-02 22:47:48.020673	0
51095e6d-997d-4c9c-8abf-5240fe1eb317	94045692300001469	stress-40456923-1469@mediqueue.test	Paciente Stress 40456923-1469	55001469	ACTIVO	2026-06-02 22:47:50.400374	2026-06-02 22:47:50.400374	0
240a4be7-7183-4f55-b740-46b69c4ebadc	94045695100001575	stress-40456951-1575@mediqueue.test	Paciente Stress 40456951-1575	55001575	ACTIVO	2026-06-02 22:47:51.369476	2026-06-02 22:47:51.369476	0
4039aea3-f93d-44b0-bb44-b894fe05a0dd	94045695100002125	stress-40456951-2125@mediqueue.test	Paciente Stress 40456951-2125	55002125	ACTIVO	2026-06-02 22:47:56.606054	2026-06-02 22:47:56.606054	0
b8b4817c-51e8-47cb-ba0f-3c43220d4f7a	94045694700002640	stress-40456947-2640@mediqueue.test	Paciente Stress 40456947-2640	55002640	ACTIVO	2026-06-02 22:48:01.267038	2026-06-02 22:48:01.267038	0
16ec1a85-1263-4bb2-a6f9-e80e64bb8e51	94045694000002882	stress-40456940-2882@mediqueue.test	Paciente Stress 40456940-2882	55002882	ACTIVO	2026-06-02 22:48:03.431853	2026-06-02 22:48:03.431853	0
07b71cdd-1d86-4a29-87fb-090b45aa1c4e	94045693100003136	stress-40456931-3136@mediqueue.test	Paciente Stress 40456931-3136	55003136	ACTIVO	2026-06-02 22:48:05.298931	2026-06-02 22:48:05.298931	0
076a9666-1c8e-40df-a70a-0e80a4864569	94045695600004097	stress-40456956-4097@mediqueue.test	Paciente Stress 40456956-4097	55004097	ACTIVO	2026-06-02 22:48:13.362641	2026-06-02 22:48:13.362641	0
9c737b3b-8658-44e0-b55c-9a23e6608c7e	94045696000004280	stress-40456960-4280@mediqueue.test	Paciente Stress 40456960-4280	55004280	ACTIVO	2026-06-02 22:48:14.997741	2026-06-02 22:48:14.997741	0
a3014af4-4ab4-4107-b016-66ffe76d2db0	94045695900004564	stress-40456959-4564@mediqueue.test	Paciente Stress 40456959-4564	55004564	ACTIVO	2026-06-02 22:48:17.629214	2026-06-02 22:48:17.629214	0
e37cf4c3-67b8-43b7-bcee-f55dc5f57311	94045692800004978	stress-40456928-4978@mediqueue.test	Paciente Stress 40456928-4978	55004978	ACTIVO	2026-06-02 22:48:21.080492	2026-06-02 22:48:21.080492	0
b3711e01-e58a-460b-8b17-1bff044b7ed5	94045692900005019	stress-40456929-5019@mediqueue.test	Paciente Stress 40456929-5019	55005019	ACTIVO	2026-06-02 22:48:21.38706	2026-06-02 22:48:21.38706	0
7f0b69dd-c3ec-4177-8eb1-366eed60f7ce	94045696000005146	stress-40456960-5146@mediqueue.test	Paciente Stress 40456960-5146	55005146	ACTIVO	2026-06-02 22:48:22.79371	2026-06-02 22:48:22.79371	0
f2f01321-c4aa-4326-bb7f-01ff35d18b51	94045692800005540	stress-40456928-5540@mediqueue.test	Paciente Stress 40456928-5540	55005540	ACTIVO	2026-06-02 22:48:25.925003	2026-06-02 22:48:25.925003	0
f3d01ea4-dca8-40bf-97bb-b6afb4ddf002	94045694300005798	stress-40456943-5798@mediqueue.test	Paciente Stress 40456943-5798	55005798	ACTIVO	2026-06-02 22:48:27.946181	2026-06-02 22:48:27.946181	0
e04e09c7-333c-4ddf-9ce9-efdc474fba23	94045691500006183	stress-40456915-6183@mediqueue.test	Paciente Stress 40456915-6183	55006183	ACTIVO	2026-06-02 22:48:38.078301	2026-06-02 22:48:38.078301	0
4932b72c-48c3-4a5a-ba43-9750b05606dd	94045695900006238	stress-40456959-6238@mediqueue.test	Paciente Stress 40456959-6238	55006238	ACTIVO	2026-06-02 22:48:38.596675	2026-06-02 22:48:38.596675	0
a2e2fd4f-c7de-4d79-a7bd-8d57b0ff6c9f	94045691800006719	stress-40456918-6719@mediqueue.test	Paciente Stress 40456918-6719	55006719	ACTIVO	2026-06-02 22:48:42.593525	2026-06-02 22:48:42.593525	0
0c4b8c55-09cc-4889-a5c7-97b7f26e4cfd	94045692100006919	stress-40456921-6919@mediqueue.test	Paciente Stress 40456921-6919	55006919	ACTIVO	2026-06-02 22:48:44.244144	2026-06-02 22:48:44.244144	0
260d82f0-2941-42fc-802f-0bde9bfb4f33	94070641700000106	stress-40706417-106@mediqueue.test	Paciente Stress 40706417-106	55000106	ACTIVO	2026-06-02 22:51:49.409946	2026-06-02 22:51:49.409946	0
acafbf5c-b267-4b1c-8042-f58cbaa914b7	94070645100000426	stress-40706451-426@mediqueue.test	Paciente Stress 40706451-426	55000426	ACTIVO	2026-06-02 22:51:51.525914	2026-06-02 22:51:51.525914	0
e65a03b3-cdd2-47d4-ac99-97c1359e2d87	94070643500000739	stress-40706435-739@mediqueue.test	Paciente Stress 40706435-739	55000739	ACTIVO	2026-06-02 22:51:53.355212	2026-06-02 22:51:53.355212	0
af132d03-5cde-42ff-979f-f5b1b6bd3dd9	94070648800001075	stress-40706488-1075@mediqueue.test	Paciente Stress 40706488-1075	55001075	ACTIVO	2026-06-02 22:51:57.481332	2026-06-02 22:51:57.481332	0
e42dece5-ae62-4d6c-8fb8-cf4f7a591a8a	94070644100002199	stress-40706441-2199@mediqueue.test	Paciente Stress 40706441-2199	55002199	ACTIVO	2026-06-02 22:53:15.280615	2026-06-02 22:53:15.280615	0
7e55ae66-8245-4f12-b66e-f7bb61aa9a5d	94070643000002232	stress-40706430-2232@mediqueue.test	Paciente Stress 40706430-2232	55002232	ACTIVO	2026-06-02 22:53:15.422546	2026-06-02 22:53:15.422546	0
91be08fa-d7c0-413a-ab63-8a691a22515d	94070641500002246	stress-40706415-2246@mediqueue.test	Paciente Stress 40706415-2246	55002246	ACTIVO	2026-06-02 22:53:15.564075	2026-06-02 22:53:15.564075	0
06758b3c-3a21-4e41-a246-deba035840e7	94070646400002348	stress-40706464-2348@mediqueue.test	Paciente Stress 40706464-2348	55002348	ACTIVO	2026-06-02 22:53:15.739426	2026-06-02 22:53:15.739426	0
7b7b1ccb-7dcd-4b24-8d98-fa5ef9f15a84	94070645100002384	stress-40706451-2384@mediqueue.test	Paciente Stress 40706451-2384	55002384	ACTIVO	2026-06-02 22:53:15.902806	2026-06-02 22:53:15.902806	0
a2913346-43cc-4660-845b-11859a195fed	94070646200003515	stress-40706462-3515@mediqueue.test	Paciente Stress 40706462-3515	55003515	ACTIVO	2026-06-02 22:53:26.827232	2026-06-02 22:53:26.827232	0
bf75f2e3-a580-49b8-9d40-4fa0dfd4efe6	94173203800000259	stress-41732038-259@mediqueue.test	Paciente Stress 41732038-259	55000259	ACTIVO	2026-06-02 23:08:56.885738	2026-06-02 23:08:56.885738	0
66fc0ae7-69ab-4450-8e7d-1bc9ae6d86f9	94173203300000308	stress-41732033-308@mediqueue.test	Paciente Stress 41732033-308	55000308	ACTIVO	2026-06-02 23:08:57.864712	2026-06-02 23:08:57.864712	0
08dfc31e-fc32-445f-b679-079eef0e6af8	94173203100000660	stress-41732031-660@mediqueue.test	Paciente Stress 41732031-660	55000660	ACTIVO	2026-06-02 23:08:58.870909	2026-06-02 23:08:58.870909	0
37a6d71c-2e0e-4317-a832-b2b2424bf83a	94173200600001055	stress-41732006-1055@mediqueue.test	Paciente Stress 41732006-1055	55001055	ACTIVO	2026-06-02 23:09:01.927406	2026-06-02 23:09:01.927406	0
d75fa2ec-915a-4d03-af72-d4bc6f94225c	94173201200001843	stress-41732012-1843@mediqueue.test	Paciente Stress 41732012-1843	55001843	ACTIVO	2026-06-02 23:09:10.161554	2026-06-02 23:09:10.161554	0
df4c6889-3dff-4731-bd93-13fe35f938ee	94173205100001864	stress-41732051-1864@mediqueue.test	Paciente Stress 41732051-1864	55001864	ACTIVO	2026-06-02 23:09:10.359401	2026-06-02 23:09:10.359401	0
feb378b4-399e-4034-9fe5-1411db8198dd	94173204400001908	stress-41732044-1908@mediqueue.test	Paciente Stress 41732044-1908	55001908	ACTIVO	2026-06-02 23:09:10.647077	2026-06-02 23:09:10.647077	0
ef5bcd21-1b65-4875-8663-9b859602fb8a	93979299900008680	stress-39792999-8680@mediqueue.test	Paciente Stress 39792999-8680	55008680	ACTIVO	2026-06-02 22:41:46.321391	2026-06-02 22:41:46.321391	0
8151ca4e-3a74-4a64-b009-187cd2b0a398	93979297400008823	stress-39792974-8823@mediqueue.test	Paciente Stress 39792974-8823	55008823	ACTIVO	2026-06-02 22:41:46.384356	2026-06-02 22:41:46.384356	0
e2008f89-105e-49f2-a5ca-461fa0871350	93979298500008957	stress-39792985-8957@mediqueue.test	Paciente Stress 39792985-8957	55008957	ACTIVO	2026-06-02 22:41:46.8102	2026-06-02 22:41:46.8102	0
95c7363b-feab-4cee-a8fb-5303c45216fe	93979302600009325	stress-39793026-9325@mediqueue.test	Paciente Stress 39793026-9325	55009325	ACTIVO	2026-06-02 22:41:49.670144	2026-06-02 22:41:49.670144	0
bc15f77c-af4d-48f9-868d-5f08b0fc08ce	93979300100009602	stress-39793001-9602@mediqueue.test	Paciente Stress 39793001-9602	55009602	ACTIVO	2026-06-02 22:41:52.074281	2026-06-02 22:41:52.074281	0
8d4ff84d-800a-45b5-aeeb-f708142543cb	93979306000009813	stress-39793060-9813@mediqueue.test	Paciente Stress 39793060-9813	55009813	ACTIVO	2026-06-02 22:41:53.859003	2026-06-02 22:41:53.859003	0
ee944cc5-cdfa-463b-9311-483f5e3f33c8	94045693600000037	stress-40456936-37@mediqueue.test	Paciente Stress 40456936-37	55000037	ACTIVO	2026-06-02 22:47:37.499546	2026-06-02 22:47:37.499546	0
b4b547a7-cdb2-40f1-a20b-a47e4377ba42	94045695900000125	stress-40456959-125@mediqueue.test	Paciente Stress 40456959-125	55000125	ACTIVO	2026-06-02 22:47:40.392492	2026-06-02 22:47:40.392492	0
ca5e1556-4ac2-4616-b04a-b34556130b6a	94045691800000421	stress-40456918-421@mediqueue.test	Paciente Stress 40456918-421	55000421	ACTIVO	2026-06-02 22:47:40.504901	2026-06-02 22:47:40.504901	0
d35ba16f-e9bb-4c9f-ad04-64da37d7117c	94045691200000307	stress-40456912-307@mediqueue.test	Paciente Stress 40456912-307	55000307	ACTIVO	2026-06-02 22:47:41.071394	2026-06-02 22:47:41.071394	0
37a889fc-3a5c-4973-9723-b3dc26409523	94045692300000366	stress-40456923-366@mediqueue.test	Paciente Stress 40456923-366	55000366	ACTIVO	2026-06-02 22:47:41.215462	2026-06-02 22:47:41.215462	0
f45daad8-9ffc-4710-9b89-5d1e79757adc	94045693000000444	stress-40456930-444@mediqueue.test	Paciente Stress 40456930-444	55000444	ACTIVO	2026-06-02 22:47:41.340196	2026-06-02 22:47:41.340196	0
45e3f714-c9c6-434f-984e-80d771f1a5f8	94045693000000553	stress-40456930-553@mediqueue.test	Paciente Stress 40456930-553	55000553	ACTIVO	2026-06-02 22:47:41.532772	2026-06-02 22:47:41.532772	0
096a9a42-857d-47e4-8751-5e0080af3997	94045694300001244	stress-40456943-1244@mediqueue.test	Paciente Stress 40456943-1244	55001244	ACTIVO	2026-06-02 22:47:48.177244	2026-06-02 22:47:48.177244	0
fcaff0b4-8cfd-49fc-97a2-712c367396d9	94045695300002467	stress-40456953-2467@mediqueue.test	Paciente Stress 40456953-2467	55002467	ACTIVO	2026-06-02 22:47:59.936806	2026-06-02 22:47:59.936806	0
45dc3b38-c8a1-4c6f-b45b-34ddff83f238	94045693600003220	stress-40456936-3220@mediqueue.test	Paciente Stress 40456936-3220	55003220	ACTIVO	2026-06-02 22:48:05.918268	2026-06-02 22:48:05.918268	0
7217ce96-60f5-46c6-a059-334d6d79d3f6	94045695600003383	stress-40456956-3383@mediqueue.test	Paciente Stress 40456956-3383	55003383	ACTIVO	2026-06-02 22:48:07.29578	2026-06-02 22:48:07.29578	0
17a7709c-704e-4dc2-b1dd-19b1f72f8124	94045695800003887	stress-40456958-3887@mediqueue.test	Paciente Stress 40456958-3887	55003887	ACTIVO	2026-06-02 22:48:12.034111	2026-06-02 22:48:12.034111	0
211bd435-36c9-4504-804c-69835e71922f	94045693000004087	stress-40456930-4087@mediqueue.test	Paciente Stress 40456930-4087	55004087	ACTIVO	2026-06-02 22:48:13.308474	2026-06-02 22:48:13.308474	0
c574d073-68ce-42ef-b56a-8034e398a1c8	94045692700005051	stress-40456927-5051@mediqueue.test	Paciente Stress 40456927-5051	55005051	ACTIVO	2026-06-02 22:48:21.78334	2026-06-02 22:48:21.78334	0
687eed5f-70a7-485a-8e86-df646a569494	94045696000005117	stress-40456960-5117@mediqueue.test	Paciente Stress 40456960-5117	55005117	ACTIVO	2026-06-02 22:48:22.533435	2026-06-02 22:48:22.533435	0
db9fcbe8-6adb-42ea-a9a1-33816b06e2c3	94045695700005264	stress-40456957-5264@mediqueue.test	Paciente Stress 40456957-5264	55005264	ACTIVO	2026-06-02 22:48:23.712274	2026-06-02 22:48:23.712274	0
692f07ec-f9b6-43c5-9ef7-ef3165b9da8b	94045696300006194	stress-40456963-6194@mediqueue.test	Paciente Stress 40456963-6194	55006194	ACTIVO	2026-06-02 22:48:38.192525	2026-06-02 22:48:38.192525	0
3ae119a0-1daa-4384-9dd0-9445f2e363bc	94045696100006283	stress-40456961-6283@mediqueue.test	Paciente Stress 40456961-6283	55006283	ACTIVO	2026-06-02 22:48:38.950231	2026-06-02 22:48:38.950231	0
0a232776-be74-4340-a209-76d6668d4bcf	94045695600006302	stress-40456956-6302@mediqueue.test	Paciente Stress 40456956-6302	55006302	ACTIVO	2026-06-02 22:48:39.188632	2026-06-02 22:48:39.188632	0
6e9dd5cb-8dfc-4da7-aeb2-63e1493167b8	94045693800006418	stress-40456938-6418@mediqueue.test	Paciente Stress 40456938-6418	55006418	ACTIVO	2026-06-02 22:48:40.261439	2026-06-02 22:48:40.261439	0
5201f49c-c5b4-43b1-be30-9326f01fd6bc	94045695700006447	stress-40456957-6447@mediqueue.test	Paciente Stress 40456957-6447	55006447	ACTIVO	2026-06-02 22:48:40.396084	2026-06-02 22:48:40.396084	0
bae4bd7b-8fd3-4495-9bab-ad2d0e781ccb	94070645500001191	stress-40706455-1191@mediqueue.test	Paciente Stress 40706455-1191	55001191	ACTIVO	2026-06-02 22:51:58.561694	2026-06-02 22:51:58.561694	0
9cf9f055-3681-423e-b7ed-8f60d2509e02	94070646500001437	stress-40706465-1437@mediqueue.test	Paciente Stress 40706465-1437	55001437	ACTIVO	2026-06-02 22:52:00.843671	2026-06-02 22:52:00.843671	0
f9d8119b-5c16-4036-adb4-1280cae21448	94070648400001843	stress-40706484-1843@mediqueue.test	Paciente Stress 40706484-1843	55001843	ACTIVO	2026-06-02 22:52:04.884925	2026-06-02 22:52:04.884925	0
e9ad3ffe-72a7-4065-bdaf-7784ef3ccbd9	94070644200001958	stress-40706442-1958@mediqueue.test	Paciente Stress 40706442-1958	55001958	ACTIVO	2026-06-02 22:53:11.244895	2026-06-02 22:53:11.244895	0
acd29a01-3e11-4547-a51f-215a7c4d43a6	94070641800001935	stress-40706418-1935@mediqueue.test	Paciente Stress 40706418-1935	55001935	ACTIVO	2026-06-02 22:53:12.216634	2026-06-02 22:53:12.216634	0
0ff8281f-c5df-46b2-91b2-9b3bd0f1b3c1	94070647600002494	stress-40706476-2494@mediqueue.test	Paciente Stress 40706476-2494	55002494	ACTIVO	2026-06-02 22:53:16.327339	2026-06-02 22:53:16.327339	0
94de7e63-2d7a-4b76-a294-235155d9340a	94070646900002467	stress-40706469-2467@mediqueue.test	Paciente Stress 40706469-2467	55002467	ACTIVO	2026-06-02 22:53:16.554671	2026-06-02 22:53:16.554671	0
cad4566a-50b4-4802-98ec-0d2c8e2bdbd8	94070645100002431	stress-40706451-2431@mediqueue.test	Paciente Stress 40706451-2431	55002431	ACTIVO	2026-06-02 22:53:17.565499	2026-06-02 22:53:17.565499	0
717cde32-aea9-402f-9b96-e1824465f48f	94070646500002913	stress-40706465-2913@mediqueue.test	Paciente Stress 40706465-2913	55002913	ACTIVO	2026-06-02 22:53:20.598775	2026-06-02 22:53:20.598775	0
bdeca1e7-78b8-4fa4-9dd2-d631a00ddfb3	94070641500002998	stress-40706415-2998@mediqueue.test	Paciente Stress 40706415-2998	55002998	ACTIVO	2026-06-02 22:53:21.444661	2026-06-02 22:53:21.444661	0
81bcc2a8-ce53-40e7-9dee-e0f6f2e21651	94070644700003103	stress-40706447-3103@mediqueue.test	Paciente Stress 40706447-3103	55003103	ACTIVO	2026-06-02 22:53:22.57004	2026-06-02 22:53:22.57004	0
a642956e-aef0-40cb-981e-b630c8b4aa38	94070645400003146	stress-40706454-3146@mediqueue.test	Paciente Stress 40706454-3146	55003146	ACTIVO	2026-06-02 22:53:22.983315	2026-06-02 22:53:22.983315	0
8c47ed49-e7cc-4c0a-bb17-7056291d9b0c	94070648400003505	stress-40706484-3505@mediqueue.test	Paciente Stress 40706484-3505	55003505	ACTIVO	2026-06-02 22:53:26.690813	2026-06-02 22:53:26.690813	0
7075e1b4-979d-4ebb-8536-4e4524518231	94173206000000124	stress-41732060-124@mediqueue.test	Paciente Stress 41732060-124	55000124	ACTIVO	2026-06-02 23:08:57.122489	2026-06-02 23:08:57.122489	0
76822261-2504-4120-9085-8ecfd5b9418b	94173200500000330	stress-41732005-330@mediqueue.test	Paciente Stress 41732005-330	55000330	ACTIVO	2026-06-02 23:08:59.51332	2026-06-02 23:08:59.51332	0
ec8e2871-982c-4f91-b788-e1439116bcd8	94173205000000767	stress-41732050-767@mediqueue.test	Paciente Stress 41732050-767	55000767	ACTIVO	2026-06-02 23:08:59.989015	2026-06-02 23:08:59.989015	0
dfd31db1-f2ec-46ec-af45-540196cf0654	94173206300000617	stress-41732063-617@mediqueue.test	Paciente Stress 41732063-617	55000617	ACTIVO	2026-06-02 23:09:00.236553	2026-06-02 23:09:00.236553	0
40405308-e942-4b63-a35c-664580224abe	94173205900001275	stress-41732059-1275@mediqueue.test	Paciente Stress 41732059-1275	55001275	ACTIVO	2026-06-02 23:09:04.656273	2026-06-02 23:09:04.656273	0
56265281-c330-4860-a20f-77ba84b344d9	94173203200001320	stress-41732032-1320@mediqueue.test	Paciente Stress 41732032-1320	55001320	ACTIVO	2026-06-02 23:09:05.010046	2026-06-02 23:09:05.010046	0
aae7318b-e975-442a-a498-13a37eccef20	94173205400001872	stress-41732054-1872@mediqueue.test	Paciente Stress 41732054-1872	55001872	ACTIVO	2026-06-02 23:09:10.451726	2026-06-02 23:09:10.451726	0
a0e002e6-fff7-4c80-9d09-80b412f59ff8	93979304600008871	stress-39793046-8871@mediqueue.test	Paciente Stress 39793046-8871	55008871	ACTIVO	2026-06-02 22:41:46.521646	2026-06-02 22:41:46.521646	0
9d5a1345-d08f-47aa-a995-b30a4cb93370	93979295900008858	stress-39792959-8858@mediqueue.test	Paciente Stress 39792959-8858	55008858	ACTIVO	2026-06-02 22:41:46.69705	2026-06-02 22:41:46.69705	0
bcc416ef-cda1-4f47-9967-608b3537fbfe	93979300600009029	stress-39793006-9029@mediqueue.test	Paciente Stress 39793006-9029	55009029	ACTIVO	2026-06-02 22:41:47.285619	2026-06-02 22:41:47.285619	0
76017c51-9b42-43d7-a181-536c1dc04f04	93979297600009271	stress-39792976-9271@mediqueue.test	Paciente Stress 39792976-9271	55009271	ACTIVO	2026-06-02 22:41:49.056439	2026-06-02 22:41:49.056439	0
f17a9d8b-240f-4365-8c91-dffab191161f	93979295900009608	stress-39792959-9608@mediqueue.test	Paciente Stress 39792959-9608	55009608	ACTIVO	2026-06-02 22:41:52.095621	2026-06-02 22:41:52.095621	0
95782a96-5faa-4bb4-87d9-61fd015cfbfd	93979300000009626	stress-39793000-9626@mediqueue.test	Paciente Stress 39793000-9626	55009626	ACTIVO	2026-06-02 22:41:52.294013	2026-06-02 22:41:52.294013	0
e3c0d2d9-f2f5-42a4-a127-79a4ecb417f0	94045691300000023	stress-40456913-23@mediqueue.test	Paciente Stress 40456913-23	55000023	ACTIVO	2026-06-02 22:47:39.57989	2026-06-02 22:47:39.57989	0
7944a180-3308-487f-9192-07f83d850779	94045692900000235	stress-40456929-235@mediqueue.test	Paciente Stress 40456929-235	55000235	ACTIVO	2026-06-02 22:47:40.499743	2026-06-02 22:47:40.499743	0
da69cd0b-0e7b-43e7-a98e-629beb7f3963	94045695200000715	stress-40456952-715@mediqueue.test	Paciente Stress 40456952-715	55000715	ACTIVO	2026-06-02 22:47:43.232681	2026-06-02 22:47:43.232681	0
64e61893-b3c0-4911-bf3c-4b6b8c4ed9e6	94045694600001961	stress-40456946-1961@mediqueue.test	Paciente Stress 40456946-1961	55001961	ACTIVO	2026-06-02 22:47:55.245798	2026-06-02 22:47:55.245798	0
808029c0-ba72-4969-8bef-af00d4234037	94045693700002149	stress-40456937-2149@mediqueue.test	Paciente Stress 40456937-2149	55002149	ACTIVO	2026-06-02 22:47:56.772638	2026-06-02 22:47:56.772638	0
1d3a8545-d748-47a4-b674-63ca8de54f91	94045695200002248	stress-40456952-2248@mediqueue.test	Paciente Stress 40456952-2248	55002248	ACTIVO	2026-06-02 22:47:57.625397	2026-06-02 22:47:57.625397	0
7ddd3c28-a15a-4682-9527-02b51f7aa398	94045692300002568	stress-40456923-2568@mediqueue.test	Paciente Stress 40456923-2568	55002568	ACTIVO	2026-06-02 22:48:00.600776	2026-06-02 22:48:00.600776	0
b392a310-fa06-445a-99ce-67f1160f41bf	94045693200002948	stress-40456932-2948@mediqueue.test	Paciente Stress 40456932-2948	55002948	ACTIVO	2026-06-02 22:48:03.788648	2026-06-02 22:48:03.788648	0
b7aa1184-b8a4-4946-8565-4593f70c21a6	94045694300003112	stress-40456943-3112@mediqueue.test	Paciente Stress 40456943-3112	55003112	ACTIVO	2026-06-02 22:48:05.099905	2026-06-02 22:48:05.099905	0
d05d50ef-6cfb-450d-8dd1-5f736e65b78d	94045695000003710	stress-40456950-3710@mediqueue.test	Paciente Stress 40456950-3710	55003710	ACTIVO	2026-06-02 22:48:10.382621	2026-06-02 22:48:10.382621	0
f627d83b-a96e-4214-8dc7-c4871822bb19	94045691200003968	stress-40456912-3968@mediqueue.test	Paciente Stress 40456912-3968	55003968	ACTIVO	2026-06-02 22:48:12.558784	2026-06-02 22:48:12.558784	0
a56ebfa6-f2f4-4bf8-b538-fde14c47a828	94045695700004094	stress-40456957-4094@mediqueue.test	Paciente Stress 40456957-4094	55004094	ACTIVO	2026-06-02 22:48:13.38994	2026-06-02 22:48:13.38994	0
1324657b-c1f0-40d6-af44-71f584956cf9	94045692300004226	stress-40456923-4226@mediqueue.test	Paciente Stress 40456923-4226	55004226	ACTIVO	2026-06-02 22:48:14.621399	2026-06-02 22:48:14.621399	0
c0b633ec-88dd-480e-839d-32635e882649	94045691500004517	stress-40456915-4517@mediqueue.test	Paciente Stress 40456915-4517	55004517	ACTIVO	2026-06-02 22:48:17.031269	2026-06-02 22:48:17.031269	0
0d6c32c5-d9b1-4583-a5d0-4f25bf1c813e	94045693600004741	stress-40456936-4741@mediqueue.test	Paciente Stress 40456936-4741	55004741	ACTIVO	2026-06-02 22:48:19.148272	2026-06-02 22:48:19.148272	0
45e890db-a688-43e5-9e52-70d8695d5e75	94045695700004846	stress-40456957-4846@mediqueue.test	Paciente Stress 40456957-4846	55004846	ACTIVO	2026-06-02 22:48:19.937939	2026-06-02 22:48:19.937939	0
941a222f-f020-4660-b473-acf2d81ec89f	94045691800005118	stress-40456918-5118@mediqueue.test	Paciente Stress 40456918-5118	55005118	ACTIVO	2026-06-02 22:48:22.551897	2026-06-02 22:48:22.551897	0
51dc30e8-e047-4861-922b-7998cedcf321	94045693900005205	stress-40456939-5205@mediqueue.test	Paciente Stress 40456939-5205	55005205	ACTIVO	2026-06-02 22:48:23.417174	2026-06-02 22:48:23.417174	0
d20f1b62-cb54-4cab-bab4-d03ca37d3c98	94045693500005455	stress-40456935-5455@mediqueue.test	Paciente Stress 40456935-5455	55005455	ACTIVO	2026-06-02 22:48:25.378173	2026-06-02 22:48:25.378173	0
30d6dbee-20b2-4b52-a280-e9fdbebec101	94045692000005534	stress-40456920-5534@mediqueue.test	Paciente Stress 40456920-5534	55005534	ACTIVO	2026-06-02 22:48:25.899355	2026-06-02 22:48:25.899355	0
656c469e-db7a-4df9-a78f-c1dd39162602	94045695100005845	stress-40456951-5845@mediqueue.test	Paciente Stress 40456951-5845	55005845	ACTIVO	2026-06-02 22:48:28.204089	2026-06-02 22:48:28.204089	0
099e241a-4b39-4e7d-8bc1-f1c0c23dd383	94045693100006069	stress-40456931-6069@mediqueue.test	Paciente Stress 40456931-6069	55006069	ACTIVO	2026-06-02 22:48:36.861607	2026-06-02 22:48:36.861607	0
b322d486-cc9f-4fe7-b18b-5032cb2a0308	94045696300006599	stress-40456963-6599@mediqueue.test	Paciente Stress 40456963-6599	55006599	ACTIVO	2026-06-02 22:48:41.797922	2026-06-02 22:48:41.797922	0
7f61d841-8873-4382-8013-5835c1b9de3a	94045693000006780	stress-40456930-6780@mediqueue.test	Paciente Stress 40456930-6780	55006780	ACTIVO	2026-06-02 22:48:43.150208	2026-06-02 22:48:43.150208	0
18324199-ab7c-49d5-87fe-314cb3ead7af	94045692800006969	stress-40456928-6969@mediqueue.test	Paciente Stress 40456928-6969	55006969	ACTIVO	2026-06-02 22:48:44.678042	2026-06-02 22:48:44.678042	0
6be3e421-3505-4095-9db3-ac5a41f94c5f	94045696200007098	stress-40456962-7098@mediqueue.test	Paciente Stress 40456962-7098	55007098	ACTIVO	2026-06-02 22:48:45.638575	2026-06-02 22:48:45.638575	0
8750e2fd-9ff7-4c05-a95a-5e1f08401044	94070646700001772	stress-40706467-1772@mediqueue.test	Paciente Stress 40706467-1772	55001772	ACTIVO	2026-06-02 22:52:04.067263	2026-06-02 22:52:04.067263	0
1ed2ba99-b1e2-4e3a-b27f-d850018ab510	94070646500002005	stress-40706465-2005@mediqueue.test	Paciente Stress 40706465-2005	55002005	ACTIVO	2026-06-02 22:53:13.244027	2026-06-02 22:53:13.244027	0
323b03d5-6b3d-4740-a17d-fc8d92d4c066	94070643500002437	stress-40706435-2437@mediqueue.test	Paciente Stress 40706435-2437	55002437	ACTIVO	2026-06-02 22:53:16.401269	2026-06-02 22:53:16.401269	0
89a58103-c1c1-46f6-956a-785ffb1adeca	94070648700002638	stress-40706487-2638@mediqueue.test	Paciente Stress 40706487-2638	55002638	ACTIVO	2026-06-02 22:53:18.397484	2026-06-02 22:53:18.397484	0
5309b63e-1bf0-4f82-ae69-5f8a18849339	94070644800002632	stress-40706448-2632@mediqueue.test	Paciente Stress 40706448-2632	55002632	ACTIVO	2026-06-02 22:53:18.488003	2026-06-02 22:53:18.488003	0
ac930bf1-a784-413d-b63c-cc879607ed53	94070645100002736	stress-40706451-2736@mediqueue.test	Paciente Stress 40706451-2736	55002736	ACTIVO	2026-06-02 22:53:18.733261	2026-06-02 22:53:18.733261	0
e06c4297-7f71-4997-9464-4a9b41e68fa7	94070646400002777	stress-40706464-2777@mediqueue.test	Paciente Stress 40706464-2777	55002777	ACTIVO	2026-06-02 22:53:19.263876	2026-06-02 22:53:19.263876	0
3613ecf9-c138-43d1-a0fe-8b21734f2749	94070646400002796	stress-40706464-2796@mediqueue.test	Paciente Stress 40706464-2796	55002796	ACTIVO	2026-06-02 22:53:19.573263	2026-06-02 22:53:19.573263	0
2cf37e09-443a-4d09-b806-22e5ac083214	94070647500003020	stress-40706475-3020@mediqueue.test	Paciente Stress 40706475-3020	55003020	ACTIVO	2026-06-02 22:53:21.575189	2026-06-02 22:53:21.575189	0
1f238db2-3dc2-47ec-86f7-7ebae804ed40	94070647000003551	stress-40706470-3551@mediqueue.test	Paciente Stress 40706470-3551	55003551	ACTIVO	2026-06-02 22:53:27.070941	2026-06-02 22:53:27.070941	0
5739fa99-7f64-44ef-b1a2-bb94df72f287	94070644100003575	stress-40706441-3575@mediqueue.test	Paciente Stress 40706441-3575	55003575	ACTIVO	2026-06-02 22:53:27.268993	2026-06-02 22:53:27.268993	0
683d90b4-a275-431f-9b66-7c23d0413fb0	94070648600003777	stress-40706486-3777@mediqueue.test	Paciente Stress 40706486-3777	55003777	ACTIVO	2026-06-02 22:53:29.062881	2026-06-02 22:53:29.062881	0
4f2a1cf6-999d-4fe9-b1a1-075424bdb57a	94070648700003795	stress-40706487-3795@mediqueue.test	Paciente Stress 40706487-3795	55003795	ACTIVO	2026-06-02 22:53:29.283806	2026-06-02 22:53:29.283806	0
1720bf16-8294-4ccb-aafe-ff381aa47a7c	94173204500000155	stress-41732045-155@mediqueue.test	Paciente Stress 41732045-155	55000155	ACTIVO	2026-06-02 23:08:57.241696	2026-06-02 23:08:57.241696	0
02e9a49c-4d23-4620-8019-93ba6183a949	94173200800000323	stress-41732008-323@mediqueue.test	Paciente Stress 41732008-323	55000323	ACTIVO	2026-06-02 23:08:57.679908	2026-06-02 23:08:57.679908	0
a47a7a56-cbaa-4fdf-b21d-8e8339d13071	93979295900008991	stress-39792959-8991@mediqueue.test	Paciente Stress 39792959-8991	55008991	ACTIVO	2026-06-02 22:41:46.925974	2026-06-02 22:41:46.925974	0
34438eda-ff8a-4b09-a650-25ef2768e80f	93979297700009124	stress-39792977-9124@mediqueue.test	Paciente Stress 39792977-9124	55009124	ACTIVO	2026-06-02 22:41:48.017564	2026-06-02 22:41:48.017564	0
9e42818e-0265-4e34-b887-2a910f6ac855	93979297700009250	stress-39792977-9250@mediqueue.test	Paciente Stress 39792977-9250	55009250	ACTIVO	2026-06-02 22:41:48.895873	2026-06-02 22:41:48.895873	0
40b295d2-fac2-4c47-948d-1ebd1bdc173a	93979295100009793	stress-39792951-9793@mediqueue.test	Paciente Stress 39792951-9793	55009793	ACTIVO	2026-06-02 22:41:53.584339	2026-06-02 22:41:53.584339	0
55a173b9-4516-45f9-a955-44859c49a32c	94045694100000253	stress-40456941-253@mediqueue.test	Paciente Stress 40456941-253	55000253	ACTIVO	2026-06-02 22:47:39.152502	2026-06-02 22:47:39.152502	0
6af47897-063c-4275-8c59-a15821d1d70a	94045692300000179	stress-40456923-179@mediqueue.test	Paciente Stress 40456923-179	55000179	ACTIVO	2026-06-02 22:47:40.328903	2026-06-02 22:47:40.328903	0
1fc7c59e-cee8-43a5-92cc-86efcc9c1fc1	94045695700000346	stress-40456957-346@mediqueue.test	Paciente Stress 40456957-346	55000346	ACTIVO	2026-06-02 22:47:40.659866	2026-06-02 22:47:40.659866	0
46b3b65a-b2c2-4071-ae5e-7d88e20cffa4	94045695600000546	stress-40456956-546@mediqueue.test	Paciente Stress 40456956-546	55000546	ACTIVO	2026-06-02 22:47:41.468362	2026-06-02 22:47:41.468362	0
7cc88821-a25b-4c9b-8669-156726ce21c9	94045695500000594	stress-40456955-594@mediqueue.test	Paciente Stress 40456955-594	55000594	ACTIVO	2026-06-02 22:47:42.049089	2026-06-02 22:47:42.049089	0
bf60249e-f8ca-4417-884f-ae9bb9afb5f0	94045693500000615	stress-40456935-615@mediqueue.test	Paciente Stress 40456935-615	55000615	ACTIVO	2026-06-02 22:47:42.373437	2026-06-02 22:47:42.373437	0
2c980dc0-6684-4156-ac2c-db01344bd11d	94045695500000646	stress-40456955-646@mediqueue.test	Paciente Stress 40456955-646	55000646	ACTIVO	2026-06-02 22:47:42.655135	2026-06-02 22:47:42.655135	0
5b833fab-6a4c-41cd-9737-b403081299c7	94045693500000674	stress-40456935-674@mediqueue.test	Paciente Stress 40456935-674	55000674	ACTIVO	2026-06-02 22:47:42.838849	2026-06-02 22:47:42.838849	0
0a0d90f4-6a0e-4d43-91ee-d84a22d5602f	94045694300000706	stress-40456943-706@mediqueue.test	Paciente Stress 40456943-706	55000706	ACTIVO	2026-06-02 22:47:43.056893	2026-06-02 22:47:43.056893	0
a7032e64-3ef4-4b45-9f30-5b9d2428856f	94045696400000804	stress-40456964-804@mediqueue.test	Paciente Stress 40456964-804	55000804	ACTIVO	2026-06-02 22:47:43.953478	2026-06-02 22:47:43.953478	0
587d3668-f7de-4a96-98c7-5344c80b636f	94045692800000916	stress-40456928-916@mediqueue.test	Paciente Stress 40456928-916	55000916	ACTIVO	2026-06-02 22:47:45.245363	2026-06-02 22:47:45.245363	0
444692c0-00c6-45d8-a882-49493d450081	94045694300001100	stress-40456943-1100@mediqueue.test	Paciente Stress 40456943-1100	55001100	ACTIVO	2026-06-02 22:47:46.749238	2026-06-02 22:47:46.749238	0
3beabef7-7679-46e4-944e-73e75be43fc1	94045692900001118	stress-40456929-1118@mediqueue.test	Paciente Stress 40456929-1118	55001118	ACTIVO	2026-06-02 22:47:46.899625	2026-06-02 22:47:46.899625	0
9d6590f9-ba22-4745-913a-3fdde28ee77d	94045695800001164	stress-40456958-1164@mediqueue.test	Paciente Stress 40456958-1164	55001164	ACTIVO	2026-06-02 22:47:47.255164	2026-06-02 22:47:47.255164	0
7c0c06a0-fd74-4895-9237-c04e9b458c88	94045691700001282	stress-40456917-1282@mediqueue.test	Paciente Stress 40456917-1282	55001282	ACTIVO	2026-06-02 22:47:48.634951	2026-06-02 22:47:48.634951	0
1f2e27d1-9556-4975-b272-2612067db26f	94045693900001429	stress-40456939-1429@mediqueue.test	Paciente Stress 40456939-1429	55001429	ACTIVO	2026-06-02 22:47:50.078976	2026-06-02 22:47:50.078976	0
4c4f21d8-fc78-4f4c-a501-579da2e5c032	94045696400001737	stress-40456964-1737@mediqueue.test	Paciente Stress 40456964-1737	55001737	ACTIVO	2026-06-02 22:47:53.031788	2026-06-02 22:47:53.031788	0
e74960ee-7817-4d60-bf8f-30e22d55e9e0	94045695300001869	stress-40456953-1869@mediqueue.test	Paciente Stress 40456953-1869	55001869	ACTIVO	2026-06-02 22:47:54.382786	2026-06-02 22:47:54.382786	0
7077d3cd-fecb-4ddc-a9bd-471c06d2e908	94045696100002275	stress-40456961-2275@mediqueue.test	Paciente Stress 40456961-2275	55002275	ACTIVO	2026-06-02 22:47:58.055674	2026-06-02 22:47:58.055674	0
18baced6-f3e5-4f8e-953a-10c9253fb919	94045694300002613	stress-40456943-2613@mediqueue.test	Paciente Stress 40456943-2613	55002613	ACTIVO	2026-06-02 22:48:01.104915	2026-06-02 22:48:01.104915	0
564130b7-213c-4ab7-b2ce-9ef0dad13988	94045693600002678	stress-40456936-2678@mediqueue.test	Paciente Stress 40456936-2678	55002678	ACTIVO	2026-06-02 22:48:01.620888	2026-06-02 22:48:01.620888	0
d821b8eb-0f89-42a9-a936-6881dd69d073	94045695600003035	stress-40456956-3035@mediqueue.test	Paciente Stress 40456956-3035	55003035	ACTIVO	2026-06-02 22:48:04.537714	2026-06-02 22:48:04.537714	0
c6299306-28ff-47ed-84e7-ece9730f1866	94045692700003065	stress-40456927-3065@mediqueue.test	Paciente Stress 40456927-3065	55003065	ACTIVO	2026-06-02 22:48:04.871562	2026-06-02 22:48:04.871562	0
be8c556a-2937-4486-8850-769e1b9753b8	94045693000003140	stress-40456930-3140@mediqueue.test	Paciente Stress 40456930-3140	55003140	ACTIVO	2026-06-02 22:48:05.357355	2026-06-02 22:48:05.357355	0
bb3fb8b2-5e0a-4ee6-be38-36747af9f006	94045696000003280	stress-40456960-3280@mediqueue.test	Paciente Stress 40456960-3280	55003280	ACTIVO	2026-06-02 22:48:06.591678	2026-06-02 22:48:06.591678	0
afaca333-d63a-4664-99b3-95e034e81dde	94045695800003433	stress-40456958-3433@mediqueue.test	Paciente Stress 40456958-3433	55003433	ACTIVO	2026-06-02 22:48:07.893372	2026-06-02 22:48:07.893372	0
0b660ca6-e0c5-4610-8bbc-8d6ae2766b27	94045696200003525	stress-40456962-3525@mediqueue.test	Paciente Stress 40456962-3525	55003525	ACTIVO	2026-06-02 22:48:08.802992	2026-06-02 22:48:08.802992	0
115bc22e-fee9-4bac-b7ed-3a097362244a	94045696300003713	stress-40456963-3713@mediqueue.test	Paciente Stress 40456963-3713	55003713	ACTIVO	2026-06-02 22:48:10.383117	2026-06-02 22:48:10.383117	0
464e84a0-4f88-4027-a68e-74442cd065e7	94045692300003874	stress-40456923-3874@mediqueue.test	Paciente Stress 40456923-3874	55003874	ACTIVO	2026-06-02 22:48:11.943359	2026-06-02 22:48:11.943359	0
1fc877d2-46bc-4062-ba73-48a9656495b6	94045693000003904	stress-40456930-3904@mediqueue.test	Paciente Stress 40456930-3904	55003904	ACTIVO	2026-06-02 22:48:12.170184	2026-06-02 22:48:12.170184	0
c5e893e3-cdf5-4c38-b7c9-6710eda0cec3	94045694300004015	stress-40456943-4015@mediqueue.test	Paciente Stress 40456943-4015	55004015	ACTIVO	2026-06-02 22:48:12.854756	2026-06-02 22:48:12.854756	0
8f3a31f6-d323-4c07-8b65-8fa30f17e1a7	94045694100004200	stress-40456941-4200@mediqueue.test	Paciente Stress 40456941-4200	55004200	ACTIVO	2026-06-02 22:48:14.42453	2026-06-02 22:48:14.42453	0
8dd8c4bb-a92a-4379-80df-a80eb517744b	94045694200004387	stress-40456942-4387@mediqueue.test	Paciente Stress 40456942-4387	55004387	ACTIVO	2026-06-02 22:48:15.931403	2026-06-02 22:48:15.931403	0
7d37bed0-60c9-4e4e-90df-31d30b38d605	94045694300004549	stress-40456943-4549@mediqueue.test	Paciente Stress 40456943-4549	55004549	ACTIVO	2026-06-02 22:48:17.498115	2026-06-02 22:48:17.498115	0
39a54e87-6542-417c-ae57-27e0d6b17910	94045694900004571	stress-40456949-4571@mediqueue.test	Paciente Stress 40456949-4571	55004571	ACTIVO	2026-06-02 22:48:17.644203	2026-06-02 22:48:17.644203	0
ffe0811c-edf2-4eaf-a574-e6afd4ced4b5	94045696200004598	stress-40456962-4598@mediqueue.test	Paciente Stress 40456962-4598	55004598	ACTIVO	2026-06-02 22:48:17.938839	2026-06-02 22:48:17.938839	0
98f7f336-3ca5-41d9-8adb-ba75bed520a3	94045692700004975	stress-40456927-4975@mediqueue.test	Paciente Stress 40456927-4975	55004975	ACTIVO	2026-06-02 22:48:21.047007	2026-06-02 22:48:21.047007	0
2d452eed-a5f6-4098-91c1-0bad67db50ce	94045695800005267	stress-40456958-5267@mediqueue.test	Paciente Stress 40456958-5267	55005267	ACTIVO	2026-06-02 22:48:23.740304	2026-06-02 22:48:23.740304	0
9f27ca40-bbc3-40f2-9954-6df9b30ad5d6	94045693500005282	stress-40456935-5282@mediqueue.test	Paciente Stress 40456935-5282	55005282	ACTIVO	2026-06-02 22:48:23.848278	2026-06-02 22:48:23.848278	0
61a76e63-8ab0-4057-84bf-1de76771f7c6	94045695600005329	stress-40456956-5329@mediqueue.test	Paciente Stress 40456956-5329	55005329	ACTIVO	2026-06-02 22:48:24.3267	2026-06-02 22:48:24.3267	0
69ce8f60-92a3-4145-a2f8-90fbfa7f041e	94045696100005354	stress-40456961-5354@mediqueue.test	Paciente Stress 40456961-5354	55005354	ACTIVO	2026-06-02 22:48:24.646869	2026-06-02 22:48:24.646869	0
940500db-3acc-4df8-859f-55e21b62933f	94045691200005380	stress-40456912-5380@mediqueue.test	Paciente Stress 40456912-5380	55005380	ACTIVO	2026-06-02 22:48:24.90613	2026-06-02 22:48:24.90613	0
75624bc3-0db3-4f72-8543-5dc24745faf7	94045694100005689	stress-40456941-5689@mediqueue.test	Paciente Stress 40456941-5689	55005689	ACTIVO	2026-06-02 22:48:27.136607	2026-06-02 22:48:27.136607	0
0cb711ea-41c9-4de8-9370-0dc99487c3c6	93979302600009007	stress-39793026-9007@mediqueue.test	Paciente Stress 39793026-9007	55009007	ACTIVO	2026-06-02 22:41:47.118378	2026-06-02 22:41:47.118378	0
954865b3-981e-43ad-a1e1-f7d38478763c	93979294900009118	stress-39792949-9118@mediqueue.test	Paciente Stress 39792949-9118	55009118	ACTIVO	2026-06-02 22:41:47.998102	2026-06-02 22:41:47.998102	0
0b1c9b0e-9a51-4dae-ade6-00da3f27e665	93979295900009437	stress-39792959-9437@mediqueue.test	Paciente Stress 39792959-9437	55009437	ACTIVO	2026-06-02 22:41:50.660154	2026-06-02 22:41:50.660154	0
2b46dfd9-f82c-4d9e-94d8-7075f1deb9cc	93979306300009468	stress-39793063-9468@mediqueue.test	Paciente Stress 39793063-9468	55009468	ACTIVO	2026-06-02 22:41:50.901777	2026-06-02 22:41:50.901777	0
932325ce-d500-4a6f-b154-d3fc7550953f	93979302200009703	stress-39793022-9703@mediqueue.test	Paciente Stress 39793022-9703	55009703	ACTIVO	2026-06-02 22:41:52.742318	2026-06-02 22:41:52.742318	0
43d6bf3d-19a5-4922-b17b-e109fc116d08	94045696600000299	stress-40456966-299@mediqueue.test	Paciente Stress 40456966-299	55000299	ACTIVO	2026-06-02 22:47:40.410689	2026-06-02 22:47:40.410689	0
be5a2bbb-c897-4500-9e60-81508e78be53	94045696900000556	stress-40456969-556@mediqueue.test	Paciente Stress 40456969-556	55000556	ACTIVO	2026-06-02 22:47:41.545896	2026-06-02 22:47:41.545896	0
617df3be-08b0-4a5b-921b-826282acbbcd	94045695500000614	stress-40456955-614@mediqueue.test	Paciente Stress 40456955-614	55000614	ACTIVO	2026-06-02 22:47:42.329051	2026-06-02 22:47:42.329051	0
27b81b82-e695-4a63-9583-aca55ee18757	94045695600000651	stress-40456956-651@mediqueue.test	Paciente Stress 40456956-651	55000651	ACTIVO	2026-06-02 22:47:42.727452	2026-06-02 22:47:42.727452	0
fa7c533a-7d5f-475e-b0f9-4bdf0fcd2cbd	94045691800000809	stress-40456918-809@mediqueue.test	Paciente Stress 40456918-809	55000809	ACTIVO	2026-06-02 22:47:43.973358	2026-06-02 22:47:43.973358	0
2b9fc0f4-ae2e-413f-8074-f7e1acc09b37	94045692200001006	stress-40456922-1006@mediqueue.test	Paciente Stress 40456922-1006	55001006	ACTIVO	2026-06-02 22:47:46.047229	2026-06-02 22:47:46.047229	0
4995d52d-225d-4b5c-aed4-d51a222da62f	94045693200001256	stress-40456932-1256@mediqueue.test	Paciente Stress 40456932-1256	55001256	ACTIVO	2026-06-02 22:47:48.285995	2026-06-02 22:47:48.285995	0
a0d43a7f-bd78-4d83-bd78-df92fc2487da	94045693100001272	stress-40456931-1272@mediqueue.test	Paciente Stress 40456931-1272	55001272	ACTIVO	2026-06-02 22:47:48.431133	2026-06-02 22:47:48.431133	0
b2657ce9-edb1-46f6-950d-bcadbc1b0efe	94045695200001315	stress-40456952-1315@mediqueue.test	Paciente Stress 40456952-1315	55001315	ACTIVO	2026-06-02 22:47:49.188655	2026-06-02 22:47:49.188655	0
3f8e432b-9523-4da4-b58e-2ef74f6c3665	94045691300001522	stress-40456913-1522@mediqueue.test	Paciente Stress 40456913-1522	55001522	ACTIVO	2026-06-02 22:47:50.829759	2026-06-02 22:47:50.829759	0
75c3e40b-7376-4740-a745-10335b84b3cb	94045696600001771	stress-40456966-1771@mediqueue.test	Paciente Stress 40456966-1771	55001771	ACTIVO	2026-06-02 22:47:53.650981	2026-06-02 22:47:53.650981	0
c796b188-6fa5-4fc4-aec1-439649dec016	94045691300002103	stress-40456913-2103@mediqueue.test	Paciente Stress 40456913-2103	55002103	ACTIVO	2026-06-02 22:47:56.391687	2026-06-02 22:47:56.391687	0
b419eea3-6caf-4452-a847-75bb29c17d79	94045695600002161	stress-40456956-2161@mediqueue.test	Paciente Stress 40456956-2161	55002161	ACTIVO	2026-06-02 22:47:56.829881	2026-06-02 22:47:56.829881	0
8e942716-7131-4511-847a-2a3804443480	94045691300002174	stress-40456913-2174@mediqueue.test	Paciente Stress 40456913-2174	55002174	ACTIVO	2026-06-02 22:47:56.953725	2026-06-02 22:47:56.953725	0
f7740c92-aa68-44d8-813e-e39784272e89	94045693800002629	stress-40456938-2629@mediqueue.test	Paciente Stress 40456938-2629	55002629	ACTIVO	2026-06-02 22:48:01.206519	2026-06-02 22:48:01.206519	0
ec20f17a-3712-4284-9a47-8283b1a535cb	94045695800002835	stress-40456958-2835@mediqueue.test	Paciente Stress 40456958-2835	55002835	ACTIVO	2026-06-02 22:48:03.077566	2026-06-02 22:48:03.077566	0
435ef129-9403-4b14-ae7e-1a1cd6f4b2a8	94045693000002979	stress-40456930-2979@mediqueue.test	Paciente Stress 40456930-2979	55002979	ACTIVO	2026-06-02 22:48:04.043092	2026-06-02 22:48:04.043092	0
011572ff-52a6-4ec2-89e7-56587bb7ad26	94045694100003223	stress-40456941-3223@mediqueue.test	Paciente Stress 40456941-3223	55003223	ACTIVO	2026-06-02 22:48:05.92556	2026-06-02 22:48:05.92556	0
d74e57b2-c555-4355-94ad-2bab49953c1c	94045696200003437	stress-40456962-3437@mediqueue.test	Paciente Stress 40456962-3437	55003437	ACTIVO	2026-06-02 22:48:07.919018	2026-06-02 22:48:07.919018	0
3a989f1d-734e-4e54-a5c8-60ce6b3c81f3	94045695000003986	stress-40456950-3986@mediqueue.test	Paciente Stress 40456950-3986	55003986	ACTIVO	2026-06-02 22:48:12.687628	2026-06-02 22:48:12.687628	0
80ca4c79-8807-4df0-9a2c-816f90b89f84	94045694300004039	stress-40456943-4039@mediqueue.test	Paciente Stress 40456943-4039	55004039	ACTIVO	2026-06-02 22:48:13.023472	2026-06-02 22:48:13.023472	0
3ba0bb96-f355-4b42-94db-b51036b0d2f1	94045696100004207	stress-40456961-4207@mediqueue.test	Paciente Stress 40456961-4207	55004207	ACTIVO	2026-06-02 22:48:14.475499	2026-06-02 22:48:14.475499	0
584e15d4-bad4-404b-8357-f6c0714fc86e	94045694700004394	stress-40456947-4394@mediqueue.test	Paciente Stress 40456947-4394	55004394	ACTIVO	2026-06-02 22:48:16.011572	2026-06-02 22:48:16.011572	0
1bd2cd18-242e-4760-b5d9-2090a754189a	94045694200004551	stress-40456942-4551@mediqueue.test	Paciente Stress 40456942-4551	55004551	ACTIVO	2026-06-02 22:48:17.53548	2026-06-02 22:48:17.53548	0
c7722121-714a-40e7-b74a-870ff0c4a80c	94045695300004656	stress-40456953-4656@mediqueue.test	Paciente Stress 40456953-4656	55004656	ACTIVO	2026-06-02 22:48:18.244671	2026-06-02 22:48:18.244671	0
ba1be3ea-3c39-41c0-a521-9fd3ea4ced9f	94045695300005013	stress-40456953-5013@mediqueue.test	Paciente Stress 40456953-5013	55005013	ACTIVO	2026-06-02 22:48:21.331368	2026-06-02 22:48:21.331368	0
830927db-d321-4dc1-ac19-2c8a9c26aafe	94045691700005479	stress-40456917-5479@mediqueue.test	Paciente Stress 40456917-5479	55005479	ACTIVO	2026-06-02 22:48:25.527856	2026-06-02 22:48:25.527856	0
f418e139-549f-475d-b08f-106f1075664a	94045695600005672	stress-40456956-5672@mediqueue.test	Paciente Stress 40456956-5672	55005672	ACTIVO	2026-06-02 22:48:27.047398	2026-06-02 22:48:27.047398	0
d2a8b5fa-cb1e-4cbd-b39c-2625fd4b1dcb	94045695000006265	stress-40456950-6265@mediqueue.test	Paciente Stress 40456950-6265	55006265	ACTIVO	2026-06-02 22:48:38.797238	2026-06-02 22:48:38.797238	0
9bcdbf7b-db6a-4243-8c53-8f34cb57ed1e	94045695500006285	stress-40456955-6285@mediqueue.test	Paciente Stress 40456955-6285	55006285	ACTIVO	2026-06-02 22:48:39.118971	2026-06-02 22:48:39.118971	0
14af0874-b863-4791-9a0a-c14dcd242e8e	94045696600006450	stress-40456966-6450@mediqueue.test	Paciente Stress 40456966-6450	55006450	ACTIVO	2026-06-02 22:48:40.491145	2026-06-02 22:48:40.491145	0
1ec8d07c-b865-498a-a3da-b949700907d8	94045692900006479	stress-40456929-6479@mediqueue.test	Paciente Stress 40456929-6479	55006479	ACTIVO	2026-06-02 22:48:40.670704	2026-06-02 22:48:40.670704	0
6436d217-199f-4206-8b73-7557781e3f15	94045694500006493	stress-40456945-6493@mediqueue.test	Paciente Stress 40456945-6493	55006493	ACTIVO	2026-06-02 22:48:40.923991	2026-06-02 22:48:40.923991	0
ebb00b24-3d58-4f9b-8212-432df49e8dfe	94045692900006810	stress-40456929-6810@mediqueue.test	Paciente Stress 40456929-6810	55006810	ACTIVO	2026-06-02 22:48:43.37283	2026-06-02 22:48:43.37283	0
1a6c1600-6dad-476a-94d8-5764b7f7a916	94045691200007023	stress-40456912-7023@mediqueue.test	Paciente Stress 40456912-7023	55007023	ACTIVO	2026-06-02 22:48:45.161441	2026-06-02 22:48:45.161441	0
f807c6ff-f25e-4665-9ff5-d281360ccbf5	94045691300007115	stress-40456913-7115@mediqueue.test	Paciente Stress 40456913-7115	55007115	ACTIVO	2026-06-02 22:48:45.812624	2026-06-02 22:48:45.812624	0
ac78b6b7-4e89-47e2-bf0e-35eac4206dfb	94070648700002945	stress-40706487-2945@mediqueue.test	Paciente Stress 40706487-2945	55002945	ACTIVO	2026-06-02 22:53:20.988864	2026-06-02 22:53:20.988864	0
304cc199-a376-417d-9e08-f69bb14ff2ca	94070645800003254	stress-40706458-3254@mediqueue.test	Paciente Stress 40706458-3254	55003254	ACTIVO	2026-06-02 22:53:24.279347	2026-06-02 22:53:24.279347	0
be80b4f0-62c0-45ef-bd42-ae7a87da756f	94070642300003485	stress-40706423-3485@mediqueue.test	Paciente Stress 40706423-3485	55003485	ACTIVO	2026-06-02 22:53:26.617596	2026-06-02 22:53:26.617596	0
f8beb87a-2c72-4432-8a8a-852df87dfec1	94070644900003556	stress-40706449-3556@mediqueue.test	Paciente Stress 40706449-3556	55003556	ACTIVO	2026-06-02 22:53:27.256956	2026-06-02 22:53:27.256956	0
6216c14c-8d06-41a3-b00e-38b3fce2db52	94070642300003821	stress-40706423-3821@mediqueue.test	Paciente Stress 40706423-3821	55003821	ACTIVO	2026-06-02 22:53:29.563425	2026-06-02 22:53:29.563425	0
a29e2c73-7dad-45e5-ac05-97c35b2b521f	94070646500003837	stress-40706465-3837@mediqueue.test	Paciente Stress 40706465-3837	55003837	ACTIVO	2026-06-02 22:53:29.665462	2026-06-02 22:53:29.665462	0
2a6b2d94-e0b1-44a9-901e-b734c98d407f	93979305600009012	stress-39793056-9012@mediqueue.test	Paciente Stress 39793056-9012	55009012	ACTIVO	2026-06-02 22:41:47.122111	2026-06-02 22:41:47.122111	0
d723d70c-6314-40ad-a8a1-f923d9e19222	93979301600009058	stress-39793016-9058@mediqueue.test	Paciente Stress 39793016-9058	55009058	ACTIVO	2026-06-02 22:41:47.655008	2026-06-02 22:41:47.655008	0
118fd590-82f1-431e-b0d9-a2aaa6ebe8f7	93979296300009313	stress-39792963-9313@mediqueue.test	Paciente Stress 39792963-9313	55009313	ACTIVO	2026-06-02 22:41:49.519723	2026-06-02 22:41:49.519723	0
e8a5781d-bb9f-493f-ba46-71ef142ba91f	93979298000009420	stress-39792980-9420@mediqueue.test	Paciente Stress 39792980-9420	55009420	ACTIVO	2026-06-02 22:41:50.51599	2026-06-02 22:41:50.51599	0
e71a773e-8a7b-4fc6-8b48-cc44c804fc93	93979295300009465	stress-39792953-9465@mediqueue.test	Paciente Stress 39792953-9465	55009465	ACTIVO	2026-06-02 22:41:50.879742	2026-06-02 22:41:50.879742	0
46065be9-cb37-40d3-8af9-8a5532be1c53	93979306000009511	stress-39793060-9511@mediqueue.test	Paciente Stress 39793060-9511	55009511	ACTIVO	2026-06-02 22:41:51.236217	2026-06-02 22:41:51.236217	0
392ceaca-a48f-4e97-858a-b608ac32badb	93979302200009716	stress-39793022-9716@mediqueue.test	Paciente Stress 39793022-9716	55009716	ACTIVO	2026-06-02 22:41:52.846771	2026-06-02 22:41:52.846771	0
a6d80b07-8b57-474f-b0ee-f694ca5e089e	93979300400009740	stress-39793004-9740@mediqueue.test	Paciente Stress 39793004-9740	55009740	ACTIVO	2026-06-02 22:41:52.952092	2026-06-02 22:41:52.952092	0
86586da9-a3dd-4051-8a58-a12be09d3e22	93979306000009841	stress-39793060-9841@mediqueue.test	Paciente Stress 39793060-9841	55009841	ACTIVO	2026-06-02 22:41:54.055771	2026-06-02 22:41:54.055771	0
ff798afd-1a30-403b-affc-cf2e76823bb7	94045696000000106	stress-40456960-106@mediqueue.test	Paciente Stress 40456960-106	55000106	ACTIVO	2026-06-02 22:47:38.063638	2026-06-02 22:47:38.063638	0
78d706fa-438e-40e8-833f-a90a71c2de3e	94045693900000327	stress-40456939-327@mediqueue.test	Paciente Stress 40456939-327	55000327	ACTIVO	2026-06-02 22:47:40.545185	2026-06-02 22:47:40.545185	0
88cc6f17-f350-43f3-80ee-98f3857f5b35	94045692700000170	stress-40456927-170@mediqueue.test	Paciente Stress 40456927-170	55000170	ACTIVO	2026-06-02 22:47:40.780555	2026-06-02 22:47:40.780555	0
15430a8d-6741-468d-a247-da4d772fe925	94045695700000371	stress-40456957-371@mediqueue.test	Paciente Stress 40456957-371	55000371	ACTIVO	2026-06-02 22:47:40.937246	2026-06-02 22:47:40.937246	0
cef84481-2338-48c0-bf6c-358b20ace5d0	94045696600000634	stress-40456966-634@mediqueue.test	Paciente Stress 40456966-634	55000634	ACTIVO	2026-06-02 22:47:42.609276	2026-06-02 22:47:42.609276	0
1d74f02d-b61e-4f8d-a07b-3a9566a71493	94045693000000663	stress-40456930-663@mediqueue.test	Paciente Stress 40456930-663	55000663	ACTIVO	2026-06-02 22:47:42.793369	2026-06-02 22:47:42.793369	0
645372b2-dc73-4c3c-ba0d-c76e2b58e74f	94045694900000680	stress-40456949-680@mediqueue.test	Paciente Stress 40456949-680	55000680	ACTIVO	2026-06-02 22:47:42.871971	2026-06-02 22:47:42.871971	0
8595b0c2-9f5f-4e13-bac9-4ad3e874443b	94045694600000817	stress-40456946-817@mediqueue.test	Paciente Stress 40456946-817	55000817	ACTIVO	2026-06-02 22:47:44.04019	2026-06-02 22:47:44.04019	0
1414d7b0-aedd-4533-923a-41aabbeb34e3	94045691300000962	stress-40456913-962@mediqueue.test	Paciente Stress 40456913-962	55000962	ACTIVO	2026-06-02 22:47:45.784997	2026-06-02 22:47:45.784997	0
00d1af08-6ec1-408b-a4c4-6f173b423310	94045696300001184	stress-40456963-1184@mediqueue.test	Paciente Stress 40456963-1184	55001184	ACTIVO	2026-06-02 22:47:47.385345	2026-06-02 22:47:47.385345	0
6e63a273-187f-41ce-b403-7c0d424103ab	94045693600001286	stress-40456936-1286@mediqueue.test	Paciente Stress 40456936-1286	55001286	ACTIVO	2026-06-02 22:47:48.747372	2026-06-02 22:47:48.747372	0
f86bba98-93ec-4077-89f0-431ddc0ab863	94045693600001325	stress-40456936-1325@mediqueue.test	Paciente Stress 40456936-1325	55001325	ACTIVO	2026-06-02 22:47:49.205347	2026-06-02 22:47:49.205347	0
03672957-a716-429d-a01f-6a39c939b557	94045692300001433	stress-40456923-1433@mediqueue.test	Paciente Stress 40456923-1433	55001433	ACTIVO	2026-06-02 22:47:50.113992	2026-06-02 22:47:50.113992	0
60e5dd67-0e7c-4459-b34f-f6dc62c158ce	94045694300001681	stress-40456943-1681@mediqueue.test	Paciente Stress 40456943-1681	55001681	ACTIVO	2026-06-02 22:47:52.369544	2026-06-02 22:47:52.369544	0
8bff11ac-9287-467c-bb86-d8f617aa4aa2	94045694900001748	stress-40456949-1748@mediqueue.test	Paciente Stress 40456949-1748	55001748	ACTIVO	2026-06-02 22:47:53.182515	2026-06-02 22:47:53.182515	0
7efe9afa-4d40-4e8f-93fb-34d30faa9f77	94045692900001907	stress-40456929-1907@mediqueue.test	Paciente Stress 40456929-1907	55001907	ACTIVO	2026-06-02 22:47:54.819132	2026-06-02 22:47:54.819132	0
f452fa0d-ba6f-4075-b7c1-8acf6a31468b	94045692700001970	stress-40456927-1970@mediqueue.test	Paciente Stress 40456927-1970	55001970	ACTIVO	2026-06-02 22:47:55.305369	2026-06-02 22:47:55.305369	0
e64bd8ce-7362-4736-8297-4c4df2c08904	94045691700002115	stress-40456917-2115@mediqueue.test	Paciente Stress 40456917-2115	55002115	ACTIVO	2026-06-02 22:47:56.48989	2026-06-02 22:47:56.48989	0
a77703da-ecc8-49e9-856e-0b57e2d6ed77	94045691800002444	stress-40456918-2444@mediqueue.test	Paciente Stress 40456918-2444	55002444	ACTIVO	2026-06-02 22:47:59.615904	2026-06-02 22:47:59.615904	0
cfd9047b-0431-4905-b97c-1360dbfd06da	94045691700002506	stress-40456917-2506@mediqueue.test	Paciente Stress 40456917-2506	55002506	ACTIVO	2026-06-02 22:48:00.22348	2026-06-02 22:48:00.22348	0
a1017bf3-7ce0-46e7-b5e9-08c178912189	94045692300002524	stress-40456923-2524@mediqueue.test	Paciente Stress 40456923-2524	55002524	ACTIVO	2026-06-02 22:48:00.374128	2026-06-02 22:48:00.374128	0
4da2f519-eff2-44dd-8310-4763a7ee6946	94045693600002704	stress-40456936-2704@mediqueue.test	Paciente Stress 40456936-2704	55002704	ACTIVO	2026-06-02 22:48:01.928018	2026-06-02 22:48:01.928018	0
50201849-5bcc-4837-bb1a-736b22411db3	94045694000002860	stress-40456940-2860@mediqueue.test	Paciente Stress 40456940-2860	55002860	ACTIVO	2026-06-02 22:48:03.299764	2026-06-02 22:48:03.299764	0
fd6b8eac-e937-427e-90b7-314d525fba3f	94045696800002967	stress-40456968-2967@mediqueue.test	Paciente Stress 40456968-2967	55002967	ACTIVO	2026-06-02 22:48:03.998284	2026-06-02 22:48:03.998284	0
03633441-1753-4fd8-a6a8-8579b3110764	94045696100003100	stress-40456961-3100@mediqueue.test	Paciente Stress 40456961-3100	55003100	ACTIVO	2026-06-02 22:48:05.044996	2026-06-02 22:48:05.044996	0
4af66ed9-dd3e-4ffe-a208-34b41d4993e4	94045693100003265	stress-40456931-3265@mediqueue.test	Paciente Stress 40456931-3265	55003265	ACTIVO	2026-06-02 22:48:06.479722	2026-06-02 22:48:06.479722	0
0d3dbf98-42f8-4b41-a301-705e72efb47b	94045696500003398	stress-40456965-3398@mediqueue.test	Paciente Stress 40456965-3398	55003398	ACTIVO	2026-06-02 22:48:07.419454	2026-06-02 22:48:07.419454	0
974de92a-cefa-438f-8641-d6fb95f89098	94045692100003504	stress-40456921-3504@mediqueue.test	Paciente Stress 40456921-3504	55003504	ACTIVO	2026-06-02 22:48:08.608401	2026-06-02 22:48:08.608401	0
1730925b-ee37-4554-b10d-65031a34837d	94045696100003523	stress-40456961-3523@mediqueue.test	Paciente Stress 40456961-3523	55003523	ACTIVO	2026-06-02 22:48:08.798938	2026-06-02 22:48:08.798938	0
ccb14681-23bb-4c93-9de4-01fccdf2a2e8	94045695800003568	stress-40456958-3568@mediqueue.test	Paciente Stress 40456958-3568	55003568	ACTIVO	2026-06-02 22:48:09.128219	2026-06-02 22:48:09.128219	0
2021a20b-1f3b-4168-acaa-403f5ae11760	94045695900003707	stress-40456959-3707@mediqueue.test	Paciente Stress 40456959-3707	55003707	ACTIVO	2026-06-02 22:48:10.383334	2026-06-02 22:48:10.383334	0
b89f433a-c36e-4f56-9a29-65faf23ab649	94045694600003791	stress-40456946-3791@mediqueue.test	Paciente Stress 40456946-3791	55003791	ACTIVO	2026-06-02 22:48:11.223536	2026-06-02 22:48:11.223536	0
2a763e49-e58a-47f1-89ab-72ec4db5bda1	94045695600003947	stress-40456956-3947@mediqueue.test	Paciente Stress 40456956-3947	55003947	ACTIVO	2026-06-02 22:48:12.389341	2026-06-02 22:48:12.389341	0
b2269d81-c036-4f6c-8ee2-c565cd561ac7	94045693900004179	stress-40456939-4179@mediqueue.test	Paciente Stress 40456939-4179	55004179	ACTIVO	2026-06-02 22:48:14.192221	2026-06-02 22:48:14.192221	0
0b8319b4-b6af-4f68-8b1f-21a8d7502e55	94045692700004298	stress-40456927-4298@mediqueue.test	Paciente Stress 40456927-4298	55004298	ACTIVO	2026-06-02 22:48:15.19636	2026-06-02 22:48:15.19636	0
ccfced39-0baa-4540-b589-0ac8e032d217	94045694400004321	stress-40456944-4321@mediqueue.test	Paciente Stress 40456944-4321	55004321	ACTIVO	2026-06-02 22:48:15.339127	2026-06-02 22:48:15.339127	0
8af2459f-8aa6-46eb-a8eb-bb1074529b6a	94045692700004645	stress-40456927-4645@mediqueue.test	Paciente Stress 40456927-4645	55004645	ACTIVO	2026-06-02 22:48:18.208702	2026-06-02 22:48:18.208702	0
f0ab90c0-195b-4938-839c-79fa1a1c7a2f	94045696300004699	stress-40456963-4699@mediqueue.test	Paciente Stress 40456963-4699	55004699	ACTIVO	2026-06-02 22:48:18.768342	2026-06-02 22:48:18.768342	0
8555fa02-00fd-4b18-9713-179453f7a705	93979297000009119	stress-39792970-9119@mediqueue.test	Paciente Stress 39792970-9119	55009119	ACTIVO	2026-06-02 22:41:47.990937	2026-06-02 22:41:47.990937	0
880096c3-b636-40a5-8e2e-a2927a02f4e1	93979304500009172	stress-39793045-9172@mediqueue.test	Paciente Stress 39793045-9172	55009172	ACTIVO	2026-06-02 22:41:48.376617	2026-06-02 22:41:48.376617	0
ba4bd5a4-9a21-49a8-90c7-23041b51979d	93979299600009550	stress-39792996-9550@mediqueue.test	Paciente Stress 39792996-9550	55009550	ACTIVO	2026-06-02 22:41:51.51476	2026-06-02 22:41:51.51476	0
1453f193-0a5b-443b-8d03-81b044891698	93979302700009607	stress-39793027-9607@mediqueue.test	Paciente Stress 39793027-9607	55009607	ACTIVO	2026-06-02 22:41:52.079836	2026-06-02 22:41:52.079836	0
605364a2-4bc7-4597-8193-041b61b3d4bf	93979299100009735	stress-39792991-9735@mediqueue.test	Paciente Stress 39792991-9735	55009735	ACTIVO	2026-06-02 22:41:52.925104	2026-06-02 22:41:52.925104	0
e510d989-7f0d-4754-a4e4-f01f68de0df3	93979306100009799	stress-39793061-9799@mediqueue.test	Paciente Stress 39793061-9799	55009799	ACTIVO	2026-06-02 22:41:53.687009	2026-06-02 22:41:53.687009	0
7c4115b8-283d-4fc3-bb39-e006d910f907	93979300000009834	stress-39793000-9834@mediqueue.test	Paciente Stress 39793000-9834	55009834	ACTIVO	2026-06-02 22:41:54.008016	2026-06-02 22:41:54.008016	0
e77cd659-b860-4a69-b303-e13922ea420a	93979306300009936	stress-39793063-9936@mediqueue.test	Paciente Stress 39793063-9936	55009936	ACTIVO	2026-06-02 22:41:54.811873	2026-06-02 22:41:54.811873	0
09a685d1-17ad-4535-9c1d-35af6c84c154	94045691300000001	stress-40456913-1@mediqueue.test	Paciente Stress 40456913-1	55000001	ACTIVO	2026-06-02 22:47:37.443488	2026-06-02 22:47:37.443488	0
02bb1492-ae53-4494-a295-920062814175	94045695800000241	stress-40456958-241@mediqueue.test	Paciente Stress 40456958-241	55000241	ACTIVO	2026-06-02 22:47:39.04136	2026-06-02 22:47:39.04136	0
89e3fa6f-ac0e-4d42-9754-e3c117c9a09f	94045693400000364	stress-40456934-364@mediqueue.test	Paciente Stress 40456934-364	55000364	ACTIVO	2026-06-02 22:47:40.67136	2026-06-02 22:47:40.67136	0
3b04870d-176d-4d21-9685-5766b40274b2	94045693600000316	stress-40456936-316@mediqueue.test	Paciente Stress 40456936-316	55000316	ACTIVO	2026-06-02 22:47:40.805973	2026-06-02 22:47:40.805973	0
ad21c939-ea71-46f2-b99b-da97e0c0f34c	94045695300000414	stress-40456953-414@mediqueue.test	Paciente Stress 40456953-414	55000414	ACTIVO	2026-06-02 22:47:40.931598	2026-06-02 22:47:40.931598	0
cc28edc4-0988-4bdb-af30-18c352f3eef3	94045691800000489	stress-40456918-489@mediqueue.test	Paciente Stress 40456918-489	55000489	ACTIVO	2026-06-02 22:47:41.465793	2026-06-02 22:47:41.465793	0
6dc88629-d538-4ad0-8b57-b8e291226728	94045694300000580	stress-40456943-580@mediqueue.test	Paciente Stress 40456943-580	55000580	ACTIVO	2026-06-02 22:47:41.980586	2026-06-02 22:47:41.980586	0
68e115a3-9b9d-4fea-b5d1-c46a057b09de	94045695600000882	stress-40456956-882@mediqueue.test	Paciente Stress 40456956-882	55000882	ACTIVO	2026-06-02 22:47:44.826715	2026-06-02 22:47:44.826715	0
0da93f69-e87a-4d26-9137-51ede69ba684	94045694300000899	stress-40456943-899@mediqueue.test	Paciente Stress 40456943-899	55000899	ACTIVO	2026-06-02 22:47:45.065727	2026-06-02 22:47:45.065727	0
7bef3582-907c-4a8b-844f-308f5617cfe4	94045693600000965	stress-40456936-965@mediqueue.test	Paciente Stress 40456936-965	55000965	ACTIVO	2026-06-02 22:47:45.808076	2026-06-02 22:47:45.808076	0
8c8b0437-0a3d-4f7d-a67d-071d3ad84939	94045695700001104	stress-40456957-1104@mediqueue.test	Paciente Stress 40456957-1104	55001104	ACTIVO	2026-06-02 22:47:46.80281	2026-06-02 22:47:46.80281	0
c74b69cd-8753-425f-8010-3882fd5f925e	94045696200001140	stress-40456962-1140@mediqueue.test	Paciente Stress 40456962-1140	55001140	ACTIVO	2026-06-02 22:47:47.090126	2026-06-02 22:47:47.090126	0
a4245f9f-a9f3-496a-997f-cde4c164e0d4	94045691800001393	stress-40456918-1393@mediqueue.test	Paciente Stress 40456918-1393	55001393	ACTIVO	2026-06-02 22:47:49.726956	2026-06-02 22:47:49.726956	0
5a79e5a3-9954-4f35-a44f-f530e2129f58	94045692300001412	stress-40456923-1412@mediqueue.test	Paciente Stress 40456923-1412	55001412	ACTIVO	2026-06-02 22:47:49.945841	2026-06-02 22:47:49.945841	0
f31e31ff-b3cd-4a1e-8f8b-58b26ae3cdb7	94045693600001792	stress-40456936-1792@mediqueue.test	Paciente Stress 40456936-1792	55001792	ACTIVO	2026-06-02 22:47:53.601964	2026-06-02 22:47:53.601964	0
061fb3a9-474e-4b33-a81b-44d715ea98bf	94045693600001821	stress-40456936-1821@mediqueue.test	Paciente Stress 40456936-1821	55001821	ACTIVO	2026-06-02 22:47:53.888578	2026-06-02 22:47:53.888578	0
c2b82919-d81a-4c4c-a1ed-b40d3f8e24e5	94045696700001840	stress-40456967-1840@mediqueue.test	Paciente Stress 40456967-1840	55001840	ACTIVO	2026-06-02 22:47:54.114909	2026-06-02 22:47:54.114909	0
92ea5285-e592-42b5-a7be-e4148bf0d2ac	94045694600001919	stress-40456946-1919@mediqueue.test	Paciente Stress 40456946-1919	55001919	ACTIVO	2026-06-02 22:47:54.934437	2026-06-02 22:47:54.934437	0
d423df69-d69f-403a-a073-a4b95c59e2f1	94045696900002119	stress-40456969-2119@mediqueue.test	Paciente Stress 40456969-2119	55002119	ACTIVO	2026-06-02 22:47:56.541806	2026-06-02 22:47:56.541806	0
46e61f99-249f-4cfb-a85b-277aa9909724	94045695000002483	stress-40456950-2483@mediqueue.test	Paciente Stress 40456950-2483	55002483	ACTIVO	2026-06-02 22:48:00.106446	2026-06-02 22:48:00.106446	0
99c824d2-5de1-441d-be8f-0a3c9bb7a20c	94045694600002846	stress-40456946-2846@mediqueue.test	Paciente Stress 40456946-2846	55002846	ACTIVO	2026-06-02 22:48:03.236899	2026-06-02 22:48:03.236899	0
517f475a-5d95-4dae-877f-c7b043bdfb7f	94045695600002905	stress-40456956-2905@mediqueue.test	Paciente Stress 40456956-2905	55002905	ACTIVO	2026-06-02 22:48:03.565901	2026-06-02 22:48:03.565901	0
3c785976-e017-4c63-9003-d6b9843b7e34	94045695000003121	stress-40456950-3121@mediqueue.test	Paciente Stress 40456950-3121	55003121	ACTIVO	2026-06-02 22:48:05.18485	2026-06-02 22:48:05.18485	0
c1f658cd-53c4-4f23-9793-d3e26242d7c9	94045695900003736	stress-40456959-3736@mediqueue.test	Paciente Stress 40456959-3736	55003736	ACTIVO	2026-06-02 22:48:10.685911	2026-06-02 22:48:10.685911	0
b0cee72f-b1b8-4a57-9cc1-6a5bc4e6df5b	94045694600004125	stress-40456946-4125@mediqueue.test	Paciente Stress 40456946-4125	55004125	ACTIVO	2026-06-02 22:48:13.673245	2026-06-02 22:48:13.673245	0
48069ad2-39d7-49b9-b5e6-6b69156f9704	94045695200004194	stress-40456952-4194@mediqueue.test	Paciente Stress 40456952-4194	55004194	ACTIVO	2026-06-02 22:48:14.348566	2026-06-02 22:48:14.348566	0
f5888a55-91ed-45b0-a9cd-3a5361d7c6e7	94045693500004393	stress-40456935-4393@mediqueue.test	Paciente Stress 40456935-4393	55004393	ACTIVO	2026-06-02 22:48:15.985571	2026-06-02 22:48:15.985571	0
18b1a1fc-3d1d-496e-b9a9-ee0b26c724bf	94045692900004427	stress-40456929-4427@mediqueue.test	Paciente Stress 40456929-4427	55004427	ACTIVO	2026-06-02 22:48:16.227433	2026-06-02 22:48:16.227433	0
5aa9bbb3-3242-4a06-bbd1-1c4339c7695f	94045692800004443	stress-40456928-4443@mediqueue.test	Paciente Stress 40456928-4443	55004443	ACTIVO	2026-06-02 22:48:16.381823	2026-06-02 22:48:16.381823	0
0bbdeb9b-d154-4e36-b5ef-fde2bc8e3e6f	94045695800004819	stress-40456958-4819@mediqueue.test	Paciente Stress 40456958-4819	55004819	ACTIVO	2026-06-02 22:48:19.683428	2026-06-02 22:48:19.683428	0
d8e3bc7f-3890-43a8-a580-61c8a79801b5	94045693600005012	stress-40456936-5012@mediqueue.test	Paciente Stress 40456936-5012	55005012	ACTIVO	2026-06-02 22:48:21.36101	2026-06-02 22:48:21.36101	0
8d2a3bcf-8fa5-47b8-9d74-bf1c3f0b59aa	94045696200005099	stress-40456962-5099@mediqueue.test	Paciente Stress 40456962-5099	55005099	ACTIVO	2026-06-02 22:48:22.32615	2026-06-02 22:48:22.32615	0
94a5836d-06f1-4999-b2e8-52495b9ed4a1	94045695600005368	stress-40456956-5368@mediqueue.test	Paciente Stress 40456956-5368	55005368	ACTIVO	2026-06-02 22:48:24.75187	2026-06-02 22:48:24.75187	0
f9344b67-5dd2-4039-9bc7-5d4263d7e59e	94045695000005481	stress-40456950-5481@mediqueue.test	Paciente Stress 40456950-5481	55005481	ACTIVO	2026-06-02 22:48:25.532814	2026-06-02 22:48:25.532814	0
2bd1fe7a-0cc1-46f9-9e8b-076b505b515e	94045693600005578	stress-40456936-5578@mediqueue.test	Paciente Stress 40456936-5578	55005578	ACTIVO	2026-06-02 22:48:26.258868	2026-06-02 22:48:26.258868	0
a3d50bcf-9ad2-480e-bf6b-bd0fa10ea373	94045695300005750	stress-40456953-5750@mediqueue.test	Paciente Stress 40456953-5750	55005750	ACTIVO	2026-06-02 22:48:27.730354	2026-06-02 22:48:27.730354	0
5025d35b-5870-49a8-bf01-8ebd716c7731	94045696200006124	stress-40456962-6124@mediqueue.test	Paciente Stress 40456962-6124	55006124	ACTIVO	2026-06-02 22:48:37.422008	2026-06-02 22:48:37.422008	0
e413624a-4cda-4c45-83fb-187650406b5a	94045696100006175	stress-40456961-6175@mediqueue.test	Paciente Stress 40456961-6175	55006175	ACTIVO	2026-06-02 22:48:38.078395	2026-06-02 22:48:38.078395	0
d7c4371b-e26e-48cc-bb23-16bf522d7281	94045694500006469	stress-40456945-6469@mediqueue.test	Paciente Stress 40456945-6469	55006469	ACTIVO	2026-06-02 22:48:40.611949	2026-06-02 22:48:40.611949	0
4947c851-d32b-420b-8256-7e857d338762	93979295800009128	stress-39792958-9128@mediqueue.test	Paciente Stress 39792958-9128	55009128	ACTIVO	2026-06-02 22:41:48.0377	2026-06-02 22:41:48.0377	0
cc0567fd-1f55-4de1-a966-41aca7ffffb3	93979300400009174	stress-39793004-9174@mediqueue.test	Paciente Stress 39793004-9174	55009174	ACTIVO	2026-06-02 22:41:48.377217	2026-06-02 22:41:48.377217	0
3ce4bef9-e0d8-41b4-8090-ea18fcf00fe8	93979294800009206	stress-39792948-9206@mediqueue.test	Paciente Stress 39792948-9206	55009206	ACTIVO	2026-06-02 22:41:48.618223	2026-06-02 22:41:48.618223	0
453fca0f-920d-4517-8c34-86cf5fbc6209	93979299400009356	stress-39792994-9356@mediqueue.test	Paciente Stress 39792994-9356	55009356	ACTIVO	2026-06-02 22:41:49.811715	2026-06-02 22:41:49.811715	0
65c7ee69-5373-47fb-87a1-167853415461	93979306300009453	stress-39793063-9453@mediqueue.test	Paciente Stress 39793063-9453	55009453	ACTIVO	2026-06-02 22:41:50.801392	2026-06-02 22:41:50.801392	0
62df36a1-2b1c-4549-89d0-7bfbd805166e	93979301400009467	stress-39793014-9467@mediqueue.test	Paciente Stress 39793014-9467	55009467	ACTIVO	2026-06-02 22:41:50.898635	2026-06-02 22:41:50.898635	0
e11ac73e-7586-4483-961d-667d0cbe97ac	93979302800009508	stress-39793028-9508@mediqueue.test	Paciente Stress 39793028-9508	55009508	ACTIVO	2026-06-02 22:41:51.213837	2026-06-02 22:41:51.213837	0
9f1f1478-1fc9-4a0f-8c0d-45bcee6c0a5f	93979297900009717	stress-39792979-9717@mediqueue.test	Paciente Stress 39792979-9717	55009717	ACTIVO	2026-06-02 22:41:52.840116	2026-06-02 22:41:52.840116	0
b9c67735-78a2-4f3f-96cd-e44c555ae3d5	93979300000009995	stress-39793000-9995@mediqueue.test	Paciente Stress 39793000-9995	55009995	ACTIVO	2026-06-02 22:41:55.18727	2026-06-02 22:41:55.18727	0
b535cf01-2af0-4cb7-b5f5-bb3a15caa91b	94045696600000161	stress-40456966-161@mediqueue.test	Paciente Stress 40456966-161	55000161	ACTIVO	2026-06-02 22:47:39.97564	2026-06-02 22:47:39.97564	0
4bc7186e-c637-4e66-ad58-955dc9629653	94045691500000479	stress-40456915-479@mediqueue.test	Paciente Stress 40456915-479	55000479	ACTIVO	2026-06-02 22:47:41.038415	2026-06-02 22:47:41.038415	0
c52a45f5-35d8-44b9-864b-0a9facac140c	94045693100001254	stress-40456931-1254@mediqueue.test	Paciente Stress 40456931-1254	55001254	ACTIVO	2026-06-02 22:47:48.299891	2026-06-02 22:47:48.299891	0
cb791c99-2880-4e8a-8173-9d331f417d65	94045696400001320	stress-40456964-1320@mediqueue.test	Paciente Stress 40456964-1320	55001320	ACTIVO	2026-06-02 22:47:49.163801	2026-06-02 22:47:49.163801	0
897b438b-3a0f-4ff9-8cbc-d89580866f7d	94045695300001885	stress-40456953-1885@mediqueue.test	Paciente Stress 40456953-1885	55001885	ACTIVO	2026-06-02 22:47:54.499578	2026-06-02 22:47:54.499578	0
f1bcf809-dfb3-4c35-a04a-8aad97ff8039	94045695000001997	stress-40456950-1997@mediqueue.test	Paciente Stress 40456950-1997	55001997	ACTIVO	2026-06-02 22:47:55.565243	2026-06-02 22:47:55.565243	0
1a63684d-c2f3-4213-b43a-1d4994a4c43a	94045696000003253	stress-40456960-3253@mediqueue.test	Paciente Stress 40456960-3253	55003253	ACTIVO	2026-06-02 22:48:06.209435	2026-06-02 22:48:06.209435	0
9c96e755-4fc7-4a49-a05e-4920ccc33c9e	94045695800003380	stress-40456958-3380@mediqueue.test	Paciente Stress 40456958-3380	55003380	ACTIVO	2026-06-02 22:48:07.282915	2026-06-02 22:48:07.282915	0
945e54e9-9633-4824-9b2f-7adeca0dd7ac	94045693600003428	stress-40456936-3428@mediqueue.test	Paciente Stress 40456936-3428	55003428	ACTIVO	2026-06-02 22:48:07.858716	2026-06-02 22:48:07.858716	0
da4ae9a2-d621-401c-8f47-3a4e68fbc770	94045695600003539	stress-40456956-3539@mediqueue.test	Paciente Stress 40456956-3539	55003539	ACTIVO	2026-06-02 22:48:08.982988	2026-06-02 22:48:08.982988	0
e824db13-70f1-4e51-8c10-6c75d8f4e502	94045692200003735	stress-40456922-3735@mediqueue.test	Paciente Stress 40456922-3735	55003735	ACTIVO	2026-06-02 22:48:10.581175	2026-06-02 22:48:10.581175	0
b828dfdc-7150-4ffd-b965-b4f717bcb405	94045693100003883	stress-40456931-3883@mediqueue.test	Paciente Stress 40456931-3883	55003883	ACTIVO	2026-06-02 22:48:12.009872	2026-06-02 22:48:12.009872	0
04f67cd6-8587-40a2-a8e1-537dbaad6039	94045696600003967	stress-40456966-3967@mediqueue.test	Paciente Stress 40456966-3967	55003967	ACTIVO	2026-06-02 22:48:12.558564	2026-06-02 22:48:12.558564	0
46dd1830-4f57-47b2-ab11-823bf8180c7f	94045692300004196	stress-40456923-4196@mediqueue.test	Paciente Stress 40456923-4196	55004196	ACTIVO	2026-06-02 22:48:14.355683	2026-06-02 22:48:14.355683	0
d8a64bc1-b850-4a58-836b-91fa3d357486	94045695800004565	stress-40456958-4565@mediqueue.test	Paciente Stress 40456958-4565	55004565	ACTIVO	2026-06-02 22:48:17.639667	2026-06-02 22:48:17.639667	0
189776c7-a471-4897-a3d6-66889d9fd6ad	94045696900004599	stress-40456969-4599@mediqueue.test	Paciente Stress 40456969-4599	55004599	ACTIVO	2026-06-02 22:48:17.959334	2026-06-02 22:48:17.959334	0
53e1a247-9800-419e-a65b-37641f342de4	94045692700005344	stress-40456927-5344@mediqueue.test	Paciente Stress 40456927-5344	55005344	ACTIVO	2026-06-02 22:48:24.541664	2026-06-02 22:48:24.541664	0
b4703b0d-0343-4a5f-9e0e-764272ba90eb	94045692900005474	stress-40456929-5474@mediqueue.test	Paciente Stress 40456929-5474	55005474	ACTIVO	2026-06-02 22:48:25.444073	2026-06-02 22:48:25.444073	0
139c0e44-f1e8-4a01-b8c2-4a1f1b5481b7	94045696400005651	stress-40456964-5651@mediqueue.test	Paciente Stress 40456964-5651	55005651	ACTIVO	2026-06-02 22:48:26.867588	2026-06-02 22:48:26.867588	0
bbcfbda1-43dd-4b6e-9361-b64d897b4ffc	94045694700006071	stress-40456947-6071@mediqueue.test	Paciente Stress 40456947-6071	55006071	ACTIVO	2026-06-02 22:48:36.861887	2026-06-02 22:48:36.861887	0
d749478e-5420-43a3-9996-d1c6b5145efe	94045691800006206	stress-40456918-6206@mediqueue.test	Paciente Stress 40456918-6206	55006206	ACTIVO	2026-06-02 22:48:38.20468	2026-06-02 22:48:38.20468	0
4a2e90fc-e0f6-4dff-9363-57fbfedb2db6	94045692100006380	stress-40456921-6380@mediqueue.test	Paciente Stress 40456921-6380	55006380	ACTIVO	2026-06-02 22:48:39.959296	2026-06-02 22:48:39.959296	0
0476c785-86ff-4ee5-98cf-2d1706c94f36	94045695700006843	stress-40456957-6843@mediqueue.test	Paciente Stress 40456957-6843	55006843	ACTIVO	2026-06-02 22:48:43.700712	2026-06-02 22:48:43.700712	0
f1ece6d6-44a3-41a7-a496-47cea2061ca7	94045695300006978	stress-40456953-6978@mediqueue.test	Paciente Stress 40456953-6978	55006978	ACTIVO	2026-06-02 22:48:44.732188	2026-06-02 22:48:44.732188	0
a5de056d-11ef-4495-afe4-721f68420653	94045695700007137	stress-40456957-7137@mediqueue.test	Paciente Stress 40456957-7137	55007137	ACTIVO	2026-06-02 22:48:45.968875	2026-06-02 22:48:45.968875	0
ef9e9e87-6055-44c3-90a2-0426a36622e3	94070648700003524	stress-40706487-3524@mediqueue.test	Paciente Stress 40706487-3524	55003524	ACTIVO	2026-06-02 22:53:26.868973	2026-06-02 22:53:26.868973	0
22e7a09a-355f-45c8-afc8-173865209434	94070648600003804	stress-40706486-3804@mediqueue.test	Paciente Stress 40706486-3804	55003804	ACTIVO	2026-06-02 22:53:29.452583	2026-06-02 22:53:29.452583	0
2c02d41c-24d0-4450-be98-036eb7b439fb	94173202300000620	stress-41732023-620@mediqueue.test	Paciente Stress 41732023-620	55000620	ACTIVO	2026-06-02 23:08:59.352445	2026-06-02 23:08:59.352445	0
d9d4058a-b0fd-4541-870b-894c27538dda	94173206800000171	stress-41732068-171@mediqueue.test	Paciente Stress 41732068-171	55000171	ACTIVO	2026-06-02 23:08:59.493695	2026-06-02 23:08:59.493695	0
a8d28f62-42e2-4750-8a17-e4cc6bb9b59c	94173200800000541	stress-41732008-541@mediqueue.test	Paciente Stress 41732008-541	55000541	ACTIVO	2026-06-02 23:08:59.64454	2026-06-02 23:08:59.64454	0
2dc32377-b3b3-4480-8781-e2bb81c8e92b	94173199700000823	stress-41731997-823@mediqueue.test	Paciente Stress 41731997-823	55000823	ACTIVO	2026-06-02 23:09:00.124532	2026-06-02 23:09:00.124532	0
17fc9cdb-4399-4efc-9269-fc1eae72a644	94173204500000841	stress-41732045-841@mediqueue.test	Paciente Stress 41732045-841	55000841	ACTIVO	2026-06-02 23:09:00.262375	2026-06-02 23:09:00.262375	0
6837c685-f63c-4c4e-9ad2-04d150627aa4	94173203900001022	stress-41732039-1022@mediqueue.test	Paciente Stress 41732039-1022	55001022	ACTIVO	2026-06-02 23:09:01.521126	2026-06-02 23:09:01.521126	0
4a45178a-2358-43b5-8d59-f14eecb74d38	94173198500001175	stress-41731985-1175@mediqueue.test	Paciente Stress 41731985-1175	55001175	ACTIVO	2026-06-02 23:09:03.394424	2026-06-02 23:09:03.394424	0
be51b3f5-1ef1-4032-81a1-c2dc3a0219df	94173206300001952	stress-41732063-1952@mediqueue.test	Paciente Stress 41732063-1952	55001952	ACTIVO	2026-06-02 23:09:10.951347	2026-06-02 23:09:10.951347	0
e9df4685-464d-4d71-93d0-3934d63ef73b	94173200800002003	stress-41732008-2003@mediqueue.test	Paciente Stress 41732008-2003	55002003	ACTIVO	2026-06-02 23:09:11.443392	2026-06-02 23:09:11.443392	0
c7401e5b-2ee8-435f-892b-3f12f405dc7a	94173199200002085	stress-41731992-2085@mediqueue.test	Paciente Stress 41731992-2085	55002085	ACTIVO	2026-06-02 23:09:12.049434	2026-06-02 23:09:12.049434	0
fb38de7c-dea4-48d8-b870-bf1dc6cbb7e2	94173201400002158	stress-41732014-2158@mediqueue.test	Paciente Stress 41732014-2158	55002158	ACTIVO	2026-06-02 23:09:12.666471	2026-06-02 23:09:12.666471	0
72bbc6fe-7a93-4b5b-b73a-1740637d2d42	93979299700009317	stress-39792997-9317@mediqueue.test	Paciente Stress 39792997-9317	55009317	ACTIVO	2026-06-02 22:41:49.5421	2026-06-02 22:41:49.5421	0
d62d9adf-f7d5-4a30-ab9b-08a131bb8b7d	93979296300009463	stress-39792963-9463@mediqueue.test	Paciente Stress 39792963-9463	55009463	ACTIVO	2026-06-02 22:41:50.878952	2026-06-02 22:41:50.878952	0
a0791226-8770-442a-a95d-56e5f8e7501f	93979302800009619	stress-39793028-9619@mediqueue.test	Paciente Stress 39793028-9619	55009619	ACTIVO	2026-06-02 22:41:52.172234	2026-06-02 22:41:52.172234	0
dde67bc4-56e6-4b75-9544-72c69e9f21c4	93979296800009790	stress-39792968-9790@mediqueue.test	Paciente Stress 39792968-9790	55009790	ACTIVO	2026-06-02 22:41:53.531237	2026-06-02 22:41:53.531237	0
6b719e7e-aff3-4bf7-bcd8-b32fce2c08bd	93979297900009810	stress-39792979-9810@mediqueue.test	Paciente Stress 39792979-9810	55009810	ACTIVO	2026-06-02 22:41:53.810745	2026-06-02 22:41:53.810745	0
9dd655d6-f4ba-403e-b3e1-21330669dd09	93979302900009909	stress-39793029-9909@mediqueue.test	Paciente Stress 39793029-9909	55009909	ACTIVO	2026-06-02 22:41:54.536235	2026-06-02 22:41:54.536235	0
c67efe02-4b7e-47e1-b10f-0d3e79b3017a	94045696900000321	stress-40456969-321@mediqueue.test	Paciente Stress 40456969-321	55000321	ACTIVO	2026-06-02 22:47:41.179167	2026-06-02 22:47:41.179167	0
b3f6bea7-5986-431d-b533-06c17aff9599	94045695800000802	stress-40456958-802@mediqueue.test	Paciente Stress 40456958-802	55000802	ACTIVO	2026-06-02 22:47:43.972024	2026-06-02 22:47:43.972024	0
80e0bcee-1654-4bbd-a4a1-f9c21ea5d9b3	94045693000001095	stress-40456930-1095@mediqueue.test	Paciente Stress 40456930-1095	55001095	ACTIVO	2026-06-02 22:47:46.704569	2026-06-02 22:47:46.704569	0
a2b7eedf-ea3f-45ad-94aa-f1cc7cf990a6	94045693000001155	stress-40456930-1155@mediqueue.test	Paciente Stress 40456930-1155	55001155	ACTIVO	2026-06-02 22:47:47.194234	2026-06-02 22:47:47.194234	0
55368dbe-e2f4-40e4-b161-38a1d2574ff4	94045696700001330	stress-40456967-1330@mediqueue.test	Paciente Stress 40456967-1330	55001330	ACTIVO	2026-06-02 22:47:49.266259	2026-06-02 22:47:49.266259	0
03370cc7-ac3a-425c-a0c3-3d10fe1f93ee	94045693600001561	stress-40456936-1561@mediqueue.test	Paciente Stress 40456936-1561	55001561	ACTIVO	2026-06-02 22:47:51.057258	2026-06-02 22:47:51.057258	0
7e0cf351-4ce4-4d30-bdd8-ceccd9b79b46	94045695300001752	stress-40456953-1752@mediqueue.test	Paciente Stress 40456953-1752	55001752	ACTIVO	2026-06-02 22:47:53.428936	2026-06-02 22:47:53.428936	0
e321ae3c-8760-4b81-9143-0c0c659092f8	94045691500001890	stress-40456915-1890@mediqueue.test	Paciente Stress 40456915-1890	55001890	ACTIVO	2026-06-02 22:47:54.483492	2026-06-02 22:47:54.483492	0
f8ffcd8b-1d7a-4494-9189-35faacf05c3a	94045696900001982	stress-40456969-1982@mediqueue.test	Paciente Stress 40456969-1982	55001982	ACTIVO	2026-06-02 22:47:55.430624	2026-06-02 22:47:55.430624	0
f6ae7cf8-d788-4e71-8f39-729acfc25639	94045695700002111	stress-40456957-2111@mediqueue.test	Paciente Stress 40456957-2111	55002111	ACTIVO	2026-06-02 22:47:56.46636	2026-06-02 22:47:56.46636	0
47320e7f-75ee-4ff0-ab56-abcf6844783d	94045696300002167	stress-40456963-2167@mediqueue.test	Paciente Stress 40456963-2167	55002167	ACTIVO	2026-06-02 22:47:56.902107	2026-06-02 22:47:56.902107	0
c860dfcb-d22d-4242-81c9-28ba72017d83	94045693900002312	stress-40456939-2312@mediqueue.test	Paciente Stress 40456939-2312	55002312	ACTIVO	2026-06-02 22:47:58.446361	2026-06-02 22:47:58.446361	0
970ce540-d5db-4526-a2db-fada9cdd631f	94045692300002503	stress-40456923-2503@mediqueue.test	Paciente Stress 40456923-2503	55002503	ACTIVO	2026-06-02 22:48:00.20958	2026-06-02 22:48:00.20958	0
c5d7e24c-d4f0-4078-aaa6-fac043b28c68	94045694300002565	stress-40456943-2565@mediqueue.test	Paciente Stress 40456943-2565	55002565	ACTIVO	2026-06-02 22:48:00.600844	2026-06-02 22:48:00.600844	0
cc7fa83b-1a7e-407d-b393-2cab6360121b	94045695200002682	stress-40456952-2682@mediqueue.test	Paciente Stress 40456952-2682	55002682	ACTIVO	2026-06-02 22:48:01.619946	2026-06-02 22:48:01.619946	0
3d52c528-1800-42f1-9ec5-298cc8ae306e	94045694300002842	stress-40456943-2842@mediqueue.test	Paciente Stress 40456943-2842	55002842	ACTIVO	2026-06-02 22:48:03.193293	2026-06-02 22:48:03.193293	0
4680fb9c-9f5f-4dc1-a566-ec27ad1ab032	94045692900003013	stress-40456929-3013@mediqueue.test	Paciente Stress 40456929-3013	55003013	ACTIVO	2026-06-02 22:48:04.263284	2026-06-02 22:48:04.263284	0
b5cc2aed-e653-4ec5-a0a5-7b9423bf96a8	94045692900003050	stress-40456929-3050@mediqueue.test	Paciente Stress 40456929-3050	55003050	ACTIVO	2026-06-02 22:48:04.639775	2026-06-02 22:48:04.639775	0
1a9ebc09-b99c-4fe3-a49a-b6853e723e51	94045696500003371	stress-40456965-3371@mediqueue.test	Paciente Stress 40456965-3371	55003371	ACTIVO	2026-06-02 22:48:07.183819	2026-06-02 22:48:07.183819	0
8798f15a-7030-4bd0-944e-ed86ba36d7a2	94045693100003585	stress-40456931-3585@mediqueue.test	Paciente Stress 40456931-3585	55003585	ACTIVO	2026-06-02 22:48:09.271341	2026-06-02 22:48:09.271341	0
15c61fda-a088-4a41-9997-de0395f0c1d6	94045693100003657	stress-40456931-3657@mediqueue.test	Paciente Stress 40456931-3657	55003657	ACTIVO	2026-06-02 22:48:09.904705	2026-06-02 22:48:09.904705	0
59f786a4-c3be-4db6-a1fd-8063705ca5bc	94045695900003746	stress-40456959-3746@mediqueue.test	Paciente Stress 40456959-3746	55003746	ACTIVO	2026-06-02 22:48:10.831308	2026-06-02 22:48:10.831308	0
7d99c84b-851c-42cc-a2c7-5b946da9ffa4	94045692200003825	stress-40456922-3825@mediqueue.test	Paciente Stress 40456922-3825	55003825	ACTIVO	2026-06-02 22:48:11.478826	2026-06-02 22:48:11.478826	0
58de6f24-e7d9-4595-a37f-4962b3cbdc75	94045692300003902	stress-40456923-3902@mediqueue.test	Paciente Stress 40456923-3902	55003902	ACTIVO	2026-06-02 22:48:12.184172	2026-06-02 22:48:12.184172	0
fbce8993-5565-4b41-beae-1bba627af61f	94045691700003946	stress-40456917-3946@mediqueue.test	Paciente Stress 40456917-3946	55003946	ACTIVO	2026-06-02 22:48:12.392466	2026-06-02 22:48:12.392466	0
d5074875-ec9c-4b3e-bef5-d77f9b82882d	94045691300004038	stress-40456913-4038@mediqueue.test	Paciente Stress 40456913-4038	55004038	ACTIVO	2026-06-02 22:48:13.069587	2026-06-02 22:48:13.069587	0
f3e64a28-e174-4d1c-9a13-1c7040dadbcd	94045695500004131	stress-40456955-4131@mediqueue.test	Paciente Stress 40456955-4131	55004131	ACTIVO	2026-06-02 22:48:13.695821	2026-06-02 22:48:13.695821	0
6b8fd93d-923a-49c4-bfbb-81b5783b2ec4	94045692300004857	stress-40456923-4857@mediqueue.test	Paciente Stress 40456923-4857	55004857	ACTIVO	2026-06-02 22:48:20.013383	2026-06-02 22:48:20.013383	0
ff8a95ca-5b56-43c8-9e2a-d3a872d4dc33	94045692800004953	stress-40456928-4953@mediqueue.test	Paciente Stress 40456928-4953	55004953	ACTIVO	2026-06-02 22:48:20.729898	2026-06-02 22:48:20.729898	0
e9fb88fb-0962-4e0c-9bd6-a6ca3f0c3906	94045695300004980	stress-40456953-4980@mediqueue.test	Paciente Stress 40456953-4980	55004980	ACTIVO	2026-06-02 22:48:21.035395	2026-06-02 22:48:21.035395	0
cbe4de6e-8fcf-4315-8b1f-a18c8aee9874	94045691300005083	stress-40456913-5083@mediqueue.test	Paciente Stress 40456913-5083	55005083	ACTIVO	2026-06-02 22:48:22.209613	2026-06-02 22:48:22.209613	0
0638f4c7-8da0-48f4-b6f4-7fd628c9b57d	94045695900005485	stress-40456959-5485@mediqueue.test	Paciente Stress 40456959-5485	55005485	ACTIVO	2026-06-02 22:48:25.536505	2026-06-02 22:48:25.536505	0
8ae3b1bb-1f1b-41b8-add7-055506addc4c	94045694200005741	stress-40456942-5741@mediqueue.test	Paciente Stress 40456942-5741	55005741	ACTIVO	2026-06-02 22:48:27.636015	2026-06-02 22:48:27.636015	0
4cc60266-e79b-4af3-86a4-673405eaeeae	94045692900005943	stress-40456929-5943@mediqueue.test	Paciente Stress 40456929-5943	55005943	ACTIVO	2026-06-02 22:48:35.733293	2026-06-02 22:48:35.733293	0
e0fdb931-5b1e-4f14-bcc1-680bf004b2e8	94045695800006065	stress-40456958-6065@mediqueue.test	Paciente Stress 40456958-6065	55006065	ACTIVO	2026-06-02 22:48:36.844318	2026-06-02 22:48:36.844318	0
57084277-86af-4e19-bb74-fcfc51956738	94045695000006153	stress-40456950-6153@mediqueue.test	Paciente Stress 40456950-6153	55006153	ACTIVO	2026-06-02 22:48:37.692366	2026-06-02 22:48:37.692366	0
805f510a-f4a8-4815-b333-8e14321fee84	94045694900006272	stress-40456949-6272@mediqueue.test	Paciente Stress 40456949-6272	55006272	ACTIVO	2026-06-02 22:48:38.806991	2026-06-02 22:48:38.806991	0
ed8aaa60-8832-42ed-9378-db3c62ae0309	94045692900006413	stress-40456929-6413@mediqueue.test	Paciente Stress 40456929-6413	55006413	ACTIVO	2026-06-02 22:48:40.234863	2026-06-02 22:48:40.234863	0
b7b78f98-86e2-4564-bbed-f62ae98edbd7	94045692200006678	stress-40456922-6678@mediqueue.test	Paciente Stress 40456922-6678	55006678	ACTIVO	2026-06-02 22:48:42.335995	2026-06-02 22:48:42.335995	0
5ab5bfff-98b5-42df-81c8-670af724e209	94045696400006794	stress-40456964-6794@mediqueue.test	Paciente Stress 40456964-6794	55006794	ACTIVO	2026-06-02 22:48:43.256883	2026-06-02 22:48:43.256883	0
66221158-3d61-4068-9211-895caf903906	94070646900003759	stress-40706469-3759@mediqueue.test	Paciente Stress 40706469-3759	55003759	ACTIVO	2026-06-02 22:53:28.958139	2026-06-02 22:53:28.958139	0
6761779e-267b-4c9b-9399-1fa00acd6250	93979302400009418	stress-39793024-9418@mediqueue.test	Paciente Stress 39793024-9418	55009418	ACTIVO	2026-06-02 22:41:50.505533	2026-06-02 22:41:50.505533	0
35c78f6d-a676-49f7-8492-871adb15f743	93979298500009892	stress-39792985-9892@mediqueue.test	Paciente Stress 39792985-9892	55009892	ACTIVO	2026-06-02 22:41:54.432125	2026-06-02 22:41:54.432125	0
8102e55b-eeec-4d6e-a62a-1f696d462c7f	94045695300001003	stress-40456953-1003@mediqueue.test	Paciente Stress 40456953-1003	55001003	ACTIVO	2026-06-02 22:47:46.052784	2026-06-02 22:47:46.052784	0
4f61a766-b488-4e0a-a43d-6c0a38c5f15d	94045693000001117	stress-40456930-1117@mediqueue.test	Paciente Stress 40456930-1117	55001117	ACTIVO	2026-06-02 22:47:46.910145	2026-06-02 22:47:46.910145	0
4f9d6aaf-75ab-4858-8817-d07ab59773b8	94045694000001249	stress-40456940-1249@mediqueue.test	Paciente Stress 40456940-1249	55001249	ACTIVO	2026-06-02 22:47:48.201638	2026-06-02 22:47:48.201638	0
46b67377-738b-4e52-8770-0b9d8f82a6ac	94045693800001731	stress-40456938-1731@mediqueue.test	Paciente Stress 40456938-1731	55001731	ACTIVO	2026-06-02 22:47:52.880434	2026-06-02 22:47:52.880434	0
42a5af5f-c027-4770-ae97-2e32bf772d7f	94045696900001958	stress-40456969-1958@mediqueue.test	Paciente Stress 40456969-1958	55001958	ACTIVO	2026-06-02 22:47:55.229027	2026-06-02 22:47:55.229027	0
1c923175-42de-49e7-8c17-cf8e7d830d4b	94045691200002472	stress-40456912-2472@mediqueue.test	Paciente Stress 40456912-2472	55002472	ACTIVO	2026-06-02 22:47:59.971615	2026-06-02 22:47:59.971615	0
d26399e7-781e-4f18-a46b-c665dd0da675	94045695000002689	stress-40456950-2689@mediqueue.test	Paciente Stress 40456950-2689	55002689	ACTIVO	2026-06-02 22:48:01.847666	2026-06-02 22:48:01.847666	0
d50e95d3-439b-41b5-8dd8-1dd54388fd47	94045691500002975	stress-40456915-2975@mediqueue.test	Paciente Stress 40456915-2975	55002975	ACTIVO	2026-06-02 22:48:04.017575	2026-06-02 22:48:04.017575	0
5bf8f9dd-4a68-4fda-84ba-9bd18e0a753e	94045694300003101	stress-40456943-3101@mediqueue.test	Paciente Stress 40456943-3101	55003101	ACTIVO	2026-06-02 22:48:05.045408	2026-06-02 22:48:05.045408	0
392090ca-ad83-463f-8d3d-48aa444f5e1b	94045695200003195	stress-40456952-3195@mediqueue.test	Paciente Stress 40456952-3195	55003195	ACTIVO	2026-06-02 22:48:05.686392	2026-06-02 22:48:05.686392	0
2ab2e437-13da-4fd6-8ae0-2ff2b06202fe	94045695300003332	stress-40456953-3332@mediqueue.test	Paciente Stress 40456953-3332	55003332	ACTIVO	2026-06-02 22:48:06.933044	2026-06-02 22:48:06.933044	0
225479ea-7e9e-4032-be8d-a70b8c089418	94045692200003927	stress-40456922-3927@mediqueue.test	Paciente Stress 40456922-3927	55003927	ACTIVO	2026-06-02 22:48:12.250401	2026-06-02 22:48:12.250401	0
15908d0c-7a74-4d73-8c83-70b9e071d155	94045696200004040	stress-40456962-4040@mediqueue.test	Paciente Stress 40456962-4040	55004040	ACTIVO	2026-06-02 22:48:13.120605	2026-06-02 22:48:13.120605	0
4dd0c2ca-6dbd-40c6-959e-28308d92ba77	94045692300004149	stress-40456923-4149@mediqueue.test	Paciente Stress 40456923-4149	55004149	ACTIVO	2026-06-02 22:48:13.882411	2026-06-02 22:48:13.882411	0
106c090e-0e1c-44a0-a675-95051f8d15cc	94045695000004345	stress-40456950-4345@mediqueue.test	Paciente Stress 40456950-4345	55004345	ACTIVO	2026-06-02 22:48:15.514569	2026-06-02 22:48:15.514569	0
12fd1237-af3e-432f-9654-741555df9da1	94045696200004413	stress-40456962-4413@mediqueue.test	Paciente Stress 40456962-4413	55004413	ACTIVO	2026-06-02 22:48:16.16495	2026-06-02 22:48:16.16495	0
0e76933c-6bcc-4e72-a44d-bc7a1fd02e22	94045692100004531	stress-40456921-4531@mediqueue.test	Paciente Stress 40456921-4531	55004531	ACTIVO	2026-06-02 22:48:17.387803	2026-06-02 22:48:17.387803	0
bcf58e7d-f144-4c65-82ca-ecc219e00ce4	94045692200005043	stress-40456922-5043@mediqueue.test	Paciente Stress 40456922-5043	55005043	ACTIVO	2026-06-02 22:48:21.728873	2026-06-02 22:48:21.728873	0
58ecc535-bde0-4563-ae03-22dbbc4ce855	94045695600005101	stress-40456956-5101@mediqueue.test	Paciente Stress 40456956-5101	55005101	ACTIVO	2026-06-02 22:48:22.340115	2026-06-02 22:48:22.340115	0
02b5742e-7ff0-4911-af3d-013cc2a4699e	94045694700005388	stress-40456947-5388@mediqueue.test	Paciente Stress 40456947-5388	55005388	ACTIVO	2026-06-02 22:48:24.984475	2026-06-02 22:48:24.984475	0
db5e0861-09d6-4b6e-ab60-0072b87c862c	94045695300005916	stress-40456953-5916@mediqueue.test	Paciente Stress 40456953-5916	55005916	ACTIVO	2026-06-02 22:48:28.7085	2026-06-02 22:48:28.7085	0
aaef33ed-8971-4b59-9074-07a7eeddb779	94045695500006061	stress-40456955-6061@mediqueue.test	Paciente Stress 40456955-6061	55006061	ACTIVO	2026-06-02 22:48:36.833201	2026-06-02 22:48:36.833201	0
c7a14379-9536-4a18-85d8-269dc4280b51	94045693600006112	stress-40456936-6112@mediqueue.test	Paciente Stress 40456936-6112	55006112	ACTIVO	2026-06-02 22:48:37.337735	2026-06-02 22:48:37.337735	0
1127b0d2-469e-41fe-be40-3a9e480f27a5	94045695700006173	stress-40456957-6173@mediqueue.test	Paciente Stress 40456957-6173	55006173	ACTIVO	2026-06-02 22:48:38.022543	2026-06-02 22:48:38.022543	0
22fb4227-2dc1-4079-8c38-de2d3e2d628f	94045694300006779	stress-40456943-6779@mediqueue.test	Paciente Stress 40456943-6779	55006779	ACTIVO	2026-06-02 22:48:43.149007	2026-06-02 22:48:43.149007	0
32409993-6fda-4810-bbb1-95b51641858d	94045695900006848	stress-40456959-6848@mediqueue.test	Paciente Stress 40456959-6848	55006848	ACTIVO	2026-06-02 22:48:43.72452	2026-06-02 22:48:43.72452	0
49897139-3fd0-4103-b85a-f5ac438db261	94045692900006878	stress-40456929-6878@mediqueue.test	Paciente Stress 40456929-6878	55006878	ACTIVO	2026-06-02 22:48:43.972351	2026-06-02 22:48:43.972351	0
49eeec34-49c6-4758-94fe-5405043c4462	94045693000006990	stress-40456930-6990@mediqueue.test	Paciente Stress 40456930-6990	55006990	ACTIVO	2026-06-02 22:48:44.79211	2026-06-02 22:48:44.79211	0
d12ea30c-015d-45d0-b367-f074eb615e10	94045693900007091	stress-40456939-7091@mediqueue.test	Paciente Stress 40456939-7091	55007091	ACTIVO	2026-06-02 22:48:45.585736	2026-06-02 22:48:45.585736	0
a60a7cce-38ea-4ca2-957a-1516ec2ef847	94070648700003835	stress-40706487-3835@mediqueue.test	Paciente Stress 40706487-3835	55003835	ACTIVO	2026-06-02 22:53:29.676654	2026-06-02 22:53:29.676654	0
b4888a35-b7e7-4756-91fd-ac7b51c954a1	94070643000003922	stress-40706430-3922@mediqueue.test	Paciente Stress 40706430-3922	55003922	ACTIVO	2026-06-02 22:53:30.473628	2026-06-02 22:53:30.473628	0
bee60846-8c5d-4e0d-b334-7114410307be	94070643100004011	stress-40706431-4011@mediqueue.test	Paciente Stress 40706431-4011	55004011	ACTIVO	2026-06-02 22:53:31.010875	2026-06-02 22:53:31.010875	0
02461c80-e0b5-49d3-b30c-49d3857e9b5c	94173201600000634	stress-41732016-634@mediqueue.test	Paciente Stress 41732016-634	55000634	ACTIVO	2026-06-02 23:08:59.472809	2026-06-02 23:08:59.472809	0
b9835c4a-a911-43e4-b4d7-3f693596c9ba	94173202600001427	stress-41732026-1427@mediqueue.test	Paciente Stress 41732026-1427	55001427	ACTIVO	2026-06-02 23:09:06.232999	2026-06-02 23:09:06.232999	0
f8c280e9-90d1-4fac-9fbf-2d4202fcb867	94173203500001598	stress-41732035-1598@mediqueue.test	Paciente Stress 41732035-1598	55001598	ACTIVO	2026-06-02 23:09:07.927938	2026-06-02 23:09:07.927938	0
be2231ba-d02c-411f-848b-ddf49d771625	94173203800001692	stress-41732038-1692@mediqueue.test	Paciente Stress 41732038-1692	55001692	ACTIVO	2026-06-02 23:09:08.841224	2026-06-02 23:09:08.841224	0
de1b868f-523e-44d7-bac2-771b0bfc6e3f	94173206500001923	stress-41732065-1923@mediqueue.test	Paciente Stress 41732065-1923	55001923	ACTIVO	2026-06-02 23:09:10.735996	2026-06-02 23:09:10.735996	0
dd2c11db-d99f-443e-8d93-4dfac80562a9	94173204000001975	stress-41732040-1975@mediqueue.test	Paciente Stress 41732040-1975	55001975	ACTIVO	2026-06-02 23:09:11.082701	2026-06-02 23:09:11.082701	0
3daa8dc2-c689-4e50-b986-ee057a8f74bd	94173197700002243	stress-41731977-2243@mediqueue.test	Paciente Stress 41731977-2243	55002243	ACTIVO	2026-06-02 23:09:13.519027	2026-06-02 23:09:13.519027	0
a7b0a4a0-e0b2-4edc-bf82-b94f3ca2cecb	94173201400002262	stress-41732014-2262@mediqueue.test	Paciente Stress 41732014-2262	55002262	ACTIVO	2026-06-02 23:09:13.643968	2026-06-02 23:09:13.643968	0
17a81c68-c1eb-4ccd-9f0a-ad09ac0324c6	94173205700002285	stress-41732057-2285@mediqueue.test	Paciente Stress 41732057-2285	55002285	ACTIVO	2026-06-02 23:09:13.894338	2026-06-02 23:09:13.894338	0
7f86f72c-1c0f-42a7-bbe4-930c4c52aaa7	94173201800002300	stress-41732018-2300@mediqueue.test	Paciente Stress 41732018-2300	55002300	ACTIVO	2026-06-02 23:09:13.973167	2026-06-02 23:09:13.973167	0
cc65f663-dc70-47ae-a9a1-917a9e52af95	94173205000002295	stress-41732050-2295@mediqueue.test	Paciente Stress 41732050-2295	55002295	ACTIVO	2026-06-02 23:09:13.996762	2026-06-02 23:09:13.996762	0
6f2df391-6863-4e67-9d45-f70bbd503238	94173204000002304	stress-41732040-2304@mediqueue.test	Paciente Stress 41732040-2304	55002304	ACTIVO	2026-06-02 23:09:14.206637	2026-06-02 23:09:14.206637	0
49898dd1-63fa-4954-94fe-cf9c87d3a873	94173199700002325	stress-41731997-2325@mediqueue.test	Paciente Stress 41731997-2325	55002325	ACTIVO	2026-06-02 23:09:14.327039	2026-06-02 23:09:14.327039	0
ebb88bba-a725-439a-87ae-9599ab619e50	94045692700004757	stress-40456927-4757@mediqueue.test	Paciente Stress 40456927-4757	55004757	ACTIVO	2026-06-02 22:48:19.201002	2026-06-02 22:48:19.201002	0
74bbd06e-9513-4c8b-aab9-0333b87b4fac	94045692900004861	stress-40456929-4861@mediqueue.test	Paciente Stress 40456929-4861	55004861	ACTIVO	2026-06-02 22:48:20.018046	2026-06-02 22:48:20.018046	0
b26e06a3-df22-49c8-b5f7-8134cd1d77f2	94045691300004910	stress-40456913-4910@mediqueue.test	Paciente Stress 40456913-4910	55004910	ACTIVO	2026-06-02 22:48:20.410282	2026-06-02 22:48:20.410282	0
4051d01e-0291-490d-b662-380d169efba1	94045692900004943	stress-40456929-4943@mediqueue.test	Paciente Stress 40456929-4943	55004943	ACTIVO	2026-06-02 22:48:20.666914	2026-06-02 22:48:20.666914	0
4e4b9701-3759-4313-bc9e-1e4d1611a4b8	94045695800005145	stress-40456958-5145@mediqueue.test	Paciente Stress 40456958-5145	55005145	ACTIVO	2026-06-02 22:48:22.771542	2026-06-02 22:48:22.771542	0
81a1520b-4232-49c0-94bd-c4740426298e	94045696800005213	stress-40456968-5213@mediqueue.test	Paciente Stress 40456968-5213	55005213	ACTIVO	2026-06-02 22:48:23.467369	2026-06-02 22:48:23.467369	0
f9848054-1e0c-46e8-bb47-f0f197f3d83f	94045695300005364	stress-40456953-5364@mediqueue.test	Paciente Stress 40456953-5364	55005364	ACTIVO	2026-06-02 22:48:24.68483	2026-06-02 22:48:24.68483	0
9a534163-341d-4d4d-a797-8d1268e47f4b	94045691700005403	stress-40456917-5403@mediqueue.test	Paciente Stress 40456917-5403	55005403	ACTIVO	2026-06-02 22:48:25.102014	2026-06-02 22:48:25.102014	0
72c5eb25-0999-4896-b845-d5cbc1c9e431	94045696600005552	stress-40456966-5552@mediqueue.test	Paciente Stress 40456966-5552	55005552	ACTIVO	2026-06-02 22:48:26.009958	2026-06-02 22:48:26.009958	0
8acb594d-9553-4a47-acdb-d9b0ebed4ca0	94045696600005904	stress-40456966-5904@mediqueue.test	Paciente Stress 40456966-5904	55005904	ACTIVO	2026-06-02 22:48:28.616912	2026-06-02 22:48:28.616912	0
ca78f9fd-1b82-4ec8-a6ec-c561530de9b4	94045695600005927	stress-40456956-5927@mediqueue.test	Paciente Stress 40456956-5927	55005927	ACTIVO	2026-06-02 22:48:35.560222	2026-06-02 22:48:35.560222	0
b7587a8a-57a1-4a8e-8c35-8a09854114a1	94045693500006171	stress-40456935-6171@mediqueue.test	Paciente Stress 40456935-6171	55006171	ACTIVO	2026-06-02 22:48:37.945048	2026-06-02 22:48:37.945048	0
f8d7236d-2c2c-4dde-aea2-7521e6602987	94045694000006570	stress-40456940-6570@mediqueue.test	Paciente Stress 40456940-6570	55006570	ACTIVO	2026-06-02 22:48:41.591739	2026-06-02 22:48:41.591739	0
0de3db83-cac0-4a71-aca1-3a6f445b6137	94045694300006606	stress-40456943-6606@mediqueue.test	Paciente Stress 40456943-6606	55006606	ACTIVO	2026-06-02 22:48:41.882286	2026-06-02 22:48:41.882286	0
d39ad457-7a8d-47a9-8f21-14f0b9ee2b9f	94045693900006638	stress-40456939-6638@mediqueue.test	Paciente Stress 40456939-6638	55006638	ACTIVO	2026-06-02 22:48:42.083693	2026-06-02 22:48:42.083693	0
d61ffee3-10ef-4a44-8b5d-9a2c24ebdbf2	94045693200006694	stress-40456932-6694@mediqueue.test	Paciente Stress 40456932-6694	55006694	ACTIVO	2026-06-02 22:48:42.447146	2026-06-02 22:48:42.447146	0
38267c1c-3df9-48fd-858d-bb43feee7c1e	94045696600006797	stress-40456966-6797@mediqueue.test	Paciente Stress 40456966-6797	55006797	ACTIVO	2026-06-02 22:48:43.271578	2026-06-02 22:48:43.271578	0
7bf9e9f9-c707-4338-985f-cf6a81d77312	94045695600006818	stress-40456956-6818@mediqueue.test	Paciente Stress 40456956-6818	55006818	ACTIVO	2026-06-02 22:48:43.47011	2026-06-02 22:48:43.47011	0
d5757a8b-66f2-4fc8-bdcd-06cf701143a4	94045691300007045	stress-40456913-7045@mediqueue.test	Paciente Stress 40456913-7045	55007045	ACTIVO	2026-06-02 22:48:45.282384	2026-06-02 22:48:45.282384	0
4a7b89d8-8cd2-44c8-aaf7-b30941c8a5bf	94173200600000014	stress-41732006-14@mediqueue.test	Paciente Stress 41732006-14	55000014	ACTIVO	2026-06-02 23:08:52.386021	2026-06-02 23:08:52.386021	0
ed8f7eac-77c0-4fd0-a068-2b8ae8c42c70	94173197700000490	stress-41731977-490@mediqueue.test	Paciente Stress 41731977-490	55000490	ACTIVO	2026-06-02 23:08:59.454351	2026-06-02 23:08:59.454351	0
8e73310f-8a86-4df4-aafd-aebdc94dd326	94173199600000644	stress-41731996-644@mediqueue.test	Paciente Stress 41731996-644	55000644	ACTIVO	2026-06-02 23:08:59.50799	2026-06-02 23:08:59.50799	0
e765d267-ae7e-4953-b04a-a800ec3b04f3	94173204900000584	stress-41732049-584@mediqueue.test	Paciente Stress 41732049-584	55000584	ACTIVO	2026-06-02 23:08:59.704836	2026-06-02 23:08:59.704836	0
43f5f0af-e665-49a7-b486-f1c7a8c4832b	94173204500000696	stress-41732045-696@mediqueue.test	Paciente Stress 41732045-696	55000696	ACTIVO	2026-06-02 23:09:00.01234	2026-06-02 23:09:00.01234	0
75b47fd6-e0c0-4155-b4d1-4cddb5ab6b3d	94173203900000459	stress-41732039-459@mediqueue.test	Paciente Stress 41732039-459	55000459	ACTIVO	2026-06-02 23:09:00.281879	2026-06-02 23:09:00.281879	0
17ac0512-0e4b-49a4-b675-bcfbb794ef7f	94173204700000737	stress-41732047-737@mediqueue.test	Paciente Stress 41732047-737	55000737	ACTIVO	2026-06-02 23:09:00.563974	2026-06-02 23:09:00.563974	0
1ed58d40-758a-4e1a-88bd-7a37a0eee15e	94173197700000861	stress-41731977-861@mediqueue.test	Paciente Stress 41731977-861	55000861	ACTIVO	2026-06-02 23:09:00.751366	2026-06-02 23:09:00.751366	0
f965ee5c-50d4-4dff-a60a-2982132afaa4	94173202300000879	stress-41732023-879@mediqueue.test	Paciente Stress 41732023-879	55000879	ACTIVO	2026-06-02 23:09:00.903097	2026-06-02 23:09:00.903097	0
f5af7db8-8430-4318-a5e9-7aed694bc0a3	94173205600001003	stress-41732056-1003@mediqueue.test	Paciente Stress 41732056-1003	55001003	ACTIVO	2026-06-02 23:09:01.314819	2026-06-02 23:09:01.314819	0
982a1ff0-11ad-4d0e-8612-333908faf1d7	94173199100001081	stress-41731991-1081@mediqueue.test	Paciente Stress 41731991-1081	55001081	ACTIVO	2026-06-02 23:09:02.638291	2026-06-02 23:09:02.638291	0
014f5307-2e76-49aa-8618-109ca35577db	94173201300001163	stress-41732013-1163@mediqueue.test	Paciente Stress 41732013-1163	55001163	ACTIVO	2026-06-02 23:09:03.264218	2026-06-02 23:09:03.264218	0
4332c3e0-443e-4099-9a5d-9bd114e4a73f	94173203800001215	stress-41732038-1215@mediqueue.test	Paciente Stress 41732038-1215	55001215	ACTIVO	2026-06-02 23:09:03.773146	2026-06-02 23:09:03.773146	0
24d1fc89-13fb-4fb3-ba37-f6b56f90a2ee	94173203100001228	stress-41732031-1228@mediqueue.test	Paciente Stress 41732031-1228	55001228	ACTIVO	2026-06-02 23:09:03.949061	2026-06-02 23:09:03.949061	0
da7d0a0b-b5f8-4c76-a9bf-e92c7f818025	94173204100001374	stress-41732041-1374@mediqueue.test	Paciente Stress 41732041-1374	55001374	ACTIVO	2026-06-02 23:09:05.417738	2026-06-02 23:09:05.417738	0
38afbee8-5a9c-45d7-a2d8-73a2b7b1191c	94173206500001411	stress-41732065-1411@mediqueue.test	Paciente Stress 41732065-1411	55001411	ACTIVO	2026-06-02 23:09:06.179002	2026-06-02 23:09:06.179002	0
3e31d04c-ad48-44ba-a95a-b479e02cd5a7	94173206500001432	stress-41732065-1432@mediqueue.test	Paciente Stress 41732065-1432	55001432	ACTIVO	2026-06-02 23:09:06.333282	2026-06-02 23:09:06.333282	0
ac7a643b-9c39-4572-acee-416566c63d30	94173206600001471	stress-41732066-1471@mediqueue.test	Paciente Stress 41732066-1471	55001471	ACTIVO	2026-06-02 23:09:06.672238	2026-06-02 23:09:06.672238	0
7a1cdaee-e1fb-4263-871f-b36a2c411a86	94173204400001693	stress-41732044-1693@mediqueue.test	Paciente Stress 41732044-1693	55001693	ACTIVO	2026-06-02 23:09:08.789607	2026-06-02 23:09:08.789607	0
79a47678-1d56-4e69-939e-35fbaf287a27	94173200300001803	stress-41732003-1803@mediqueue.test	Paciente Stress 41732003-1803	55001803	ACTIVO	2026-06-02 23:09:09.882225	2026-06-02 23:09:09.882225	0
5bb5b85e-21dd-4f4e-82a5-c4a0ef5cdb69	94173199200001974	stress-41731992-1974@mediqueue.test	Paciente Stress 41731992-1974	55001974	ACTIVO	2026-06-02 23:09:11.114367	2026-06-02 23:09:11.114367	0
3a877617-c831-4fa6-84da-1c06e862509f	94173204400002038	stress-41732044-2038@mediqueue.test	Paciente Stress 41732044-2038	55002038	ACTIVO	2026-06-02 23:09:11.569287	2026-06-02 23:09:11.569287	0
35f055a3-c592-4fd0-815c-4e23e9f6d128	94173205800002050	stress-41732058-2050@mediqueue.test	Paciente Stress 41732058-2050	55002050	ACTIVO	2026-06-02 23:09:11.623832	2026-06-02 23:09:11.623832	0
6e330355-986b-4f30-b512-e4a2c5e181ac	94173204400002156	stress-41732044-2156@mediqueue.test	Paciente Stress 41732044-2156	55002156	ACTIVO	2026-06-02 23:09:12.637218	2026-06-02 23:09:12.637218	0
a63f41eb-7948-48ba-a705-ad5b6100bf12	94173206100002174	stress-41732061-2174@mediqueue.test	Paciente Stress 41732061-2174	55002174	ACTIVO	2026-06-02 23:09:12.841742	2026-06-02 23:09:12.841742	0
f6db6db4-b992-4cd9-9fe3-a38221930056	94173201300002191	stress-41732013-2191@mediqueue.test	Paciente Stress 41732013-2191	55002191	ACTIVO	2026-06-02 23:09:12.953846	2026-06-02 23:09:12.953846	0
2deb01d5-8493-4b3a-aaf8-617d47feafb7	94173200800002218	stress-41732008-2218@mediqueue.test	Paciente Stress 41732008-2218	55002218	ACTIVO	2026-06-02 23:09:13.151728	2026-06-02 23:09:13.151728	0
44e6efb2-0542-4966-8f75-ad99afaf99ab	94173203600002236	stress-41732036-2236@mediqueue.test	Paciente Stress 41732036-2236	55002236	ACTIVO	2026-06-02 23:09:13.368964	2026-06-02 23:09:13.368964	0
add5891a-c940-4e15-806b-11edc0ea801f	93969226700000937	stress-39692267-937@mediqueue.test	Paciente Stress 39692267-937	55000937	ACTIVO	2026-06-02 22:35:07.83752	2026-06-02 22:35:07.83752	0
3aa2eb65-56f8-4479-8bdc-ac963ce25c11	93969228000001238	stress-39692280-1238@mediqueue.test	Paciente Stress 39692280-1238	55001238	ACTIVO	2026-06-02 22:35:10.7259	2026-06-02 22:35:10.7259	0
eda2a03b-6b8a-4510-ab81-ba12a2d5c0a5	93969227100001328	stress-39692271-1328@mediqueue.test	Paciente Stress 39692271-1328	55001328	ACTIVO	2026-06-02 22:35:11.61997	2026-06-02 22:35:11.61997	0
f0b487a9-e9d5-4005-9455-15b0fd6a4222	93969226200001509	stress-39692262-1509@mediqueue.test	Paciente Stress 39692262-1509	55001509	ACTIVO	2026-06-02 22:35:13.350517	2026-06-02 22:35:13.350517	0
10b925f1-0cbc-4231-a6a9-0c6feb0857bf	93969226200001581	stress-39692262-1581@mediqueue.test	Paciente Stress 39692262-1581	55001581	ACTIVO	2026-06-02 22:35:13.893331	2026-06-02 22:35:13.893331	0
b9d530e3-f5eb-46eb-a870-84efd0876c94	93969227900001764	stress-39692279-1764@mediqueue.test	Paciente Stress 39692279-1764	55001764	ACTIVO	2026-06-02 22:35:15.524858	2026-06-02 22:35:15.524858	0
4cef3a3c-17d0-4da2-8e35-77c48b473ed4	93969227100001838	stress-39692271-1838@mediqueue.test	Paciente Stress 39692271-1838	55001838	ACTIVO	2026-06-02 22:35:16.190426	2026-06-02 22:35:16.190426	0
67039b2a-3b4b-4020-8240-5c90c97a3837	93969225700001912	stress-39692257-1912@mediqueue.test	Paciente Stress 39692257-1912	55001912	ACTIVO	2026-06-02 22:35:16.954796	2026-06-02 22:35:16.954796	0
2c9d99fa-a1c6-4af7-a951-deece35472ee	93969225400002143	stress-39692254-2143@mediqueue.test	Paciente Stress 39692254-2143	55002143	ACTIVO	2026-06-02 22:35:19.380584	2026-06-02 22:35:19.380584	0
7828f64c-2c50-4efc-9bb1-bc387ac8e58d	93969228000002451	stress-39692280-2451@mediqueue.test	Paciente Stress 39692280-2451	55002451	ACTIVO	2026-06-02 22:35:22.305802	2026-06-02 22:35:22.305802	0
d87e7e2d-1698-465f-96e4-ee831395e3b3	93969226300002519	stress-39692263-2519@mediqueue.test	Paciente Stress 39692263-2519	55002519	ACTIVO	2026-06-02 22:35:22.880967	2026-06-02 22:35:22.880967	0
fbee8666-5010-460b-b2f0-5df45b1d5bcf	93969227200002548	stress-39692272-2548@mediqueue.test	Paciente Stress 39692272-2548	55002548	ACTIVO	2026-06-02 22:35:23.078304	2026-06-02 22:35:23.078304	0
14b21d46-a169-4a94-a368-badb9a793a01	93969225400002586	stress-39692254-2586@mediqueue.test	Paciente Stress 39692254-2586	55002586	ACTIVO	2026-06-02 22:35:23.37249	2026-06-02 22:35:23.37249	0
14c0773e-6f5a-45ef-a3a2-1bf40512183b	93969227300002868	stress-39692273-2868@mediqueue.test	Paciente Stress 39692273-2868	55002868	ACTIVO	2026-06-02 22:35:26.129017	2026-06-02 22:35:26.129017	0
3f88ed9e-2a14-4788-b3ce-65f03e91e7a6	93969227900002948	stress-39692279-2948@mediqueue.test	Paciente Stress 39692279-2948	55002948	ACTIVO	2026-06-02 22:35:26.823071	2026-06-02 22:35:26.823071	0
e4f69dcc-ca54-4e5b-bd7b-6a0ae60818d7	93969227800003094	stress-39692278-3094@mediqueue.test	Paciente Stress 39692278-3094	55003094	ACTIVO	2026-06-02 22:35:28.133477	2026-06-02 22:35:28.133477	0
bdc45399-dd38-4315-a8f2-b6ea170984f4	93969227900003516	stress-39692279-3516@mediqueue.test	Paciente Stress 39692279-3516	55003516	ACTIVO	2026-06-02 22:35:31.973818	2026-06-02 22:35:31.973818	0
da40a3ff-f62b-4d28-89b3-0fe943f0f944	93969226200003726	stress-39692262-3726@mediqueue.test	Paciente Stress 39692262-3726	55003726	ACTIVO	2026-06-02 22:35:34.052784	2026-06-02 22:35:34.052784	0
5f3bb1e9-3670-40c0-93e4-7ee159310bfb	93969227300004100	stress-39692273-4100@mediqueue.test	Paciente Stress 39692273-4100	55004100	ACTIVO	2026-06-02 22:35:36.848284	2026-06-02 22:35:36.848284	0
3f65cc20-dfe1-4dab-9981-c68977b87c3c	93969228000004199	stress-39692280-4199@mediqueue.test	Paciente Stress 39692280-4199	55004199	ACTIVO	2026-06-02 22:35:37.639943	2026-06-02 22:35:37.639943	0
8189581a-569a-4898-80e7-0de46f0ee1f2	93969227800004225	stress-39692278-4225@mediqueue.test	Paciente Stress 39692278-4225	55004225	ACTIVO	2026-06-02 22:35:37.885064	2026-06-02 22:35:37.885064	0
33d1a0dc-da6d-429a-a7e3-1eb4f1eee00c	93969225700004664	stress-39692257-4664@mediqueue.test	Paciente Stress 39692257-4664	55004664	ACTIVO	2026-06-02 22:35:41.642151	2026-06-02 22:35:41.642151	0
57bc4f5b-3b9b-4bed-9a39-15e6f7ee6771	93969225300004745	stress-39692253-4745@mediqueue.test	Paciente Stress 39692253-4745	55004745	ACTIVO	2026-06-02 22:35:42.17769	2026-06-02 22:35:42.17769	0
0293ddd6-a3d0-4148-90c0-b372ade81806	93969225000004894	stress-39692250-4894@mediqueue.test	Paciente Stress 39692250-4894	55004894	ACTIVO	2026-06-02 22:35:43.171481	2026-06-02 22:35:43.171481	0
2ac2f566-8d98-45ff-9426-d837e23b6a68	94045695800005776	stress-40456958-5776@mediqueue.test	Paciente Stress 40456958-5776	55005776	ACTIVO	2026-06-02 22:48:27.845233	2026-06-02 22:48:27.845233	0
1ad147c8-0cc6-4c1a-8677-7bb768e568cb	94045696100005812	stress-40456961-5812@mediqueue.test	Paciente Stress 40456961-5812	55005812	ACTIVO	2026-06-02 22:48:28.001032	2026-06-02 22:48:28.001032	0
82b47eef-4306-4109-b8e7-7e510f6f1d21	94045692700005928	stress-40456927-5928@mediqueue.test	Paciente Stress 40456927-5928	55005928	ACTIVO	2026-06-02 22:48:35.560247	2026-06-02 22:48:35.560247	0
d8f08e12-a040-4e5a-a492-2ae40723d122	94045692700005958	stress-40456927-5958@mediqueue.test	Paciente Stress 40456927-5958	55005958	ACTIVO	2026-06-02 22:48:35.925729	2026-06-02 22:48:35.925729	0
66503b3d-7772-4357-8e9c-c78013765c15	94045695900006056	stress-40456959-6056@mediqueue.test	Paciente Stress 40456959-6056	55006056	ACTIVO	2026-06-02 22:48:36.79814	2026-06-02 22:48:36.79814	0
0c30db6b-3040-44e8-81af-0afe258e5a4b	94045695200006209	stress-40456952-6209@mediqueue.test	Paciente Stress 40456952-6209	55006209	ACTIVO	2026-06-02 22:48:38.303641	2026-06-02 22:48:38.303641	0
1afcd0c0-9cbe-4765-bdc6-a27ba7f98ccf	94045695500006401	stress-40456955-6401@mediqueue.test	Paciente Stress 40456955-6401	55006401	ACTIVO	2026-06-02 22:48:40.122972	2026-06-02 22:48:40.122972	0
c41097e1-de97-4611-8981-0160cb6615bf	94045696900006611	stress-40456969-6611@mediqueue.test	Paciente Stress 40456969-6611	55006611	ACTIVO	2026-06-02 22:48:41.956251	2026-06-02 22:48:41.956251	0
161928b8-0098-49d1-8f75-41ecd26afd0e	94045696100006715	stress-40456961-6715@mediqueue.test	Paciente Stress 40456961-6715	55006715	ACTIVO	2026-06-02 22:48:42.511023	2026-06-02 22:48:42.511023	0
ba4f9865-a51c-4032-8208-2f5bd48658b1	94045695600006765	stress-40456956-6765@mediqueue.test	Paciente Stress 40456956-6765	55006765	ACTIVO	2026-06-02 22:48:43.008965	2026-06-02 22:48:43.008965	0
db4d941a-54e6-4822-98a3-b3a0e3c85b72	94045692900006861	stress-40456929-6861@mediqueue.test	Paciente Stress 40456929-6861	55006861	ACTIVO	2026-06-02 22:48:43.81246	2026-06-02 22:48:43.81246	0
d9578fb8-d187-44d6-a99f-b19b0284fb0d	94045695900006958	stress-40456959-6958@mediqueue.test	Paciente Stress 40456959-6958	55006958	ACTIVO	2026-06-02 22:48:44.607844	2026-06-02 22:48:44.607844	0
00ccb70d-a900-42d2-b7b5-ef4f2e1833e1	94173199200000035	stress-41731992-35@mediqueue.test	Paciente Stress 41731992-35	55000035	ACTIVO	2026-06-02 23:08:52.516699	2026-06-02 23:08:52.516699	0
500c433c-ec0c-4bfe-9756-5c3e3bd279a5	94173201700000062	stress-41732017-62@mediqueue.test	Paciente Stress 41732017-62	55000062	ACTIVO	2026-06-02 23:08:54.640287	2026-06-02 23:08:54.640287	0
7ce7c4ae-ea0b-4117-bb68-ae7f04abbdfc	94173206400000106	stress-41732064-106@mediqueue.test	Paciente Stress 41732064-106	55000106	ACTIVO	2026-06-02 23:08:55.340855	2026-06-02 23:08:55.340855	0
518c7a8c-b26e-47a6-89fd-4dd53bf6a3b5	94173206200000438	stress-41732062-438@mediqueue.test	Paciente Stress 41732062-438	55000438	ACTIVO	2026-06-02 23:08:58.877829	2026-06-02 23:08:58.877829	0
fe1314a2-7763-472e-9b5d-e97328dbef7a	94173204400000792	stress-41732044-792@mediqueue.test	Paciente Stress 41732044-792	55000792	ACTIVO	2026-06-02 23:08:59.739511	2026-06-02 23:08:59.739511	0
ff0f06ce-11c1-46e9-bafb-3a28b60db2ed	94173204600000591	stress-41732046-591@mediqueue.test	Paciente Stress 41732046-591	55000591	ACTIVO	2026-06-02 23:08:59.920847	2026-06-02 23:08:59.920847	0
c0c574b7-12b7-4192-934a-16ce2197ffba	94173202200000837	stress-41732022-837@mediqueue.test	Paciente Stress 41732022-837	55000837	ACTIVO	2026-06-02 23:09:00.250284	2026-06-02 23:09:00.250284	0
a854207b-43ea-4d50-9784-be7f789495a2	94173205600000780	stress-41732056-780@mediqueue.test	Paciente Stress 41732056-780	55000780	ACTIVO	2026-06-02 23:09:00.355774	2026-06-02 23:09:00.355774	0
e6c5d673-a637-42c9-9eb4-4e4b139f2fd1	94173200400000890	stress-41732004-890@mediqueue.test	Paciente Stress 41732004-890	55000890	ACTIVO	2026-06-02 23:09:00.814723	2026-06-02 23:09:00.814723	0
0c178b2f-0fb9-4c0c-8a27-6ec69ccc8d1e	94173202600000955	stress-41732026-955@mediqueue.test	Paciente Stress 41732026-955	55000955	ACTIVO	2026-06-02 23:09:01.062334	2026-06-02 23:09:01.062334	0
50fc4c54-96b3-4734-99ab-a86271af1bbe	94173203400001144	stress-41732034-1144@mediqueue.test	Paciente Stress 41732034-1144	55001144	ACTIVO	2026-06-02 23:09:03.316656	2026-06-02 23:09:03.316656	0
28141ab6-66a6-409c-96e9-7b16b5f92821	94173203700002321	stress-41732037-2321@mediqueue.test	Paciente Stress 41732037-2321	55002321	ACTIVO	2026-06-02 23:09:14.356203	2026-06-02 23:09:14.356203	0
9f7f2e1e-4a60-4904-8dba-17fcfc660e56	94173204500002400	stress-41732045-2400@mediqueue.test	Paciente Stress 41732045-2400	55002400	ACTIVO	2026-06-02 23:09:14.879883	2026-06-02 23:09:14.879883	0
8ad3ae2f-7cde-4372-9bf9-a22459298579	94173201300002694	stress-41732013-2694@mediqueue.test	Paciente Stress 41732013-2694	55002694	ACTIVO	2026-06-02 23:09:17.865437	2026-06-02 23:09:17.865437	0
1a828f8e-2ee2-4487-beea-46658a2ec2a6	94173200500002830	stress-41732005-2830@mediqueue.test	Paciente Stress 41732005-2830	55002830	ACTIVO	2026-06-02 23:09:19.544413	2026-06-02 23:09:19.544413	0
5ef764e4-3730-42aa-8f9a-641dbdab9293	94173200400002892	stress-41732004-2892@mediqueue.test	Paciente Stress 41732004-2892	55002892	ACTIVO	2026-06-02 23:09:19.955037	2026-06-02 23:09:19.955037	0
a470d357-3865-447c-93c7-99dfcd4d74f1	94173203900002927	stress-41732039-2927@mediqueue.test	Paciente Stress 41732039-2927	55002927	ACTIVO	2026-06-02 23:09:20.664755	2026-06-02 23:09:20.664755	0
eb55b362-d1d3-4f6b-be95-cc3087c186c3	94173205300002958	stress-41732053-2958@mediqueue.test	Paciente Stress 41732053-2958	55002958	ACTIVO	2026-06-02 23:09:20.904354	2026-06-02 23:09:20.904354	0
063fe38d-06c5-4ae2-9408-692b84938a9b	94173198700003127	stress-41731987-3127@mediqueue.test	Paciente Stress 41731987-3127	55003127	ACTIVO	2026-06-02 23:09:22.722577	2026-06-02 23:09:22.722577	0
ddb1d9e9-377d-42f6-b770-5bfbff9b4a86	94173207000003303	stress-41732070-3303@mediqueue.test	Paciente Stress 41732070-3303	55003303	ACTIVO	2026-06-02 23:09:24.207131	2026-06-02 23:09:24.207131	0
2b11f3ba-2da9-47fe-a5e5-383d9d433117	94173201700003346	stress-41732017-3346@mediqueue.test	Paciente Stress 41732017-3346	55003346	ACTIVO	2026-06-02 23:09:24.515963	2026-06-02 23:09:24.515963	0
5acff2d1-dc9b-4976-95f7-8d5f2eb77a9d	94173201900003646	stress-41732019-3646@mediqueue.test	Paciente Stress 41732019-3646	55003646	ACTIVO	2026-06-02 23:09:27.407997	2026-06-02 23:09:27.407997	0
c66d59b8-d09f-4766-b755-557dca4f2eb7	94173200800003770	stress-41732008-3770@mediqueue.test	Paciente Stress 41732008-3770	55003770	ACTIVO	2026-06-02 23:09:28.277129	2026-06-02 23:09:28.277129	0
a7fc04f3-b9c7-4002-aee8-600295910416	94173201500003835	stress-41732015-3835@mediqueue.test	Paciente Stress 41732015-3835	55003835	ACTIVO	2026-06-02 23:09:28.905349	2026-06-02 23:09:28.905349	0
e458f7c4-58a5-4771-913a-4d462b2f2134	94173203100003849	stress-41732031-3849@mediqueue.test	Paciente Stress 41732031-3849	55003849	ACTIVO	2026-06-02 23:09:29.369995	2026-06-02 23:09:29.369995	0
de3fdf22-dee7-4f4d-94c6-e11daee95b87	94173200400004132	stress-41732004-4132@mediqueue.test	Paciente Stress 41732004-4132	55004132	ACTIVO	2026-06-02 23:09:31.933281	2026-06-02 23:09:31.933281	0
e898502d-b7a0-4e90-8991-8225ea348b8f	94173204400004222	stress-41732044-4222@mediqueue.test	Paciente Stress 41732044-4222	55004222	ACTIVO	2026-06-02 23:09:32.792883	2026-06-02 23:09:32.792883	0
c8f5f191-2494-454f-b06c-eb10f883e8b0	94173199200004292	stress-41731992-4292@mediqueue.test	Paciente Stress 41731992-4292	55004292	ACTIVO	2026-06-02 23:09:33.576562	2026-06-02 23:09:33.576562	0
f96514bc-dc7b-4a3d-9694-9ddb740e286b	94173200000004440	stress-41732000-4440@mediqueue.test	Paciente Stress 41732000-4440	55004440	ACTIVO	2026-06-02 23:09:34.850717	2026-06-02 23:09:34.850717	0
87dd7794-2fe8-420b-9e3b-0ad470adc59b	94173197700004473	stress-41731977-4473@mediqueue.test	Paciente Stress 41731977-4473	55004473	ACTIVO	2026-06-02 23:09:35.221157	2026-06-02 23:09:35.221157	0
475fc340-361b-4a6a-8e95-6ac3ae0a6d7e	94173198500004670	stress-41731985-4670@mediqueue.test	Paciente Stress 41731985-4670	55004670	ACTIVO	2026-06-02 23:09:36.847871	2026-06-02 23:09:36.847871	0
82fba923-bcbc-408d-8d71-ec92c69def76	94173202200004930	stress-41732022-4930@mediqueue.test	Paciente Stress 41732022-4930	55004930	ACTIVO	2026-06-02 23:09:39.305876	2026-06-02 23:09:39.305876	0
fd60ff5e-00ba-4216-a235-d556caebddbe	94173206000005025	stress-41732060-5025@mediqueue.test	Paciente Stress 41732060-5025	55005025	ACTIVO	2026-06-02 23:09:40.225212	2026-06-02 23:09:40.225212	0
5018152a-25ae-4279-b5ee-defa665ea464	94173206700005062	stress-41732067-5062@mediqueue.test	Paciente Stress 41732067-5062	55005062	ACTIVO	2026-06-02 23:09:40.552413	2026-06-02 23:09:40.552413	0
9e2b4ec9-28a4-42bc-9b4c-a3a67b97df52	94173200600005157	stress-41732006-5157@mediqueue.test	Paciente Stress 41732006-5157	55005157	ACTIVO	2026-06-02 23:09:41.578548	2026-06-02 23:09:41.578548	0
6ceaa9cd-5b2f-4edf-92d0-7a53092fba8b	94173201900005197	stress-41732019-5197@mediqueue.test	Paciente Stress 41732019-5197	55005197	ACTIVO	2026-06-02 23:09:42.119584	2026-06-02 23:09:42.119584	0
51c93834-6d3e-4b80-bf80-6e0beaa5b2f1	94173200600005373	stress-41732006-5373@mediqueue.test	Paciente Stress 41732006-5373	55005373	ACTIVO	2026-06-02 23:09:44.697048	2026-06-02 23:09:44.697048	0
83675c27-8cf3-47ca-99c1-72ea9bb07950	94173200800005410	stress-41732008-5410@mediqueue.test	Paciente Stress 41732008-5410	55005410	ACTIVO	2026-06-02 23:09:44.90004	2026-06-02 23:09:44.90004	0
0bd3e322-ffaa-4c79-aae4-d64d799ccc7c	94173203000005448	stress-41732030-5448@mediqueue.test	Paciente Stress 41732030-5448	55005448	ACTIVO	2026-06-02 23:09:45.402253	2026-06-02 23:09:45.402253	0
1e9382a8-ef36-48cb-8b48-00d13b533c28	94173199500005644	stress-41731995-5644@mediqueue.test	Paciente Stress 41731995-5644	55005644	ACTIVO	2026-06-02 23:09:47.215749	2026-06-02 23:09:47.215749	0
6b95e061-8d1d-4813-8c2e-8f9b370dfd37	94173203400005851	stress-41732034-5851@mediqueue.test	Paciente Stress 41732034-5851	55005851	ACTIVO	2026-06-02 23:09:49.331295	2026-06-02 23:09:49.331295	0
67eed660-0dd2-4825-a5ff-17bf263f0a4b	94173200400006094	stress-41732004-6094@mediqueue.test	Paciente Stress 41732004-6094	55006094	ACTIVO	2026-06-02 23:09:51.939301	2026-06-02 23:09:51.939301	0
c4796027-317d-47f1-9b7f-2f5ad118e73f	94173201600006158	stress-41732016-6158@mediqueue.test	Paciente Stress 41732016-6158	55006158	ACTIVO	2026-06-02 23:09:52.55217	2026-06-02 23:09:52.55217	0
ffbc1056-4d9f-4474-822c-0cf444f1ffd1	94173203200006329	stress-41732032-6329@mediqueue.test	Paciente Stress 41732032-6329	55006329	ACTIVO	2026-06-02 23:10:01.01447	2026-06-02 23:10:01.01447	0
97ddf781-193f-4658-8c03-a48938c48304	94173204000006394	stress-41732040-6394@mediqueue.test	Paciente Stress 41732040-6394	55006394	ACTIVO	2026-06-02 23:10:01.630245	2026-06-02 23:10:01.630245	0
28694de5-47f4-4d85-bb7e-9b8fcfb4da1f	94173198100006525	stress-41731981-6525@mediqueue.test	Paciente Stress 41731981-6525	55006525	ACTIVO	2026-06-02 23:10:03.281003	2026-06-02 23:10:03.281003	0
6ff7d38c-abfe-49c4-ad7d-a2a4d758e09b	94173205100006694	stress-41732051-6694@mediqueue.test	Paciente Stress 41732051-6694	55006694	ACTIVO	2026-06-02 23:10:04.599133	2026-06-02 23:10:04.599133	0
1cba2b21-b789-445d-9619-1e71e2b5c405	94173206500006730	stress-41732065-6730@mediqueue.test	Paciente Stress 41732065-6730	55006730	ACTIVO	2026-06-02 23:10:04.805915	2026-06-02 23:10:04.805915	0
43fd2f5f-f33b-428b-8075-0a629a1edae2	94173200600006751	stress-41732006-6751@mediqueue.test	Paciente Stress 41732006-6751	55006751	ACTIVO	2026-06-02 23:10:04.952399	2026-06-02 23:10:04.952399	0
a5136d36-4f10-419e-bcde-3cded077332c	94173204100007133	stress-41732041-7133@mediqueue.test	Paciente Stress 41732041-7133	55007133	ACTIVO	2026-06-02 23:10:09.189194	2026-06-02 23:10:09.189194	0
9368bd30-17a4-4832-9ce5-8a6de34ed83c	94173202600007166	stress-41732026-7166@mediqueue.test	Paciente Stress 41732026-7166	55007166	ACTIVO	2026-06-02 23:10:09.359106	2026-06-02 23:10:09.359106	0
3afd4091-97c5-41f6-9e55-abb5ae78db4d	94173199200007363	stress-41731992-7363@mediqueue.test	Paciente Stress 41731992-7363	55007363	ACTIVO	2026-06-02 23:10:11.491967	2026-06-02 23:10:11.491967	0
19fdded5-c5ab-415f-89af-53eb3d696c8e	94173204000007702	stress-41732040-7702@mediqueue.test	Paciente Stress 41732040-7702	55007702	ACTIVO	2026-06-02 23:10:14.678555	2026-06-02 23:10:14.678555	0
2ced14ce-6958-485a-b8cd-f5e35acfdbc8	94173204200007901	stress-41732042-7901@mediqueue.test	Paciente Stress 41732042-7901	55007901	ACTIVO	2026-06-02 23:10:31.083975	2026-06-02 23:10:31.083975	0
04017fff-b61e-4540-8104-a114ec579e76	94173204100007984	stress-41732041-7984@mediqueue.test	Paciente Stress 41732041-7984	55007984	ACTIVO	2026-06-02 23:10:31.808592	2026-06-02 23:10:31.808592	0
99a1cfa6-b8dd-4f40-a6a8-94ce656b0a37	94173203700008007	stress-41732037-8007@mediqueue.test	Paciente Stress 41732037-8007	55008007	ACTIVO	2026-06-02 23:10:32.09338	2026-06-02 23:10:32.09338	0
bca584cf-a37b-470d-8672-368029c5b739	94173204800008269	stress-41732048-8269@mediqueue.test	Paciente Stress 41732048-8269	55008269	ACTIVO	2026-06-02 23:10:41.110771	2026-06-02 23:10:41.110771	0
88967cef-df44-4155-a117-d7c7c651f9e1	94173201600008699	stress-41732016-8699@mediqueue.test	Paciente Stress 41732016-8699	55008699	ACTIVO	2026-06-02 23:10:44.844328	2026-06-02 23:10:44.844328	0
667b0bba-533e-4469-819e-3cc05776f7b7	94173203000002393	stress-41732030-2393@mediqueue.test	Paciente Stress 41732030-2393	55002393	ACTIVO	2026-06-02 23:09:14.780522	2026-06-02 23:09:14.780522	0
f4163a6f-6a90-4cbf-a551-f5f81713e2e0	94173201900002408	stress-41732019-2408@mediqueue.test	Paciente Stress 41732019-2408	55002408	ACTIVO	2026-06-02 23:09:14.911888	2026-06-02 23:09:14.911888	0
2dc57a21-4cd1-47b1-9d2f-7b990bd80a17	94173203200002702	stress-41732032-2702@mediqueue.test	Paciente Stress 41732032-2702	55002702	ACTIVO	2026-06-02 23:09:18.007694	2026-06-02 23:09:18.007694	0
30da0b4b-ca96-495a-acca-172282b26018	94173200300002818	stress-41732003-2818@mediqueue.test	Paciente Stress 41732003-2818	55002818	ACTIVO	2026-06-02 23:09:19.405996	2026-06-02 23:09:19.405996	0
2871227e-e7d4-461a-a2f4-168819a86236	94173204400003002	stress-41732044-3002@mediqueue.test	Paciente Stress 41732044-3002	55003002	ACTIVO	2026-06-02 23:09:21.291058	2026-06-02 23:09:21.291058	0
9642f9b9-e7dd-48d7-bd6c-f5de053ce9b2	94173204000003065	stress-41732040-3065@mediqueue.test	Paciente Stress 41732040-3065	55003065	ACTIVO	2026-06-02 23:09:22.329695	2026-06-02 23:09:22.329695	0
0b0aed34-7c1f-4359-ad1e-e67c8fa02b73	94173199100003382	stress-41731991-3382@mediqueue.test	Paciente Stress 41731991-3382	55003382	ACTIVO	2026-06-02 23:09:24.87761	2026-06-02 23:09:24.87761	0
0adc9c68-f30e-4019-bb33-5df4f826a289	94173204000003395	stress-41732040-3395@mediqueue.test	Paciente Stress 41732040-3395	55003395	ACTIVO	2026-06-02 23:09:25.078423	2026-06-02 23:09:25.078423	0
8f490dd9-4b14-47c0-b378-39e4e3082423	94173202200003431	stress-41732022-3431@mediqueue.test	Paciente Stress 41732022-3431	55003431	ACTIVO	2026-06-02 23:09:25.736261	2026-06-02 23:09:25.736261	0
72d3a0f3-54c1-4708-b942-b933c243a2ef	94173197900003692	stress-41731979-3692@mediqueue.test	Paciente Stress 41731979-3692	55003692	ACTIVO	2026-06-02 23:09:27.466438	2026-06-02 23:09:27.466438	0
f88728f5-65d5-4143-aef7-a1f8bd589071	94173205300003938	stress-41732053-3938@mediqueue.test	Paciente Stress 41732053-3938	55003938	ACTIVO	2026-06-02 23:09:30.113373	2026-06-02 23:09:30.113373	0
3aaaa7e5-7ac9-4547-8288-0f0a2695fdbf	94173206000004020	stress-41732060-4020@mediqueue.test	Paciente Stress 41732060-4020	55004020	ACTIVO	2026-06-02 23:09:31.099974	2026-06-02 23:09:31.099974	0
b598b876-4ff2-4746-9244-338e1e135d21	94173200500004061	stress-41732005-4061@mediqueue.test	Paciente Stress 41732005-4061	55004061	ACTIVO	2026-06-02 23:09:31.428727	2026-06-02 23:09:31.428727	0
1885e1c3-b883-4546-9a6b-f1f869ef3666	94173198700004127	stress-41731987-4127@mediqueue.test	Paciente Stress 41731987-4127	55004127	ACTIVO	2026-06-02 23:09:32.075761	2026-06-02 23:09:32.075761	0
b08c0cbd-9503-4103-983a-435c339cd614	94173204600004267	stress-41732046-4267@mediqueue.test	Paciente Stress 41732046-4267	55004267	ACTIVO	2026-06-02 23:09:33.273955	2026-06-02 23:09:33.273955	0
776a906f-6c5b-47cb-a520-d5d1bfd8f974	94173205900004254	stress-41732059-4254@mediqueue.test	Paciente Stress 41732059-4254	55004254	ACTIVO	2026-06-02 23:09:33.496202	2026-06-02 23:09:33.496202	0
fd3f9364-8ccc-4369-9084-031ac418a278	94173199500004527	stress-41731995-4527@mediqueue.test	Paciente Stress 41731995-4527	55004527	ACTIVO	2026-06-02 23:09:35.708915	2026-06-02 23:09:35.708915	0
3bbef834-069e-4023-981e-822be9ebf82d	94173205400004565	stress-41732054-4565@mediqueue.test	Paciente Stress 41732054-4565	55004565	ACTIVO	2026-06-02 23:09:35.905827	2026-06-02 23:09:35.905827	0
4c125981-d1cb-43cc-9a0c-ed67fe117cbc	94173200600004886	stress-41732006-4886@mediqueue.test	Paciente Stress 41732006-4886	55004886	ACTIVO	2026-06-02 23:09:38.750606	2026-06-02 23:09:38.750606	0
fa5c3a18-49f8-49f6-a293-c5cc2ffa964c	94173204100004910	stress-41732041-4910@mediqueue.test	Paciente Stress 41732041-4910	55004910	ACTIVO	2026-06-02 23:09:38.930245	2026-06-02 23:09:38.930245	0
fdc264f5-7b3f-4ce7-b4b1-5931bba31b81	94173203100005561	stress-41732031-5561@mediqueue.test	Paciente Stress 41732031-5561	55005561	ACTIVO	2026-06-02 23:09:46.425401	2026-06-02 23:09:46.425401	0
e4a70651-4bd5-4edd-ba5f-849964b57fa8	94173205200005667	stress-41732052-5667@mediqueue.test	Paciente Stress 41732052-5667	55005667	ACTIVO	2026-06-02 23:09:47.319636	2026-06-02 23:09:47.319636	0
dc40a474-8d84-4d9a-a3ea-cd6240833962	94173206200005839	stress-41732062-5839@mediqueue.test	Paciente Stress 41732062-5839	55005839	ACTIVO	2026-06-02 23:09:48.958519	2026-06-02 23:09:48.958519	0
02dfa1f0-bb50-419f-9110-b12d20ae291e	94173205500005837	stress-41732055-5837@mediqueue.test	Paciente Stress 41732055-5837	55005837	ACTIVO	2026-06-02 23:09:49.088025	2026-06-02 23:09:49.088025	0
1b4b0adc-915e-4608-8052-c1d30f49acdf	94173205900005905	stress-41732059-5905@mediqueue.test	Paciente Stress 41732059-5905	55005905	ACTIVO	2026-06-02 23:09:49.920348	2026-06-02 23:09:49.920348	0
b91cfa53-4a37-4829-a9d9-329c84b61a17	94173201400005941	stress-41732014-5941@mediqueue.test	Paciente Stress 41732014-5941	55005941	ACTIVO	2026-06-02 23:09:50.361022	2026-06-02 23:09:50.361022	0
aff8cdd8-0a9a-4b8b-98bd-b31821946d7b	94173205300005964	stress-41732053-5964@mediqueue.test	Paciente Stress 41732053-5964	55005964	ACTIVO	2026-06-02 23:09:50.698575	2026-06-02 23:09:50.698575	0
5200987d-e575-476f-9d93-6f587712b9a3	94173198300006080	stress-41731983-6080@mediqueue.test	Paciente Stress 41731983-6080	55006080	ACTIVO	2026-06-02 23:09:51.774517	2026-06-02 23:09:51.774517	0
d2f34ca8-03e6-40f3-be15-dfee2dbcf02f	94173197900006826	stress-41731979-6826@mediqueue.test	Paciente Stress 41731979-6826	55006826	ACTIVO	2026-06-02 23:10:05.893106	2026-06-02 23:10:05.893106	0
14fdf4d2-b63e-4cbe-bf23-3cabd6186290	94173205600006947	stress-41732056-6947@mediqueue.test	Paciente Stress 41732056-6947	55006947	ACTIVO	2026-06-02 23:10:07.243311	2026-06-02 23:10:07.243311	0
8d2cd0ad-8445-44e1-8ffb-b9d29cffb125	94173202600007040	stress-41732026-7040@mediqueue.test	Paciente Stress 41732026-7040	55007040	ACTIVO	2026-06-02 23:10:08.26001	2026-06-02 23:10:08.26001	0
3e96de42-6996-4269-95f4-d9d3483302db	94173201200007282	stress-41732012-7282@mediqueue.test	Paciente Stress 41732012-7282	55007282	ACTIVO	2026-06-02 23:10:10.627331	2026-06-02 23:10:10.627331	0
7ef21067-48b9-4555-bc45-31d2820934b2	94173204600007523	stress-41732046-7523@mediqueue.test	Paciente Stress 41732046-7523	55007523	ACTIVO	2026-06-02 23:10:12.948533	2026-06-02 23:10:12.948533	0
d4c1669f-c419-4603-a17b-5872df57e825	94173203300007812	stress-41732033-7812@mediqueue.test	Paciente Stress 41732033-7812	55007812	ACTIVO	2026-06-02 23:10:15.936627	2026-06-02 23:10:15.936627	0
4b346f4d-8986-48cd-bcb1-2922434e6478	94173206300007883	stress-41732063-7883@mediqueue.test	Paciente Stress 41732063-7883	55007883	ACTIVO	2026-06-02 23:10:30.994541	2026-06-02 23:10:30.994541	0
d9c869d8-c6cb-4af2-a617-13c474e59fed	94173203800007933	stress-41732038-7933@mediqueue.test	Paciente Stress 41732038-7933	55007933	ACTIVO	2026-06-02 23:10:31.238028	2026-06-02 23:10:31.238028	0
60b1f17a-3b69-4885-8e94-a212d4163e76	94173202600008494	stress-41732026-8494@mediqueue.test	Paciente Stress 41732026-8494	55008494	ACTIVO	2026-06-02 23:10:42.760056	2026-06-02 23:10:42.760056	0
eb77979b-1936-4c03-87f4-e0505efb7549	94173206100008593	stress-41732061-8593@mediqueue.test	Paciente Stress 41732061-8593	55008593	ACTIVO	2026-06-02 23:10:43.74879	2026-06-02 23:10:43.74879	0
2beda086-ac17-494f-89a0-29a4d9cb15cd	94173198600008596	stress-41731986-8596@mediqueue.test	Paciente Stress 41731986-8596	55008596	ACTIVO	2026-06-02 23:10:43.848833	2026-06-02 23:10:43.848833	0
f5ecc845-512a-4098-baae-106ebdcaf3b1	94173200300008610	stress-41732003-8610@mediqueue.test	Paciente Stress 41732003-8610	55008610	ACTIVO	2026-06-02 23:10:43.969892	2026-06-02 23:10:43.969892	0
7f07c020-fc9c-4bdd-82f9-a902a9f2347c	94173197900008673	stress-41731979-8673@mediqueue.test	Paciente Stress 41731979-8673	55008673	ACTIVO	2026-06-02 23:10:44.70105	2026-06-02 23:10:44.70105	0
178f8fbb-b41c-4d4a-8ea6-6c71cf0dc022	94173198700008679	stress-41731987-8679@mediqueue.test	Paciente Stress 41731987-8679	55008679	ACTIVO	2026-06-02 23:10:44.824689	2026-06-02 23:10:44.824689	0
3607b79e-562f-4cca-9ae9-ace43311558f	94173197700008793	stress-41731977-8793@mediqueue.test	Paciente Stress 41731977-8793	55008793	ACTIVO	2026-06-02 23:10:45.666651	2026-06-02 23:10:45.666651	0
5adc0505-4970-4ffb-b3b4-54a13d4abf4a	94173198600008910	stress-41731986-8910@mediqueue.test	Paciente Stress 41731986-8910	55008910	ACTIVO	2026-06-02 23:10:46.680435	2026-06-02 23:10:46.680435	0
08c3e9fd-961f-4180-8b4e-289f8979f369	94173197800009006	stress-41731978-9006@mediqueue.test	Paciente Stress 41731978-9006	55009006	ACTIVO	2026-06-02 23:10:47.595116	2026-06-02 23:10:47.595116	0
4b4fec2e-f3ab-4e98-a658-7ea12066115f	94173198500009112	stress-41731985-9112@mediqueue.test	Paciente Stress 41731985-9112	55009112	ACTIVO	2026-06-02 23:10:48.642	2026-06-02 23:10:48.642	0
11dcde40-a22e-465c-8ad2-d17dbfef92d1	94173205100009181	stress-41732051-9181@mediqueue.test	Paciente Stress 41732051-9181	55009181	ACTIVO	2026-06-02 23:10:49.376795	2026-06-02 23:10:49.376795	0
5aab3f31-38b0-4372-b971-a400bc848409	94173203500002369	stress-41732035-2369@mediqueue.test	Paciente Stress 41732035-2369	55002369	ACTIVO	2026-06-02 23:09:14.796449	2026-06-02 23:09:14.796449	0
165fcd95-d70e-4359-bbdd-0f2853211a0d	94173203200002441	stress-41732032-2441@mediqueue.test	Paciente Stress 41732032-2441	55002441	ACTIVO	2026-06-02 23:09:15.29255	2026-06-02 23:09:15.29255	0
792d0c4e-87e3-4f10-a1fc-39e0a6f30ae1	94173203100003345	stress-41732031-3345@mediqueue.test	Paciente Stress 41732031-3345	55003345	ACTIVO	2026-06-02 23:09:24.551248	2026-06-02 23:09:24.551248	0
81c84ac7-d41f-4181-a71e-c9bdba24d6af	94173204100003397	stress-41732041-3397@mediqueue.test	Paciente Stress 41732041-3397	55003397	ACTIVO	2026-06-02 23:09:25.082997	2026-06-02 23:09:25.082997	0
e51e71a2-c6de-4659-84e9-9aed437f77f5	94173199600003625	stress-41731996-3625@mediqueue.test	Paciente Stress 41731996-3625	55003625	ACTIVO	2026-06-02 23:09:27.105453	2026-06-02 23:09:27.105453	0
a65fab1d-1a2b-4962-bbb6-7a0e1cf7db19	94173204700003773	stress-41732047-3773@mediqueue.test	Paciente Stress 41732047-3773	55003773	ACTIVO	2026-06-02 23:09:28.469216	2026-06-02 23:09:28.469216	0
76e7167f-8d08-40fb-95ba-5d798e4a4033	94173202200003971	stress-41732022-3971@mediqueue.test	Paciente Stress 41732022-3971	55003971	ACTIVO	2026-06-02 23:09:30.316406	2026-06-02 23:09:30.316406	0
5c2a58cf-558a-4415-89d9-e1531bd84cca	94173200700004337	stress-41732007-4337@mediqueue.test	Paciente Stress 41732007-4337	55004337	ACTIVO	2026-06-02 23:09:34.020542	2026-06-02 23:09:34.020542	0
7cbdc095-2ba7-4c4e-afb7-58fc9180a1d5	94173201400004475	stress-41732014-4475@mediqueue.test	Paciente Stress 41732014-4475	55004475	ACTIVO	2026-06-02 23:09:35.31526	2026-06-02 23:09:35.31526	0
52d4f2ea-dec0-4de5-affa-368800e063cb	94173204400004624	stress-41732044-4624@mediqueue.test	Paciente Stress 41732044-4624	55004624	ACTIVO	2026-06-02 23:09:36.463781	2026-06-02 23:09:36.463781	0
dfe6f240-35e5-4e87-93b1-d026737d56af	94173201900004738	stress-41732019-4738@mediqueue.test	Paciente Stress 41732019-4738	55004738	ACTIVO	2026-06-02 23:09:37.3627	2026-06-02 23:09:37.3627	0
ed55279c-2e69-4e21-a019-c9945e173931	94173199300005100	stress-41731993-5100@mediqueue.test	Paciente Stress 41731993-5100	55005100	ACTIVO	2026-06-02 23:09:40.892599	2026-06-02 23:09:40.892599	0
2f64b747-60b1-4562-889e-547da0c07a8d	94173200500005293	stress-41732005-5293@mediqueue.test	Paciente Stress 41732005-5293	55005293	ACTIVO	2026-06-02 23:09:43.29696	2026-06-02 23:09:43.29696	0
8ba14682-4257-448f-aa0b-8e1d8de785a5	94173199600005669	stress-41731996-5669@mediqueue.test	Paciente Stress 41731996-5669	55005669	ACTIVO	2026-06-02 23:09:47.359583	2026-06-02 23:09:47.359583	0
5f84f3bc-6c99-4c32-846b-62534a58c213	94173202500005765	stress-41732025-5765@mediqueue.test	Paciente Stress 41732025-5765	55005765	ACTIVO	2026-06-02 23:09:48.361732	2026-06-02 23:09:48.361732	0
858da65d-179c-4ed7-90bb-242216f99de5	94173197700006229	stress-41731977-6229@mediqueue.test	Paciente Stress 41731977-6229	55006229	ACTIVO	2026-06-02 23:10:00.280453	2026-06-02 23:10:00.280453	0
334d18ce-da97-440b-863b-fc66081063d1	94173206500006608	stress-41732065-6608@mediqueue.test	Paciente Stress 41732065-6608	55006608	ACTIVO	2026-06-02 23:10:03.928396	2026-06-02 23:10:03.928396	0
526d8306-6150-42f9-a616-f256b61cf392	94173206000006840	stress-41732060-6840@mediqueue.test	Paciente Stress 41732060-6840	55006840	ACTIVO	2026-06-02 23:10:05.997192	2026-06-02 23:10:05.997192	0
97560138-d2d8-412c-9c1a-b38b28a62149	94173205700006880	stress-41732057-6880@mediqueue.test	Paciente Stress 41732057-6880	55006880	ACTIVO	2026-06-02 23:10:06.272364	2026-06-02 23:10:06.272364	0
bdb7161d-e066-47ad-bcc9-ff5ddf7b208f	94173199600006996	stress-41731996-6996@mediqueue.test	Paciente Stress 41731996-6996	55006996	ACTIVO	2026-06-02 23:10:07.817187	2026-06-02 23:10:07.817187	0
a79013fe-1cd4-4ad9-87b8-606cca05df32	94173200500007120	stress-41732005-7120@mediqueue.test	Paciente Stress 41732005-7120	55007120	ACTIVO	2026-06-02 23:10:09.103328	2026-06-02 23:10:09.103328	0
b6daf32b-ee16-4d4e-aaab-b736290ba4b1	94173204000007378	stress-41732040-7378@mediqueue.test	Paciente Stress 41732040-7378	55007378	ACTIVO	2026-06-02 23:10:11.91225	2026-06-02 23:10:11.91225	0
702cc02b-81d7-4c40-aa00-32d2e3f46caa	94173204100007399	stress-41732041-7399@mediqueue.test	Paciente Stress 41732041-7399	55007399	ACTIVO	2026-06-02 23:10:12.011448	2026-06-02 23:10:12.011448	0
5bf2195b-004d-4352-bbc2-d62e24138759	94173206800007454	stress-41732068-7454@mediqueue.test	Paciente Stress 41732068-7454	55007454	ACTIVO	2026-06-02 23:10:12.31371	2026-06-02 23:10:12.31371	0
6af52ddc-daca-4761-98a9-6c6f8f30dc86	94173205600008582	stress-41732056-8582@mediqueue.test	Paciente Stress 41732056-8582	55008582	ACTIVO	2026-06-02 23:10:43.837311	2026-06-02 23:10:43.837311	0
5d5c8597-8ebc-4171-bc6c-6f207dc05452	94173201400008884	stress-41732014-8884@mediqueue.test	Paciente Stress 41732014-8884	55008884	ACTIVO	2026-06-02 23:10:46.533843	2026-06-02 23:10:46.533843	0
058c90ed-8989-4afe-bbff-a952d32366da	94173205900009024	stress-41732059-9024@mediqueue.test	Paciente Stress 41732059-9024	55009024	ACTIVO	2026-06-02 23:10:47.750635	2026-06-02 23:10:47.750635	0
1414c25e-4361-4722-97f5-b3ccb25426a9	94173198500009060	stress-41731985-9060@mediqueue.test	Paciente Stress 41731985-9060	55009060	ACTIVO	2026-06-02 23:10:48.034419	2026-06-02 23:10:48.034419	0
d4773274-123c-4f47-8168-a72cdae778cb	94173206300009048	stress-41732063-9048@mediqueue.test	Paciente Stress 41732063-9048	55009048	ACTIVO	2026-06-02 23:10:48.110836	2026-06-02 23:10:48.110836	0
7ca42180-e0d5-45d7-98bd-fabe188d9196	94173202000009070	stress-41732020-9070@mediqueue.test	Paciente Stress 41732020-9070	55009070	ACTIVO	2026-06-02 23:10:48.151378	2026-06-02 23:10:48.151378	0
d3396921-5bbc-4e9a-be23-b29d3b9a9737	94173204200009148	stress-41732042-9148@mediqueue.test	Paciente Stress 41732042-9148	55009148	ACTIVO	2026-06-02 23:10:49.379164	2026-06-02 23:10:49.379164	0
f4634209-1c9c-4488-b627-ef2d8f9f0efb	94173197600009347	stress-41731976-9347@mediqueue.test	Paciente Stress 41731976-9347	55009347	ACTIVO	2026-06-02 23:10:52.006219	2026-06-02 23:10:52.006219	0
ccc95e82-d5e5-4e6c-9d9c-a2918ae2ab51	94173205800009389	stress-41732058-9389@mediqueue.test	Paciente Stress 41732058-9389	55009389	ACTIVO	2026-06-02 23:10:52.214773	2026-06-02 23:10:52.214773	0
6713b594-a877-4280-aa66-7fa23508d1af	94173204400009445	stress-41732044-9445@mediqueue.test	Paciente Stress 41732044-9445	55009445	ACTIVO	2026-06-02 23:10:52.409449	2026-06-02 23:10:52.409449	0
3bc70fee-221e-4b8b-b263-4df4366eebe9	94173200800009433	stress-41732008-9433@mediqueue.test	Paciente Stress 41732008-9433	55009433	ACTIVO	2026-06-02 23:10:52.592008	2026-06-02 23:10:52.592008	0
86e412e5-5c94-46b2-ab28-5ed0ba79ef07	94173206700009485	stress-41732067-9485@mediqueue.test	Paciente Stress 41732067-9485	55009485	ACTIVO	2026-06-02 23:10:52.906244	2026-06-02 23:10:52.906244	0
c01224f8-5a95-40ae-bba9-41dd50ccaff7	94173204800009591	stress-41732048-9591@mediqueue.test	Paciente Stress 41732048-9591	55009591	ACTIVO	2026-06-02 23:10:54.751526	2026-06-02 23:10:54.751526	0
38d32582-d4b3-4847-b698-072cdc4062b6	94173200300009661	stress-41732003-9661@mediqueue.test	Paciente Stress 41732003-9661	55009661	ACTIVO	2026-06-02 23:10:55.231153	2026-06-02 23:10:55.231153	0
94639a74-e8e3-4d26-b9cb-ab78ce3525f5	94173200400009767	stress-41732004-9767@mediqueue.test	Paciente Stress 41732004-9767	55009767	ACTIVO	2026-06-02 23:10:56.500457	2026-06-02 23:10:56.500457	0
8fc8492f-b99e-4cee-9c75-fa12e1bd6d84	94173201100009812	stress-41732011-9812@mediqueue.test	Paciente Stress 41732011-9812	55009812	ACTIVO	2026-06-02 23:10:56.628765	2026-06-02 23:10:56.628765	0
a6f2ce64-7eb2-44fd-a75e-e6298fcb10b2	94173202600010228	stress-41732026-10228@mediqueue.test	Paciente Stress 41732026-10228	55010228	ACTIVO	2026-06-02 23:11:49.016036	2026-06-02 23:11:49.016036	0
5b434337-f368-44c3-ac42-c452cc0815f8	94173198700010084	stress-41731987-10084@mediqueue.test	Paciente Stress 41731987-10084	55010084	ACTIVO	2026-06-02 23:11:49.071453	2026-06-02 23:11:49.071453	0
b355e52c-7744-4d38-8496-cec0c54825a1	94173205100010300	stress-41732051-10300@mediqueue.test	Paciente Stress 41732051-10300	55010300	ACTIVO	2026-06-02 23:11:49.266216	2026-06-02 23:11:49.266216	0
182e6973-ef20-4c6f-9b96-3b8b981b6280	94173200800010037	stress-41732008-10037@mediqueue.test	Paciente Stress 41732008-10037	55010037	ACTIVO	2026-06-02 23:11:49.44848	2026-06-02 23:11:49.44848	0
ec96c5db-816e-47bb-a352-0f5032b8e746	94173206500010231	stress-41732065-10231@mediqueue.test	Paciente Stress 41732065-10231	55010231	ACTIVO	2026-06-02 23:11:49.863139	2026-06-02 23:11:49.863139	0
33d37a50-e127-41e7-affc-60d4b568f25c	94173204100010329	stress-41732041-10329@mediqueue.test	Paciente Stress 41732041-10329	55010329	ACTIVO	2026-06-02 23:11:50.593836	2026-06-02 23:11:50.593836	0
2c941dff-5790-4d0b-8e3a-cf76388401c2	94173200500010208	stress-41732005-10208@mediqueue.test	Paciente Stress 41732005-10208	55010208	ACTIVO	2026-06-02 23:11:50.896596	2026-06-02 23:11:50.896596	0
f4e60a00-7fca-47af-9ddd-4286fc08674a	94173203200002426	stress-41732032-2426@mediqueue.test	Paciente Stress 41732032-2426	55002426	ACTIVO	2026-06-02 23:09:15.23678	2026-06-02 23:09:15.23678	0
c03b7a74-8a14-4ba9-9d1f-21aff1f408e8	94173203900002559	stress-41732039-2559@mediqueue.test	Paciente Stress 41732039-2559	55002559	ACTIVO	2026-06-02 23:09:16.362843	2026-06-02 23:09:16.362843	0
1519490f-a7ff-42e1-ae31-2843a74f0246	94173197900002783	stress-41731979-2783@mediqueue.test	Paciente Stress 41731979-2783	55002783	ACTIVO	2026-06-02 23:09:19.113827	2026-06-02 23:09:19.113827	0
349dc2f6-92bc-4d4c-b893-177a3c0fc4ae	94173205600002808	stress-41732056-2808@mediqueue.test	Paciente Stress 41732056-2808	55002808	ACTIVO	2026-06-02 23:09:19.334133	2026-06-02 23:09:19.334133	0
5fba1a6b-48e6-41b5-89f1-e60acb415ba8	94173203500002882	stress-41732035-2882@mediqueue.test	Paciente Stress 41732035-2882	55002882	ACTIVO	2026-06-02 23:09:19.911958	2026-06-02 23:09:19.911958	0
7bcce347-5a58-425a-8417-275c0bb4d9c2	94173200600003102	stress-41732006-3102@mediqueue.test	Paciente Stress 41732006-3102	55003102	ACTIVO	2026-06-02 23:09:22.558365	2026-06-02 23:09:22.558365	0
6c37b7ee-1512-491b-b7e9-59d273b2fae6	94173207000003266	stress-41732070-3266@mediqueue.test	Paciente Stress 41732070-3266	55003266	ACTIVO	2026-06-02 23:09:23.936067	2026-06-02 23:09:23.936067	0
32178f48-8015-4aa0-b202-fa142596c649	94173198500003293	stress-41731985-3293@mediqueue.test	Paciente Stress 41731985-3293	55003293	ACTIVO	2026-06-02 23:09:24.137715	2026-06-02 23:09:24.137715	0
033ffa99-a6fc-4789-add7-e0e68850deb4	94173200500003428	stress-41732005-3428@mediqueue.test	Paciente Stress 41732005-3428	55003428	ACTIVO	2026-06-02 23:09:25.66024	2026-06-02 23:09:25.66024	0
5fb853cf-e1a6-4760-bc38-49aac9b98d29	94173197600003533	stress-41731976-3533@mediqueue.test	Paciente Stress 41731976-3533	55003533	ACTIVO	2026-06-02 23:09:26.326536	2026-06-02 23:09:26.326536	0
9ebd87e2-8911-4b4f-a97d-c54a76043a59	94173200500003580	stress-41732005-3580@mediqueue.test	Paciente Stress 41732005-3580	55003580	ACTIVO	2026-06-02 23:09:26.717492	2026-06-02 23:09:26.717492	0
9e2ff2f6-5e5c-4a47-8102-691a75c5992c	94173204500003638	stress-41732045-3638@mediqueue.test	Paciente Stress 41732045-3638	55003638	ACTIVO	2026-06-02 23:09:27.161268	2026-06-02 23:09:27.161268	0
1976893b-b0bd-4cd5-a997-be92a94595cf	94173199600003868	stress-41731996-3868@mediqueue.test	Paciente Stress 41731996-3868	55003868	ACTIVO	2026-06-02 23:09:29.393341	2026-06-02 23:09:29.393341	0
159cde52-bba6-4c44-9153-ce056cca2875	94173206700003907	stress-41732067-3907@mediqueue.test	Paciente Stress 41732067-3907	55003907	ACTIVO	2026-06-02 23:09:29.62913	2026-06-02 23:09:29.62913	0
59ca528d-bd77-4599-8110-50d88620021c	94173204500004012	stress-41732045-4012@mediqueue.test	Paciente Stress 41732045-4012	55004012	ACTIVO	2026-06-02 23:09:30.860259	2026-06-02 23:09:30.860259	0
fe0c6f0f-40f2-45d7-9ed3-5016e160d73e	94173203800004393	stress-41732038-4393@mediqueue.test	Paciente Stress 41732038-4393	55004393	ACTIVO	2026-06-02 23:09:34.622228	2026-06-02 23:09:34.622228	0
b9eadb9a-7046-4ad9-aea0-0f476647386e	94173203900004611	stress-41732039-4611@mediqueue.test	Paciente Stress 41732039-4611	55004611	ACTIVO	2026-06-02 23:09:36.369777	2026-06-02 23:09:36.369777	0
959dcb6d-d7c8-4c6d-ac73-e1e0b116b3e8	94173204100004628	stress-41732041-4628@mediqueue.test	Paciente Stress 41732041-4628	55004628	ACTIVO	2026-06-02 23:09:36.554615	2026-06-02 23:09:36.554615	0
f2ba71fa-de5c-4c11-93a2-c18cdd8e24bd	94173203900004693	stress-41732039-4693@mediqueue.test	Paciente Stress 41732039-4693	55004693	ACTIVO	2026-06-02 23:09:36.988246	2026-06-02 23:09:36.988246	0
65a76e77-4fbe-4ace-81dd-eea6d0aeb425	94173199200004717	stress-41731992-4717@mediqueue.test	Paciente Stress 41731992-4717	55004717	ACTIVO	2026-06-02 23:09:37.195815	2026-06-02 23:09:37.195815	0
440b30c8-57f9-49a4-93d5-15003f6fdf9d	94173203900004809	stress-41732039-4809@mediqueue.test	Paciente Stress 41732039-4809	55004809	ACTIVO	2026-06-02 23:09:37.839662	2026-06-02 23:09:37.839662	0
46fe12bf-52a4-4274-ab5f-5dddeab13fa9	94173202200004944	stress-41732022-4944@mediqueue.test	Paciente Stress 41732022-4944	55004944	ACTIVO	2026-06-02 23:09:39.49228	2026-06-02 23:09:39.49228	0
ebca7925-054a-471d-89bb-318c7cdf343f	94173206200004979	stress-41732062-4979@mediqueue.test	Paciente Stress 41732062-4979	55004979	ACTIVO	2026-06-02 23:09:39.614399	2026-06-02 23:09:39.614399	0
190f4e4d-744e-4e9e-9ede-bc0197b140fb	94173204400005026	stress-41732044-5026@mediqueue.test	Paciente Stress 41732044-5026	55005026	ACTIVO	2026-06-02 23:09:40.226	2026-06-02 23:09:40.226	0
95f7e6f0-ef53-43dc-bf50-fce0c9eb9e44	94173198500005250	stress-41731985-5250@mediqueue.test	Paciente Stress 41731985-5250	55005250	ACTIVO	2026-06-02 23:09:42.654765	2026-06-02 23:09:42.654765	0
13facb11-6e02-4f0c-9ddd-46f7f513c708	94173203300005342	stress-41732033-5342@mediqueue.test	Paciente Stress 41732033-5342	55005342	ACTIVO	2026-06-02 23:09:44.25986	2026-06-02 23:09:44.25986	0
8a161575-f8ff-46b0-9d77-1c9fb6433391	94173204100005353	stress-41732041-5353@mediqueue.test	Paciente Stress 41732041-5353	55005353	ACTIVO	2026-06-02 23:09:44.900534	2026-06-02 23:09:44.900534	0
575a7f06-7315-4069-b6ad-eebf8e6f7171	94173202300005457	stress-41732023-5457@mediqueue.test	Paciente Stress 41732023-5457	55005457	ACTIVO	2026-06-02 23:09:45.656547	2026-06-02 23:09:45.656547	0
440bc47a-b3e8-456d-a092-8dcc0a89e515	94173204600005572	stress-41732046-5572@mediqueue.test	Paciente Stress 41732046-5572	55005572	ACTIVO	2026-06-02 23:09:46.545569	2026-06-02 23:09:46.545569	0
3e456882-7690-42da-9dfb-a95007182b40	94173204600005730	stress-41732046-5730@mediqueue.test	Paciente Stress 41732046-5730	55005730	ACTIVO	2026-06-02 23:09:47.75321	2026-06-02 23:09:47.75321	0
d71cfe42-f263-4cb3-a183-5e2a261278eb	94173203500006194	stress-41732035-6194@mediqueue.test	Paciente Stress 41732035-6194	55006194	ACTIVO	2026-06-02 23:10:00.172238	2026-06-02 23:10:00.172238	0
ebdc1c20-74b9-418f-ad86-156a438f20bb	94173205900006246	stress-41732059-6246@mediqueue.test	Paciente Stress 41732059-6246	55006246	ACTIVO	2026-06-02 23:10:00.35797	2026-06-02 23:10:00.35797	0
8080e97d-930f-460d-8f0c-2a8d000c66b2	94173205000007049	stress-41732050-7049@mediqueue.test	Paciente Stress 41732050-7049	55007049	ACTIVO	2026-06-02 23:10:08.349679	2026-06-02 23:10:08.349679	0
0809cc56-cda6-4742-b66b-ccde5e3ea791	94173203800007142	stress-41732038-7142@mediqueue.test	Paciente Stress 41732038-7142	55007142	ACTIVO	2026-06-02 23:10:09.237947	2026-06-02 23:10:09.237947	0
6c6a3dd9-5927-4674-aa98-bb39e989f4ac	94173202600007224	stress-41732026-7224@mediqueue.test	Paciente Stress 41732026-7224	55007224	ACTIVO	2026-06-02 23:10:10.273791	2026-06-02 23:10:10.273791	0
6891318f-3084-449e-a062-5a0d4bee8f86	94173206000007486	stress-41732060-7486@mediqueue.test	Paciente Stress 41732060-7486	55007486	ACTIVO	2026-06-02 23:10:12.47522	2026-06-02 23:10:12.47522	0
41829a96-7b4d-44bd-aaaa-a3079375a5eb	94173203500007790	stress-41732035-7790@mediqueue.test	Paciente Stress 41732035-7790	55007790	ACTIVO	2026-06-02 23:10:15.75891	2026-06-02 23:10:15.75891	0
9cbb7ede-5066-4959-9b77-2cbdcfd63566	94173200700007882	stress-41732007-7882@mediqueue.test	Paciente Stress 41732007-7882	55007882	ACTIVO	2026-06-02 23:10:30.977126	2026-06-02 23:10:30.977126	0
a5a45d23-c59e-44a4-9210-b42b954678ce	94173199600008313	stress-41731996-8313@mediqueue.test	Paciente Stress 41731996-8313	55008313	ACTIVO	2026-06-02 23:10:41.394476	2026-06-02 23:10:41.394476	0
c35373a1-c58f-494e-9f7c-e0a4af8457ce	94173201400008428	stress-41732014-8428@mediqueue.test	Paciente Stress 41732014-8428	55008428	ACTIVO	2026-06-02 23:10:42.240461	2026-06-02 23:10:42.240461	0
f4532eef-db9f-4663-9a2e-68d13397ea06	94173203600008520	stress-41732036-8520@mediqueue.test	Paciente Stress 41732036-8520	55008520	ACTIVO	2026-06-02 23:10:43.128246	2026-06-02 23:10:43.128246	0
3071bf58-7ec9-465d-ad08-1711a7af4f9c	94173205400008689	stress-41732054-8689@mediqueue.test	Paciente Stress 41732054-8689	55008689	ACTIVO	2026-06-02 23:10:44.776093	2026-06-02 23:10:44.776093	0
2bfd252e-d2a7-4ad4-a391-ae74ae70ba6b	94173202300008812	stress-41732023-8812@mediqueue.test	Paciente Stress 41732023-8812	55008812	ACTIVO	2026-06-02 23:10:46.014987	2026-06-02 23:10:46.014987	0
12d0943b-159f-4861-8df4-3f2a40972c16	94173203300008879	stress-41732033-8879@mediqueue.test	Paciente Stress 41732033-8879	55008879	ACTIVO	2026-06-02 23:10:46.41073	2026-06-02 23:10:46.41073	0
1e9ab1c3-8dce-4613-a338-a4bc0b5ba118	94173204400008882	stress-41732044-8882@mediqueue.test	Paciente Stress 41732044-8882	55008882	ACTIVO	2026-06-02 23:10:46.55633	2026-06-02 23:10:46.55633	0
b0844827-65f8-4e20-bb3b-f81ffb4c1bdd	94173205000009037	stress-41732050-9037@mediqueue.test	Paciente Stress 41732050-9037	55009037	ACTIVO	2026-06-02 23:10:48.015398	2026-06-02 23:10:48.015398	0
106877c9-86f6-4aa8-8ea4-2272fe1f9072	94173203500009165	stress-41732035-9165@mediqueue.test	Paciente Stress 41732035-9165	55009165	ACTIVO	2026-06-02 23:10:49.34923	2026-06-02 23:10:49.34923	0
6e94d71d-3528-4336-b316-9ca28965ba1e	94173204800002450	stress-41732048-2450@mediqueue.test	Paciente Stress 41732048-2450	55002450	ACTIVO	2026-06-02 23:09:15.372195	2026-06-02 23:09:15.372195	0
43257212-ac43-4f98-852f-c7fd87c542a6	94173206400002601	stress-41732064-2601@mediqueue.test	Paciente Stress 41732064-2601	55002601	ACTIVO	2026-06-02 23:09:16.855268	2026-06-02 23:09:16.855268	0
a5e69948-ba12-4b5c-8cbb-fc27b1e56bf9	94173205100002922	stress-41732051-2922@mediqueue.test	Paciente Stress 41732051-2922	55002922	ACTIVO	2026-06-02 23:09:20.523187	2026-06-02 23:09:20.523187	0
cc282aff-7c34-4b1f-a593-bbf11b4a6839	94173206500002993	stress-41732065-2993@mediqueue.test	Paciente Stress 41732065-2993	55002993	ACTIVO	2026-06-02 23:09:21.157467	2026-06-02 23:09:21.157467	0
0b58bf34-d029-41f4-896d-415f8fa7c81f	94173204400003041	stress-41732044-3041@mediqueue.test	Paciente Stress 41732044-3041	55003041	ACTIVO	2026-06-02 23:09:22.188781	2026-06-02 23:09:22.188781	0
51ffbccc-f0ad-40d0-9fea-820c79c0721e	94173200800003555	stress-41732008-3555@mediqueue.test	Paciente Stress 41732008-3555	55003555	ACTIVO	2026-06-02 23:09:26.488495	2026-06-02 23:09:26.488495	0
524972de-967b-404e-bd95-2b0671ad8b91	94173201100003764	stress-41732011-3764@mediqueue.test	Paciente Stress 41732011-3764	55003764	ACTIVO	2026-06-02 23:09:28.22214	2026-06-02 23:09:28.22214	0
1f8214b6-00c1-40cb-9777-17558198ae44	94173206400003879	stress-41732064-3879@mediqueue.test	Paciente Stress 41732064-3879	55003879	ACTIVO	2026-06-02 23:09:29.425642	2026-06-02 23:09:29.425642	0
b92a7362-3260-4185-a1ac-237b505d4023	94173205100004064	stress-41732051-4064@mediqueue.test	Paciente Stress 41732051-4064	55004064	ACTIVO	2026-06-02 23:09:31.509832	2026-06-02 23:09:31.509832	0
6a5a517a-4749-43e2-885c-b479a1a34f2a	94173205600004151	stress-41732056-4151@mediqueue.test	Paciente Stress 41732056-4151	55004151	ACTIVO	2026-06-02 23:09:32.076323	2026-06-02 23:09:32.076323	0
8d92e1fe-dd0a-45b2-ad68-fbdb18718ec7	94173200300004371	stress-41732003-4371@mediqueue.test	Paciente Stress 41732003-4371	55004371	ACTIVO	2026-06-02 23:09:34.562018	2026-06-02 23:09:34.562018	0
b8228326-25ca-474e-aae5-2de85e2de3df	94173198700004656	stress-41731987-4656@mediqueue.test	Paciente Stress 41731987-4656	55004656	ACTIVO	2026-06-02 23:09:36.737281	2026-06-02 23:09:36.737281	0
a6db06fc-9152-4680-aa10-cd852e3a0a06	94173203800004686	stress-41732038-4686@mediqueue.test	Paciente Stress 41732038-4686	55004686	ACTIVO	2026-06-02 23:09:36.955537	2026-06-02 23:09:36.955537	0
eac00902-26df-4b3a-baa6-f006c9a7a37d	94173205800004710	stress-41732058-4710@mediqueue.test	Paciente Stress 41732058-4710	55004710	ACTIVO	2026-06-02 23:09:37.126386	2026-06-02 23:09:37.126386	0
c1dee3c3-0f7d-494e-aabd-1d1ea13873f7	94173202600004734	stress-41732026-4734@mediqueue.test	Paciente Stress 41732026-4734	55004734	ACTIVO	2026-06-02 23:09:37.303864	2026-06-02 23:09:37.303864	0
cc8bcef4-fac0-4c6b-ac83-d20c8a45b30f	94173205700004793	stress-41732057-4793@mediqueue.test	Paciente Stress 41732057-4793	55004793	ACTIVO	2026-06-02 23:09:37.763019	2026-06-02 23:09:37.763019	0
658f40d3-708c-4f36-bb7b-ed947e4aae36	94173200500004916	stress-41732005-4916@mediqueue.test	Paciente Stress 41732005-4916	55004916	ACTIVO	2026-06-02 23:09:39.007837	2026-06-02 23:09:39.007837	0
aa1712c3-3d21-4266-a1b2-ca116115db51	94173203100005004	stress-41732031-5004@mediqueue.test	Paciente Stress 41732031-5004	55005004	ACTIVO	2026-06-02 23:09:40.195887	2026-06-02 23:09:40.195887	0
feeb22b7-9f3e-4318-88fd-bf7f78971590	94173200500005119	stress-41732005-5119@mediqueue.test	Paciente Stress 41732005-5119	55005119	ACTIVO	2026-06-02 23:09:41.125279	2026-06-02 23:09:41.125279	0
7f60b899-9615-4479-a537-943e1b9e4bd5	94173203600005165	stress-41732036-5165@mediqueue.test	Paciente Stress 41732036-5165	55005165	ACTIVO	2026-06-02 23:09:41.692363	2026-06-02 23:09:41.692363	0
e5e7ca00-99f0-4356-99c0-2fba07df5994	94173204200005243	stress-41732042-5243@mediqueue.test	Paciente Stress 41732042-5243	55005243	ACTIVO	2026-06-02 23:09:42.589789	2026-06-02 23:09:42.589789	0
3a335cdc-1acc-45b1-a7db-5d26ee250a6f	94173205200005363	stress-41732052-5363@mediqueue.test	Paciente Stress 41732052-5363	55005363	ACTIVO	2026-06-02 23:09:44.582995	2026-06-02 23:09:44.582995	0
8de7aabc-9d6a-4da6-b044-e8900dec6067	94173198500005747	stress-41731985-5747@mediqueue.test	Paciente Stress 41731985-5747	55005747	ACTIVO	2026-06-02 23:09:48.09165	2026-06-02 23:09:48.09165	0
b34237df-7a04-4da3-8cc4-a3f8550aa50e	94173198600005772	stress-41731986-5772@mediqueue.test	Paciente Stress 41731986-5772	55005772	ACTIVO	2026-06-02 23:09:48.401305	2026-06-02 23:09:48.401305	0
5a405383-2766-4c75-b278-137c3c6c6eec	94173203800005942	stress-41732038-5942@mediqueue.test	Paciente Stress 41732038-5942	55005942	ACTIVO	2026-06-02 23:09:50.459082	2026-06-02 23:09:50.459082	0
8984db48-531e-4a3c-b515-055905024785	94173203200006085	stress-41732032-6085@mediqueue.test	Paciente Stress 41732032-6085	55006085	ACTIVO	2026-06-02 23:09:52.141577	2026-06-02 23:09:52.141577	0
0640a630-3e88-44c1-92e2-5287415ae4da	94173206800006334	stress-41732068-6334@mediqueue.test	Paciente Stress 41732068-6334	55006334	ACTIVO	2026-06-02 23:10:01.054906	2026-06-02 23:10:01.054906	0
9a4e625f-7619-4905-9a4e-cacb9d9eae9f	94173202500006517	stress-41732025-6517@mediqueue.test	Paciente Stress 41732025-6517	55006517	ACTIVO	2026-06-02 23:10:03.094849	2026-06-02 23:10:03.094849	0
5afa739c-42ac-451b-b891-df2e91623b82	94173202600006948	stress-41732026-6948@mediqueue.test	Paciente Stress 41732026-6948	55006948	ACTIVO	2026-06-02 23:10:07.314302	2026-06-02 23:10:07.314302	0
02f4c374-acdf-43c7-8a07-d7755143339a	94173203700007022	stress-41732037-7022@mediqueue.test	Paciente Stress 41732037-7022	55007022	ACTIVO	2026-06-02 23:10:08.073072	2026-06-02 23:10:08.073072	0
490f1d44-9037-4844-8a27-bdde4f4abdc0	94173201800007834	stress-41732018-7834@mediqueue.test	Paciente Stress 41732018-7834	55007834	ACTIVO	2026-06-02 23:10:16.115229	2026-06-02 23:10:16.115229	0
ef7c95fb-2d75-4141-bed8-966de30f79a9	94173197800007985	stress-41731978-7985@mediqueue.test	Paciente Stress 41731978-7985	55007985	ACTIVO	2026-06-02 23:10:32.029478	2026-06-02 23:10:32.029478	0
eb1308c2-6e25-467e-855b-36217a41baee	94173199400008056	stress-41731994-8056@mediqueue.test	Paciente Stress 41731994-8056	55008056	ACTIVO	2026-06-02 23:10:32.742873	2026-06-02 23:10:32.742873	0
84f1eec8-c5b7-4b56-b8fe-22b4a9b79714	94173204500008327	stress-41732045-8327@mediqueue.test	Paciente Stress 41732045-8327	55008327	ACTIVO	2026-06-02 23:10:41.538957	2026-06-02 23:10:41.538957	0
92b7b658-3add-4184-b5ca-52d1acd4adde	94173205600008351	stress-41732056-8351@mediqueue.test	Paciente Stress 41732056-8351	55008351	ACTIVO	2026-06-02 23:10:41.730488	2026-06-02 23:10:41.730488	0
1ae34616-1f9e-4d93-b8e9-1a09d86ba5b5	94173206100008497	stress-41732061-8497@mediqueue.test	Paciente Stress 41732061-8497	55008497	ACTIVO	2026-06-02 23:10:42.85452	2026-06-02 23:10:42.85452	0
b6f5b616-c99d-478f-a8f4-585c4596d066	94173199600008683	stress-41731996-8683@mediqueue.test	Paciente Stress 41731996-8683	55008683	ACTIVO	2026-06-02 23:10:44.842928	2026-06-02 23:10:44.842928	0
b914bba2-a831-425d-8243-d103d3dfcc2b	94173204000008947	stress-41732040-8947@mediqueue.test	Paciente Stress 41732040-8947	55008947	ACTIVO	2026-06-02 23:10:47.142252	2026-06-02 23:10:47.142252	0
acbeb31c-9cd4-4198-b432-eecc27acb543	94173202300009279	stress-41732023-9279@mediqueue.test	Paciente Stress 41732023-9279	55009279	ACTIVO	2026-06-02 23:10:50.923259	2026-06-02 23:10:50.923259	0
6eed7e3b-6d81-4ed1-a540-e337ce8ef585	94173206000009349	stress-41732060-9349@mediqueue.test	Paciente Stress 41732060-9349	55009349	ACTIVO	2026-06-02 23:10:52.035208	2026-06-02 23:10:52.035208	0
3c415620-69b2-42e3-9854-004e02e73d86	94173203100009451	stress-41732031-9451@mediqueue.test	Paciente Stress 41732031-9451	55009451	ACTIVO	2026-06-02 23:10:52.789817	2026-06-02 23:10:52.789817	0
7c72e2b7-4bc5-4992-82a5-1c7708d6220e	94173206800009558	stress-41732068-9558@mediqueue.test	Paciente Stress 41732068-9558	55009558	ACTIVO	2026-06-02 23:10:54.120514	2026-06-02 23:10:54.120514	0
548243a7-9b0d-42e5-a599-f81ed607d4a3	94173202500009580	stress-41732025-9580@mediqueue.test	Paciente Stress 41732025-9580	55009580	ACTIVO	2026-06-02 23:10:54.130468	2026-06-02 23:10:54.130468	0
78cf4b25-5114-460e-ae7b-cb844c831ed8	94173203700009951	stress-41732037-9951@mediqueue.test	Paciente Stress 41732037-9951	55009951	ACTIVO	2026-06-02 23:10:57.615208	2026-06-02 23:10:57.615208	0
d6aeda46-c399-4b7d-a9f5-37f48cdc4df7	94173203300010007	stress-41732033-10007@mediqueue.test	Paciente Stress 41732033-10007	55010007	ACTIVO	2026-06-02 23:11:47.835639	2026-06-02 23:11:47.835639	0
1d5c7447-76c0-4a79-b5dc-cf981202fa1e	94173203700010320	stress-41732037-10320@mediqueue.test	Paciente Stress 41732037-10320	55010320	ACTIVO	2026-06-02 23:11:50.593434	2026-06-02 23:11:50.593434	0
99d40b35-abab-4833-953a-30a3cc5888e6	94173200800010298	stress-41732008-10298@mediqueue.test	Paciente Stress 41732008-10298	55010298	ACTIVO	2026-06-02 23:11:50.715537	2026-06-02 23:11:50.715537	0
2a620650-eb0d-4279-a0d3-f8e934791d69	94173199300002458	stress-41731993-2458@mediqueue.test	Paciente Stress 41731993-2458	55002458	ACTIVO	2026-06-02 23:09:15.426115	2026-06-02 23:09:15.426115	0
89061023-bbe8-41da-9c74-d6fd71247158	94173202500002610	stress-41732025-2610@mediqueue.test	Paciente Stress 41732025-2610	55002610	ACTIVO	2026-06-02 23:09:16.812439	2026-06-02 23:09:16.812439	0
31edf2eb-54ba-4874-8ddc-7f0603d21418	94173200300003221	stress-41732003-3221@mediqueue.test	Paciente Stress 41732003-3221	55003221	ACTIVO	2026-06-02 23:09:23.527765	2026-06-02 23:09:23.527765	0
4a468874-4e7c-4050-8f01-e3495d400142	94173203700003252	stress-41732037-3252@mediqueue.test	Paciente Stress 41732037-3252	55003252	ACTIVO	2026-06-02 23:09:23.892421	2026-06-02 23:09:23.892421	0
2181d562-a6f1-4159-828c-b40a927b86bb	94173204500003517	stress-41732045-3517@mediqueue.test	Paciente Stress 41732045-3517	55003517	ACTIVO	2026-06-02 23:09:26.251916	2026-06-02 23:09:26.251916	0
ca625323-8778-48e9-bd9c-7166c2787cf8	94173199600003571	stress-41731996-3571@mediqueue.test	Paciente Stress 41731996-3571	55003571	ACTIVO	2026-06-02 23:09:26.645874	2026-06-02 23:09:26.645874	0
46307b83-a1d4-4ffb-8ebd-07f44b3da880	94173198300003628	stress-41731983-3628@mediqueue.test	Paciente Stress 41731983-3628	55003628	ACTIVO	2026-06-02 23:09:27.098949	2026-06-02 23:09:27.098949	0
1bb0d49c-a8b0-4b97-b058-104f2e0a4683	94173201100003662	stress-41732011-3662@mediqueue.test	Paciente Stress 41732011-3662	55003662	ACTIVO	2026-06-02 23:09:27.218919	2026-06-02 23:09:27.218919	0
aacc7101-e650-41f9-bd13-1fcb4b38d862	94173199500003847	stress-41731995-3847@mediqueue.test	Paciente Stress 41731995-3847	55003847	ACTIVO	2026-06-02 23:09:29.11393	2026-06-02 23:09:29.11393	0
fd94aa43-06c6-459f-8815-fc21eeaad385	94173203600004005	stress-41732036-4005@mediqueue.test	Paciente Stress 41732036-4005	55004005	ACTIVO	2026-06-02 23:09:30.682172	2026-06-02 23:09:30.682172	0
a7a733f7-f9a7-451e-981a-dae3662d2c5a	94173204000004153	stress-41732040-4153@mediqueue.test	Paciente Stress 41732040-4153	55004153	ACTIVO	2026-06-02 23:09:32.084693	2026-06-02 23:09:32.084693	0
7df3136d-5382-493d-ba93-42e429076ed0	94173205600004253	stress-41732056-4253@mediqueue.test	Paciente Stress 41732056-4253	55004253	ACTIVO	2026-06-02 23:09:33.177227	2026-06-02 23:09:33.177227	0
c618b522-27f2-448f-9d8c-838b3850c0ed	94173204000004379	stress-41732040-4379@mediqueue.test	Paciente Stress 41732040-4379	55004379	ACTIVO	2026-06-02 23:09:34.509875	2026-06-02 23:09:34.509875	0
03287863-24e0-4cad-a9d9-022a4ce26dc5	94173203100004470	stress-41732031-4470@mediqueue.test	Paciente Stress 41732031-4470	55004470	ACTIVO	2026-06-02 23:09:35.237412	2026-06-02 23:09:35.237412	0
5fbfb911-3509-4604-bf7b-f07af341d983	94173199200004502	stress-41731992-4502@mediqueue.test	Paciente Stress 41731992-4502	55004502	ACTIVO	2026-06-02 23:09:35.530676	2026-06-02 23:09:35.530676	0
b24694ce-93ad-471d-b147-217db5a66b35	94173204100004974	stress-41732041-4974@mediqueue.test	Paciente Stress 41732041-4974	55004974	ACTIVO	2026-06-02 23:09:39.691653	2026-06-02 23:09:39.691653	0
cc29846c-284a-4d8f-9a21-084f9ab6ce73	94173199000005014	stress-41731990-5014@mediqueue.test	Paciente Stress 41731990-5014	55005014	ACTIVO	2026-06-02 23:09:40.248115	2026-06-02 23:09:40.248115	0
cf1a4ae0-51f4-4789-937d-defeed7b98ae	94173198600005179	stress-41731986-5179@mediqueue.test	Paciente Stress 41731986-5179	55005179	ACTIVO	2026-06-02 23:09:41.680838	2026-06-02 23:09:41.680838	0
760173c0-5672-41bb-b486-0a53559658ac	94173203400005329	stress-41732034-5329@mediqueue.test	Paciente Stress 41732034-5329	55005329	ACTIVO	2026-06-02 23:09:44.260377	2026-06-02 23:09:44.260377	0
e1c594a1-73b0-44b3-9e6d-f2fa4f2ed4a1	94173199200005778	stress-41731992-5778@mediqueue.test	Paciente Stress 41731992-5778	55005778	ACTIVO	2026-06-02 23:09:48.371631	2026-06-02 23:09:48.371631	0
84b30b68-b3e4-4603-be8d-3bbff41cf3e5	94173203900005786	stress-41732039-5786@mediqueue.test	Paciente Stress 41732039-5786	55005786	ACTIVO	2026-06-02 23:09:48.568829	2026-06-02 23:09:48.568829	0
169bd6d6-8f75-4783-8e52-a001b7ad4e8c	94173197700005955	stress-41731977-5955@mediqueue.test	Paciente Stress 41731977-5955	55005955	ACTIVO	2026-06-02 23:09:50.573302	2026-06-02 23:09:50.573302	0
7734117c-f542-4c84-8bec-2532f19b5e9f	94173199200006552	stress-41731992-6552@mediqueue.test	Paciente Stress 41731992-6552	55006552	ACTIVO	2026-06-02 23:10:03.362842	2026-06-02 23:10:03.362842	0
34780cd6-c309-42ad-8ce9-3ba23c5c6bcc	94173197700006879	stress-41731977-6879@mediqueue.test	Paciente Stress 41731977-6879	55006879	ACTIVO	2026-06-02 23:10:06.347696	2026-06-02 23:10:06.347696	0
6d0059a8-79cc-4b92-8bea-0df11bbcc346	94173205000007027	stress-41732050-7027@mediqueue.test	Paciente Stress 41732050-7027	55007027	ACTIVO	2026-06-02 23:10:08.300471	2026-06-02 23:10:08.300471	0
1f017b88-b221-4261-9bf2-6974353043bf	94173201700007070	stress-41732017-7070@mediqueue.test	Paciente Stress 41732017-7070	55007070	ACTIVO	2026-06-02 23:10:08.635082	2026-06-02 23:10:08.635082	0
b3313f21-2067-4041-89b3-fb6994846c81	94173202000007146	stress-41732020-7146@mediqueue.test	Paciente Stress 41732020-7146	55007146	ACTIVO	2026-06-02 23:10:09.272774	2026-06-02 23:10:09.272774	0
ccf7238f-e39e-4bb7-bb62-8021a3c1d1b7	94173200400007181	stress-41732004-7181@mediqueue.test	Paciente Stress 41732004-7181	55007181	ACTIVO	2026-06-02 23:10:09.658748	2026-06-02 23:10:09.658748	0
04003f05-48ac-4dba-8078-b3861abca114	94173199100007651	stress-41731991-7651@mediqueue.test	Paciente Stress 41731991-7651	55007651	ACTIVO	2026-06-02 23:10:14.185893	2026-06-02 23:10:14.185893	0
9710ffa2-b55e-434d-9965-7ce2f347e305	94173204100007672	stress-41732041-7672@mediqueue.test	Paciente Stress 41732041-7672	55007672	ACTIVO	2026-06-02 23:10:14.396287	2026-06-02 23:10:14.396287	0
6c19be61-9ede-44b7-b488-7cf78ce01bf3	94173199300007709	stress-41731993-7709@mediqueue.test	Paciente Stress 41731993-7709	55007709	ACTIVO	2026-06-02 23:10:14.68828	2026-06-02 23:10:14.68828	0
11e9a8fb-e86e-41ab-bb89-71f4a5f43c3b	94173205000007721	stress-41732050-7721@mediqueue.test	Paciente Stress 41732050-7721	55007721	ACTIVO	2026-06-02 23:10:14.935219	2026-06-02 23:10:14.935219	0
6506760d-beb9-4033-be7e-299f779c361c	94173203400007966	stress-41732034-7966@mediqueue.test	Paciente Stress 41732034-7966	55007966	ACTIVO	2026-06-02 23:10:31.585748	2026-06-02 23:10:31.585748	0
92f7ad3d-3331-4cfb-95e4-9a612e966064	94173202600008156	stress-41732026-8156@mediqueue.test	Paciente Stress 41732026-8156	55008156	ACTIVO	2026-06-02 23:10:40.266654	2026-06-02 23:10:40.266654	0
d749ce2c-cdc1-44e9-bbce-eebfa146cf55	94173203200008289	stress-41732032-8289@mediqueue.test	Paciente Stress 41732032-8289	55008289	ACTIVO	2026-06-02 23:10:41.285305	2026-06-02 23:10:41.285305	0
8a2e52fa-22e9-4bd2-9869-bcb5abc07185	94173205600008461	stress-41732056-8461@mediqueue.test	Paciente Stress 41732056-8461	55008461	ACTIVO	2026-06-02 23:10:42.383468	2026-06-02 23:10:42.383468	0
820cb871-e755-4e18-b41e-80bd955ee853	94173201500008565	stress-41732015-8565@mediqueue.test	Paciente Stress 41732015-8565	55008565	ACTIVO	2026-06-02 23:10:43.744213	2026-06-02 23:10:43.744213	0
fcc74318-41c9-4a5f-83ab-46ff01fad132	94173206500008945	stress-41732065-8945@mediqueue.test	Paciente Stress 41732065-8945	55008945	ACTIVO	2026-06-02 23:10:46.93848	2026-06-02 23:10:46.93848	0
668e53da-0df7-4495-a590-91a32b96634d	94173198500009138	stress-41731985-9138@mediqueue.test	Paciente Stress 41731985-9138	55009138	ACTIVO	2026-06-02 23:10:49.23082	2026-06-02 23:10:49.23082	0
29c1b92b-fb4c-4e8b-b6a2-ccaa3510e4f2	94173201700009291	stress-41732017-9291@mediqueue.test	Paciente Stress 41732017-9291	55009291	ACTIVO	2026-06-02 23:10:52.125725	2026-06-02 23:10:52.125725	0
1441a00b-0167-47df-81f7-088a636e7754	94173203900009418	stress-41732039-9418@mediqueue.test	Paciente Stress 41732039-9418	55009418	ACTIVO	2026-06-02 23:10:52.310567	2026-06-02 23:10:52.310567	0
39687705-66fe-49df-bf7d-6cd4dbb010a1	94173203500009393	stress-41732035-9393@mediqueue.test	Paciente Stress 41732035-9393	55009393	ACTIVO	2026-06-02 23:10:52.699889	2026-06-02 23:10:52.699889	0
336640dc-6f77-4bd9-809c-3bb6849b79df	94173203100009400	stress-41732031-9400@mediqueue.test	Paciente Stress 41732031-9400	55009400	ACTIVO	2026-06-02 23:10:52.811969	2026-06-02 23:10:52.811969	0
6fa0c020-a90e-4901-96cc-31786105c526	94173203000009538	stress-41732030-9538@mediqueue.test	Paciente Stress 41732030-9538	55009538	ACTIVO	2026-06-02 23:10:54.097511	2026-06-02 23:10:54.097511	0
c9331d5e-259d-48fe-b7eb-ea5bef19be36	94173205900009609	stress-41732059-9609@mediqueue.test	Paciente Stress 41732059-9609	55009609	ACTIVO	2026-06-02 23:10:55.06743	2026-06-02 23:10:55.06743	0
f5944fe5-4b33-4be0-a3cd-f3e51566e755	94173206800009601	stress-41732068-9601@mediqueue.test	Paciente Stress 41732068-9601	55009601	ACTIVO	2026-06-02 23:10:56.038448	2026-06-02 23:10:56.038448	0
05cbfcf8-4230-4cfb-8983-13ca227e988f	94173201800009760	stress-41732018-9760@mediqueue.test	Paciente Stress 41732018-9760	55009760	ACTIVO	2026-06-02 23:10:56.528384	2026-06-02 23:10:56.528384	0
4d65f2c8-9a75-4410-9e60-467e7b6b525f	94173198500002481	stress-41731985-2481@mediqueue.test	Paciente Stress 41731985-2481	55002481	ACTIVO	2026-06-02 23:09:15.565847	2026-06-02 23:09:15.565847	0
88d41d73-93da-4701-aea5-bb2fb9e6922a	94173204900002948	stress-41732049-2948@mediqueue.test	Paciente Stress 41732049-2948	55002948	ACTIVO	2026-06-02 23:09:20.871822	2026-06-02 23:09:20.871822	0
a406c691-f74f-456d-a6ab-50b87e354b5f	94173205000003017	stress-41732050-3017@mediqueue.test	Paciente Stress 41732050-3017	55003017	ACTIVO	2026-06-02 23:09:21.663983	2026-06-02 23:09:21.663983	0
b1ac003a-97f1-4625-846b-2f47126ce51a	94173204700003052	stress-41732047-3052@mediqueue.test	Paciente Stress 41732047-3052	55003052	ACTIVO	2026-06-02 23:09:22.235978	2026-06-02 23:09:22.235978	0
694b97fe-3d72-4ccf-8480-6dd56e7fbed4	94173198500003110	stress-41731985-3110@mediqueue.test	Paciente Stress 41731985-3110	55003110	ACTIVO	2026-06-02 23:09:22.594377	2026-06-02 23:09:22.594377	0
0db6ad06-3909-41ad-887c-c0d1d9394d62	94173206700003217	stress-41732067-3217@mediqueue.test	Paciente Stress 41732067-3217	55003217	ACTIVO	2026-06-02 23:09:23.554705	2026-06-02 23:09:23.554705	0
f6ad8ff1-30e1-48c0-9ea1-4f879450ff61	94173205600003411	stress-41732056-3411@mediqueue.test	Paciente Stress 41732056-3411	55003411	ACTIVO	2026-06-02 23:09:25.320578	2026-06-02 23:09:25.320578	0
16589621-6320-46c9-aad5-6641203ee9de	94173203300003440	stress-41732033-3440@mediqueue.test	Paciente Stress 41732033-3440	55003440	ACTIVO	2026-06-02 23:09:25.744037	2026-06-02 23:09:25.744037	0
fbe3f353-85b1-43dd-93f9-b1a356198ac6	94173206800003527	stress-41732068-3527@mediqueue.test	Paciente Stress 41732068-3527	55003527	ACTIVO	2026-06-02 23:09:26.309981	2026-06-02 23:09:26.309981	0
ca4332c6-89d6-4d37-8224-51780cbd7ebe	94173202000003612	stress-41732020-3612@mediqueue.test	Paciente Stress 41732020-3612	55003612	ACTIVO	2026-06-02 23:09:27.105726	2026-06-02 23:09:27.105726	0
3555406d-5034-4cf0-bbb0-50a294e2d02b	94173206200003648	stress-41732062-3648@mediqueue.test	Paciente Stress 41732062-3648	55003648	ACTIVO	2026-06-02 23:09:27.21003	2026-06-02 23:09:27.21003	0
002477fe-da13-4f94-8389-6777ef09f497	94173204400003910	stress-41732044-3910@mediqueue.test	Paciente Stress 41732044-3910	55003910	ACTIVO	2026-06-02 23:09:29.927554	2026-06-02 23:09:29.927554	0
d39fc9f2-c99f-4f27-8dcc-ce5171be0e02	94173203200004009	stress-41732032-4009@mediqueue.test	Paciente Stress 41732032-4009	55004009	ACTIVO	2026-06-02 23:09:30.924031	2026-06-02 23:09:30.924031	0
ef94c840-188d-4bf6-bf0d-60483ccf3134	94173206900004345	stress-41732069-4345@mediqueue.test	Paciente Stress 41732069-4345	55004345	ACTIVO	2026-06-02 23:09:34.115276	2026-06-02 23:09:34.115276	0
507abc09-2541-435e-82f6-a0bf44f17e3a	94173203900004372	stress-41732039-4372@mediqueue.test	Paciente Stress 41732039-4372	55004372	ACTIVO	2026-06-02 23:09:34.566917	2026-06-02 23:09:34.566917	0
87a76616-5aff-489e-9be8-7764fa0bf645	94173200700004450	stress-41732007-4450@mediqueue.test	Paciente Stress 41732007-4450	55004450	ACTIVO	2026-06-02 23:09:34.894489	2026-06-02 23:09:34.894489	0
b31e6928-9bbf-4bf6-ae41-e0efcff5d6a7	94173200800004568	stress-41732008-4568@mediqueue.test	Paciente Stress 41732008-4568	55004568	ACTIVO	2026-06-02 23:09:35.969512	2026-06-02 23:09:35.969512	0
e6804019-379e-4968-9171-718e8bbba4eb	94173204500004604	stress-41732045-4604@mediqueue.test	Paciente Stress 41732045-4604	55004604	ACTIVO	2026-06-02 23:09:36.258412	2026-06-02 23:09:36.258412	0
9aa005de-6a42-4cf9-ba18-b84ae70f7d78	94173203500004861	stress-41732035-4861@mediqueue.test	Paciente Stress 41732035-4861	55004861	ACTIVO	2026-06-02 23:09:38.573418	2026-06-02 23:09:38.573418	0
6e8a1ab7-17c7-4d16-9321-2f9bee739f26	94173203900004926	stress-41732039-4926@mediqueue.test	Paciente Stress 41732039-4926	55004926	ACTIVO	2026-06-02 23:09:39.245694	2026-06-02 23:09:39.245694	0
2c74becd-9fca-4d80-8f97-9005cbba6543	94173203100004955	stress-41732031-4955@mediqueue.test	Paciente Stress 41732031-4955	55004955	ACTIVO	2026-06-02 23:09:39.585165	2026-06-02 23:09:39.585165	0
2e079ac3-7238-45ec-937b-3862a4bbae47	94173204500005359	stress-41732045-5359@mediqueue.test	Paciente Stress 41732045-5359	55005359	ACTIVO	2026-06-02 23:09:44.553434	2026-06-02 23:09:44.553434	0
f021c4e8-2281-42d1-b9a3-87598bbcae15	94173197800005571	stress-41731978-5571@mediqueue.test	Paciente Stress 41731978-5571	55005571	ACTIVO	2026-06-02 23:09:46.541986	2026-06-02 23:09:46.541986	0
e2e3d79a-a452-4a62-af96-21d649005d89	94173199300005774	stress-41731993-5774@mediqueue.test	Paciente Stress 41731993-5774	55005774	ACTIVO	2026-06-02 23:09:48.412904	2026-06-02 23:09:48.412904	0
1b3a8b89-1090-4784-a8fd-f6466fdc06e9	94173205200005798	stress-41732052-5798@mediqueue.test	Paciente Stress 41732052-5798	55005798	ACTIVO	2026-06-02 23:09:48.590521	2026-06-02 23:09:48.590521	0
8ce813f1-fbe7-4cdc-a5cd-e35e44c105c0	94173203400006009	stress-41732034-6009@mediqueue.test	Paciente Stress 41732034-6009	55006009	ACTIVO	2026-06-02 23:09:51.089486	2026-06-02 23:09:51.089486	0
2936f44d-c061-4822-acbb-085a9660e5b8	94173197800006179	stress-41731978-6179@mediqueue.test	Paciente Stress 41731978-6179	55006179	ACTIVO	2026-06-02 23:10:00.153798	2026-06-02 23:10:00.153798	0
c0ce814b-5e4f-436b-a8e7-1a8760b7d7a3	94173197600006227	stress-41731976-6227@mediqueue.test	Paciente Stress 41731976-6227	55006227	ACTIVO	2026-06-02 23:10:00.274972	2026-06-02 23:10:00.274972	0
14a51ab6-f13f-4a77-965c-65d347bb3d14	94173198600006259	stress-41731986-6259@mediqueue.test	Paciente Stress 41731986-6259	55006259	ACTIVO	2026-06-02 23:10:00.408153	2026-06-02 23:10:00.408153	0
bce6e90e-43f4-4a53-bdae-a03a77617bbe	94173202300006326	stress-41732023-6326@mediqueue.test	Paciente Stress 41732023-6326	55006326	ACTIVO	2026-06-02 23:10:00.987695	2026-06-02 23:10:00.987695	0
51d0ba25-23a6-48ca-82f6-102ff0b8e60f	94173205300006631	stress-41732053-6631@mediqueue.test	Paciente Stress 41732053-6631	55006631	ACTIVO	2026-06-02 23:10:04.042608	2026-06-02 23:10:04.042608	0
c53ea4e1-a7dd-4fdf-9c8a-7276fcf74ff6	94173206800006680	stress-41732068-6680@mediqueue.test	Paciente Stress 41732068-6680	55006680	ACTIVO	2026-06-02 23:10:04.434766	2026-06-02 23:10:04.434766	0
10ad37ab-1dd9-4e0c-a2f7-09421672cf0f	94173204900007046	stress-41732049-7046@mediqueue.test	Paciente Stress 41732049-7046	55007046	ACTIVO	2026-06-02 23:10:08.667544	2026-06-02 23:10:08.667544	0
0ba84112-d99f-4749-bc91-7ea49860cd6e	94173206000007118	stress-41732060-7118@mediqueue.test	Paciente Stress 41732060-7118	55007118	ACTIVO	2026-06-02 23:10:08.940605	2026-06-02 23:10:08.940605	0
6372f082-bd28-41a8-b0a2-1b55bf223dc3	94173204700007235	stress-41732047-7235@mediqueue.test	Paciente Stress 41732047-7235	55007235	ACTIVO	2026-06-02 23:10:10.32658	2026-06-02 23:10:10.32658	0
15d029ee-a848-49df-88ac-dbe3497d5b3c	94173200800007350	stress-41732008-7350@mediqueue.test	Paciente Stress 41732008-7350	55007350	ACTIVO	2026-06-02 23:10:11.555484	2026-06-02 23:10:11.555484	0
dc1efbb1-7458-4448-8058-14ac94395b28	94173203600007388	stress-41732036-7388@mediqueue.test	Paciente Stress 41732036-7388	55007388	ACTIVO	2026-06-02 23:10:11.863118	2026-06-02 23:10:11.863118	0
6214ef02-21cf-4cf9-ae53-b641a58af060	94173203800007830	stress-41732038-7830@mediqueue.test	Paciente Stress 41732038-7830	55007830	ACTIVO	2026-06-02 23:10:15.950389	2026-06-02 23:10:15.950389	0
4ce74e85-41cd-4405-a848-32e960d5671b	94173202700007880	stress-41732027-7880@mediqueue.test	Paciente Stress 41732027-7880	55007880	ACTIVO	2026-06-02 23:10:30.929335	2026-06-02 23:10:30.929335	0
0942eff7-0e1c-4109-9574-4c062592f8ba	94173204000007920	stress-41732040-7920@mediqueue.test	Paciente Stress 41732040-7920	55007920	ACTIVO	2026-06-02 23:10:31.160416	2026-06-02 23:10:31.160416	0
0cf0b9cc-4db7-4942-8462-8941b9b4fb8e	94173203800008046	stress-41732038-8046@mediqueue.test	Paciente Stress 41732038-8046	55008046	ACTIVO	2026-06-02 23:10:32.542542	2026-06-02 23:10:32.542542	0
e77b5f68-2ef5-4f22-9e1f-d3fdb38f49ba	94173200500008230	stress-41732005-8230@mediqueue.test	Paciente Stress 41732005-8230	55008230	ACTIVO	2026-06-02 23:10:40.779715	2026-06-02 23:10:40.779715	0
ebb89dd2-b7a2-4fa1-b70a-a57c132f164b	94173202300008300	stress-41732023-8300@mediqueue.test	Paciente Stress 41732023-8300	55008300	ACTIVO	2026-06-02 23:10:41.322225	2026-06-02 23:10:41.322225	0
e9eea3bf-4baa-40da-9635-9775154f9bcd	94173200800008510	stress-41732008-8510@mediqueue.test	Paciente Stress 41732008-8510	55008510	ACTIVO	2026-06-02 23:10:42.869241	2026-06-02 23:10:42.869241	0
9052c6c3-f9c0-4e50-9776-25ac4e273c88	94173200800008741	stress-41732008-8741@mediqueue.test	Paciente Stress 41732008-8741	55008741	ACTIVO	2026-06-02 23:10:45.273	2026-06-02 23:10:45.273	0
6eae20e9-7383-4dcc-a6ea-b4d45c679cd9	94173203400008798	stress-41732034-8798@mediqueue.test	Paciente Stress 41732034-8798	55008798	ACTIVO	2026-06-02 23:10:45.736936	2026-06-02 23:10:45.736936	0
6d455aaa-ac54-4eff-8c2a-e1cb5c2a8417	94173201400008814	stress-41732014-8814@mediqueue.test	Paciente Stress 41732014-8814	55008814	ACTIVO	2026-06-02 23:10:45.896807	2026-06-02 23:10:45.896807	0
bc3db4d6-7b47-4abd-9a22-1a51177f3c75	94173197900002527	stress-41731979-2527@mediqueue.test	Paciente Stress 41731979-2527	55002527	ACTIVO	2026-06-02 23:09:16.037565	2026-06-02 23:09:16.037565	0
f79d86e5-5a95-4629-9767-7b358ba44ff4	94173199100002810	stress-41731991-2810@mediqueue.test	Paciente Stress 41731991-2810	55002810	ACTIVO	2026-06-02 23:09:19.204256	2026-06-02 23:09:19.204256	0
7bdc73d5-6dc3-4e29-9c06-e29d68afaf05	94173204100002812	stress-41732041-2812@mediqueue.test	Paciente Stress 41732041-2812	55002812	ACTIVO	2026-06-02 23:09:19.334108	2026-06-02 23:09:19.334108	0
792bd19c-4a2d-4ef6-ba41-955d7c6a61ee	94173204400002884	stress-41732044-2884@mediqueue.test	Paciente Stress 41732044-2884	55002884	ACTIVO	2026-06-02 23:09:20.015385	2026-06-02 23:09:20.015385	0
465a4237-ae5c-4789-a16a-9d970869ca04	94173205200002910	stress-41732052-2910@mediqueue.test	Paciente Stress 41732052-2910	55002910	ACTIVO	2026-06-02 23:09:20.252012	2026-06-02 23:09:20.252012	0
484cf9fb-0f00-4273-95fa-82e941a54cca	94173203700003139	stress-41732037-3139@mediqueue.test	Paciente Stress 41732037-3139	55003139	ACTIVO	2026-06-02 23:09:22.858689	2026-06-02 23:09:22.858689	0
259f5b1a-a72d-4538-b715-1b2dfec25774	94173200700003590	stress-41732007-3590@mediqueue.test	Paciente Stress 41732007-3590	55003590	ACTIVO	2026-06-02 23:09:26.821308	2026-06-02 23:09:26.821308	0
b7409a0b-2d8e-4b0d-8b9c-eb44d73ebd5d	94173205200003607	stress-41732052-3607@mediqueue.test	Paciente Stress 41732052-3607	55003607	ACTIVO	2026-06-02 23:09:27.018455	2026-06-02 23:09:27.018455	0
35f7e3d6-8031-48a1-823b-2d66b3a8e839	94173204700003915	stress-41732047-3915@mediqueue.test	Paciente Stress 41732047-3915	55003915	ACTIVO	2026-06-02 23:09:29.92253	2026-06-02 23:09:29.92253	0
13058a02-644a-41c7-be00-98e8d87771cb	94173204700003944	stress-41732047-3944@mediqueue.test	Paciente Stress 41732047-3944	55003944	ACTIVO	2026-06-02 23:09:30.171583	2026-06-02 23:09:30.171583	0
b7fc710b-2427-436e-a01b-582e469cbfd9	94173201300004071	stress-41732013-4071@mediqueue.test	Paciente Stress 41732013-4071	55004071	ACTIVO	2026-06-02 23:09:31.676828	2026-06-02 23:09:31.676828	0
c4b2a8e0-a693-481c-a4d0-9baa66659639	94173198500004552	stress-41731985-4552@mediqueue.test	Paciente Stress 41731985-4552	55004552	ACTIVO	2026-06-02 23:09:35.831355	2026-06-02 23:09:35.831355	0
58d16234-9e5d-43f4-8b06-8a310456b3be	94173200700004863	stress-41732007-4863@mediqueue.test	Paciente Stress 41732007-4863	55004863	ACTIVO	2026-06-02 23:09:38.736665	2026-06-02 23:09:38.736665	0
c2a577a6-0aa1-402c-8e23-fe4f89ff4e98	94173197600005006	stress-41731976-5006@mediqueue.test	Paciente Stress 41731976-5006	55005006	ACTIVO	2026-06-02 23:09:40.049077	2026-06-02 23:09:40.049077	0
3461cd49-a13f-4f7c-9a9d-89987b362c13	94173207000005105	stress-41732070-5105@mediqueue.test	Paciente Stress 41732070-5105	55005105	ACTIVO	2026-06-02 23:09:40.918731	2026-06-02 23:09:40.918731	0
490eb936-21a5-4c5c-bc7c-7723bc482b5e	94173203600005299	stress-41732036-5299@mediqueue.test	Paciente Stress 41732036-5299	55005299	ACTIVO	2026-06-02 23:09:43.342017	2026-06-02 23:09:43.342017	0
dfadb248-a66e-45b6-aaa0-280db11b5b74	94173201400005771	stress-41732014-5771@mediqueue.test	Paciente Stress 41732014-5771	55005771	ACTIVO	2026-06-02 23:09:48.451647	2026-06-02 23:09:48.451647	0
bda7bfff-fde8-40e2-a1eb-1e07de8ad1fc	94173198700005947	stress-41731987-5947@mediqueue.test	Paciente Stress 41731987-5947	55005947	ACTIVO	2026-06-02 23:09:50.484722	2026-06-02 23:09:50.484722	0
e7bc3133-475c-4baf-8496-83aa42dd5306	94173204800006022	stress-41732048-6022@mediqueue.test	Paciente Stress 41732048-6022	55006022	ACTIVO	2026-06-02 23:09:51.110788	2026-06-02 23:09:51.110788	0
95bd58df-1da7-4826-b7c7-f3982f4fe894	94173204800006119	stress-41732048-6119@mediqueue.test	Paciente Stress 41732048-6119	55006119	ACTIVO	2026-06-02 23:09:52.26692	2026-06-02 23:09:52.26692	0
5dd5b87b-6b63-4753-b919-d5a62739ac3c	94173204000006271	stress-41732040-6271@mediqueue.test	Paciente Stress 41732040-6271	55006271	ACTIVO	2026-06-02 23:10:00.445971	2026-06-02 23:10:00.445971	0
0eeff7ef-721b-44a1-8d95-b834e4c22047	94173203900006372	stress-41732039-6372@mediqueue.test	Paciente Stress 41732039-6372	55006372	ACTIVO	2026-06-02 23:10:01.352076	2026-06-02 23:10:01.352076	0
6f464654-c76c-4528-8b98-f435aaa616e6	94173205600006832	stress-41732056-6832@mediqueue.test	Paciente Stress 41732056-6832	55006832	ACTIVO	2026-06-02 23:10:05.921474	2026-06-02 23:10:05.921474	0
b50348c8-8251-4bf2-8d19-b64bba9686bb	94173203000007238	stress-41732030-7238@mediqueue.test	Paciente Stress 41732030-7238	55007238	ACTIVO	2026-06-02 23:10:10.306435	2026-06-02 23:10:10.306435	0
607e70cd-6e09-4487-bed6-74d98494e9ee	94173204200007331	stress-41732042-7331@mediqueue.test	Paciente Stress 41732042-7331	55007331	ACTIVO	2026-06-02 23:10:11.202442	2026-06-02 23:10:11.202442	0
7b71e8e6-4a57-46d9-be7f-7b71a89f3c52	94173198500007448	stress-41731985-7448@mediqueue.test	Paciente Stress 41731985-7448	55007448	ACTIVO	2026-06-02 23:10:12.159712	2026-06-02 23:10:12.159712	0
59eee0c0-ec71-4d60-994c-2000d5ec6ac0	94173204100007535	stress-41732041-7535@mediqueue.test	Paciente Stress 41732041-7535	55007535	ACTIVO	2026-06-02 23:10:13.169194	2026-06-02 23:10:13.169194	0
5e4a0cc4-9019-40be-a403-922161f64321	94173198600007636	stress-41731986-7636@mediqueue.test	Paciente Stress 41731986-7636	55007636	ACTIVO	2026-06-02 23:10:13.86745	2026-06-02 23:10:13.86745	0
ff3723f6-d6fc-46a6-8617-654aea90c835	94173202600007697	stress-41732026-7697@mediqueue.test	Paciente Stress 41732026-7697	55007697	ACTIVO	2026-06-02 23:10:14.688977	2026-06-02 23:10:14.688977	0
bb89b317-1dba-44f2-b712-d0659e7e0f48	94173198500007715	stress-41731985-7715@mediqueue.test	Paciente Stress 41731985-7715	55007715	ACTIVO	2026-06-02 23:10:14.823117	2026-06-02 23:10:14.823117	0
b77c9008-19a7-4de3-b4ef-649196baf496	94173198600007735	stress-41731986-7735@mediqueue.test	Paciente Stress 41731986-7735	55007735	ACTIVO	2026-06-02 23:10:14.972577	2026-06-02 23:10:14.972577	0
df197f1a-c522-4cb7-bc29-a33d9467caab	94173206000007972	stress-41732060-7972@mediqueue.test	Paciente Stress 41732060-7972	55007972	ACTIVO	2026-06-02 23:10:31.650698	2026-06-02 23:10:31.650698	0
31965b0f-a6f1-4c5f-8aac-81ab4500844b	94173204500008443	stress-41732045-8443@mediqueue.test	Paciente Stress 41732045-8443	55008443	ACTIVO	2026-06-02 23:10:42.330877	2026-06-02 23:10:42.330877	0
6416f9d5-9682-4a2d-8be6-cd27b1852564	94173197700008485	stress-41731977-8485@mediqueue.test	Paciente Stress 41731977-8485	55008485	ACTIVO	2026-06-02 23:10:42.586246	2026-06-02 23:10:42.586246	0
d31821d3-5b18-4f84-a742-f8227921e162	94173202300008635	stress-41732023-8635@mediqueue.test	Paciente Stress 41732023-8635	55008635	ACTIVO	2026-06-02 23:10:44.364583	2026-06-02 23:10:44.364583	0
5892a12b-2c71-4a40-af11-6e724b1d9647	94173200500008678	stress-41732005-8678@mediqueue.test	Paciente Stress 41732005-8678	55008678	ACTIVO	2026-06-02 23:10:44.73436	2026-06-02 23:10:44.73436	0
7fdded4c-0835-4ff0-9948-7292ec3e130b	94173206100008800	stress-41732061-8800@mediqueue.test	Paciente Stress 41732061-8800	55008800	ACTIVO	2026-06-02 23:10:45.774891	2026-06-02 23:10:45.774891	0
70ffa4f1-07fe-431f-b594-b53f390d48b4	94173203600008821	stress-41732036-8821@mediqueue.test	Paciente Stress 41732036-8821	55008821	ACTIVO	2026-06-02 23:10:45.928067	2026-06-02 23:10:45.928067	0
d0fc7d9a-15b2-4c79-ae7b-43dd1474ffcc	94173203600009219	stress-41732036-9219@mediqueue.test	Paciente Stress 41732036-9219	55009219	ACTIVO	2026-06-02 23:10:49.630887	2026-06-02 23:10:49.630887	0
f45633a8-61c0-46cf-912d-b48751a00a56	94173201900009355	stress-41732019-9355@mediqueue.test	Paciente Stress 41732019-9355	55009355	ACTIVO	2026-06-02 23:10:52.704549	2026-06-02 23:10:52.704549	0
3aca0eaf-c91b-462a-bd6a-2d78b2f1283a	94173197700009383	stress-41731977-9383@mediqueue.test	Paciente Stress 41731977-9383	55009383	ACTIVO	2026-06-02 23:10:52.792971	2026-06-02 23:10:52.792971	0
8d5463c5-a5de-46a5-b7a9-cc7035e3055c	94173203100009598	stress-41732031-9598@mediqueue.test	Paciente Stress 41732031-9598	55009598	ACTIVO	2026-06-02 23:10:55.403557	2026-06-02 23:10:55.403557	0
afd9605f-c61f-416f-83a8-dabd36eb0b26	94173201800009724	stress-41732018-9724@mediqueue.test	Paciente Stress 41732018-9724	55009724	ACTIVO	2026-06-02 23:10:56.153431	2026-06-02 23:10:56.153431	0
e770c615-3640-4980-857d-6db8e41ad832	94173200400009797	stress-41732004-9797@mediqueue.test	Paciente Stress 41732004-9797	55009797	ACTIVO	2026-06-02 23:10:56.590895	2026-06-02 23:10:56.590895	0
87415054-7653-4301-97e7-1ce62ca0950b	94173199200010146	stress-41731992-10146@mediqueue.test	Paciente Stress 41731992-10146	55010146	ACTIVO	2026-06-02 23:11:50.314669	2026-06-02 23:11:50.314669	0
ea5406a7-b770-49eb-933f-15b59c206b6b	94173203000010105	stress-41732030-10105@mediqueue.test	Paciente Stress 41732030-10105	55010105	ACTIVO	2026-06-02 23:11:50.391566	2026-06-02 23:11:50.391566	0
167e6278-0c52-4d1c-a94f-b6b58b13181e	94173206000010199	stress-41732060-10199@mediqueue.test	Paciente Stress 41732060-10199	55010199	ACTIVO	2026-06-02 23:11:50.451479	2026-06-02 23:11:50.451479	0
c12fc1d3-6581-4145-8a56-d7dfe4a79a94	94173204100002686	stress-41732041-2686@mediqueue.test	Paciente Stress 41732041-2686	55002686	ACTIVO	2026-06-02 23:09:17.756416	2026-06-02 23:09:17.756416	0
c42c410b-4397-4fac-977e-04e2ad727641	94173200500002701	stress-41732005-2701@mediqueue.test	Paciente Stress 41732005-2701	55002701	ACTIVO	2026-06-02 23:09:18.049131	2026-06-02 23:09:18.049131	0
43955263-6d7c-47be-9951-37037ff7f19a	94173200800002721	stress-41732008-2721@mediqueue.test	Paciente Stress 41732008-2721	55002721	ACTIVO	2026-06-02 23:09:18.471929	2026-06-02 23:09:18.471929	0
1c5ec426-51c0-494f-be42-6e5c53b76852	94173206700004010	stress-41732067-4010@mediqueue.test	Paciente Stress 41732067-4010	55004010	ACTIVO	2026-06-02 23:09:30.875618	2026-06-02 23:09:30.875618	0
30a73633-a00b-42bc-bc84-3cea6a19b616	94173203400004170	stress-41732034-4170@mediqueue.test	Paciente Stress 41732034-4170	55004170	ACTIVO	2026-06-02 23:09:32.222938	2026-06-02 23:09:32.222938	0
0cb3af2a-245c-4c8b-aca6-81bc3538506f	94173204100004359	stress-41732041-4359@mediqueue.test	Paciente Stress 41732041-4359	55004359	ACTIVO	2026-06-02 23:09:34.32492	2026-06-02 23:09:34.32492	0
97efe9e6-1b69-4a10-9e9b-d626b9166c2e	94173203400004384	stress-41732034-4384@mediqueue.test	Paciente Stress 41732034-4384	55004384	ACTIVO	2026-06-02 23:09:34.605202	2026-06-02 23:09:34.605202	0
cbb14c00-995b-4c9f-8b9d-6c873cc88898	94173201100004650	stress-41732011-4650@mediqueue.test	Paciente Stress 41732011-4650	55004650	ACTIVO	2026-06-02 23:09:36.722157	2026-06-02 23:09:36.722157	0
5e6847d7-89c1-477c-ba88-f6e6fb8cda17	94173202300005015	stress-41732023-5015@mediqueue.test	Paciente Stress 41732023-5015	55005015	ACTIVO	2026-06-02 23:09:40.07162	2026-06-02 23:09:40.07162	0
591a7790-32ad-4f5b-b420-c29be00c2410	94173206900005195	stress-41732069-5195@mediqueue.test	Paciente Stress 41732069-5195	55005195	ACTIVO	2026-06-02 23:09:42.118377	2026-06-02 23:09:42.118377	0
9831eea3-9230-4e6a-9c11-3af678e0e0b6	94173205600005272	stress-41732056-5272@mediqueue.test	Paciente Stress 41732056-5272	55005272	ACTIVO	2026-06-02 23:09:42.989076	2026-06-02 23:09:42.989076	0
d98da4bc-c3d0-46cf-8937-379a3f9129a5	94173204900005507	stress-41732049-5507@mediqueue.test	Paciente Stress 41732049-5507	55005507	ACTIVO	2026-06-02 23:09:46.066722	2026-06-02 23:09:46.066722	0
59cf4e9e-271c-4c6b-ae3d-f517c548ec73	94173203400005784	stress-41732034-5784@mediqueue.test	Paciente Stress 41732034-5784	55005784	ACTIVO	2026-06-02 23:09:48.527048	2026-06-02 23:09:48.527048	0
344c3329-6082-4eb5-9f78-fe119b696c5b	94173201400005806	stress-41732014-5806@mediqueue.test	Paciente Stress 41732014-5806	55005806	ACTIVO	2026-06-02 23:09:48.728845	2026-06-02 23:09:48.728845	0
82d964e6-2159-49f2-aeb7-42bb42e38e09	94173205800005818	stress-41732058-5818@mediqueue.test	Paciente Stress 41732058-5818	55005818	ACTIVO	2026-06-02 23:09:48.915495	2026-06-02 23:09:48.915495	0
48b66a02-2c0f-4c33-958a-5dde3733a75b	94173200800006204	stress-41732008-6204@mediqueue.test	Paciente Stress 41732008-6204	55006204	ACTIVO	2026-06-02 23:10:00.180107	2026-06-02 23:10:00.180107	0
5530bda9-0f80-4d97-9348-1ac06ce3ebe5	94173206800006808	stress-41732068-6808@mediqueue.test	Paciente Stress 41732068-6808	55006808	ACTIVO	2026-06-02 23:10:05.677298	2026-06-02 23:10:05.677298	0
7dd74db7-28d3-40e9-aebf-8db4e6a86944	94173206200007086	stress-41732062-7086@mediqueue.test	Paciente Stress 41732062-7086	55007086	ACTIVO	2026-06-02 23:10:08.667532	2026-06-02 23:10:08.667532	0
e41e5a0c-90f0-4d89-9422-08c23af2eb4e	94173198600007252	stress-41731986-7252@mediqueue.test	Paciente Stress 41731986-7252	55007252	ACTIVO	2026-06-02 23:10:10.401728	2026-06-02 23:10:10.401728	0
8363cdc2-0cc9-4677-a97a-221a9e6dfd29	94173205100007747	stress-41732051-7747@mediqueue.test	Paciente Stress 41732051-7747	55007747	ACTIVO	2026-06-02 23:10:15.182555	2026-06-02 23:10:15.182555	0
ebecdf7f-3f52-46a0-965f-01248946d1cf	94173198600007835	stress-41731986-7835@mediqueue.test	Paciente Stress 41731986-7835	55007835	ACTIVO	2026-06-02 23:10:16.096776	2026-06-02 23:10:16.096776	0
f90e145a-8ef1-4762-9222-edc7769c1cb4	94173204800007859	stress-41732048-7859@mediqueue.test	Paciente Stress 41732048-7859	55007859	ACTIVO	2026-06-02 23:10:30.890358	2026-06-02 23:10:30.890358	0
a871453d-65b7-4d2a-8d7b-847ae9ae0521	94173203900008189	stress-41732039-8189@mediqueue.test	Paciente Stress 41732039-8189	55008189	ACTIVO	2026-06-02 23:10:40.430423	2026-06-02 23:10:40.430423	0
8de7df88-e689-4de5-ac13-469d8a5ce9a0	94173205700008253	stress-41732057-8253@mediqueue.test	Paciente Stress 41732057-8253	55008253	ACTIVO	2026-06-02 23:10:40.967279	2026-06-02 23:10:40.967279	0
7b3d4713-f670-484e-94ce-019a322a6bdb	94173203100008352	stress-41732031-8352@mediqueue.test	Paciente Stress 41732031-8352	55008352	ACTIVO	2026-06-02 23:10:41.711413	2026-06-02 23:10:41.711413	0
b57c9b6b-1bb7-4eca-944e-bfe74bed2721	94173199100008374	stress-41731991-8374@mediqueue.test	Paciente Stress 41731991-8374	55008374	ACTIVO	2026-06-02 23:10:41.925745	2026-06-02 23:10:41.925745	0
f8fcf88c-6b29-4dc2-b56c-e79c8c98616f	94173202700008675	stress-41732027-8675@mediqueue.test	Paciente Stress 41732027-8675	55008675	ACTIVO	2026-06-02 23:10:44.792277	2026-06-02 23:10:44.792277	0
efd90bab-8257-43e0-a7c5-62059ca5f8b9	94173199100008774	stress-41731991-8774@mediqueue.test	Paciente Stress 41731991-8774	55008774	ACTIVO	2026-06-02 23:10:45.73526	2026-06-02 23:10:45.73526	0
e89f6545-06c8-4a9b-81fa-d22ff9ce7386	94173199100008902	stress-41731991-8902@mediqueue.test	Paciente Stress 41731991-8902	55008902	ACTIVO	2026-06-02 23:10:46.596314	2026-06-02 23:10:46.596314	0
24e45f9d-072c-4fca-bb3a-e38c54219469	94173206200009759	stress-41732062-9759@mediqueue.test	Paciente Stress 41732062-9759	55009759	ACTIVO	2026-06-02 23:10:56.673493	2026-06-02 23:10:56.673493	0
1d797c2d-577b-437a-b4ca-cfa6472502ae	94173203900009788	stress-41732039-9788@mediqueue.test	Paciente Stress 41732039-9788	55009788	ACTIVO	2026-06-02 23:10:56.740761	2026-06-02 23:10:56.740761	0
85dfdf66-c799-4868-9ebc-7c250d2bd080	94173203900009908	stress-41732039-9908@mediqueue.test	Paciente Stress 41732039-9908	55009908	ACTIVO	2026-06-02 23:10:57.268354	2026-06-02 23:10:57.268354	0
0a6f4997-cd1f-49e0-b31a-ead9033625e2	94173206800009957	stress-41732068-9957@mediqueue.test	Paciente Stress 41732068-9957	55009957	ACTIVO	2026-06-02 23:10:57.71697	2026-06-02 23:10:57.71697	0
434b7a75-f085-4fa3-add6-d2d89569679b	94173202500010001	stress-41732025-10001@mediqueue.test	Paciente Stress 41732025-10001	55010001	ACTIVO	2026-06-02 23:11:47.7942	2026-06-02 23:11:47.7942	0
75a1997a-a589-4893-afc3-47af74c6f10a	94173202200009988	stress-41732022-9988@mediqueue.test	Paciente Stress 41732022-9988	55009988	ACTIVO	2026-06-02 23:11:47.80767	2026-06-02 23:11:47.80767	0
d8186a54-0fdd-4de7-9cc8-4dd0ffe34e43	94173200400010055	stress-41732004-10055@mediqueue.test	Paciente Stress 41732004-10055	55010055	ACTIVO	2026-06-02 23:11:47.977247	2026-06-02 23:11:47.977247	0
4ea1219f-d7ff-4450-843c-8d9e22fa825c	94173202300010074	stress-41732023-10074@mediqueue.test	Paciente Stress 41732023-10074	55010074	ACTIVO	2026-06-02 23:11:48.316088	2026-06-02 23:11:48.316088	0
647669c5-e531-48f6-be7b-74731f3f25b1	94173200700010186	stress-41732007-10186@mediqueue.test	Paciente Stress 41732007-10186	55010186	ACTIVO	2026-06-02 23:11:49.500389	2026-06-02 23:11:49.500389	0
1ac75661-8531-44ed-bae4-ef9d614b8be2	94173205700010211	stress-41732057-10211@mediqueue.test	Paciente Stress 41732057-10211	55010211	ACTIVO	2026-06-02 23:11:50.771363	2026-06-02 23:11:50.771363	0
095e6e17-8c8b-4323-8e9f-6de6fc53a35e	94173202600010291	stress-41732026-10291@mediqueue.test	Paciente Stress 41732026-10291	55010291	ACTIVO	2026-06-02 23:11:50.955315	2026-06-02 23:11:50.955315	0
f6b9eb97-38ea-4273-8179-3975cf470eee	94173200500010380	stress-41732005-10380@mediqueue.test	Paciente Stress 41732005-10380	55010380	ACTIVO	2026-06-02 23:11:51.033391	2026-06-02 23:11:51.033391	0
5608a13c-997b-4f7b-b70a-b43274ec2cfa	94173202900010438	stress-41732029-10438@mediqueue.test	Paciente Stress 41732029-10438	55010438	ACTIVO	2026-06-02 23:11:51.05289	2026-06-02 23:11:51.05289	0
c8cd501d-c73f-47f5-982b-ee543fd0b41c	94173203600010445	stress-41732036-10445@mediqueue.test	Paciente Stress 41732036-10445	55010445	ACTIVO	2026-06-02 23:11:51.111051	2026-06-02 23:11:51.111051	0
f03c5221-67e8-4069-bf2f-d90d346619db	94173197600010479	stress-41731976-10479@mediqueue.test	Paciente Stress 41731976-10479	55010479	ACTIVO	2026-06-02 23:11:51.11209	2026-06-02 23:11:51.11209	0
a758b5d1-ecd1-4556-88ed-40b5f212eabe	94173205100010458	stress-41732051-10458@mediqueue.test	Paciente Stress 41732051-10458	55010458	ACTIVO	2026-06-02 23:11:51.137445	2026-06-02 23:11:51.137445	0
22918dee-6ee4-4a6f-8750-35ecf3db1968	94173201400010416	stress-41732014-10416@mediqueue.test	Paciente Stress 41732014-10416	55010416	ACTIVO	2026-06-02 23:11:51.185026	2026-06-02 23:11:51.185026	0
25238c26-e6fd-486d-8c9b-c947fc141a37	94173200700010492	stress-41732007-10492@mediqueue.test	Paciente Stress 41732007-10492	55010492	ACTIVO	2026-06-02 23:11:51.194993	2026-06-02 23:11:51.194993	0
2506fa67-fa6a-4bab-b2cc-d9b2c55ed52d	94173206700002965	stress-41732067-2965@mediqueue.test	Paciente Stress 41732067-2965	55002965	ACTIVO	2026-06-02 23:09:20.938445	2026-06-02 23:09:20.938445	0
9610119d-ed49-48eb-9f61-26ae03717a49	94173199300003045	stress-41731993-3045@mediqueue.test	Paciente Stress 41731993-3045	55003045	ACTIVO	2026-06-02 23:09:22.199651	2026-06-02 23:09:22.199651	0
ffa850a6-c1ad-4a3a-844d-bdbcd737e6f5	94173205100003403	stress-41732051-3403@mediqueue.test	Paciente Stress 41732051-3403	55003403	ACTIVO	2026-06-02 23:09:25.119984	2026-06-02 23:09:25.119984	0
562a4104-0ce7-478a-bc03-68ad86c12b5f	94173206800003483	stress-41732068-3483@mediqueue.test	Paciente Stress 41732068-3483	55003483	ACTIVO	2026-06-02 23:09:25.931356	2026-06-02 23:09:25.931356	0
1023d917-3edd-43ae-8045-0fd132c2f26e	94173200700003504	stress-41732007-3504@mediqueue.test	Paciente Stress 41732007-3504	55003504	ACTIVO	2026-06-02 23:09:26.126494	2026-06-02 23:09:26.126494	0
42438861-d332-41ca-a2c2-8891c783b13e	94173202200004282	stress-41732022-4282@mediqueue.test	Paciente Stress 41732022-4282	55004282	ACTIVO	2026-06-02 23:09:33.566099	2026-06-02 23:09:33.566099	0
725d3af1-0e2a-4372-844c-41320821f3b0	94173201800004642	stress-41732018-4642@mediqueue.test	Paciente Stress 41732018-4642	55004642	ACTIVO	2026-06-02 23:09:36.655456	2026-06-02 23:09:36.655456	0
7ffcfe5c-a2e7-4ac5-b370-c23ebcb9aa1e	94173204800004731	stress-41732048-4731@mediqueue.test	Paciente Stress 41732048-4731	55004731	ACTIVO	2026-06-02 23:09:37.261028	2026-06-02 23:09:37.261028	0
b7fd6287-e91b-4e62-9658-642d128a181b	94173206500004764	stress-41732065-4764@mediqueue.test	Paciente Stress 41732065-4764	55004764	ACTIVO	2026-06-02 23:09:37.557012	2026-06-02 23:09:37.557012	0
1d160e52-dcc1-4bb8-9de8-07e60f4806e6	94173200800004783	stress-41732008-4783@mediqueue.test	Paciente Stress 41732008-4783	55004783	ACTIVO	2026-06-02 23:09:37.681393	2026-06-02 23:09:37.681393	0
d2398a18-23e0-4d35-b7e2-d6362962f819	94173206200004862	stress-41732062-4862@mediqueue.test	Paciente Stress 41732062-4862	55004862	ACTIVO	2026-06-02 23:09:38.558396	2026-06-02 23:09:38.558396	0
eabd76a8-2521-41b5-924d-1508bebe61e0	94173200000005327	stress-41732000-5327@mediqueue.test	Paciente Stress 41732000-5327	55005327	ACTIVO	2026-06-02 23:09:44.26178	2026-06-02 23:09:44.26178	0
5cf8f100-d163-47f4-ac2a-bab4ccb0ef14	94173204600005977	stress-41732046-5977@mediqueue.test	Paciente Stress 41732046-5977	55005977	ACTIVO	2026-06-02 23:09:50.795316	2026-06-02 23:09:50.795316	0
12ef5ff2-c7b8-4a5a-b0dc-3ae775fb261f	94173197700006358	stress-41731977-6358@mediqueue.test	Paciente Stress 41731977-6358	55006358	ACTIVO	2026-06-02 23:10:01.208036	2026-06-02 23:10:01.208036	0
f9b3607c-629f-471e-9859-05a4ae01bc15	94173205800006470	stress-41732058-6470@mediqueue.test	Paciente Stress 41732058-6470	55006470	ACTIVO	2026-06-02 23:10:02.485583	2026-06-02 23:10:02.485583	0
faa3849c-ab60-41f6-a959-814803381dca	94173202700007335	stress-41732027-7335@mediqueue.test	Paciente Stress 41732027-7335	55007335	ACTIVO	2026-06-02 23:10:11.265814	2026-06-02 23:10:11.265814	0
2a873c2c-16e3-4a2f-b9d7-f54d1878484e	94173204100007409	stress-41732041-7409@mediqueue.test	Paciente Stress 41732041-7409	55007409	ACTIVO	2026-06-02 23:10:12.057014	2026-06-02 23:10:12.057014	0
7884e365-aff2-44fe-9283-6432c3e273c4	94173202200008003	stress-41732022-8003@mediqueue.test	Paciente Stress 41732022-8003	55008003	ACTIVO	2026-06-02 23:10:32.278924	2026-06-02 23:10:32.278924	0
99ec2967-ca1b-4e10-b04e-f161c178b6e5	94173199200008060	stress-41731992-8060@mediqueue.test	Paciente Stress 41731992-8060	55008060	ACTIVO	2026-06-02 23:10:32.709772	2026-06-02 23:10:32.709772	0
b1439c7b-de05-41b9-947e-bfaa0e985a72	94173202300008174	stress-41732023-8174@mediqueue.test	Paciente Stress 41732023-8174	55008174	ACTIVO	2026-06-02 23:10:40.372735	2026-06-02 23:10:40.372735	0
1476bc17-2ab9-4e69-a0d6-1e09fded2f76	94173201600009068	stress-41732016-9068@mediqueue.test	Paciente Stress 41732016-9068	55009068	ACTIVO	2026-06-02 23:10:48.270495	2026-06-02 23:10:48.270495	0
bb9b8b1b-cb87-4c44-93fc-2e48b357362a	94173206300009167	stress-41732063-9167@mediqueue.test	Paciente Stress 41732063-9167	55009167	ACTIVO	2026-06-02 23:10:49.306031	2026-06-02 23:10:49.306031	0
8769510f-d157-40b4-aeb8-b79fb09ba40a	94173204100009213	stress-41732041-9213@mediqueue.test	Paciente Stress 41732041-9213	55009213	ACTIVO	2026-06-02 23:10:49.598883	2026-06-02 23:10:49.598883	0
619c2c02-e3a5-46da-bb1c-6a3e4d3e65ee	94173204000009568	stress-41732040-9568@mediqueue.test	Paciente Stress 41732040-9568	55009568	ACTIVO	2026-06-02 23:10:54.617873	2026-06-02 23:10:54.617873	0
cca723d0-4c0f-4353-adfb-5b267603ef94	94173204400009786	stress-41732044-9786@mediqueue.test	Paciente Stress 41732044-9786	55009786	ACTIVO	2026-06-02 23:10:56.615599	2026-06-02 23:10:56.615599	0
87b84fb6-34c7-4838-b763-b7011fef1851	94173202000009823	stress-41732020-9823@mediqueue.test	Paciente Stress 41732020-9823	55009823	ACTIVO	2026-06-02 23:10:56.878509	2026-06-02 23:10:56.878509	0
265658ee-337c-422a-a6e3-2a668f2f66f5	94173198600009882	stress-41731986-9882@mediqueue.test	Paciente Stress 41731986-9882	55009882	ACTIVO	2026-06-02 23:10:57.253016	2026-06-02 23:10:57.253016	0
279b480a-62df-4785-9c8a-80d667747e95	94173203400010327	stress-41732034-10327@mediqueue.test	Paciente Stress 41732034-10327	55010327	ACTIVO	2026-06-02 23:11:50.567167	2026-06-02 23:11:50.567167	0
398e601e-d1b2-4456-95b0-bc6751e2984d	94173200800010369	stress-41732008-10369@mediqueue.test	Paciente Stress 41732008-10369	55010369	ACTIVO	2026-06-02 23:11:50.718091	2026-06-02 23:11:50.718091	0
d389cdc5-af37-410a-925a-efa6bebeefae	94173201600010352	stress-41732016-10352@mediqueue.test	Paciente Stress 41732016-10352	55010352	ACTIVO	2026-06-02 23:11:50.955857	2026-06-02 23:11:50.955857	0
c5ed2e68-b370-40b0-9516-dc46ebc16570	94173199100010275	stress-41731991-10275@mediqueue.test	Paciente Stress 41731991-10275	55010275	ACTIVO	2026-06-02 23:11:51.056236	2026-06-02 23:11:51.056236	0
20319a12-e37f-4ee1-bf60-a01f25b76cf0	94173203300010456	stress-41732033-10456@mediqueue.test	Paciente Stress 41732033-10456	55010456	ACTIVO	2026-06-02 23:11:51.064764	2026-06-02 23:11:51.064764	0
e5e4750e-386f-488a-ae98-58b3e70d55fa	94173204000010483	stress-41732040-10483@mediqueue.test	Paciente Stress 41732040-10483	55010483	ACTIVO	2026-06-02 23:11:51.136139	2026-06-02 23:11:51.136139	0
c5612a44-e5d6-4230-9997-5c24e45c90fd	94173204500010481	stress-41732045-10481@mediqueue.test	Paciente Stress 41732045-10481	55010481	ACTIVO	2026-06-02 23:11:51.14623	2026-06-02 23:11:51.14623	0
400670a1-9cfa-4c82-9194-8c19705f3ea1	94173201200010500	stress-41732012-10500@mediqueue.test	Paciente Stress 41732012-10500	55010500	ACTIVO	2026-06-02 23:11:51.222956	2026-06-02 23:11:51.222956	0
bd8f87bd-318f-4408-9f8d-07c87c84d865	94173206200010507	stress-41732062-10507@mediqueue.test	Paciente Stress 41732062-10507	55010507	ACTIVO	2026-06-02 23:11:51.272523	2026-06-02 23:11:51.272523	0
b69dc3da-e3a7-461c-8caa-0bbfe937eec0	94173203200010518	stress-41732032-10518@mediqueue.test	Paciente Stress 41732032-10518	55010518	ACTIVO	2026-06-02 23:11:51.380035	2026-06-02 23:11:51.380035	0
9d1a223e-be01-446d-ba84-95d73f9829d2	94173200400010523	stress-41732004-10523@mediqueue.test	Paciente Stress 41732004-10523	55010523	ACTIVO	2026-06-02 23:11:51.695846	2026-06-02 23:11:51.695846	0
88c333f5-6ff8-4413-af3a-29100fbd0d37	94173203400010563	stress-41732034-10563@mediqueue.test	Paciente Stress 41732034-10563	55010563	ACTIVO	2026-06-02 23:12:08.118758	2026-06-02 23:12:08.118758	0
fb942ce3-69e0-4708-b407-d6adb607652c	94173204700010576	stress-41732047-10576@mediqueue.test	Paciente Stress 41732047-10576	55010576	ACTIVO	2026-06-02 23:12:08.137709	2026-06-02 23:12:08.137709	0
0ef26e3f-26b1-4758-9411-bb13b050f8b8	94173204000010596	stress-41732040-10596@mediqueue.test	Paciente Stress 41732040-10596	55010596	ACTIVO	2026-06-02 23:12:08.286854	2026-06-02 23:12:08.286854	0
3b46eadd-c08d-45ab-984d-35de6987a3cf	94173203600010615	stress-41732036-10615@mediqueue.test	Paciente Stress 41732036-10615	55010615	ACTIVO	2026-06-02 23:12:08.46914	2026-06-02 23:12:08.46914	0
6ff6090c-ec43-4c66-8647-c58f6d1af5ab	94173203400010631	stress-41732034-10631@mediqueue.test	Paciente Stress 41732034-10631	55010631	ACTIVO	2026-06-02 23:12:08.645227	2026-06-02 23:12:08.645227	0
a832fe33-b7a5-411a-8199-560fa725fe41	94173197900010673	stress-41731979-10673@mediqueue.test	Paciente Stress 41731979-10673	55010673	ACTIVO	2026-06-02 23:12:09.257611	2026-06-02 23:12:09.257611	0
a88f3de9-c6f7-4e0e-9d53-d8daca9b2243	94173203100010667	stress-41732031-10667@mediqueue.test	Paciente Stress 41732031-10667	55010667	ACTIVO	2026-06-02 23:12:09.420098	2026-06-02 23:12:09.420098	0
5beb27f4-b9f2-4cb6-be0c-1a9db7b86c3e	94173203600010725	stress-41732036-10725@mediqueue.test	Paciente Stress 41732036-10725	55010725	ACTIVO	2026-06-02 23:12:09.798123	2026-06-02 23:12:09.798123	0
3b1287b4-78ce-44a2-9920-58947669385d	94173206800010744	stress-41732068-10744@mediqueue.test	Paciente Stress 41732068-10744	55010744	ACTIVO	2026-06-02 23:12:10.077862	2026-06-02 23:12:10.077862	0
3e78f058-8e13-4bbb-8a15-58fd1addad54	94173203400010743	stress-41732034-10743@mediqueue.test	Paciente Stress 41732034-10743	55010743	ACTIVO	2026-06-02 23:12:10.207264	2026-06-02 23:12:10.207264	0
084bdace-d74a-496f-b4f5-f3b609e963d4	94173199500010854	stress-41731995-10854@mediqueue.test	Paciente Stress 41731995-10854	55010854	ACTIVO	2026-06-02 23:12:12.070217	2026-06-02 23:12:12.070217	0
39554a22-48bd-463f-8c1a-c7ff11660519	94173198600010921	stress-41731986-10921@mediqueue.test	Paciente Stress 41731986-10921	55010921	ACTIVO	2026-06-02 23:12:12.371681	2026-06-02 23:12:12.371681	0
d4e8e9be-0276-438d-b8f5-df17bbbe02d2	94173203400010991	stress-41732034-10991@mediqueue.test	Paciente Stress 41732034-10991	55010991	ACTIVO	2026-06-02 23:12:12.993972	2026-06-02 23:12:12.993972	0
22e6bbc9-5aa2-4cac-9df9-44757b8c9dca	94173203900011263	stress-41732039-11263@mediqueue.test	Paciente Stress 41732039-11263	55011263	ACTIVO	2026-06-02 23:12:15.411779	2026-06-02 23:12:15.411779	0
8319c384-8fcd-48f8-af51-96da12a0c15c	94173200500011913	stress-41732005-11913@mediqueue.test	Paciente Stress 41732005-11913	55011913	ACTIVO	2026-06-02 23:12:23.744769	2026-06-02 23:12:23.744769	0
8c5d8220-4515-4608-ab7d-2515ef0330ec	94173199600012123	stress-41731996-12123@mediqueue.test	Paciente Stress 41731996-12123	55012123	ACTIVO	2026-06-02 23:12:26.121052	2026-06-02 23:12:26.121052	0
7001f3b7-053c-4803-9a46-f82fedac472c	94173203200012182	stress-41732032-12182@mediqueue.test	Paciente Stress 41732032-12182	55012182	ACTIVO	2026-06-02 23:12:26.444978	2026-06-02 23:12:26.444978	0
325f1175-97ec-4db5-990e-db709017a2e1	94173199600010774	stress-41731996-10774@mediqueue.test	Paciente Stress 41731996-10774	55010774	ACTIVO	2026-06-02 23:12:10.552973	2026-06-02 23:12:10.552973	0
e1b5e4ad-e37a-4e64-bcee-0cd27bef16d6	94173204000010892	stress-41732040-10892@mediqueue.test	Paciente Stress 41732040-10892	55010892	ACTIVO	2026-06-02 23:12:12.21433	2026-06-02 23:12:12.21433	0
b6939a6a-30e5-4db8-96e3-b29fef0ca959	94173203900011279	stress-41732039-11279@mediqueue.test	Paciente Stress 41732039-11279	55011279	ACTIVO	2026-06-02 23:12:15.578919	2026-06-02 23:12:15.578919	0
83fee63a-218e-4769-9ba5-cccab23a6588	94173202600010856	stress-41732026-10856@mediqueue.test	Paciente Stress 41732026-10856	55010856	ACTIVO	2026-06-02 23:12:11.678867	2026-06-02 23:12:11.678867	0
eee7a154-7d0f-4938-b20b-3fe6677437e7	94173203600011799	stress-41732036-11799@mediqueue.test	Paciente Stress 41732036-11799	55011799	ACTIVO	2026-06-02 23:12:22.076281	2026-06-02 23:12:22.076281	0
b9e3f5f1-370f-425f-b0b3-eaa622e23062	94173203900012018	stress-41732039-12018@mediqueue.test	Paciente Stress 41732039-12018	55012018	ACTIVO	2026-06-02 23:12:24.820624	2026-06-02 23:12:24.820624	0
efe30174-5708-446a-94a3-08bbd4e86051	94173204900010851	stress-41732049-10851@mediqueue.test	Paciente Stress 41732049-10851	55010851	ACTIVO	2026-06-02 23:12:11.992821	2026-06-02 23:12:11.992821	0
4450ddda-439d-4146-b8da-6b029b93a84e	94173203800011075	stress-41732038-11075@mediqueue.test	Paciente Stress 41732038-11075	55011075	ACTIVO	2026-06-02 23:12:13.789113	2026-06-02 23:12:13.789113	0
3fe528f0-f41f-4dd2-8cf4-43f6f703d69e	94173198500011099	stress-41731985-11099@mediqueue.test	Paciente Stress 41731985-11099	55011099	ACTIVO	2026-06-02 23:12:13.910325	2026-06-02 23:12:13.910325	0
d357a67c-7363-468d-85c0-8a3aadea1300	94173206900011474	stress-41732069-11474@mediqueue.test	Paciente Stress 41732069-11474	55011474	ACTIVO	2026-06-02 23:12:17.984752	2026-06-02 23:12:17.984752	0
89bd5a1d-dd65-471c-8ff3-c284d9543495	94173199600011680	stress-41731996-11680@mediqueue.test	Paciente Stress 41731996-11680	55011680	ACTIVO	2026-06-02 23:12:20.581964	2026-06-02 23:12:20.581964	0
20653a0d-eba2-49d4-af89-e819c50af680	94173198700011734	stress-41731987-11734@mediqueue.test	Paciente Stress 41731987-11734	55011734	ACTIVO	2026-06-02 23:12:21.251683	2026-06-02 23:12:21.251683	0
562a9034-7372-4f5d-8ffe-ee61427dbb1c	94173203000011916	stress-41732030-11916@mediqueue.test	Paciente Stress 41732030-11916	55011916	ACTIVO	2026-06-02 23:12:23.836901	2026-06-02 23:12:23.836901	0
29382780-d715-40e2-aaff-98f27050aab4	94173197700012088	stress-41731977-12088@mediqueue.test	Paciente Stress 41731977-12088	55012088	ACTIVO	2026-06-02 23:12:25.764263	2026-06-02 23:12:25.764263	0
d4ced56f-9482-4eae-ac56-47dd902a79a4	94173201300012103	stress-41732013-12103@mediqueue.test	Paciente Stress 41732013-12103	55012103	ACTIVO	2026-06-02 23:12:25.93068	2026-06-02 23:12:25.93068	0
8e59072b-7c7e-4da0-9078-a7e25c1e6449	94173206200010888	stress-41732062-10888@mediqueue.test	Paciente Stress 41732062-10888	55010888	ACTIVO	2026-06-02 23:12:12.213104	2026-06-02 23:12:12.213104	0
8043458c-b583-4a73-afe7-0a5dcf6235ff	94173198700010935	stress-41731987-10935@mediqueue.test	Paciente Stress 41731987-10935	55010935	ACTIVO	2026-06-02 23:12:12.522964	2026-06-02 23:12:12.522964	0
bf91ab62-e364-4606-b655-5b906d21dc2c	94173206500011065	stress-41732065-11065@mediqueue.test	Paciente Stress 41732065-11065	55011065	ACTIVO	2026-06-02 23:12:13.771367	2026-06-02 23:12:13.771367	0
4076587a-cda3-467d-8062-95b9e39fd05f	94173199200011238	stress-41731992-11238@mediqueue.test	Paciente Stress 41731992-11238	55011238	ACTIVO	2026-06-02 23:12:15.173613	2026-06-02 23:12:15.173613	0
113aa355-e259-49fd-a8d4-2f832c834847	94173201800011416	stress-41732018-11416@mediqueue.test	Paciente Stress 41732018-11416	55011416	ACTIVO	2026-06-02 23:12:17.25596	2026-06-02 23:12:17.25596	0
502975b0-6546-4594-8301-cf3892d67c5b	94173202300011476	stress-41732023-11476@mediqueue.test	Paciente Stress 41732023-11476	55011476	ACTIVO	2026-06-02 23:12:18.080847	2026-06-02 23:12:18.080847	0
7242b5c6-9917-45bd-8235-f7ae04e786fc	94173197600011600	stress-41731976-11600@mediqueue.test	Paciente Stress 41731976-11600	55011600	ACTIVO	2026-06-02 23:12:19.666039	2026-06-02 23:12:19.666039	0
df8bd945-7feb-4de2-9c72-9ebe0177d298	94173205900011696	stress-41732059-11696@mediqueue.test	Paciente Stress 41732059-11696	55011696	ACTIVO	2026-06-02 23:12:20.762743	2026-06-02 23:12:20.762743	0
58bded28-6565-4fde-a1e1-6ef1647942ff	94173201900011050	stress-41732019-11050@mediqueue.test	Paciente Stress 41732019-11050	55011050	ACTIVO	2026-06-02 23:12:13.553546	2026-06-02 23:12:13.553546	0
81a707cd-9ff3-4bae-b320-0160ff9c1bb5	94173205600011071	stress-41732056-11071@mediqueue.test	Paciente Stress 41732056-11071	55011071	ACTIVO	2026-06-02 23:12:13.781458	2026-06-02 23:12:13.781458	0
fdc9aa04-e43e-4679-a449-56b53f8f007a	94173205400011104	stress-41732054-11104@mediqueue.test	Paciente Stress 41732054-11104	55011104	ACTIVO	2026-06-02 23:12:14.048222	2026-06-02 23:12:14.048222	0
600e1c4a-2c8b-4562-9fbb-d51f1bca43d3	94173204100011501	stress-41732041-11501@mediqueue.test	Paciente Stress 41732041-11501	55011501	ACTIVO	2026-06-02 23:12:18.26562	2026-06-02 23:12:18.26562	0
779afbf9-be1d-4cc1-8c78-963e5158e086	94173201800011546	stress-41732018-11546@mediqueue.test	Paciente Stress 41732018-11546	55011546	ACTIVO	2026-06-02 23:12:18.811568	2026-06-02 23:12:18.811568	0
a28fa646-7729-46ca-b664-4c6bd39d4e6b	94173204500011673	stress-41732045-11673@mediqueue.test	Paciente Stress 41732045-11673	55011673	ACTIVO	2026-06-02 23:12:20.382567	2026-06-02 23:12:20.382567	0
ea902d05-2d9b-40e0-91f0-b553d67960a1	94173204700011691	stress-41732047-11691@mediqueue.test	Paciente Stress 41732047-11691	55011691	ACTIVO	2026-06-02 23:12:20.60813	2026-06-02 23:12:20.60813	0
4a01edc7-25f3-4394-8ca1-26a7a828aabb	94173202600011816	stress-41732026-11816@mediqueue.test	Paciente Stress 41732026-11816	55011816	ACTIVO	2026-06-02 23:12:22.368001	2026-06-02 23:12:22.368001	0
23831b61-c6f8-4a6d-a168-0148e170b59f	94173206700011888	stress-41732067-11888@mediqueue.test	Paciente Stress 41732067-11888	55011888	ACTIVO	2026-06-02 23:12:23.478442	2026-06-02 23:12:23.478442	0
f183b3f2-1f89-4177-b02b-5bc1c206eca1	94173198500011958	stress-41731985-11958@mediqueue.test	Paciente Stress 41731985-11958	55011958	ACTIVO	2026-06-02 23:12:24.219529	2026-06-02 23:12:24.219529	0
d1570004-bf40-47e8-92ad-4f5b7dcaac07	94173205800011089	stress-41732058-11089@mediqueue.test	Paciente Stress 41732058-11089	55011089	ACTIVO	2026-06-02 23:12:13.901681	2026-06-02 23:12:13.901681	0
08953eb9-c24e-463c-b368-2a738e811fed	94173203700011530	stress-41732037-11530@mediqueue.test	Paciente Stress 41732037-11530	55011530	ACTIVO	2026-06-02 23:12:18.499952	2026-06-02 23:12:18.499952	0
3e7fd507-04a5-489a-b4f6-83c5e6b911c8	94173206200011641	stress-41732062-11641@mediqueue.test	Paciente Stress 41732062-11641	55011641	ACTIVO	2026-06-02 23:12:20.073482	2026-06-02 23:12:20.073482	0
e25f5c77-da70-43f8-8964-03542da70458	94173197900011785	stress-41731979-11785@mediqueue.test	Paciente Stress 41731979-11785	55011785	ACTIVO	2026-06-02 23:12:22.012857	2026-06-02 23:12:22.012857	0
866d1636-de51-49f5-a40b-aa517017b859	94173202000011817	stress-41732020-11817@mediqueue.test	Paciente Stress 41732020-11817	55011817	ACTIVO	2026-06-02 23:12:22.369278	2026-06-02 23:12:22.369278	0
58bb5e01-39a0-4627-983e-65e3172d0e5c	94173206400011882	stress-41732064-11882@mediqueue.test	Paciente Stress 41732064-11882	55011882	ACTIVO	2026-06-02 23:12:23.126728	2026-06-02 23:12:23.126728	0
8c71bc81-301a-4436-870c-84e0f69c31b2	94173203100011893	stress-41732031-11893@mediqueue.test	Paciente Stress 41732031-11893	55011893	ACTIVO	2026-06-02 23:12:23.574418	2026-06-02 23:12:23.574418	0
1763cfea-5ae5-452c-ae17-1119e9d30814	94173203800012116	stress-41732038-12116@mediqueue.test	Paciente Stress 41732038-12116	55012116	ACTIVO	2026-06-02 23:12:26.146708	2026-06-02 23:12:26.146708	0
210602f2-afd5-4f64-9128-578f7094e771	94173199400011095	stress-41731994-11095@mediqueue.test	Paciente Stress 41731994-11095	55011095	ACTIVO	2026-06-02 23:12:13.922667	2026-06-02 23:12:13.922667	0
25911910-d52d-476f-9617-6f576d7de9da	94173206200011247	stress-41732062-11247@mediqueue.test	Paciente Stress 41732062-11247	55011247	ACTIVO	2026-06-02 23:12:15.306282	2026-06-02 23:12:15.306282	0
09030b96-c624-4a74-bfea-26fcbcb9d7a7	94173206700011328	stress-41732067-11328@mediqueue.test	Paciente Stress 41732067-11328	55011328	ACTIVO	2026-06-02 23:12:16.050248	2026-06-02 23:12:16.050248	0
aa058905-4cd1-456a-b7cb-d16635c0bbad	94173205600011491	stress-41732056-11491@mediqueue.test	Paciente Stress 41732056-11491	55011491	ACTIVO	2026-06-02 23:12:18.334787	2026-06-02 23:12:18.334787	0
5eeb61c0-a563-4582-afb1-fbaca7de6bab	94173204100011581	stress-41732041-11581@mediqueue.test	Paciente Stress 41732041-11581	55011581	ACTIVO	2026-06-02 23:12:19.542542	2026-06-02 23:12:19.542542	0
13cf18de-5f53-4a88-b08c-4dc335709cef	94173200300011620	stress-41732003-11620@mediqueue.test	Paciente Stress 41732003-11620	55011620	ACTIVO	2026-06-02 23:12:20.058511	2026-06-02 23:12:20.058511	0
dac995c0-eca9-44d2-8e67-aede53ef7588	94173202000011891	stress-41732020-11891@mediqueue.test	Paciente Stress 41732020-11891	55011891	ACTIVO	2026-06-02 23:12:23.328157	2026-06-02 23:12:23.328157	0
e506471a-7c27-47ff-b582-56eeaec4bc69	94173202600011929	stress-41732026-11929@mediqueue.test	Paciente Stress 41732026-11929	55011929	ACTIVO	2026-06-02 23:12:23.965907	2026-06-02 23:12:23.965907	0
87e7f37c-a06e-49c1-a976-b9cc23c143c6	94173202600011946	stress-41732026-11946@mediqueue.test	Paciente Stress 41732026-11946	55011946	ACTIVO	2026-06-02 23:12:24.066506	2026-06-02 23:12:24.066506	0
cc86792c-9c44-4734-941d-ae235aeebece	94173200400012178	stress-41732004-12178@mediqueue.test	Paciente Stress 41732004-12178	55012178	ACTIVO	2026-06-02 23:12:26.561369	2026-06-02 23:12:26.561369	0
c6ce7148-afa6-4046-ba21-36185d33a4be	94173198600011094	stress-41731986-11094@mediqueue.test	Paciente Stress 41731986-11094	55011094	ACTIVO	2026-06-02 23:12:13.945311	2026-06-02 23:12:13.945311	0
6eaef94e-4a25-45cf-87f8-2f7599d8ce5d	94173201100011153	stress-41732011-11153@mediqueue.test	Paciente Stress 41732011-11153	55011153	ACTIVO	2026-06-02 23:12:14.546721	2026-06-02 23:12:14.546721	0
f37a7f0b-4c8e-48da-b7cf-b60e70701a00	94173202000011192	stress-41732020-11192@mediqueue.test	Paciente Stress 41732020-11192	55011192	ACTIVO	2026-06-02 23:12:14.744857	2026-06-02 23:12:14.744857	0
783ae893-4a6b-435a-a98e-2790c92909c0	94173207000011244	stress-41732070-11244@mediqueue.test	Paciente Stress 41732070-11244	55011244	ACTIVO	2026-06-02 23:12:15.327873	2026-06-02 23:12:15.327873	0
a1f3574d-f590-44e3-bed0-06e6d49fbb87	94173206300011288	stress-41732063-11288@mediqueue.test	Paciente Stress 41732063-11288	55011288	ACTIVO	2026-06-02 23:12:15.642992	2026-06-02 23:12:15.642992	0
a6ef8357-a72b-492c-910a-5abd92d9a110	94173205900011595	stress-41732059-11595@mediqueue.test	Paciente Stress 41732059-11595	55011595	ACTIVO	2026-06-02 23:12:19.564859	2026-06-02 23:12:19.564859	0
4482016d-0851-4abd-8be2-5ca88533df24	94173202500011679	stress-41732025-11679@mediqueue.test	Paciente Stress 41732025-11679	55011679	ACTIVO	2026-06-02 23:12:20.587969	2026-06-02 23:12:20.587969	0
18066c7b-1014-4d35-af74-f787d81c9f4b	94173204100011711	stress-41732041-11711@mediqueue.test	Paciente Stress 41732041-11711	55011711	ACTIVO	2026-06-02 23:12:20.7359	2026-06-02 23:12:20.7359	0
e76593d5-d2a4-404e-be48-d78e07dc38d0	94173204000011901	stress-41732040-11901@mediqueue.test	Paciente Stress 41732040-11901	55011901	ACTIVO	2026-06-02 23:12:23.673172	2026-06-02 23:12:23.673172	0
f966875d-05e7-4b62-a8f5-7628aaf467b5	94173206500012186	stress-41732065-12186@mediqueue.test	Paciente Stress 41732065-12186	55012186	ACTIVO	2026-06-02 23:12:26.625568	2026-06-02 23:12:26.625568	0
1713124b-231c-420b-b264-e77e521943ba	94173201500011108	stress-41732015-11108@mediqueue.test	Paciente Stress 41732015-11108	55011108	ACTIVO	2026-06-02 23:12:14.061975	2026-06-02 23:12:14.061975	0
24eb13e5-2cdd-4c00-b2af-afb6f4648110	94173204100011484	stress-41732041-11484@mediqueue.test	Paciente Stress 41732041-11484	55011484	ACTIVO	2026-06-02 23:12:18.030424	2026-06-02 23:12:18.030424	0
7f337824-8476-4a44-8327-5dae5ba7de15	94173203700012102	stress-41732037-12102@mediqueue.test	Paciente Stress 41732037-12102	55012102	ACTIVO	2026-06-02 23:12:25.730732	2026-06-02 23:12:25.730732	0
12fcac4c-6151-4ad7-ba20-bd1a6c564944	94173200500012104	stress-41732005-12104@mediqueue.test	Paciente Stress 41732005-12104	55012104	ACTIVO	2026-06-02 23:12:25.931516	2026-06-02 23:12:25.931516	0
799e7a76-049e-4edb-b82b-059bda687816	94173204600012219	stress-41732046-12219@mediqueue.test	Paciente Stress 41732046-12219	55012219	ACTIVO	2026-06-02 23:13:33.243657	2026-06-02 23:13:33.243657	0
dac76ced-b60a-4747-92f7-2c524dc95b78	94173203600012433	stress-41732036-12433@mediqueue.test	Paciente Stress 41732036-12433	55012433	ACTIVO	2026-06-02 23:13:33.542489	2026-06-02 23:13:33.542489	0
9758a5df-fe7c-4a2f-95d5-d3412f74eb9a	94173203800012283	stress-41732038-12283@mediqueue.test	Paciente Stress 41732038-12283	55012283	ACTIVO	2026-06-02 23:13:35.152026	2026-06-02 23:13:35.152026	0
88748d99-16d2-40d0-964e-2113e92fce9d	94173206000012250	stress-41732060-12250@mediqueue.test	Paciente Stress 41732060-12250	55012250	ACTIVO	2026-06-02 23:13:35.229815	2026-06-02 23:13:35.229815	0
03416c3f-6ae0-47b1-91f4-8c068afc135c	94173201800012503	stress-41732018-12503@mediqueue.test	Paciente Stress 41732018-12503	55012503	ACTIVO	2026-06-02 23:13:35.371975	2026-06-02 23:13:35.371975	0
a8320ef7-9d87-4bb5-a639-c3929c353b13	94173204000012435	stress-41732040-12435@mediqueue.test	Paciente Stress 41732040-12435	55012435	ACTIVO	2026-06-02 23:13:35.955659	2026-06-02 23:13:35.955659	0
00bcdc5d-01af-40ff-a594-d4a9608e7c88	94173203300012386	stress-41732033-12386@mediqueue.test	Paciente Stress 41732033-12386	55012386	ACTIVO	2026-06-02 23:13:36.045677	2026-06-02 23:13:36.045677	0
83d71ff9-9d01-4cd6-9b65-47c200c9f911	94173203100012281	stress-41732031-12281@mediqueue.test	Paciente Stress 41732031-12281	55012281	ACTIVO	2026-06-02 23:13:36.080206	2026-06-02 23:13:36.080206	0
07e44474-0a22-4576-8216-c9946161a23c	94173200500012344	stress-41732005-12344@mediqueue.test	Paciente Stress 41732005-12344	55012344	ACTIVO	2026-06-02 23:13:36.17184	2026-06-02 23:13:36.17184	0
f7809d51-1ceb-43a1-9ac2-7eea2b587ca3	94173202300012359	stress-41732023-12359@mediqueue.test	Paciente Stress 41732023-12359	55012359	ACTIVO	2026-06-02 23:13:36.249181	2026-06-02 23:13:36.249181	0
12c89ba0-8737-4937-8bbe-274350bf04c8	94173205700012348	stress-41732057-12348@mediqueue.test	Paciente Stress 41732057-12348	55012348	ACTIVO	2026-06-02 23:13:36.254457	2026-06-02 23:13:36.254457	0
1f31b322-7355-4743-8e75-c202f43625a7	94173207000012389	stress-41732070-12389@mediqueue.test	Paciente Stress 41732070-12389	55012389	ACTIVO	2026-06-02 23:13:36.333889	2026-06-02 23:13:36.333889	0
eac4aff8-8207-4552-8082-688b542eaf93	94173206400012480	stress-41732064-12480@mediqueue.test	Paciente Stress 41732064-12480	55012480	ACTIVO	2026-06-02 23:13:36.42005	2026-06-02 23:13:36.42005	0
d457a7fe-9185-4c38-a1cb-a44df0062502	94173203200012414	stress-41732032-12414@mediqueue.test	Paciente Stress 41732032-12414	55012414	ACTIVO	2026-06-02 23:13:36.433713	2026-06-02 23:13:36.433713	0
f9984bf6-a32a-4eb4-b0c3-34e6892a2e85	94173203900012496	stress-41732039-12496@mediqueue.test	Paciente Stress 41732039-12496	55012496	ACTIVO	2026-06-02 23:13:36.435074	2026-06-02 23:13:36.435074	0
846b815b-d479-41c4-9c23-731a25d60f01	94173205600012591	stress-41732056-12591@mediqueue.test	Paciente Stress 41732056-12591	55012591	ACTIVO	2026-06-02 23:13:36.483614	2026-06-02 23:13:36.483614	0
e003bfbc-81c9-4732-9ef0-f2c27f3e41a4	94173203400012607	stress-41732034-12607@mediqueue.test	Paciente Stress 41732034-12607	55012607	ACTIVO	2026-06-02 23:13:36.510936	2026-06-02 23:13:36.510936	0
00c8db0d-4f86-48ee-b557-b973490c1df3	94173206300012277	stress-41732063-12277@mediqueue.test	Paciente Stress 41732063-12277	55012277	ACTIVO	2026-06-02 23:13:36.525307	2026-06-02 23:13:36.525307	0
8cf8bf7d-af09-4784-a330-401338363489	94173203500012465	stress-41732035-12465@mediqueue.test	Paciente Stress 41732035-12465	55012465	ACTIVO	2026-06-02 23:13:36.555993	2026-06-02 23:13:36.555993	0
a74b5bd3-e699-4722-9c62-f50a811e4aac	94173204500012619	stress-41732045-12619@mediqueue.test	Paciente Stress 41732045-12619	55012619	ACTIVO	2026-06-02 23:13:36.57479	2026-06-02 23:13:36.57479	0
a1462e0f-3a48-4fa8-9d48-24db1c2f7318	94173200400012664	stress-41732004-12664@mediqueue.test	Paciente Stress 41732004-12664	55012664	ACTIVO	2026-06-02 23:13:36.742179	2026-06-02 23:13:36.742179	0
42cd9732-7f33-479b-9e23-929065aee7a5	94173201500012685	stress-41732015-12685@mediqueue.test	Paciente Stress 41732015-12685	55012685	ACTIVO	2026-06-02 23:13:36.934214	2026-06-02 23:13:36.934214	0
a545666a-ae0d-4f2b-bcda-93bee5d7d4dd	94173204800012689	stress-41732048-12689@mediqueue.test	Paciente Stress 41732048-12689	55012689	ACTIVO	2026-06-02 23:13:37.07063	2026-06-02 23:13:37.07063	0
70695d3a-8ebf-4d1f-b22d-34e8a8fd115a	94173203100012702	stress-41732031-12702@mediqueue.test	Paciente Stress 41732031-12702	55012702	ACTIVO	2026-06-02 23:13:37.442949	2026-06-02 23:13:37.442949	0
71c66020-f9d0-42f5-b446-7bd0a6397e4e	94173205700012703	stress-41732057-12703@mediqueue.test	Paciente Stress 41732057-12703	55012703	ACTIVO	2026-06-02 23:13:37.520242	2026-06-02 23:13:37.520242	0
78d6162d-c11f-4aac-98fc-f79d5f47140d	94173204700012730	stress-41732047-12730@mediqueue.test	Paciente Stress 41732047-12730	55012730	ACTIVO	2026-06-02 23:13:56.94787	2026-06-02 23:13:56.94787	0
fadb74f3-7ad7-49ab-94e8-0cad00d4a892	94173202700012738	stress-41732027-12738@mediqueue.test	Paciente Stress 41732027-12738	55012738	ACTIVO	2026-06-02 23:13:56.972122	2026-06-02 23:13:56.972122	0
8d1033bc-6e91-4672-9de5-346b2b4f2089	94173199300012744	stress-41731993-12744@mediqueue.test	Paciente Stress 41731993-12744	55012744	ACTIVO	2026-06-02 23:13:56.992748	2026-06-02 23:13:56.992748	0
33120326-246e-45b4-8810-cd8c54194f45	94173206100012752	stress-41732061-12752@mediqueue.test	Paciente Stress 41732061-12752	55012752	ACTIVO	2026-06-02 23:13:57.032513	2026-06-02 23:13:57.032513	0
937f34c1-5931-40d1-83a9-02ba41b5216a	94173207000012778	stress-41732070-12778@mediqueue.test	Paciente Stress 41732070-12778	55012778	ACTIVO	2026-06-02 23:13:57.101901	2026-06-02 23:13:57.101901	0
527aa327-daa0-4f9d-a727-68f94975e8d8	94173202300012779	stress-41732023-12779@mediqueue.test	Paciente Stress 41732023-12779	55012779	ACTIVO	2026-06-02 23:13:57.13029	2026-06-02 23:13:57.13029	0
c12a36ef-fdf4-4a20-a421-1999ed967190	94173203600012786	stress-41732036-12786@mediqueue.test	Paciente Stress 41732036-12786	55012786	ACTIVO	2026-06-02 23:13:57.219443	2026-06-02 23:13:57.219443	0
9ffdd64a-27be-42ec-a8e3-2fd5cd0a9495	94173203900012791	stress-41732039-12791@mediqueue.test	Paciente Stress 41732039-12791	55012791	ACTIVO	2026-06-02 23:13:57.221558	2026-06-02 23:13:57.221558	0
f323b1d9-da09-4ece-86de-1e5a1a28dc45	94173205900012813	stress-41732059-12813@mediqueue.test	Paciente Stress 41732059-12813	55012813	ACTIVO	2026-06-02 23:13:57.323028	2026-06-02 23:13:57.323028	0
ab4c51fa-1f76-4016-8b4a-d853ccf11418	94173204400012827	stress-41732044-12827@mediqueue.test	Paciente Stress 41732044-12827	55012827	ACTIVO	2026-06-02 23:13:57.516191	2026-06-02 23:13:57.516191	0
27de5e80-3309-4795-9319-fd3bdb2b4acc	94173205500012822	stress-41732055-12822@mediqueue.test	Paciente Stress 41732055-12822	55012822	ACTIVO	2026-06-02 23:13:57.587805	2026-06-02 23:13:57.587805	0
0ba4ee2b-259a-4b2e-88a2-4668540a5054	94173205700012843	stress-41732057-12843@mediqueue.test	Paciente Stress 41732057-12843	55012843	ACTIVO	2026-06-02 23:13:57.699299	2026-06-02 23:13:57.699299	0
39156613-6fd7-43c8-a149-b413868fa9b8	94173205900012851	stress-41732059-12851@mediqueue.test	Paciente Stress 41732059-12851	55012851	ACTIVO	2026-06-02 23:13:57.868261	2026-06-02 23:13:57.868261	0
1c7ee206-542b-4376-8089-144a2f743914	94173206100012877	stress-41732061-12877@mediqueue.test	Paciente Stress 41732061-12877	55012877	ACTIVO	2026-06-02 23:13:58.179581	2026-06-02 23:13:58.179581	0
aa39ef55-efdb-4da0-931f-48b53f9f90cc	94173200300012903	stress-41732003-12903@mediqueue.test	Paciente Stress 41732003-12903	55012903	ACTIVO	2026-06-02 23:13:58.472083	2026-06-02 23:13:58.472083	0
fad1e258-4390-4128-9d9d-be49ceb4b90e	94173199200012910	stress-41731992-12910@mediqueue.test	Paciente Stress 41731992-12910	55012910	ACTIVO	2026-06-02 23:13:58.479383	2026-06-02 23:13:58.479383	0
6576abf2-37fc-4100-843d-77627e2efcf8	94173200800012909	stress-41732008-12909@mediqueue.test	Paciente Stress 41732008-12909	55012909	ACTIVO	2026-06-02 23:13:58.544579	2026-06-02 23:13:58.544579	0
2bcbe5b8-093b-4243-889a-df81ebb237d9	94173204800012966	stress-41732048-12966@mediqueue.test	Paciente Stress 41732048-12966	55012966	ACTIVO	2026-06-02 23:13:59.035957	2026-06-02 23:13:59.035957	0
4348953e-f99a-4fe1-8bea-318235b33514	94173205100012979	stress-41732051-12979@mediqueue.test	Paciente Stress 41732051-12979	55012979	ACTIVO	2026-06-02 23:13:59.294437	2026-06-02 23:13:59.294437	0
770f23f9-abc5-4b2e-9723-67bd8147a2a4	94173203300013099	stress-41732033-13099@mediqueue.test	Paciente Stress 41732033-13099	55013099	ACTIVO	2026-06-02 23:14:01.382232	2026-06-02 23:14:01.382232	0
845ae7ed-6bd5-48b1-8819-bf4cb026ed1f	94173206200013127	stress-41732062-13127@mediqueue.test	Paciente Stress 41732062-13127	55013127	ACTIVO	2026-06-02 23:14:01.550032	2026-06-02 23:14:01.550032	0
9d1997fd-07bf-4f3c-aa44-dbe94956b6d9	94173203300013556	stress-41732033-13556@mediqueue.test	Paciente Stress 41732033-13556	55013556	ACTIVO	2026-06-02 23:14:06.171133	2026-06-02 23:14:06.171133	0
b26613a2-2569-477d-80e5-0fa420abf47d	94173203300014310	stress-41732033-14310@mediqueue.test	Paciente Stress 41732033-14310	55014310	ACTIVO	2026-06-02 23:14:48.225375	2026-06-02 23:14:48.225375	0
f7bff999-ce2c-45e2-bc53-f541fbf1ea4e	94173204600014359	stress-41732046-14359@mediqueue.test	Paciente Stress 41732046-14359	55014359	ACTIVO	2026-06-02 23:14:52.426582	2026-06-02 23:14:52.426582	0
bc9a5eb9-bc2f-408d-a5a7-da674b8ca085	94173201800014718	stress-41732018-14718@mediqueue.test	Paciente Stress 41732018-14718	55014718	ACTIVO	2026-06-02 23:14:53.403893	2026-06-02 23:14:53.403893	0
8e789279-a851-4172-bc40-bedfa224d1b3	94173199300014942	stress-41731993-14942@mediqueue.test	Paciente Stress 41731993-14942	55014942	ACTIVO	2026-06-02 23:15:17.17822	2026-06-02 23:15:17.17822	0
7dbc4704-cd4c-4d3c-8e0e-72591f4c9064	94173198600012994	stress-41731986-12994@mediqueue.test	Paciente Stress 41731986-12994	55012994	ACTIVO	2026-06-02 23:13:59.444194	2026-06-02 23:13:59.444194	0
891b879e-18bc-448e-ab36-99dd28f07456	94173204400013155	stress-41732044-13155@mediqueue.test	Paciente Stress 41732044-13155	55013155	ACTIVO	2026-06-02 23:14:02.163576	2026-06-02 23:14:02.163576	0
971eb70d-b3b1-4796-b274-fd84de5d955d	94173199100013786	stress-41731991-13786@mediqueue.test	Paciente Stress 41731991-13786	55013786	ACTIVO	2026-06-02 23:14:08.501573	2026-06-02 23:14:08.501573	0
aa66c1ce-ffae-4c8c-9098-f383762fa931	94173205100013886	stress-41732051-13886@mediqueue.test	Paciente Stress 41732051-13886	55013886	ACTIVO	2026-06-02 23:14:09.507736	2026-06-02 23:14:09.507736	0
8e14dce2-4a41-4db4-b98b-1b993b473aa2	94173200300013920	stress-41732003-13920@mediqueue.test	Paciente Stress 41732003-13920	55013920	ACTIVO	2026-06-02 23:14:09.933695	2026-06-02 23:14:09.933695	0
471f4633-fec7-4380-85e6-dd011e563b9f	94173197700013958	stress-41731977-13958@mediqueue.test	Paciente Stress 41731977-13958	55013958	ACTIVO	2026-06-02 23:14:10.526894	2026-06-02 23:14:10.526894	0
a2eb3c5d-19ce-47e5-aa80-566166860d04	94173205600014232	stress-41732056-14232@mediqueue.test	Paciente Stress 41732056-14232	55014232	ACTIVO	2026-06-02 23:14:13.216225	2026-06-02 23:14:13.216225	0
558ed07e-1f50-4fa1-b2e5-5f0f94c0d6ba	94173202200014454	stress-41732022-14454@mediqueue.test	Paciente Stress 41732022-14454	55014454	ACTIVO	2026-06-02 23:14:51.79189	2026-06-02 23:14:51.79189	0
b66ea683-6672-4d10-93a5-cd33fdacd307	94173206700014309	stress-41732067-14309@mediqueue.test	Paciente Stress 41732067-14309	55014309	ACTIVO	2026-06-02 23:14:51.963829	2026-06-02 23:14:51.963829	0
b9242136-b724-4769-af21-eb8108180c37	94173201800013023	stress-41732018-13023@mediqueue.test	Paciente Stress 41732018-13023	55013023	ACTIVO	2026-06-02 23:13:59.633991	2026-06-02 23:13:59.633991	0
b88e4f0d-85e2-447a-9487-40e6e753aee6	94173199200013047	stress-41731992-13047@mediqueue.test	Paciente Stress 41731992-13047	55013047	ACTIVO	2026-06-02 23:13:59.891204	2026-06-02 23:13:59.891204	0
f41fb9df-4fce-4ccc-bae5-fbc272c5c617	94173199200013062	stress-41731992-13062@mediqueue.test	Paciente Stress 41731992-13062	55013062	ACTIVO	2026-06-02 23:14:00.087473	2026-06-02 23:14:00.087473	0
56e3b8c3-9651-40e0-a594-a79c0537e52b	94173204400013261	stress-41732044-13261@mediqueue.test	Paciente Stress 41732044-13261	55013261	ACTIVO	2026-06-02 23:14:02.907639	2026-06-02 23:14:02.907639	0
525dd241-3859-4910-80ea-b0a9e1a55336	94173206500013352	stress-41732065-13352@mediqueue.test	Paciente Stress 41732065-13352	55013352	ACTIVO	2026-06-02 23:14:04.11883	2026-06-02 23:14:04.11883	0
5115ea1e-f4a7-42ee-a773-bad01aa591fc	94173201800013534	stress-41732018-13534@mediqueue.test	Paciente Stress 41732018-13534	55013534	ACTIVO	2026-06-02 23:14:05.985081	2026-06-02 23:14:05.985081	0
1b3ffe21-d6a6-4e4b-872a-96eec92e9ed7	94173200800013662	stress-41732008-13662@mediqueue.test	Paciente Stress 41732008-13662	55013662	ACTIVO	2026-06-02 23:14:07.314864	2026-06-02 23:14:07.314864	0
d3c97b07-c06c-4e04-8892-84718d4f8d74	94173205000014243	stress-41732050-14243@mediqueue.test	Paciente Stress 41732050-14243	55014243	ACTIVO	2026-06-02 23:14:13.411208	2026-06-02 23:14:13.411208	0
231e838e-2c7e-4da1-959f-5ddd05919243	94173203100014261	stress-41732031-14261@mediqueue.test	Paciente Stress 41732031-14261	55014261	ACTIVO	2026-06-02 23:14:13.565592	2026-06-02 23:14:13.565592	0
4639ec52-001c-4150-8dab-b32914be1c7d	94173203200014442	stress-41732032-14442@mediqueue.test	Paciente Stress 41732032-14442	55014442	ACTIVO	2026-06-02 23:14:52.855896	2026-06-02 23:14:52.855896	0
8e1fc25e-c05e-4726-b8b6-08873b2a7cde	94173203100014490	stress-41732031-14490@mediqueue.test	Paciente Stress 41732031-14490	55014490	ACTIVO	2026-06-02 23:14:53.117279	2026-06-02 23:14:53.117279	0
a5509524-81eb-4da9-b850-66c52966ca87	94173203900014649	stress-41732039-14649@mediqueue.test	Paciente Stress 41732039-14649	55014649	ACTIVO	2026-06-02 23:14:53.233277	2026-06-02 23:14:53.233277	0
32832044-18f6-4a5f-8ec6-8a2f304bd4d4	94173202200014691	stress-41732022-14691@mediqueue.test	Paciente Stress 41732022-14691	55014691	ACTIVO	2026-06-02 23:14:53.291067	2026-06-02 23:14:53.291067	0
ed8ecd5c-2583-4762-b7c5-1b548c824f8f	94173202000014809	stress-41732020-14809@mediqueue.test	Paciente Stress 41732020-14809	55014809	ACTIVO	2026-06-02 23:14:53.802399	2026-06-02 23:14:53.802399	0
b92b82a6-8ddc-43c4-84f7-2d4d8527aee1	94173203600014880	stress-41732036-14880@mediqueue.test	Paciente Stress 41732036-14880	55014880	ACTIVO	2026-06-02 23:14:54.378776	2026-06-02 23:14:54.378776	0
00c69525-563a-4f14-a229-a6d819df46c0	94173203200014889	stress-41732032-14889@mediqueue.test	Paciente Stress 41732032-14889	55014889	ACTIVO	2026-06-02 23:15:16.847223	2026-06-02 23:15:16.847223	0
9ada51a3-6ec3-46fb-b5e7-1b8ec1c14068	94173204000013038	stress-41732040-13038@mediqueue.test	Paciente Stress 41732040-13038	55013038	ACTIVO	2026-06-02 23:13:59.768821	2026-06-02 23:13:59.768821	0
5601ed18-b905-42ff-bd21-80a3377012fd	94173203400013049	stress-41732034-13049@mediqueue.test	Paciente Stress 41732034-13049	55013049	ACTIVO	2026-06-02 23:13:59.911649	2026-06-02 23:13:59.911649	0
5e9ea4c5-59ec-4461-8398-5caa06f061b6	94173201700013088	stress-41732017-13088@mediqueue.test	Paciente Stress 41732017-13088	55013088	ACTIVO	2026-06-02 23:14:00.633045	2026-06-02 23:14:00.633045	0
4e94c3d7-6c73-4bbc-8e76-cd0712683e3a	94173204700013096	stress-41732047-13096@mediqueue.test	Paciente Stress 41732047-13096	55013096	ACTIVO	2026-06-02 23:14:01.148791	2026-06-02 23:14:01.148791	0
dc1fceab-ed0a-4aad-9309-bdc6457f6fd1	94173206200013156	stress-41732062-13156@mediqueue.test	Paciente Stress 41732062-13156	55013156	ACTIVO	2026-06-02 23:14:01.662813	2026-06-02 23:14:01.662813	0
6ecaf073-2b09-4d6b-9bc5-b36d1cba2b79	94173199300013310	stress-41731993-13310@mediqueue.test	Paciente Stress 41731993-13310	55013310	ACTIVO	2026-06-02 23:14:03.240938	2026-06-02 23:14:03.240938	0
37e07ad0-52bd-4e28-951c-6bafff17c89d	94173199000013440	stress-41731990-13440@mediqueue.test	Paciente Stress 41731990-13440	55013440	ACTIVO	2026-06-02 23:14:04.724804	2026-06-02 23:14:04.724804	0
bde75f08-8249-4404-a264-b5f6dd65aee3	94173203400013774	stress-41732034-13774@mediqueue.test	Paciente Stress 41732034-13774	55013774	ACTIVO	2026-06-02 23:14:08.093546	2026-06-02 23:14:08.093546	0
236680a8-0801-4ab3-bf7f-e3d752eed1e5	94173200800013840	stress-41732008-13840@mediqueue.test	Paciente Stress 41732008-13840	55013840	ACTIVO	2026-06-02 23:14:08.950716	2026-06-02 23:14:08.950716	0
56bac7d4-d5a4-409b-b4c0-3969680602ec	94173206500013858	stress-41732065-13858@mediqueue.test	Paciente Stress 41732065-13858	55013858	ACTIVO	2026-06-02 23:14:09.11128	2026-06-02 23:14:09.11128	0
2a6a9577-c588-4dbd-8718-45803099fb41	94173201600013953	stress-41732016-13953@mediqueue.test	Paciente Stress 41732016-13953	55013953	ACTIVO	2026-06-02 23:14:10.12655	2026-06-02 23:14:10.12655	0
1927eee7-0249-4e44-9907-47e4c2133f93	94173204000013981	stress-41732040-13981@mediqueue.test	Paciente Stress 41732040-13981	55013981	ACTIVO	2026-06-02 23:14:10.735213	2026-06-02 23:14:10.735213	0
00e0597e-9780-496e-8f47-a70fcefd6b90	94173202600014063	stress-41732026-14063@mediqueue.test	Paciente Stress 41732026-14063	55014063	ACTIVO	2026-06-02 23:14:11.528467	2026-06-02 23:14:11.528467	0
b3101b70-b864-4887-9e38-64cb2c8d9919	94173203800014188	stress-41732038-14188@mediqueue.test	Paciente Stress 41732038-14188	55014188	ACTIVO	2026-06-02 23:14:12.837608	2026-06-02 23:14:12.837608	0
1cae3354-e35f-49e8-a9bc-c8f8f968f3c9	94173205300014204	stress-41732053-14204@mediqueue.test	Paciente Stress 41732053-14204	55014204	ACTIVO	2026-06-02 23:14:13.154569	2026-06-02 23:14:13.154569	0
7bdad13a-0c7d-4996-b89d-bf856a4534a5	94173206500014283	stress-41732065-14283@mediqueue.test	Paciente Stress 41732065-14283	55014283	ACTIVO	2026-06-02 23:14:48.091627	2026-06-02 23:14:48.091627	0
f2279d8e-0e06-4067-9dde-df4898ed8cab	94173200800014298	stress-41732008-14298@mediqueue.test	Paciente Stress 41732008-14298	55014298	ACTIVO	2026-06-02 23:14:52.412135	2026-06-02 23:14:52.412135	0
590a4d02-a0bd-450f-b0db-82aae1948801	94173198700014437	stress-41731987-14437@mediqueue.test	Paciente Stress 41731987-14437	55014437	ACTIVO	2026-06-02 23:14:52.610783	2026-06-02 23:14:52.610783	0
88c0b982-4959-4def-b9e9-6b0839128e91	94173197900014467	stress-41731979-14467@mediqueue.test	Paciente Stress 41731979-14467	55014467	ACTIVO	2026-06-02 23:14:53.253828	2026-06-02 23:14:53.253828	0
8ec93527-3d64-4d5a-b477-689d1d1516cf	94173204500014688	stress-41732045-14688@mediqueue.test	Paciente Stress 41732045-14688	55014688	ACTIVO	2026-06-02 23:14:53.35449	2026-06-02 23:14:53.35449	0
3ac0a18c-4043-4d08-ae41-76bff6d280e8	94173203300014702	stress-41732033-14702@mediqueue.test	Paciente Stress 41732033-14702	55014702	ACTIVO	2026-06-02 23:14:53.483754	2026-06-02 23:14:53.483754	0
43c75975-37f0-4b66-950c-ccc2d4526f8b	94173199700014946	stress-41731997-14946@mediqueue.test	Paciente Stress 41731997-14946	55014946	ACTIVO	2026-06-02 23:15:17.138695	2026-06-02 23:15:17.138695	0
fc42cfa3-2cab-4597-8253-b35e622bad10	94173203400013085	stress-41732034-13085@mediqueue.test	Paciente Stress 41732034-13085	55013085	ACTIVO	2026-06-02 23:14:00.849634	2026-06-02 23:14:00.849634	0
3ba2e150-baed-40cb-96be-eb29c05463d1	94173197900013184	stress-41731979-13184@mediqueue.test	Paciente Stress 41731979-13184	55013184	ACTIVO	2026-06-02 23:14:01.849174	2026-06-02 23:14:01.849174	0
4dd86a59-e776-4f02-af07-9be647322091	94173203100013207	stress-41732031-13207@mediqueue.test	Paciente Stress 41732031-13207	55013207	ACTIVO	2026-06-02 23:14:02.414515	2026-06-02 23:14:02.414515	0
ce18cdf5-63bc-49b8-98f0-a6728f2d8b51	94173203200013258	stress-41732032-13258@mediqueue.test	Paciente Stress 41732032-13258	55013258	ACTIVO	2026-06-02 23:14:02.837406	2026-06-02 23:14:02.837406	0
9152fcaf-7183-4163-85d9-e83a854671d3	94173197900013312	stress-41731979-13312@mediqueue.test	Paciente Stress 41731979-13312	55013312	ACTIVO	2026-06-02 23:14:03.213695	2026-06-02 23:14:03.213695	0
bd478750-ed8c-4a2b-85be-7fbee2f28c76	94173203700013295	stress-41732037-13295@mediqueue.test	Paciente Stress 41732037-13295	55013295	ACTIVO	2026-06-02 23:14:03.33506	2026-06-02 23:14:03.33506	0
5bbf3922-7812-4dde-913d-8cb5e520c655	94173202500013388	stress-41732025-13388@mediqueue.test	Paciente Stress 41732025-13388	55013388	ACTIVO	2026-06-02 23:14:04.522162	2026-06-02 23:14:04.522162	0
c214886c-cc22-44f2-a0d7-d8e4c4ae0bca	94173206300013618	stress-41732063-13618@mediqueue.test	Paciente Stress 41732063-13618	55013618	ACTIVO	2026-06-02 23:14:06.745674	2026-06-02 23:14:06.745674	0
dc63c1a1-b73c-49f5-8cdc-4f8e9281b7f2	94173206500013632	stress-41732065-13632@mediqueue.test	Paciente Stress 41732065-13632	55013632	ACTIVO	2026-06-02 23:14:06.784934	2026-06-02 23:14:06.784934	0
724ea56b-9885-4410-a7f7-54130f0f99cf	94173203600014145	stress-41732036-14145@mediqueue.test	Paciente Stress 41732036-14145	55014145	ACTIVO	2026-06-02 23:14:12.200275	2026-06-02 23:14:12.200275	0
18ef8842-a335-41bc-a625-d66d01f3d7fc	94173200300014165	stress-41732003-14165@mediqueue.test	Paciente Stress 41732003-14165	55014165	ACTIVO	2026-06-02 23:14:12.696863	2026-06-02 23:14:12.696863	0
94b81fd6-14bc-48fa-aab4-047fb3c84b7e	94173199500014335	stress-41731995-14335@mediqueue.test	Paciente Stress 41731995-14335	55014335	ACTIVO	2026-06-02 23:14:51.252254	2026-06-02 23:14:51.252254	0
e2048d04-2ae6-4bca-bb6c-61e39464f905	94173202600013115	stress-41732026-13115@mediqueue.test	Paciente Stress 41732026-13115	55013115	ACTIVO	2026-06-02 23:14:01.453801	2026-06-02 23:14:01.453801	0
f5fcc5d1-19d5-453f-a7eb-6894b69e96d5	94173203800013246	stress-41732038-13246@mediqueue.test	Paciente Stress 41732038-13246	55013246	ACTIVO	2026-06-02 23:14:02.74201	2026-06-02 23:14:02.74201	0
b3ca3d1b-263b-42e7-b4b7-737787fb5f37	94173201200013582	stress-41732012-13582@mediqueue.test	Paciente Stress 41732012-13582	55013582	ACTIVO	2026-06-02 23:14:06.382653	2026-06-02 23:14:06.382653	0
82e81980-6afc-46c6-98e2-d6cf9eceaff4	94173207000014228	stress-41732070-14228@mediqueue.test	Paciente Stress 41732070-14228	55014228	ACTIVO	2026-06-02 23:14:13.293081	2026-06-02 23:14:13.293081	0
f2594d61-96f9-482c-aec7-8201a5da6d47	94173198500014250	stress-41731985-14250@mediqueue.test	Paciente Stress 41731985-14250	55014250	ACTIVO	2026-06-02 23:14:13.437533	2026-06-02 23:14:13.437533	0
69328f14-963e-4cc2-8359-576bfa238066	94173201600014561	stress-41732016-14561@mediqueue.test	Paciente Stress 41732016-14561	55014561	ACTIVO	2026-06-02 23:14:53.042949	2026-06-02 23:14:53.042949	0
c21dcc18-fe2d-4212-897b-9da17ba3b3c9	94173203600014609	stress-41732036-14609@mediqueue.test	Paciente Stress 41732036-14609	55014609	ACTIVO	2026-06-02 23:14:53.16944	2026-06-02 23:14:53.16944	0
7817b023-02b6-46a6-9e7f-7bed6113242f	94173204800014466	stress-41732048-14466@mediqueue.test	Paciente Stress 41732048-14466	55014466	ACTIVO	2026-06-02 23:14:53.307676	2026-06-02 23:14:53.307676	0
376760bd-9e74-40b1-a1c2-042e5eef848f	94173202500013317	stress-41732025-13317@mediqueue.test	Paciente Stress 41732025-13317	55013317	ACTIVO	2026-06-02 23:14:03.268866	2026-06-02 23:14:03.268866	0
b4c52068-c3b2-4765-a397-b5d7c7dec15d	94173202600013386	stress-41732026-13386@mediqueue.test	Paciente Stress 41732026-13386	55013386	ACTIVO	2026-06-02 23:14:04.352665	2026-06-02 23:14:04.352665	0
fd36783f-1a84-47fa-8886-6f9a0759b16d	94173206500013600	stress-41732065-13600@mediqueue.test	Paciente Stress 41732065-13600	55013600	ACTIVO	2026-06-02 23:14:06.556529	2026-06-02 23:14:06.556529	0
6fe03f56-6eae-4823-95fc-a53c41394747	94173197700013616	stress-41731977-13616@mediqueue.test	Paciente Stress 41731977-13616	55013616	ACTIVO	2026-06-02 23:14:06.65023	2026-06-02 23:14:06.65023	0
5c5b989e-bdcf-4b1a-8748-5c188894b5c0	94173202000013819	stress-41732020-13819@mediqueue.test	Paciente Stress 41732020-13819	55013819	ACTIVO	2026-06-02 23:14:08.837477	2026-06-02 23:14:08.837477	0
90dacef1-9785-4580-8973-c1e1ce94fe3a	94173206800013846	stress-41732068-13846@mediqueue.test	Paciente Stress 41732068-13846	55013846	ACTIVO	2026-06-02 23:14:09.024402	2026-06-02 23:14:09.024402	0
6f3e0599-8a0a-4b54-8b32-bcfc2a5d0eb5	94173199100013996	stress-41731991-13996@mediqueue.test	Paciente Stress 41731991-13996	55013996	ACTIVO	2026-06-02 23:14:10.948092	2026-06-02 23:14:10.948092	0
9678b579-fcd4-4d26-bb44-629d29903dbc	94173206400014086	stress-41732064-14086@mediqueue.test	Paciente Stress 41732064-14086	55014086	ACTIVO	2026-06-02 23:14:11.690349	2026-06-02 23:14:11.690349	0
85451bd2-f7d5-437c-9539-1203184a7647	94173198500014257	stress-41731985-14257@mediqueue.test	Paciente Stress 41731985-14257	55014257	ACTIVO	2026-06-02 23:14:13.537809	2026-06-02 23:14:13.537809	0
9a7a3d2a-c02a-44fb-8b60-5927e0f37f33	94173198500014351	stress-41731985-14351@mediqueue.test	Paciente Stress 41731985-14351	55014351	ACTIVO	2026-06-02 23:14:50.735646	2026-06-02 23:14:50.735646	0
0035f3e4-a643-4ca6-bc35-5ed072ed1aa9	94173201500014472	stress-41732015-14472@mediqueue.test	Paciente Stress 41732015-14472	55014472	ACTIVO	2026-06-02 23:14:51.413374	2026-06-02 23:14:51.413374	0
c9925f8c-0bc8-4a1b-94a2-57224ad2ee81	94173205300014411	stress-41732053-14411@mediqueue.test	Paciente Stress 41732053-14411	55014411	ACTIVO	2026-06-02 23:14:52.705746	2026-06-02 23:14:52.705746	0
aad4a817-937f-45f1-a8ce-b955896726a3	94173204900014699	stress-41732049-14699@mediqueue.test	Paciente Stress 41732049-14699	55014699	ACTIVO	2026-06-02 23:14:53.300071	2026-06-02 23:14:53.300071	0
f09474f2-bef9-4c44-a0d1-1d2db1a52ea2	94173203400013311	stress-41732034-13311@mediqueue.test	Paciente Stress 41732034-13311	55013311	ACTIVO	2026-06-02 23:14:03.29444	2026-06-02 23:14:03.29444	0
e25b7710-16f3-47b5-863f-9571766665c6	94173206500013451	stress-41732065-13451@mediqueue.test	Paciente Stress 41732065-13451	55013451	ACTIVO	2026-06-02 23:14:04.992657	2026-06-02 23:14:04.992657	0
f0a02139-da19-4f48-8126-c1b4fdd63797	94173206900013552	stress-41732069-13552@mediqueue.test	Paciente Stress 41732069-13552	55013552	ACTIVO	2026-06-02 23:14:06.18544	2026-06-02 23:14:06.18544	0
0ae75f3c-81da-49ef-844a-7302c55a6ab3	94173206500014066	stress-41732065-14066@mediqueue.test	Paciente Stress 41732065-14066	55014066	ACTIVO	2026-06-02 23:14:11.480811	2026-06-02 23:14:11.480811	0
96abee93-52fb-4b0c-86af-c135db263bf3	94173203900014100	stress-41732039-14100@mediqueue.test	Paciente Stress 41732039-14100	55014100	ACTIVO	2026-06-02 23:14:11.775812	2026-06-02 23:14:11.775812	0
edbdda3f-0fb0-4a69-8512-612f2d6a1ad8	94173197700014238	stress-41731977-14238@mediqueue.test	Paciente Stress 41731977-14238	55014238	ACTIVO	2026-06-02 23:14:13.243875	2026-06-02 23:14:13.243875	0
d0a7dc29-2d30-452a-8076-ae4e46b338a0	94173202600014304	stress-41732026-14304@mediqueue.test	Paciente Stress 41732026-14304	55014304	ACTIVO	2026-06-02 23:14:50.870551	2026-06-02 23:14:50.870551	0
b016f5d8-ea2e-4516-a7bd-d9b2cb5fab2f	94173199300014612	stress-41731993-14612@mediqueue.test	Paciente Stress 41731993-14612	55014612	ACTIVO	2026-06-02 23:14:53.259453	2026-06-02 23:14:53.259453	0
fc275ba2-9830-41f1-bd8c-3268d07b5db1	94173203600013893	stress-41732036-13893@mediqueue.test	Paciente Stress 41732036-13893	55013893	ACTIVO	2026-06-02 23:14:09.687715	2026-06-02 23:14:09.687715	0
0f1fbcc6-a476-4486-8fe6-d517a8de084b	94173200700013972	stress-41732007-13972@mediqueue.test	Paciente Stress 41732007-13972	55013972	ACTIVO	2026-06-02 23:14:10.822882	2026-06-02 23:14:10.822882	0
89cc2ee4-848c-4d73-96c6-4b825cbf9292	94173203600014193	stress-41732036-14193@mediqueue.test	Paciente Stress 41732036-14193	55014193	ACTIVO	2026-06-02 23:14:12.988512	2026-06-02 23:14:12.988512	0
9dfe62a0-e192-4e6f-af16-1689f410f31d	94173205600014316	stress-41732056-14316@mediqueue.test	Paciente Stress 41732056-14316	55014316	ACTIVO	2026-06-02 23:14:51.626395	2026-06-02 23:14:51.626395	0
1d15fe4b-b902-4660-95db-97d7ae7fa061	94173206200014641	stress-41732062-14641@mediqueue.test	Paciente Stress 41732062-14641	55014641	ACTIVO	2026-06-02 23:14:53.178317	2026-06-02 23:14:53.178317	0
c49e465e-2520-480c-a131-0f437dfb0220	94173206000014773	stress-41732060-14773@mediqueue.test	Paciente Stress 41732060-14773	55014773	ACTIVO	2026-06-02 23:14:53.308462	2026-06-02 23:14:53.308462	0
7e25d679-3ce3-4e52-a024-1a982a762e18	94173201600014714	stress-41732016-14714@mediqueue.test	Paciente Stress 41732016-14714	55014714	ACTIVO	2026-06-02 23:14:53.432286	2026-06-02 23:14:53.432286	0
f49d3438-0bd1-4a3d-bada-2ef0fe0346a7	94173202300014818	stress-41732023-14818@mediqueue.test	Paciente Stress 41732023-14818	55014818	ACTIVO	2026-06-02 23:14:53.539582	2026-06-02 23:14:53.539582	0
1e7ed98b-8183-491e-bc1d-b3693ba3e386	94173204700014401	stress-41732047-14401@mediqueue.test	Paciente Stress 41732047-14401	55014401	ACTIVO	2026-06-02 23:14:49.837838	2026-06-02 23:14:49.837838	0
1551db04-316a-4a86-9a79-459e16539c33	94173200800014348	stress-41732008-14348@mediqueue.test	Paciente Stress 41732008-14348	55014348	ACTIVO	2026-06-02 23:14:51.788091	2026-06-02 23:14:51.788091	0
e9800d47-8504-44d9-8e9a-a6d2e0bc691a	94173205200014508	stress-41732052-14508@mediqueue.test	Paciente Stress 41732052-14508	55014508	ACTIVO	2026-06-02 23:14:51.893184	2026-06-02 23:14:51.893184	0
e3f73eee-af63-44f2-8236-77fa0fa37d6e	7894365219685	cecha@gmail.com	Cesar Palacios	45782365	ACTIVO	2026-06-03 00:08:32.491875	2026-06-03 00:08:32.491875	0
\.


--
-- Data for Name: pagos; Type: TABLE DATA; Schema: public; Owner: mediqueue
--

COPY public.pagos (id_pago, cita_id, paciente_id, monto, estado, metodo_pago, referencia, idempotency_key, creado_en, actualizado_en, version) FROM stdin;
\.


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: mediqueue
--

COPY public.payments (id, appointment_id, patient_id, amount, status, idempotency_key, created_at, updated_at, version) FROM stdin;
1	aefdba29-7f83-419d-8a01-37f3323b0728	df7e58c8-adf1-4ea2-ade8-8301ac9e2c96	300.00	SUCCESS	pago-aefdba29-7f83-419d-8a01-37f3323b0728	2026-06-02 07:22:58.95371	2026-06-02 07:22:58.95371	0
2	a0bdc2ed-58eb-4f4f-ab90-9397318a7b48	952c6e62-70a9-4859-81f9-48572560a828	200.00	SUCCESS	pago-a0bdc2ed-58eb-4f4f-ab90-9397318a7b48	2026-06-02 07:26:16.807465	2026-06-02 07:26:16.807465	0
3	6c1f8416-1384-4979-9fa9-6f8eed88b4c5	e7c7f9eb-87b7-418a-b0b1-997c52e51120	180.00	SUCCESS	pago-6c1f8416-1384-4979-9fa9-6f8eed88b4c5	2026-06-02 08:09:44.316865	2026-06-02 08:09:44.316865	0
4	3536d46e-d04c-4661-8e77-fd66fc9b7c38	051c63a7-e758-4231-99f8-f09262fc876b	220.00	SUCCESS	pago-3536d46e-d04c-4661-8e77-fd66fc9b7c38	2026-06-02 10:29:13.232162	2026-06-02 10:29:13.232162	0
5	d99aca75-d530-4fa4-a706-1efc148af7ab	051c63a7-e758-4231-99f8-f09262fc876b	200.00	SUCCESS	pago-d99aca75-d530-4fa4-a706-1efc148af7ab	2026-06-02 10:41:52.432399	2026-06-02 10:41:52.432399	0
6	187f95c0-edde-4846-a3d8-877c83fb9298	df7e58c8-adf1-4ea2-ade8-8301ac9e2c96	230.00	SUCCESS	pago-187f95c0-edde-4846-a3d8-877c83fb9298	2026-06-02 11:37:39.657656	2026-06-02 11:37:39.657656	0
7	ee27330f-0d25-4e39-9353-e494ad4338fe	07937abf-707e-4065-a893-a923baf72322	220.00	SUCCESS	pago-ee27330f-0d25-4e39-9353-e494ad4338fe	2026-06-02 11:47:58.606332	2026-06-02 11:47:58.606332	0
40	78d9852d-8355-4117-86d3-2e09b8c72f31	051c63a7-e758-4231-99f8-f09262fc876b	230.00	SUCCESS	pago-78d9852d-8355-4117-86d3-2e09b8c72f31	2026-06-02 18:11:36.851542	2026-06-02 18:11:36.851542	0
41	ae53445a-eccb-4f23-b7d3-592e01ba4fe2	aa9e2b24-e6f4-4354-a796-156531fca09e	200.00	SUCCESS	pago-ae53445a-eccb-4f23-b7d3-592e01ba4fe2	2026-06-02 18:18:02.01692	2026-06-02 18:18:02.01692	0
\.


--
-- Name: payments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: mediqueue
--

SELECT pg_catalog.setval('public.payments_id_seq', 73, true);


--
-- Name: appointments appointments_pkey; Type: CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_pkey PRIMARY KEY (id);


--
-- Name: citas citas_pkey; Type: CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.citas
    ADD CONSTRAINT citas_pkey PRIMARY KEY (id_cita);


--
-- Name: doctores doctores_pkey; Type: CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.doctores
    ADD CONSTRAINT doctores_pkey PRIMARY KEY (id_doctor);


--
-- Name: especialidades especialidades_pkey; Type: CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.especialidades
    ADD CONSTRAINT especialidades_pkey PRIMARY KEY (id_especialidad);


--
-- Name: eventos_salientes eventos_salientes_pkey; Type: CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.eventos_salientes
    ADD CONSTRAINT eventos_salientes_pkey PRIMARY KEY (id);


--
-- Name: horarios horarios_pkey; Type: CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.horarios
    ADD CONSTRAINT horarios_pkey PRIMARY KEY (id_horario);


--
-- Name: doctores idx_doctors_correo; Type: CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.doctores
    ADD CONSTRAINT idx_doctors_correo UNIQUE (correo);


--
-- Name: pacientes idx_dpi; Type: CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.pacientes
    ADD CONSTRAINT idx_dpi UNIQUE (dpi);


--
-- Name: llaves_idempotencia llaves_idempotencia_idempotency_key_key; Type: CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.llaves_idempotencia
    ADD CONSTRAINT llaves_idempotencia_idempotency_key_key UNIQUE (idempotency_key);


--
-- Name: llaves_idempotencia llaves_idempotencia_pkey; Type: CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.llaves_idempotencia
    ADD CONSTRAINT llaves_idempotencia_pkey PRIMARY KEY (client_id);


--
-- Name: outbox_events outbox_events_pkey; Type: CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.outbox_events
    ADD CONSTRAINT outbox_events_pkey PRIMARY KEY (id);


--
-- Name: pacientes pacientes_correo_key; Type: CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.pacientes
    ADD CONSTRAINT pacientes_correo_key UNIQUE (correo);


--
-- Name: pacientes pacientes_dpi_key; Type: CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.pacientes
    ADD CONSTRAINT pacientes_dpi_key UNIQUE (dpi);


--
-- Name: pacientes pacientes_pkey; Type: CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.pacientes
    ADD CONSTRAINT pacientes_pkey PRIMARY KEY (id_paciente);


--
-- Name: pagos pagos_cita_id_key; Type: CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_cita_id_key UNIQUE (cita_id);


--
-- Name: pagos pagos_pkey; Type: CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_pkey PRIMARY KEY (id_pago);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: idx_doctor_horario_disponible; Type: INDEX; Schema: public; Owner: mediqueue
--

CREATE INDEX idx_doctor_horario_disponible ON public.horarios USING btree (disponible);


--
-- Name: idx_doctor_horario_doctor_id; Type: INDEX; Schema: public; Owner: mediqueue
--

CREATE INDEX idx_doctor_horario_doctor_id ON public.horarios USING btree (doctor_id);


--
-- Name: idx_doctors_activo; Type: INDEX; Schema: public; Owner: mediqueue
--

CREATE INDEX idx_doctors_activo ON public.doctores USING btree (estado);


--
-- Name: ux_appointments_doctor_datetime_jpa; Type: INDEX; Schema: public; Owner: mediqueue
--

CREATE UNIQUE INDEX ux_appointments_doctor_datetime_jpa ON public.appointments USING btree (doctor_id, appointment_date);


--
-- Name: ux_appointments_idempotency_key_jpa; Type: INDEX; Schema: public; Owner: mediqueue
--

CREATE UNIQUE INDEX ux_appointments_idempotency_key_jpa ON public.appointments USING btree (idempotency_key) WHERE (idempotency_key IS NOT NULL);


--
-- Name: ux_appointments_patient_datetime_jpa; Type: INDEX; Schema: public; Owner: mediqueue
--

CREATE UNIQUE INDEX ux_appointments_patient_datetime_jpa ON public.appointments USING btree (patient_id, appointment_date);


--
-- Name: ux_doctor_horario_activo; Type: INDEX; Schema: public; Owner: mediqueue
--

CREATE UNIQUE INDEX ux_doctor_horario_activo ON public.citas USING btree (doctor_id, horario_id) WHERE ((estado_cita)::text = 'CONFIRMADA'::text);


--
-- Name: ux_paciente_horario_activo; Type: INDEX; Schema: public; Owner: mediqueue
--

CREATE UNIQUE INDEX ux_paciente_horario_activo ON public.citas USING btree (paciente_id, horario_id) WHERE ((estado_cita)::text = 'CONFIRMADA'::text);


--
-- Name: ux_payments_appointment_id_jpa; Type: INDEX; Schema: public; Owner: mediqueue
--

CREATE UNIQUE INDEX ux_payments_appointment_id_jpa ON public.payments USING btree (appointment_id);


--
-- Name: ux_payments_idempotency_key_jpa; Type: INDEX; Schema: public; Owner: mediqueue
--

CREATE UNIQUE INDEX ux_payments_idempotency_key_jpa ON public.payments USING btree (idempotency_key) WHERE (idempotency_key IS NOT NULL);


--
-- Name: citas fk_cita_doctor; Type: FK CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.citas
    ADD CONSTRAINT fk_cita_doctor FOREIGN KEY (doctor_id) REFERENCES public.doctores(id_doctor);


--
-- Name: citas fk_cita_horario; Type: FK CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.citas
    ADD CONSTRAINT fk_cita_horario FOREIGN KEY (horario_id) REFERENCES public.horarios(id_horario);


--
-- Name: citas fk_cita_paciente; Type: FK CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.citas
    ADD CONSTRAINT fk_cita_paciente FOREIGN KEY (paciente_id) REFERENCES public.pacientes(id_paciente);


--
-- Name: doctores fk_doctor_especialidad; Type: FK CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.doctores
    ADD CONSTRAINT fk_doctor_especialidad FOREIGN KEY (especialidad_id) REFERENCES public.especialidades(id_especialidad);


--
-- Name: horarios fk_horario_doctor; Type: FK CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.horarios
    ADD CONSTRAINT fk_horario_doctor FOREIGN KEY (doctor_id) REFERENCES public.doctores(id_doctor) ON DELETE CASCADE;


--
-- Name: pagos fk_pago_cita; Type: FK CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT fk_pago_cita FOREIGN KEY (cita_id) REFERENCES public.citas(id_cita);


--
-- Name: pagos fk_pago_paciente; Type: FK CONSTRAINT; Schema: public; Owner: mediqueue
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT fk_pago_paciente FOREIGN KEY (paciente_id) REFERENCES public.pacientes(id_paciente);


--
-- PostgreSQL database dump complete
--

\unrestrict ZhVYvdwQLD9NLCiF8Lgppr9Px0sJAShJh6Mc34EW8CUiPozMr3A1nl6YTA7LArN

