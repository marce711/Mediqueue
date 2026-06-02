import React, { useState, useEffect, useMemo } from 'react';
import { citaService, pacienteService, doctorService } from '../services/api';
import { Activity, Calendar as CalendarIcon, Clock, Search, User, Filter, Trash2, X, ChevronLeft, ChevronRight, Hash, CalendarPlus, UserPlus } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

const DOCTOR_COLORS = [
  'bg-blue-100 text-blue-800 border-blue-200',
  'bg-purple-100 text-purple-800 border-purple-200',
  'bg-emerald-100 text-emerald-800 border-emerald-200',
  'bg-rose-100 text-rose-800 border-rose-200',
  'bg-amber-100 text-amber-800 border-amber-200',
  'bg-indigo-100 text-indigo-800 border-indigo-200',
  'bg-teal-100 text-teal-800 border-teal-200',
  'bg-orange-100 text-orange-800 border-orange-200',
];

export default function Citas() {
  const navigate = useNavigate();
  const [citas, setCitas] = useState([]);
  const [doctores, setDoctores] = useState([]);
  const [selectedDoctorId, setSelectedDoctorId] = useState('all');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [showIds, setShowIds] = useState(false);
  
  // Agendamiento State
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

  // Vista de Calendario
  const [viewDate, setViewDate] = useState(new Date());
  
  useEffect(() => {
    fetchDoctores();
    fetchCitas();
  }, [selectedDoctorId]);

  const fetchDoctores = async () => {
    try {
      const res = await doctorService.listar();
      setDoctores(res.data);
    } catch (err) {
      console.error('Error al cargar doctores:', err);
    }
  };

  const fetchCitas = async () => {
    try {
      setLoading(true);
      setError(null);
      const params = selectedDoctorId !== 'all' ? { doctorId: selectedDoctorId } : {};
      const res = await citaService.listar(params);
      setCitas(res.data);
    } catch (err) {
      console.error('Error al cargar citas:', err);
      setError('No se pudieron cargar las citas.');
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
      setMessage({ type: 'error', text: 'El paciente con el DPI ingresado no existe.' });
    }
  };

  const handleCheckAvailability = async () => {
    if (!form.doctorId || !form.appointmentDate) {
      setMessage({ type: 'error', text: 'Seleccione doctor y fecha.' });
      return;
    }
    try {
      setLoading(true);
      const res = await citaService.verificarDisponibilidad(form.doctorId, form.appointmentDate, form.durationMinutes);
      setAvailability(res.data);
      setMessage({
        type: res.data.available ? 'success' : 'error',
        text: res.data.available ? 'Horario disponible.' : 'Horario no disponible.',
      });
    } catch (err) {
      const detail = err.response?.data?.message || err.response?.data?.error;
      setMessage({ type: 'error', text: detail || 'Error al validar disponibilidad.' });
    } finally {
      setLoading(false);
    }
  };

  const handleCreateCita = async (e) => {
    e.preventDefault();
    if (!form.patientId || !availability?.available) return;
    try {
      setLoading(true);
      const idempotencyKey = `cita-${form.patientId}-${form.doctorId}-${form.appointmentDate}-${form.durationMinutes}`;
      const res = await citaService.crear(form, idempotencyKey);
      setMessage({ type: 'success', text: 'Cita creada.' });
      setForm({ patientId: '', doctorId: '', appointmentDate: '', durationMinutes: 30, reason: '' });
      setPacienteFound(null);
      setSearchDpi('');
      setAvailability(null);
      fetchCitas();
      navigate(`/pagos?appointmentId=${res.data.id}&amount=${res.data.consultationPrice}`);
    } catch (err) {
      const detail = err.response?.data?.message || err.response?.data?.error;
      setMessage({ type: 'error', text: detail || 'Error al crear cita.' });
    } finally {
      setLoading(false);
    }
  };

  const handleCancelar = async (id) => {
    if (!window.confirm('¿Esta seguro de que desea cancelar esta cita?')) return;
    try {
      setLoading(true);
      await citaService.cancelar(id);
      fetchCitas();
      alert('Cita cancelada con exito.');
    } catch (err) {
      const detail = err.response?.data?.message || err.response?.data?.error;
      alert(detail || 'No se pudo cancelar la cita. Verifique la regla de 48 horas.');
    } finally {
      setLoading(false);
    }
  };

  const doctorColorsMap = useMemo(() => {
    const map = {};
    doctores.forEach((doc, i) => {
      map[doc.id] = DOCTOR_COLORS[i % DOCTOR_COLORS.length];
    });
    return map;
  }, [doctores]);

  const calendarDays = useMemo(() => {
    const start = new Date(viewDate.getFullYear(), viewDate.getMonth(), 1);
    const end = new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 0);
    const days = [];
    for (let i = 0; i < start.getDay(); i++) days.push(null);
    for (let i = 1; i <= end.getDate(); i++) {
      const date = new Date(viewDate.getFullYear(), viewDate.getMonth(), i);
      const dayCitas = citas.filter(c => {
        const cDate = new Date(c.appointmentDate);
        return cDate.getDate() === i && cDate.getMonth() === viewDate.getMonth() && cDate.getFullYear() === viewDate.getFullYear();
      });
      days.push({ date, citas: dayCitas });
    }
    return days;
  }, [viewDate, citas]);

  const selectedDoctor = doctores.find(d => d.id === form.doctorId);

  return (
    <div className="mx-auto max-w-7xl space-y-8 py-2">
      <header className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
        <p className="text-sm font-semibold uppercase tracking-wider text-[#2f6f62]">MediQueue</p>
        <h2 className="mt-2 text-3xl font-bold text-slate-950">Gestion de Citas</h2>
      </header>

      <div className="grid gap-6 lg:grid-cols-[340px_1fr]">
        <aside className="space-y-6">
          {/* Nueva Cita */}
          <section className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
            <h3 className="mb-5 flex items-center gap-2 text-lg font-bold text-slate-950">
              <CalendarPlus size={20} className="text-[#2f6f62]" />
              Nueva Cita
            </h3>
            <div className="space-y-4">
              <div className="pb-4 border-b border-slate-100">
                <label className="text-xs font-bold uppercase text-slate-500">Paciente (DPI)</label>
                <div className="mt-2 flex gap-2">
                  <input 
                    className="flex-1 rounded-md border border-slate-300 p-2 text-sm focus:border-[#2f6f62] focus:outline-none"
                    value={searchDpi}
                    onChange={e => setSearchDpi(e.target.value)}
                  />
                  <button onClick={handleSearchPaciente} className="p-2 bg-slate-100 rounded-md hover:bg-slate-200">
                    <Search size={16} />
                  </button>
                </div>
                {pacienteFound && (
                  <div className="mt-2 text-xs font-semibold text-[#2f6f62] bg-[#e0eee8] p-2 rounded">
                    {pacienteFound.nombre}
                  </div>
                )}
              </div>
              <form onSubmit={handleCreateCita} className="space-y-4">
                <div>
                  <label className="text-xs font-bold uppercase text-slate-500">Doctor</label>
                  <select 
                    className="mt-1 w-full rounded-md border border-slate-300 p-2 text-sm"
                    value={form.doctorId}
                    onChange={e => {setForm({...form, doctorId: e.target.value}); setAvailability(null);}}
                  >
                    <option value="">Seleccione...</option>
                    {doctores.filter(d => d.activo).map(doc => (
                      <option key={doc.id} value={doc.id}>{doc.nombre}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="text-xs font-bold uppercase text-slate-500">Fecha y Hora</label>
                  <input 
                    type="datetime-local"
                    className="mt-1 w-full rounded-md border border-slate-300 p-2 text-sm"
                    value={form.appointmentDate}
                    onChange={e => {setForm({...form, appointmentDate: e.target.value}); setAvailability(null);}}
                  />
                </div>
                <div className="flex gap-3">
                   <button type="button" onClick={handleCheckAvailability} className="flex-1 rounded-md bg-slate-100 py-2 text-xs font-bold text-slate-700 hover:bg-slate-200">
                    Validar
                  </button>
                  <button type="submit" disabled={!availability?.available} className="flex-1 rounded-md bg-[#12312b] py-2 text-xs font-bold text-white hover:bg-[#1b493f] disabled:opacity-50">
                    Agendar
                  </button>
                </div>
                {message && <p className={`text-[10px] font-bold ${message.type === 'success' ? 'text-green-600' : 'text-red-600'}`}>{message.text}</p>}
              </form>
            </div>
          </section>

          {/* Filtros */}
          <section className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
            <h3 className="mb-4 flex items-center gap-2 font-bold text-slate-900">
              <Filter size={18} />
              Filtros Calendario
            </h3>
            <div className="space-y-4">
              <select
                className="w-full rounded-md border border-slate-300 p-2 text-sm focus:border-[#2f6f62] focus:outline-none"
                value={selectedDoctorId}
                onChange={(e) => setSelectedDoctorId(e.target.value)}
              >
                <option value="all">Todos los doctores</option>
                {doctores.map(doc => <option key={doc.id} value={doc.id}>{doc.nombre}</option>)}
              </select>
              <div className="flex items-center gap-2">
                <input type="checkbox" id="showIds" checked={showIds} onChange={() => setShowIds(!showIds)} className="rounded border-slate-300 text-[#2f6f62]" />
                <label htmlFor="showIds" className="text-xs text-slate-700 font-medium">Ver IDs detallados</label>
              </div>
            </div>
          </section>
        </aside>

        <main className="space-y-6">
          {/* Calendario */}
          <section className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
            <div className="mb-6 flex items-center justify-between">
              <h3 className="text-xl font-bold text-slate-900 uppercase">
                {viewDate.toLocaleString('default', { month: 'long', year: 'numeric' })}
              </h3>
              <div className="flex gap-2">
                <button onClick={() => setViewDate(new Date(viewDate.getFullYear(), viewDate.getMonth() - 1, 1))} className="p-2 hover:bg-slate-100 rounded-full transition"><ChevronLeft size={20} /></button>
                <button onClick={() => setViewDate(new Date())} className="px-3 py-1 text-sm font-bold bg-slate-100 rounded hover:bg-slate-200">Hoy</button>
                <button onClick={() => setViewDate(new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 1))} className="p-2 hover:bg-slate-100 rounded-full transition"><ChevronRight size={20} /></button>
              </div>
            </div>

            <div className="grid grid-cols-7 gap-px bg-slate-200 overflow-hidden rounded-md border border-slate-200">
              {['Dom', 'Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab'].map(d => <div key={d} className="bg-slate-50 py-2 text-center text-[10px] font-bold uppercase text-slate-500">{d}</div>)}
              {calendarDays.map((day, i) => (
                <div key={i} className={`min-h-[110px] bg-white p-2 ${day ? '' : 'bg-slate-50/50'}`}>
                  {day && (
                    <>
                      <span className={`text-xs font-bold ${day.date.toDateString() === new Date().toDateString() ? 'bg-blue-600 text-white w-5 h-5 inline-grid place-items-center rounded-full' : 'text-slate-400'}`}>{day.date.getDate()}</span>
                      <div className="mt-1 space-y-1">
                        {day.citas.slice(0, 3).map(cita => (
                          <div key={cita.id} className={`truncate text-[9px] px-1 py-0.5 rounded border ${doctorColorsMap[cita.doctorId] || 'bg-gray-100 text-gray-700'}`}>
                            {new Date(cita.appointmentDate).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})} {cita.patientName}
                          </div>
                        ))}
                        {day.citas.length > 3 && <div className="text-[8px] text-center text-slate-400 font-bold">+{day.citas.length - 3} mas</div>}
                      </div>
                    </>
                  )}
                </div>
              ))}
            </div>
          </section>

          {/* Agenda Table */}
          <section className="rounded-md bg-white shadow-sm ring-1 ring-slate-200 overflow-hidden">
             <div className="border-b border-slate-100 p-6 bg-slate-50/50">
              <h3 className="text-lg font-bold text-slate-900">Agenda de Citas</h3>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead className="bg-slate-50 text-[10px] font-bold uppercase text-slate-500">
                  <tr>
                    <th className="px-6 py-4">Fecha / Hora</th>
                    <th className="px-6 py-4">Paciente</th>
                    <th className="px-6 py-4">Especialista</th>
                    <th className="px-6 py-4 text-center">Estado</th>
                    <th className="px-6 py-4 text-center">Accion</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {citas.map(cita => (
                    <tr key={cita.id} className="hover:bg-slate-50 transition">
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-2 font-bold text-slate-900">
                          <Clock size={12} className="text-blue-500" />
                          {new Date(cita.appointmentDate).toLocaleString()}
                        </div>
                        {showIds && <div className="mt-1 font-mono text-[9px] text-slate-400">ID: {cita.id}</div>}
                      </td>
                      <td className="px-6 py-4">
                        <div className="font-semibold text-slate-700">{cita.patientName}</div>
                        {showIds && (
                          <div className="mt-1 flex items-center gap-2 font-mono text-[9px] text-slate-400">
                            ID: {cita.patientId}
                            <button onClick={() => navigator.clipboard.writeText(cita.patientId)} className="text-blue-400 hover:underline">Copiar</button>
                          </div>
                        )}
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-2 font-semibold text-slate-700">
                          <div className={`h-2 w-2 rounded-full ${doctorColorsMap[cita.doctorId]?.split(' ')[0] || 'bg-gray-400'}`}></div>
                          {cita.doctorName}
                        </div>
                        {showIds && (
                          <div className="mt-1 flex items-center gap-2 font-mono text-[9px] text-slate-400">
                            ID: {cita.doctorId}
                            <button onClick={() => navigator.clipboard.writeText(cita.doctorId)} className="text-blue-400 hover:underline">Copiar</button>
                          </div>
                        )}
                      </td>
                      <td className="px-6 py-4 text-center">
                        <span className={`px-2 py-0.5 rounded-full text-[9px] font-bold border ${
                          cita.status === 'CONFIRMED' ? 'bg-green-100 text-green-800 border-green-200' : 
                          cita.status === 'CANCELLED' ? 'bg-red-100 text-red-800 border-red-200' : 
                          'bg-blue-100 text-blue-800 border-blue-200'
                        }`}>
                          {cita.status}
                        </span>
                      </td>
                      <td className="px-6 py-4 text-center">
                        {cita.status !== 'CANCELLED' && (
                          <button onClick={() => handleCancelar(cita.id)} className="text-red-400 hover:text-red-600 transition"><Trash2 size={16} /></button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {citas.length === 0 && !loading && <div className="py-16 text-center text-slate-400 italic">No hay registros.</div>}
            </div>
          </section>
        </main>
      </div>
    </div>
  );
}
