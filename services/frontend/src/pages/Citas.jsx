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
      // Filtrar citas canceladas
      const activeCitas = res.data.filter(c => c.status !== 'CANCELLED');
      setCitas(activeCitas);
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
    if (!window.confirm('¿Está seguro de que desea cancelar esta cita?')) return;
    try {
      setLoading(true);
      await citaService.cancelar(id);
      fetchCitas();
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

  return (
    <div className="mx-auto max-w-[1600px] space-y-8 py-2 px-6">
      <header className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
        <p className="text-sm font-semibold uppercase tracking-wider text-[#2f6f62]">MediQueue</p>
        <h2 className="mt-2 text-3xl font-bold text-slate-950">Agenda Médica Centralizada</h2>
      </header>

      {/* 1. Calendario Ocupa todo el ancho */}
      <section className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
        <div className="mb-6 flex items-center justify-between">
          <div className="flex items-center gap-6">
            <h3 className="text-2xl font-bold text-slate-900 uppercase">
              {viewDate.toLocaleString('default', { month: 'long', year: 'numeric' })}
            </h3>
            <div className="flex gap-2">
              <button onClick={() => setViewDate(new Date(viewDate.getFullYear(), viewDate.getMonth() - 1, 1))} className="p-2 hover:bg-slate-100 rounded-full transition"><ChevronLeft size={24} /></button>
              <button onClick={() => setViewDate(new Date())} className="px-5 py-2 text-sm font-bold bg-[#e0eee8] text-[#12312b] rounded-md hover:bg-[#c9e4d9] transition">Hoy</button>
              <button onClick={() => setViewDate(new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 1))} className="p-2 hover:bg-slate-100 rounded-full transition"><ChevronRight size={24} /></button>
            </div>
          </div>
          <div className="hidden md:flex gap-4">
             {doctores.filter(d => d.activo).slice(0, 6).map(doc => (
               <div key={doc.id} className="flex items-center gap-2 text-xs font-bold text-slate-500">
                 <div className={`h-3 w-3 rounded-full ${doctorColorsMap[doc.id]?.split(' ')[0] || 'bg-gray-200'}`}></div>
                 {doc.nombre.split(' ')[0]}
               </div>
             ))}
          </div>
        </div>

        <div className="grid grid-cols-7 gap-px bg-slate-200 overflow-hidden rounded-md border border-slate-200">
          {['Domingo', 'Lunes', 'Martes', 'Miercoles', 'Jueves', 'Viernes', 'Sabado'].map(d => (
            <div key={d} className="bg-slate-50 py-3 text-center text-xs font-bold uppercase text-slate-500">{d}</div>
          ))}
          {calendarDays.map((day, i) => (
            <div key={i} className={`min-h-[140px] bg-white p-3 ${day ? '' : 'bg-slate-50/50'}`}>
              {day && (
                <>
                  <span className={`text-sm font-bold ${day.date.toDateString() === new Date().toDateString() ? 'bg-blue-600 text-white w-6 h-6 inline-grid place-items-center rounded-full shadow-md' : 'text-slate-400'}`}>{day.date.getDate()}</span>
                  <div className="mt-2 space-y-1.5">
                    {day.citas.map(cita => (
                      <div key={cita.id} className={`truncate text-[10px] px-2 py-1.5 rounded-md border shadow-sm font-semibold ${doctorColorsMap[cita.doctorId] || 'bg-gray-100 text-gray-700'}`}>
                        <span>{new Date(cita.appointmentDate).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}</span> {cita.patientName}
                      </div>
                    ))}
                  </div>
                </>
              )}
            </div>
          ))}
        </div>
      </section>

      {/* 2. Fila Inferior: Sidebar y Tabla */}
      <div className="grid gap-6 lg:grid-cols-[340px_1fr]">
        <aside className="space-y-6">
          <section className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
            <h3 className="mb-5 flex items-center gap-2 text-lg font-bold text-slate-950">
              <CalendarPlus size={20} className="text-[#2f6f62]" />
              Agendar Nueva Cita
            </h3>
            <div className="space-y-4">
              <div className="pb-4 border-b border-slate-100">
                <label className="text-xs font-bold uppercase text-slate-500">Paciente (DPI)</label>
                <div className="mt-2 flex gap-2">
                  <input 
                    className="flex-1 rounded-md border border-slate-300 p-2 text-sm focus:border-[#2f6f62] focus:outline-none"
                    placeholder="Busque por DPI..."
                    value={searchDpi}
                    onChange={e => setSearchDpi(e.target.value)}
                  />
                  <button onClick={handleSearchPaciente} className="p-2 bg-slate-100 rounded-md hover:bg-slate-200">
                    <Search size={16} />
                  </button>
                </div>
                {pacienteFound && (
                  <div className="mt-3 p-3 bg-[#e0eee8] text-[#12312b] rounded border border-[#2f6f62]/10">
                    <p className="text-xs font-bold uppercase opacity-60">Paciente Seleccionado</p>
                    <p className="font-bold text-sm mt-1">{pacienteFound.nombre}</p>
                  </div>
                )}
              </div>
              <form onSubmit={handleCreateCita} className="space-y-4">
                <div>
                  <label className="text-xs font-bold uppercase text-slate-500">Especialista</label>
                  <select 
                    className="mt-1 w-full rounded-md border border-slate-300 p-2 text-sm focus:ring-2 focus:ring-[#2f6f62]/20"
                    value={form.doctorId}
                    onChange={e => {setForm({...form, doctorId: e.target.value}); setAvailability(null);}}
                  >
                    <option value="">Seleccione...</option>
                    {doctores.filter(d => d.activo).map(doc => (
                      <option key={doc.id} value={doc.id}>{doc.nombre} ({doc.specialtyName})</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="text-xs font-bold uppercase text-slate-500">Fecha y Hora</label>
                  <input 
                    type="datetime-local"
                    className="mt-1 w-full rounded-md border border-slate-300 p-2 text-sm focus:ring-2 focus:ring-[#2f6f62]/20"
                    value={form.appointmentDate}
                    onChange={e => {setForm({...form, appointmentDate: e.target.value}); setAvailability(null);}}
                  />
                </div>
                <div className="grid grid-cols-2 gap-3 pt-2">
                   <button type="button" onClick={handleCheckAvailability} className="rounded-md border-2 border-[#12312b] py-2.5 text-xs font-bold text-[#12312b] hover:bg-[#12312b] hover:text-white transition">
                    Validar
                  </button>
                  <button type="submit" disabled={!availability?.available} className="rounded-md bg-[#12312b] py-2.5 text-xs font-bold text-white hover:bg-[#1b493f] disabled:opacity-30 shadow-md">
                    Agendar
                  </button>
                </div>
                {message && (
                  <div className={`p-3 rounded-md text-[11px] font-bold ring-1 ${message.type === 'success' ? 'bg-green-50 text-green-700 ring-green-200' : 'bg-red-50 text-red-700 ring-red-200'}`}>
                    {message.text}
                  </div>
                )}
              </form>
            </div>
          </section>

          <section className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
            <h3 className="mb-4 flex items-center gap-2 font-bold text-slate-900">
              <Filter size={18} />
              Configuración de Vista
            </h3>
            <div className="space-y-4">
              <div>
                <label className="text-[10px] font-bold uppercase text-slate-500">Filtrar por Especialista</label>
                <select
                  className="mt-1 w-full rounded-md border border-slate-300 p-2 text-sm focus:border-[#2f6f62] focus:outline-none"
                  value={selectedDoctorId}
                  onChange={(e) => setSelectedDoctorId(e.target.value)}
                >
                  <option value="all">Todos los doctores</option>
                  {doctores.map(doc => <option key={doc.id} value={doc.id}>{doc.nombre}</option>)}
                </select>
              </div>
              <div className="flex items-center gap-2 pt-2">
                <input type="checkbox" id="showIds" checked={showIds} onChange={() => setShowIds(!showIds)} className="h-4 w-4 rounded border-slate-300 text-[#2f6f62] focus:ring-[#2f6f62]" />
                <label htmlFor="showIds" className="text-xs text-slate-700 font-bold select-none cursor-pointer">Ver IDs detallados (UUID)</label>
              </div>
            </div>
          </section>
        </aside>

        {/* Agenda Table */}
        <section className="rounded-md bg-white shadow-sm ring-1 ring-slate-200 overflow-hidden self-start">
           <div className="border-b border-slate-100 p-6 bg-slate-50/50 flex justify-between items-center">
            <h3 className="text-xl font-bold text-slate-900">Listado de Agenda Activa</h3>
            <Activity size={20} className="text-[#2f6f62]" />
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="bg-slate-50 text-[10px] font-bold uppercase text-slate-500">
                <tr>
                  <th className="px-6 py-4">Horario</th>
                  <th className="px-6 py-4">Paciente</th>
                  <th className="px-6 py-4">Especialista</th>
                  <th className="px-6 py-4 text-center">Estado</th>
                  <th className="px-6 py-4 text-center">Acciones</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {citas.map(cita => (
                  <tr key={cita.id} className="hover:bg-slate-50/80 transition-colors">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-2 font-bold text-slate-900">
                        <Clock size={14} className="text-blue-500" />
                        {new Date(cita.appointmentDate).toLocaleString([], { dateStyle: 'short', timeStyle: 'short' })}
                      </div>
                      {showIds && <div className="mt-1 font-mono text-[9px] text-slate-400">ID: {cita.id}</div>}
                    </td>
                    <td className="px-6 py-4">
                      <div className="font-bold text-slate-700">{cita.patientName || 'Cargando...'}</div>
                      {showIds && (
                        <div className="mt-1 flex items-center gap-2 font-mono text-[9px] text-slate-400">
                          ID: {cita.patientId}
                          <button onClick={() => {navigator.clipboard.writeText(cita.patientId); alert('ID Copiado');}} className="text-blue-500 hover:underline">Copiar</button>
                        </div>
                      )}
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-2 font-bold text-slate-700">
                        <div className={`h-2.5 w-2.5 rounded-full shadow-sm ${doctorColorsMap[cita.doctorId]?.split(' ')[0] || 'bg-gray-400'}`}></div>
                        {cita.doctorName || 'Cargando...'}
                      </div>
                      {showIds && (
                        <div className="mt-1 flex items-center gap-2 font-mono text-[9px] text-slate-400">
                          ID: {cita.doctorId}
                          <button onClick={() => {navigator.clipboard.writeText(cita.doctorId); alert('ID Copiado');}} className="text-blue-500 hover:underline">Copiar</button>
                        </div>
                      )}
                    </td>
                    <td className="px-6 py-4 text-center">
                      <span className={`px-2.5 py-1 rounded-full text-[10px] font-black uppercase border-2 ${
                        cita.status === 'CONFIRMED' ? 'bg-green-50 text-green-700 border-green-200' : 
                        cita.status === 'PENDING' ? 'bg-blue-50 text-blue-700 border-blue-200' : 
                        'bg-gray-50 text-gray-700 border-gray-200'
                      }`}>
                        {cita.status}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <button 
                        onClick={() => handleCancelar(cita.id)} 
                        className="p-2 text-red-400 hover:bg-red-50 hover:text-red-600 rounded-lg transition-all" 
                        title="Cancelar Cita"
                      >
                        <Trash2 size={20} />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {citas.length === 0 && !loading && (
              <div className="py-24 text-center text-slate-400">
                <CalendarIcon size={48} className="mx-auto mb-4 opacity-10" />
                <p className="italic font-medium">No se encontraron citas agendadas activas.</p>
              </div>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}
