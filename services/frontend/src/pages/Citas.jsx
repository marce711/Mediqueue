import React, { useState, useEffect } from 'react';
import { citaService, pacienteService } from '../services/api';
import { CalendarPlus, Search, Clock, CheckCircle, XCircle } from 'lucide-react';

export default function Citas() {
  const [citas, setCitas] = useState([]);
  const [loading, setLoading] = useState(false);
  const [searchDpi, setSearchDpi] = useState('');
  const [pacienteFound, setPacienteFound] = useState(null);
  const [form, setForm] = useState({ 
    patientId: '', 
    doctorId: 'DOC-001', // Placeholder hasta tener listado de doctores funcional
    appointmentDate: '',
    reason: '' 
  });
  const [message, setMessage] = useState(null);

  useEffect(() => {
    fetchCitas();
  }, []);

  const fetchCitas = async () => {
    try {
      setLoading(true);
      const res = await citaService.listar();
      setCitas(res.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleSearchPaciente = async () => {
    try {
      const res = await pacienteService.obtenerPorDpi(searchDpi);
      setPacienteFound(res.data);
      setForm({ ...form, patientId: res.data.id });
      setMessage(null);
    } catch (err) {
      setPacienteFound(null);
      setMessage({ type: 'error', text: 'Paciente no encontrado' });
    }
  };

  const handleCreateCita = async (e) => {
    e.preventDefault();
    try {
      // 1. Verificar disponibilidad (Lógica estricta conectada al backend)
      const availability = await citaService.verificarDisponibilidad(form.doctorId, form.appointmentDate);
      if (!availability.data.available) {
        setMessage({ type: 'error', text: 'El horario no está disponible' });
        return;
      }

      // 2. Crear cita
      await citaService.crear({
        ...form,
        appointmentDate: new Date(form.appointmentDate).toISOString()
      });
      
      setMessage({ type: 'success', text: 'Cita agendada. Validando en segundo plano via RabbitMQ...' });
      setForm({ patientId: '', doctorId: 'DOC-001', appointmentDate: '', reason: '' });
      setPacienteFound(null);
      setSearchDpi('');
      setTimeout(fetchCitas, 2000); // Dar tiempo a RabbitMQ para procesar
    } catch (err) {
      setMessage({ type: 'error', text: 'Error al agendar la cita' });
    }
  };

  const handleCancel = async (id) => {
    try {
      await citaService.cancelar(id);
      fetchCitas();
    } catch (err) {
      console.error(err);
    }
  };

  return (
    <div className="space-y-8">
      <header>
        <h2 className="text-3xl font-bold text-gray-800">Agendamiento de Citas</h2>
        <p className="text-gray-500">Gestión de turnos y disponibilidad médica.</p>
      </header>

      {message && (
        <div className={`p-4 rounded-lg shadow-sm border ${message.type === 'success' ? 'bg-green-50 border-green-200 text-green-700' : 'bg-red-50 border-red-200 text-red-700'}`}>
          {message.text}
        </div>
      )}

      <div className="grid grid-cols-1 xl:grid-cols-3 gap-8">
        {/* Formulario de Agendamiento */}
        <section className="xl:col-span-1 space-y-6">
          <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
            <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
              <Search size={18} className="text-indigo-600" />
              1. Identificar Paciente
            </h3>
            <div className="flex gap-2">
              <input 
                type="text" 
                placeholder="DPI del paciente"
                className="flex-1 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 bg-gray-50 p-2 text-sm"
                value={searchDpi}
                onChange={e => setSearchDpi(e.target.value)}
              />
              <button 
                onClick={handleSearchPaciente}
                className="bg-indigo-600 text-white p-2 rounded-md hover:bg-indigo-700 transition"
              >
                Buscar
              </button>
            </div>
            {pacienteFound && (
              <div className="mt-4 p-3 bg-indigo-50 rounded-lg text-sm border border-indigo-100">
                <p className="font-bold text-indigo-900">{pacienteFound.nombre}</p>
                <p className="text-indigo-700">DPI: {pacienteFound.dpi}</p>
              </div>
            )}
          </div>

          <div className={`bg-white p-6 rounded-xl shadow-sm border border-gray-100 transition-opacity ${!pacienteFound ? 'opacity-50 pointer-events-none' : ''}`}>
            <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
              <CalendarPlus size={18} className="text-indigo-600" />
              2. Datos de la Cita
            </h3>
            <form onSubmit={handleCreateCita} className="space-y-4">
              <div>
                <label className="block text-xs font-medium text-gray-500 uppercase">Doctor / Especialidad</label>
                <select className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 bg-gray-50 p-2 text-sm">
                  <option value="DOC-001">Dr. Mario Perez - Medicina General</option>
                  <option value="DOC-002">Dra. Ana Gomez - Pediatría</option>
                </select>
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-500 uppercase">Fecha y Hora</label>
                <input 
                  type="datetime-local" 
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 bg-gray-50 p-2 text-sm"
                  value={form.appointmentDate}
                  onChange={e => setForm({...form, appointmentDate: e.target.value})}
                  required
                />
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-500 uppercase">Motivo</label>
                <textarea 
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 bg-gray-50 p-2 text-sm"
                  rows="2"
                  value={form.reason}
                  onChange={e => setForm({...form, reason: e.target.value})}
                ></textarea>
              </div>
              <button 
                type="submit" 
                className="w-full bg-indigo-600 text-white py-2 px-4 rounded-md hover:bg-indigo-700 transition font-semibold"
              >
                Confirmar Reserva
              </button>
            </form>
          </div>
        </section>

        {/* Listado de Citas */}
        <section className="xl:col-span-2 bg-white p-6 rounded-xl shadow-sm border border-gray-100">
          <h3 className="text-xl font-semibold mb-6 flex items-center gap-2 border-b pb-4">
            <Clock size={20} className="text-indigo-600" />
            Agenda del Sistema
          </h3>
          {loading ? (
            <div className="text-center py-20 text-gray-400">Consultando agenda...</div>
          ) : (
            <div className="space-y-4">
              {citas.map(cita => (
                <div key={cita.id} className="flex items-center justify-between p-4 rounded-lg border border-gray-50 hover:bg-gray-50 transition-colors">
                  <div className="flex gap-4 items-center">
                    <div className={`p-2 rounded-full ${cita.status === 'CONFIRMADA' ? 'bg-green-100 text-green-600' : 'bg-yellow-100 text-yellow-600'}`}>
                      {cita.status === 'CONFIRMADA' ? <CheckCircle size={20} /> : <Clock size={20} />}
                    </div>
                    <div>
                      <h4 className="font-bold text-gray-900">Paciente ID: {cita.patientId.substring(0,8)}...</h4>
                      <p className="text-sm text-gray-500">
                        {new Date(cita.appointmentDate).toLocaleString()} - {cita.reason || 'Consulta general'}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className={`px-3 py-1 rounded-full text-xs font-bold ${
                      cita.status === 'CONFIRMADA' ? 'bg-green-100 text-green-700' : 
                      cita.status === 'CANCELADA' ? 'bg-red-100 text-red-700' : 'bg-blue-100 text-blue-700'
                    }`}>
                      {cita.status}
                    </span>
                    {cita.status !== 'CANCELADA' && (
                      <button 
                        onClick={() => handleCancel(cita.id)}
                        className="text-gray-400 hover:text-red-500 transition-colors"
                        title="Cancelar cita"
                      >
                        <XCircle size={20} />
                      </button>
                    )}
                  </div>
                </div>
              ))}
              {citas.length === 0 && (
                <div className="text-center py-20 text-gray-400 italic">No hay citas agendadas para este periodo.</div>
              )}
            </div>
          )}
        </section>
      </div>
    </div>
  );
}
