import axios from 'axios';

const API_BASE_URL = import.meta.env.VITE_API_URL || '';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

export const pacienteService = {
  listar: () => api.get('/api/pacientes'),
  obtenerPorDpi: (dpi) => api.get(`/api/pacientes/dpi/${dpi}`),
  crear: (data) => api.post('/api/pacientes', data),
};

export const doctorService = {
  listar: () => api.get('/api/horarios/doctores'),
  crear: (data) => api.post('/api/horarios/doctores', data),
  obtenerHorarios: (doctorId) => api.get(`/api/horarios/doctor/${doctorId}`),
};

export const citaService = {
  listar: (params) => api.get('/api/v1/appointments', { params }),
  crear: (data, idempotencyKey) => 
    api.post('/api/v1/appointments', data, {
      headers: idempotencyKey ? { 'Idempotency-Key': idempotencyKey } : {},
    }),
  verificarDisponibilidad: (doctorId, date) => 
    api.get('/api/v1/appointments/availability', {
      params: { doctorId, appointmentDate: date },
    }),
  cancelar: (id) => api.delete(`/api/v1/appointments/${id}`),
};

export const pagoService = {
  listarPorPaciente: (pacienteId) => api.get(`/api/payments/paciente/${pacienteId}`),
  obtenerPorCita: (appointmentId) => api.get(`/api/payments/appointment/${appointmentId}`),
  procesar: (data) => api.post('/api/payments', data),
};

export default api;
