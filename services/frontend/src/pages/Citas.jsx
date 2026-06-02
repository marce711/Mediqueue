import React, { useState, useEffect } from 'react';
import { citaService, pacienteService, doctorService } from '../services/api';
import { Activity, CalendarPlus, Clock, Search, User } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

export default function Citas() {
  const navigate = useNavigate();
  const [citas, setCitas] = useState([]);
  const [doctores, setDoctores] = useState([]);
  const [loading, setLoading] = useState(false);
  const [searchDpi, setSearchDpi] = useState('');
  const [pacienteFound, setPacienteFound] = useState(null);
  const [form, setForm] = useState({ 
    patientId: '', 
    doctorId: '', 
    appointmentDate: '',
    durationMinutes: 30,
    reason: '' 
  });
  const [message, setMessage] = useState(null);
  const [availability, setAvailability] = useState(null);

  const selectedDoctor = doctores.find(doctor => doctor.id === form.doctorId);
  const selectedPrice = selectedDoctor?.consultationPrice;

  useEffect(() => {
    fetchCitas();
    fetchDoctores();
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

  const fetchDoctores = async () => {
    try {
      const res = await doctorService.listar();
      setDoctores(Array.isArray(res.data) ? res.data : []);
    } catch (err) {
      console.error('Error cargando doctores:', err);
      setDoctores([]);
      setMessage({ type: 'error', text: 'No se pudieron cargar los doctores. Verifique que doctor-horario y el API Gateway esten activos.' });
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
      setMessage({ type: 'error', text: 'El paciente con el DPI ingresado no existe en el sistema.' });
    }
  };

  const handleCheckAvailability = async () => {
    if (!form.doctorId || !form.appointmentDate) {
      setMessage({ type: 'error', text: 'Seleccione doctor, fecha y hora antes de validar disponibilidad.' });
      return;
    }

    try {
      setLoading(true);
      setAvailability(null);
      const res = await citaService.verificarDisponibilidad(form.doctorId, form.appointmentDate, form.durationMinutes);
      setAvailability(res.data);
      setMessage({
        type: res.data.available ? 'success' : 'error',
        text: res.data.available
          ? 'Horario disponible. Puede crear la cita pendiente y continuar al pago.'
          : 'El doctor no esta disponible en la fecha y hora seleccionada.',
      });
    } catch (err) {
      const detail = err.response?.data?.message || err.response?.data?.error;
      setAvailability(null);
      setMessage({ type: 'error', text: detail || 'No se pudo validar la disponibilidad del doctor.' });
    } finally {
      setLoading(false);
    }
  };

  const handleCreateCita = async (e) => {
    e.preventDefault();
    if (!form.patientId) {
      setMessage({ type: 'error', text: 'Debe validar un paciente antes de agendar.' });
      return;
    }
    if (!availability?.available || availability.doctorId !== form.doctorId) {
      setMessage({ type: 'error', text: 'Debe verificar disponibilidad para este doctor y horario antes de crear la cita.' });
      return;
    }
    
    try {
      setLoading(true);
      const idempotencyKey = `cita-${form.patientId}-${form.doctorId}-${form.appointmentDate}-${form.durationMinutes}`;
      const res = await citaService.crear(form, idempotencyKey);
      setMessage({ type: 'success', text: `Cita pendiente creada. Complete el pago para confirmar. ID: ${res.data.id}` });
      setForm({ patientId: '', doctorId: '', appointmentDate: '', durationMinutes: 30, reason: '' });
      setPacienteFound(null);
      setSearchDpi('');
      setAvailability(null);
      fetchCitas();
      navigate(`/pagos?appointmentId=${res.data.id}&amount=${res.data.consultationPrice}`);
    } catch (err) {
      const detail = err.response?.data?.message || err.response?.data?.error;
      setMessage({ type: 'error', text: detail || 'Error al crear la cita pendiente. Verifique la disponibilidad del horario.' });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-6xl mx-auto space-y-10 py-6">
      <header className="border-b border-gray-200 pb-6">
        <h2 className="text-2xl font-semibold text-gray-900">Agenda de Citas Médicas</h2>
        <p className="text-gray-500 mt-1">Control de citas, validación de disponibilidad y asignación de especialistas.</p>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-10">
        {/* Panel de Agendamiento */}
        <div className="lg:col-span-1 space-y-6">
          <div className="bg-white p-6 rounded-lg border border-gray-200 shadow-sm">
            <h3 className="text-lg font-medium text-gray-900 mb-6 flex items-center gap-2">
              <CalendarPlus size={20} className="text-blue-600" />
              Agendar Nueva Cita
            </h3>

            <div className="space-y-4">
              {/* Buscador de Paciente */}
              <div className="pb-4 border-b border-gray-100">
                <label className="block text-xs font-semibold text-gray-500 uppercase mb-2">Validar Paciente (DPI)</label>
                <div className="flex gap-2">
                  <input 
                    type="text" 
                    placeholder="Ingrese DPI"
                    className="flex-1 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 p-2 text-sm border"
                    value={searchDpi}
                    onChange={e => setSearchDpi(e.target.value)}
                  />
                  <button 
                    onClick={handleSearchPaciente}
                    className="p-2 bg-gray-100 rounded-md hover:bg-gray-200 text-gray-600"
                  >
                    <Search size={18} />
                  </button>
                </div>
                {pacienteFound && (
                  <div className="mt-3 p-2 bg-blue-50 rounded border border-blue-100 flex items-center gap-2">
                    <User size={14} className="text-blue-600" />
                    <span className="text-xs font-medium text-blue-800">{pacienteFound.nombre}</span>
                  </div>
                )}
              </div>

              <form onSubmit={handleCreateCita} className="space-y-4 pt-2">
                <div>
                  <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Especialista</label>
                  <select 
                    required
                    className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 p-2.5 text-sm border bg-white"
                    value={form.doctorId}
                    onChange={e => {
                      setForm({...form, doctorId: e.target.value});
                      setAvailability(null);
                    }}
                  >
                    <option value="">Seleccione un doctor...</option>
                    {doctores.map(doc => (
                      <option key={doc.id} value={doc.id}>
                        {doc.nombre} - {doc.specialtyName} - Q {Number(doc.consultationPrice || 0).toFixed(2)}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Fecha y Hora</label>
                  <input 
                    required
                    type="datetime-local" 
                    className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 p-2.5 text-sm border"
                    value={form.appointmentDate}
                    onChange={e => {
                      setForm({...form, appointmentDate: e.target.value});
                      setAvailability(null);
                    }}
                  />
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Duración</label>
                    <select
                      className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 p-2.5 text-sm border bg-white"
                      value={form.durationMinutes}
                      onChange={e => {
                        setForm({ ...form, durationMinutes: Number(e.target.value) });
                        setAvailability(null);
                      }}
                    >
                      <option value={20}>20 minutos</option>
                      <option value={30}>30 minutos</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Precio</label>
                    <div className="rounded-md border border-gray-200 bg-gray-50 p-2.5 text-sm font-semibold text-gray-800">
                      {selectedPrice ? `Q ${Number(selectedPrice).toFixed(2)}` : 'Seleccione doctor'}
                    </div>
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-gray-500 uppercase mb-1">Motivo de Consulta</label>
                  <textarea 
                    className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 p-2.5 text-sm border"
                    rows="3"
                    value={form.reason}
                    onChange={e => setForm({...form, reason: e.target.value})}
                  ></textarea>
                </div>

                <button
                  type="button"
                  onClick={handleCheckAvailability}
                  disabled={loading || !form.doctorId || !form.appointmentDate}
                  className="w-full rounded-md border border-blue-200 bg-blue-50 py-3 text-sm font-medium text-blue-700 transition hover:bg-blue-100 disabled:opacity-50"
                >
                  Verificar disponibilidad
                </button>

                <button 
                  type="submit"
                  disabled={loading || !availability?.available}
                  className="w-full bg-blue-600 text-white py-3 rounded-md hover:bg-blue-700 transition font-medium text-sm shadow-sm disabled:opacity-50"
                >
                  {loading ? 'Procesando...' : 'Crear cita pendiente y pagar'}
                </button>
              </form>

              {message && (
                <div className={`p-4 rounded-md text-sm ${
                  message.type === 'success' ? 'bg-green-50 text-green-700 border border-green-200' : 'bg-red-50 text-red-700 border border-red-200'
                }`}>
                  {message.text}
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Listado de Citas */}
        <div className="lg:col-span-2 space-y-6">
          <h3 className="text-lg font-medium text-gray-900">Agenda del Día</h3>
          
          <div className="bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden">
            <table className="min-w-full divide-y divide-gray-200 text-sm">
              <thead className="bg-gray-50 text-gray-500">
                <tr>
                  <th className="px-6 py-4 text-left font-semibold uppercase tracking-wider">Fecha / Hora</th>
                  <th className="px-6 py-4 text-left font-semibold uppercase tracking-wider">Paciente</th>
                  <th className="px-6 py-4 text-left font-semibold uppercase tracking-wider">Especialista</th>
                  <th className="px-6 py-4 text-center font-semibold uppercase tracking-wider">Estado</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {citas.map(cita => (
                  <tr key={cita.id} className="hover:bg-gray-50 transition">
                    <td className="px-6 py-4">
                      <div className="font-medium text-gray-900 flex items-center gap-2">
                        <Clock size={14} className="text-blue-500" />
                        {new Date(cita.appointmentDate).toLocaleString()}
                      </div>
                      <div className="text-xs text-gray-400 font-mono mt-1">
                        Ref: {cita.id?.substring(0,8)} · {cita.durationMinutes || 30} min · Q {Number(cita.consultationPrice || 0).toFixed(2)}
                        <button 
                          onClick={() => {navigator.clipboard.writeText(cita.id); alert('ID de cita copiado');}}
                          className="ml-2 text-blue-400 hover:text-blue-600"
                          title="Copiar ID de cita"
                        >
                          Copiar ID
                        </button>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="text-gray-700 font-medium">{cita.patientName || 'Cargando...'}</div>
                      <div className="flex items-center gap-2 mt-1">
                        <span className="text-[10px] text-gray-400 font-mono">ID: {cita.patientId?.substring(0,8)}...</span>
                        <button 
                          onClick={() => {navigator.clipboard.writeText(cita.patientId); alert('ID de paciente copiado');}}
                          className="text-[10px] text-blue-400 hover:underline"
                        >
                          Copiar
                        </button>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-gray-700">
                      <div className="text-gray-700 font-medium">{cita.doctorName || 'Cargando...'}</div>
                      <div className="flex items-center gap-2 mt-1">
                        <span className="text-[10px] text-gray-400 font-mono">ID: {cita.doctorId?.substring(0,8)}...</span>
                        <button 
                          onClick={() => {navigator.clipboard.writeText(cita.doctorId); alert('ID de doctor copiado');}}
                          className="text-[10px] text-blue-400 hover:underline"
                        >
                          Copiar
                        </button>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <span className={`px-2.5 py-1 rounded-full text-xs font-medium border ${
                        cita.status === 'CONFIRMED' ? 'bg-green-100 text-green-800 border-green-200' : 
                        cita.status === 'CANCELLED' ? 'bg-red-100 text-red-800 border-red-200' : 
                        'bg-blue-100 text-blue-800 border-blue-200'
                      }`}>
                        {cita.status}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {citas.length === 0 && !loading && (
              <div className="py-20 text-center text-gray-400 italic flex flex-col items-center gap-2">
                <Activity size={32} className="text-gray-200" />
                No hay citas agendadas para este periodo.
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
