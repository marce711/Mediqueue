import React, { useState, useEffect, useMemo } from 'react';
import { citaService, pacienteService, doctorService } from '../services/api';
import { Activity, Calendar as CalendarIcon, Clock, Search, User, Filter, Trash2, X, ChevronLeft, ChevronRight, Hash, CalendarPlus, CheckCircle2, AlertCircle } from 'lucide-react';
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
  const [viewDate, setViewDate] = useState(new Date());
  
  useEffect(() => {
    fetchDoctores();
    fetchCitas();
  }, [selectedDoctorId]);

  const fetchDoctores = async () => {
    try {
      const res = await doctorService.listar();
      setDoctores(res.data || []);
    } catch (err) { console.error(err); }
  };

  const fetchCitas = async () => {
    try {
      setLoading(true);
      const params = selectedDoctorId !== 'all' ? { doctorId: selectedDoctorId } : {};
      const res = await citaService.listar(params);
      const activeCitas = (res.data || []).filter(c => c.status !== 'CANCELLED');
      setCitas(activeCitas);
    } catch (err) {
      console.error(err);
      setError('Error al cargar citas.');
    } finally { setLoading(false); }
  };

  const handleSearchPaciente = async () => {
    try {
      const res = await pacienteService.obtenerPorDpi(searchDpi);
      setPacienteFound(res.data);
      setForm({ ...form, patientId: res.data.id });
      setMessage(null);
    } catch (err) {
      setPacienteFound(null);
      setMessage({ type: 'error', text: 'Paciente no encontrado.' });
    }
  };

  const handleCheckAvailability = async () => {
    if (!form.doctorId || !form.appointmentDate) return;
    try {
      setLoading(true);
      const res = await citaService.verificarDisponibilidad(form.doctorId, form.appointmentDate, form.durationMinutes);
      setAvailability(res.data);
      setMessage({ type: res.data.available ? 'success' : 'error', text: res.data.available ? 'Horario Disponible' : 'Horario No Disponible' });
    } catch (err) {
      setMessage({ type: 'error', text: 'Error al validar.' });
    } finally { setLoading(false); }
  };

  const handleCreateCita = async (e) => {
    e.preventDefault();
    if (!form.patientId || !availability?.available) return;
    try {
      setLoading(true);
      const res = await citaService.crear(form, `cita-${Date.now()}`);
      setMessage({ type: 'success', text: 'Cita agendada correctamente.' });
      setForm({ patientId: '', doctorId: '', appointmentDate: '', durationMinutes: 30, reason: '' });
      setPacienteFound(null);
      setSearchDpi('');
      setAvailability(null);
      fetchCitas();
      setTimeout(() => navigate(`/pagos?appointmentId=${res.data.id}&amount=${res.data.consultationPrice}`), 1500);
    } catch (err) {
      setMessage({ type: 'error', text: 'Error al agendar.' });
    } finally { setLoading(false); }
  };

  const handleCancelar = async (id) => {
    if (!window.confirm('¿Desea cancelar esta cita?')) return;
    try {
      setLoading(true);
      await citaService.cancelar(id);
      fetchCitas();
      setMessage({ type: 'success', text: 'Cita cancelada.' });
    } catch (err) {
      alert('No se pudo cancelar (debe ser con 48h de anticipación)');
    } finally { setLoading(false); }
  };

  const doctorColorsMap = useMemo(() => {
    const map = {};
    doctores.forEach((doc, i) => { map[doc.id] = DOCTOR_COLORS[i % DOCTOR_COLORS.length]; });
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
        const d = new Date(c.appointmentDate);
        return d.getDate() === i && d.getMonth() === viewDate.getMonth() && d.getFullYear() === viewDate.getFullYear();
      });
      days.push({ date, citas: dayCitas });
    }
    return days;
  }, [viewDate, citas]);

  return (
    <div className="mx-auto max-w-[1600px] space-y-8 py-2 px-6">
      <header className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
        <h2 className="text-3xl font-black text-slate-950">Gestión Operativa de Citas</h2>
      </header>

      {/* SUPERIOR: SIDEBAR Y TABLA */}
      <div className="grid gap-6 lg:grid-cols-[360px_1fr]">
        <aside className="space-y-6">
          <section className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200 border-l-4 border-l-[#2f6f62]">
            <h3 className="mb-5 flex items-center gap-2 font-black text-slate-900 uppercase tracking-tighter">
              <CalendarPlus size={20} className="text-[#2f6f62]" /> Agendar Cita
            </h3>
            <div className="space-y-4">
               <div>
                 <label className="text-[10px] font-black uppercase text-slate-400">Paciente (DPI)</label>
                 <div className="mt-1 flex gap-2">
                   <input className="flex-1 rounded border p-2 text-sm outline-none focus:ring-2 focus:ring-[#2f6f62]/20" value={searchDpi} onChange={e => setSearchDpi(e.target.value)} />
                   <button onClick={handleSearchPaciente} className="p-2 bg-slate-100 rounded hover:bg-slate-200 transition"><Search size={16} /></button>
                 </div>
               </div>
               {pacienteFound && <div className="p-3 bg-emerald-50 text-[#12312b] text-xs font-bold rounded border border-emerald-100">{pacienteFound.nombre}</div>}
               
               <div>
                 <label className="text-[10px] font-black uppercase text-slate-400">Especialista</label>
                 <select className="mt-1 w-full rounded border p-2 text-sm outline-none focus:ring-2 focus:ring-[#2f6f62]/20" value={form.doctorId} onChange={e => setForm({...form, doctorId: e.target.value})}>
                   <option value="">Seleccione Doctor...</option>
                   {doctores.filter(d => d.activo).map(d => <option key={d.id} value={d.id}>{d.nombre}</option>)}
                 </select>
               </div>

               <div>
                 <label className="text-[10px] font-black uppercase text-slate-400">Fecha y Hora</label>
                 <input type="datetime-local" className="mt-1 w-full rounded border p-2 text-sm outline-none" value={form.appointmentDate} onChange={e => setForm({...form, appointmentDate: e.target.value})} />
               </div>

               <div className="grid grid-cols-2 gap-3 pt-2">
                 <button onClick={handleCheckAvailability} className="rounded border-2 border-slate-900 py-2.5 text-xs font-black transition hover:bg-slate-900 hover:text-white">VALIDAR</button>
                 <button onClick={handleCreateCita} disabled={!availability?.available} className="rounded bg-[#12312b] py-2.5 text-xs font-black text-white transition hover:bg-[#1b493f] disabled:opacity-20 shadow-lg">AGENDAR</button>
               </div>

               {message && (
                 <div className={`p-3 rounded-md text-[11px] font-bold border ${message.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
                    {message.text}
                 </div>
               )}
            </div>
          </section>
          
          <section className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
             <h3 className="mb-4 flex items-center gap-2 font-bold text-slate-900"><Filter size={18} /> Filtros de Vista</h3>
             <select className="w-full rounded border p-2 text-sm outline-none" value={selectedDoctorId} onChange={e => setSelectedDoctorId(e.target.value)}>
               <option value="all">Todos los doctores</option>
               {doctores.map(d => <option key={d.id} value={d.id}>{d.nombre}</option>)}
             </select>
             <div className="mt-4 flex items-center gap-2">
               <input type="checkbox" id="shIds" checked={showIds} onChange={() => setShowIds(!showIds)} className="h-4 w-4 text-[#2f6f62]" />
               <label htmlFor="shIds" className="text-xs font-bold text-slate-700 cursor-pointer">Mostrar IDs Detallados</label>
             </div>
          </section>
        </aside>

        <section className="rounded-md bg-white shadow-sm ring-1 ring-slate-200 overflow-hidden self-start">
           <div className="border-b p-6 bg-slate-50/50 flex justify-between items-center">
             <h3 className="text-xl font-black text-slate-900 uppercase">Agenda de Citas Activas</h3>
             <Activity size={20} className="text-[#2f6f62]" />
           </div>
           <div className="overflow-x-auto">
             <table className="w-full text-left text-sm">
               <thead className="bg-slate-50 text-[10px] font-black uppercase text-slate-400">
                 <tr><th className="px-6 py-4">Horario</th><th className="px-6 py-4">Paciente</th><th className="px-6 py-4">Especialista</th><th className="px-6 py-4 text-center">Estado</th><th className="px-6 py-4 text-center">Acciones</th></tr>
               </thead>
               <tbody className="divide-y">
                 {citas.map(c => (
                   <tr key={c.id} className="hover:bg-slate-50 transition-colors">
                     <td className="px-6 py-4">
                       <div className="flex items-center gap-2 font-bold text-slate-900">
                         <Clock size={14} className="text-blue-500" />
                         {new Date(c.appointmentDate).toLocaleString([], {dateStyle:'short', timeStyle:'short'})}
                       </div>
                       <div className="mt-1 flex items-center gap-2">
                         <span className="font-mono text-[9px] text-slate-400 bg-slate-50 px-1.5 py-0.5 rounded border border-slate-100">ID: {c.id}</span>
                         <button onClick={() => {navigator.clipboard.writeText(c.id); alert('ID de Cita Copiado');}} className="text-[9px] text-blue-500 hover:underline">Copiar</button>
                       </div>
                     </td>
                     <td className="px-6 py-4">
                       <div className="font-bold text-slate-700">{c.patientName}</div>
                       {showIds && <button onClick={() => {navigator.clipboard.writeText(c.patientId); alert('ID Copiado');}} className="text-[9px] text-blue-500 block hover:underline">ID: {c.patientId.substring(0,8)}...</button>}
                     </td>
                     <td className="px-6 py-4">
                        <div className="flex items-center gap-2 font-bold">
                          <div className={`h-2.5 w-2.5 rounded-full ${doctorColorsMap[c.doctorId]?.split(' ')[0]}`}></div>
                          {c.doctorName}
                        </div>
                        {showIds && <button onClick={() => {navigator.clipboard.writeText(c.doctorId); alert('ID Copiado');}} className="text-[9px] text-blue-500 block hover:underline">ID: {c.doctorId.substring(0,8)}...</button>}
                     </td>
                     <td className="px-6 py-4 text-center">
                       <span className={`px-2.5 py-1 rounded-full text-[10px] font-black uppercase border ${c.status === 'CONFIRMED' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-blue-50 text-blue-700 border-blue-200'}`}>
                         {c.status}
                       </span>
                     </td>
                     <td className="px-6 py-4 text-center">
                       <button onClick={() => handleCancelar(c.id)} className="p-2 text-red-400 hover:bg-red-50 hover:text-red-600 rounded-lg transition-all"><Trash2 size={20} /></button>
                     </td>
                   </tr>
                 ))}
               </tbody>
             </table>
             {citas.length === 0 && !loading && (
               <div className="py-24 text-center text-slate-300 italic">No hay registros activos para mostrar.</div>
             )}
           </div>
        </section>
      </div>

      {/* INFERIOR: CALENDARIO FULL WIDTH */}
      <section className="rounded-md bg-white p-8 shadow-sm ring-1 ring-slate-200">
        <div className="mb-8 flex items-center justify-between border-b pb-6">
          <div>
            <p className="text-[10px] font-black uppercase text-[#2f6f62] tracking-[0.2em]">Vista General Mensual</p>
            <h3 className="text-3xl font-black text-slate-950 uppercase mt-1">{viewDate.toLocaleString('default', { month: 'long', year: 'numeric' })}</h3>
          </div>
          <div className="flex gap-2">
            <button onClick={() => setViewDate(new Date(viewDate.getFullYear(), viewDate.getMonth() - 1, 1))} className="p-3 hover:bg-slate-100 rounded-full transition border shadow-sm"><ChevronLeft size={24} /></button>
            <button onClick={() => setViewDate(new Date())} className="px-6 py-1 font-black text-xs bg-slate-900 text-white rounded-md uppercase tracking-wider">Hoy</button>
            <button onClick={() => setViewDate(new Date(viewDate.getFullYear(), viewDate.getMonth() + 1, 1))} className="p-3 hover:bg-slate-100 rounded-full transition border shadow-sm"><ChevronRight size={24} /></button>
          </div>
        </div>
        <div className="grid grid-cols-7 gap-px bg-slate-200 rounded-xl overflow-hidden border shadow-inner">
          {['Dom', 'Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab'].map(d => <div key={d} className="bg-slate-50 py-4 text-center text-[10px] font-black uppercase text-slate-400 tracking-widest">{d}</div>)}
          {calendarDays.map((day, i) => (
            <div key={i} className={`min-h-[160px] bg-white p-4 transition-colors ${day ? 'hover:bg-slate-50/50' : 'bg-slate-50/50'}`}>
              {day && (
                <>
                  <span className={`text-sm font-black ${day.date.toDateString() === new Date().toDateString() ? 'bg-blue-600 text-white w-7 h-7 inline-grid place-items-center rounded-full shadow-lg' : 'text-slate-400'}`}>{day.date.getDate()}</span>
                  <div className="mt-3 space-y-1.5">
                    {day.citas.map(c => (
                      <div key={c.id} className={`truncate text-[9px] px-2 py-1.5 rounded-md border font-black shadow-sm uppercase tracking-tighter ${doctorColorsMap[c.doctorId] || 'bg-gray-100 text-gray-700'}`}>
                        {new Date(c.appointmentDate).toLocaleTimeString([], {hour:'2-digit', minute:'2-digit'})} | {c.patientName?.split(' ')[0]}
                      </div>
                    ))}
                  </div>
                </>
              )}
            </div>
          ))}
        </div>
      </section>

      {/* FLOATING NOTIFICATIONS */}
      {message && (
        <div className="fixed bottom-10 right-10 z-[200] animate-in slide-in-from-bottom-10 duration-500">
           <div className={`flex items-center gap-4 rounded-2xl p-6 shadow-2xl ring-1 ${message.type === 'success' ? 'bg-slate-900 text-white ring-white/10' : 'bg-red-600 text-white ring-white/10'}`}>
             {message.type === 'success' ? <CheckCircle2 size={24} className="text-green-400" /> : <AlertCircle size={24} />}
             <div>
               <p className="text-[10px] font-black uppercase opacity-50 tracking-widest">MediQueue System</p>
               <p className="text-sm font-bold mt-0.5">{message.text}</p>
             </div>
             <button onClick={() => setMessage(null)} className="ml-4 hover:opacity-50"><X size={18} /></button>
           </div>
        </div>
      )}
    </div>
  );
}
