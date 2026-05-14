# Reporte Actualizado de la Base de Datos - Mediqueue

Este documento detalla la estructura **actualizada** de la base de datos definida en `infrastructure/postgres/init.sql`. Se han verificado las correcciones y la inclusión de nuevas tablas y restricciones.

## 1. Información General
- **Base de Datos:** `mediqueueadmin`
- **Extensiones:** Se incluye `pgcrypto` para el soporte de `gen_random_uuid()`.
- **Estandarización:** Se observa una mejora en la nomenclatura de las llaves primarias (prefijo `id_`) y la traducción de nombres al español.

---

## 2. Definición de Tablas

### 2.1. Tabla: `pacientes`
| Columna | Tipo | Restricciones |
| :--- | :--- | :--- |
| `id_paciente` | UUID | PK, Default `gen_random_uuid()` |
| `dpi` | VARCHAR(30) | NOT NULL, UNIQUE |
| `correo` | VARCHAR(120) | NOT NULL, UNIQUE |
| `estado` | VARCHAR(20) | CHECK ('ACTIVO', 'INACTIVO') |

### 2.2. Tabla: `especialidades`
| Columna | Tipo | Restricciones |
| :--- | :--- | :--- |
| `id_especialidad` | UUID | PK, Default `gen_random_uuid()` |
| `nombre` | VARCHAR(100) | NOT NULL, UNIQUE |

### 2.3. Tabla: `doctores`
| Columna | Tipo | Restricciones |
| :--- | :--- | :--- |
| `id_doctor` | UUID | PK |
| `especialidad_id` | UUID | FK -> `especialidades(id_especialidad)` |

### 2.4. Tabla: `horarios`
| Columna | Tipo | Restricciones |
| :--- | :--- | :--- |
| `id_horario` | UUID | PK |
| `doctor_id` | UUID | FK -> `doctores(id_doctor)` (ON DELETE CASCADE) |

### 2.5. Tabla: `citas` (**NUEVA**)
Esta tabla ha sido agregada para cerrar la brecha de integridad detectada anteriormente.
| Columna | Tipo | Restricciones |
| :--- | :--- | :--- |
| `id_cita` | UUID | PK |
| `paciente_id` | UUID | FK -> `pacientes(id_paciente)` |
| `doctor_id` | UUID | FK -> `doctores(id_doctor)` |
| `horario_id` | UUID | FK -> `horarios(id_horario)` |
| `estado_cita` | VARCHAR(30) | CHECK ('CONFIRMADA', 'CANCELADA', 'PENDIENTE', 'FINALIZADA') |

### 2.6. Tabla: `pagos` (**ACTUALIZADA**)
| Columna | Tipo | Restricciones |
| :--- | :--- | :--- |
| `id_pago` | UUID | PK |
| `cita_id` | UUID | **UNIQUE**, FK -> `citas(id_cita)` |
| `paciente_id` | UUID | FK -> `pacientes(id_paciente)` |
| `estado` | VARCHAR(30) | CHECK ('PENDIENTE', 'PAGADO', 'FALLIDO', 'CANCELADO') |

### 2.7. Tabla: `llaves_idempotencia` (**NUEVA**)
Unifica la gestión de idempotencia en un solo lugar.
| Columna | Tipo | Restricciones |
| :--- | :--- | :--- |
| `client_id` | UUID | PK |
| `idempotency_key`| VARCHAR(120) | UNIQUE, NOT NULL |

### 2.8. Tabla: `eventos_salientes` (**ACTUALIZADA**)
Anteriormente `outbox_events`. Se eliminó la duplicidad y se estandarizaron los nombres.
| Columna | Tipo | Restricciones |
| :--- | :--- | :--- |
| `id` | UUID | PK |
| `status` | VARCHAR(30) | CHECK ('PENDIENTE', 'PROCESADO') |

---

## 3. Índices de Unicidad (Reglas de Negocio)
Se han definido índices parciales para gestionar la disponibilidad en tiempo real:
- **`ux_doctor_horario_activo`**: Un doctor no puede tener dos citas `CONFIRMADA` en el mismo bloque horario.
- **`ux_paciente_horario_activo`**: Un paciente no puede reservar dos citas `CONFIRMADA` para el mismo bloque horario.

---

## 4. Cambios y Mejoras Detectadas
1.  **Integridad Referencial:** Se agregaron todas las llaves foráneas faltantes (FK) en las tablas `citas` y `pagos`.
2.  **Resolución de Duplicados:** La tabla de eventos (Outbox) ahora aparece una sola vez con el nombre `eventos_salientes`.
3.  **Soporte de Citas:** Se definió formalmente la tabla `citas`, permitiendo que el sistema sea funcional y relacionalmente correcto.
4.  **Relación 1:1 en Pagos:** La columna `cita_id` en `pagos` ahora es `UNIQUE`, asegurando que una cita no se pague dos veces.
5.  **Idioma:** Se ha migrado la mayoría de la nomenclatura al español, manteniendo la coherencia técnica.

---

## 5. Estado Final
La base de datos se encuentra **correctamente estructurada y validada**. No se detectan errores sintácticos ni vacíos relacionales en la versión actual del script `init.sql`.

---

## 6. Evolución de la Comunicación (Pendiente)
Se ha identificado la necesidad de migrar las consultas inter-servicios de REST a RabbitMQ. Esto impactará la base de datos de la siguiente manera:
- **Redundancia Controlada:** Se evaluará la creación de tablas de "réplica" o "proyección" en `cita_service` para almacenar datos básicos de `pacientes` y `horarios`, permitiendo validaciones locales sin depender de llamadas externas.
- **Sincronización:** Estas tablas se mantendrán actualizadas mediante el consumo de eventos de RabbitMQ, garantizando consistencia eventual.
