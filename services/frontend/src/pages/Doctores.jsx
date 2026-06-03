import React, { useEffect, useState } from 'react';
import { Calendar, Clock, Plus, Trash2, UserPlus, CheckCircle2, AlertCircle, X } from 'lucide-react';
import { doctorService } from '../services/api';

const dias = [
  ['MONDAY', 'Lunes'],
  ['TUESDAY', 'Martes'],
  ['WEDNESDAY', 'Miercoles'],
  ['THURSDAY', 'Jueves'],
  ['FRIDAY', 'Viernes'],
  ['SATURDAY', 'Sabado'],
  ['SUNDAY', 'Domingo'],
];

const emptySchedule = { diaSemana: 'MONDAY', horaInicio: '08:00', horaFin: '12:00', disponible: true };

export default function Doctores() {
  const [doctores, setDoctores] = useState([]);
  const [especialidades, setEspecialidades] = useState([]);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState(null);
  const [especialidadesError, setEspecialidadesError] = useState(null);
  const [confirmModal, setConfirmModal] = useState({ show: false, doctorId: null, nombre: '', action: '' });
  
  const [form, setForm] = useState({
    nombre: '',
    specialtyId: '',
    telefono: '',
    correo: '',
    maxAppointmentsPerDay: 10,
    horarios: [emptySchedule],
  });

  useEffect(() => {
    fetchDoctores();
    fetchEspecialidades();
  }, []);

  const handleToggleStatus = async () => {
    const { doctorId } = confirmModal;
    if (!doctorId) return;
    try {
      setLoading(true);
      await doctorService.cambiarEstado(doctorId);
      setMessage({ type: 'success', text: 'Estado del doctor actualizado correctamente.' });
      fetchDoctores();
    } catch (err) {
      console.error(err);
      setMessage({ type: 'error', text: 'No se pudo cambiar el estado del doctor.' });
    } finally {
      setLoading(false);
      setConfirmModal({ show: false, doctorId: null, nombre: '', action: '' });
      setTimeout(() => setMessage(null), 4000);
    }
  };

  const openConfirmModal = (doctor) => {
    setConfirmModal({ 
      show: true, 
      doctorId: doctor.id, 
      nombre: doctor.nombre,
      action: doctor.activo ? 'desactivar' : 'activar'
    });
  };

  const fetchDoctores = async () => {
    try {
      setLoading(true);
      const res = await doctorService.listar();
      setDoctores(Array.isArray(res.data) ? res.data : []);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const fetchEspecialidades = async () => {
    try {
      setEspecialidadesError(null);
      const res = await doctorService.listarEspecialidades();
      const data = Array.isArray(res.data) ? res.data : [];
      
      const uniqueSpecs = [];
      const seen = new Set();
      data.forEach(esp => {
        if (esp.name && !seen.has(esp.name.toLowerCase().trim())) {
          seen.add(esp.name.toLowerCase().trim());
          uniqueSpecs.push(esp);
        }
      });

      setEspecialidades(uniqueSpecs);
      if (uniqueSpecs.length > 0 && !form.specialtyId) {
        setForm(prev => ({ ...prev, specialtyId: uniqueSpecs[0].id }));
      }
    } catch (err) {
      console.error('Error fetching specialties:', err);
      setEspecialidades([]);
      const detail = err.response?.data?.message || err.response?.data?.error || err.message;
      setEspecialidadesError(detail || 'No se pudieron cargar las especialidades.');
    }
  };

  const updateSchedule = (index, patch) => {
    setForm(current => ({
      ...current,
      horarios: current.horarios.map((horario, i) => i === index ? { ...horario, ...patch } : horario),
    }));
  };

  const addSchedule = () => {
    setForm(current => ({
      ...current,
      horarios: [...current.horarios, { ...emptySchedule }],
    }));
  };

  const removeSchedule = (index) => {
    setForm(current => ({
      ...current,
      horarios: current.horarios.filter((_, i) => i !== index),
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      setLoading(true);
      setMessage(null);
      await doctorService.crear({
        ...form,
        activo: true,
      });
      setMessage({ type: 'success', text: 'Doctor y horarios registrados correctamente.' });
      setForm({ nombre: '', specialtyId: especialidades[0]?.id || '', telefono: '', correo: '', maxAppointmentsPerDay: 10, horarios: [{ ...emptySchedule }] });
      fetchDoctores();
    } catch (err) {
      const detail = err.response?.data?.message || err.response?.data?.error;
      setMessage({ type: 'error', text: detail || 'No se pudo registrar el doctor.' });
    } finally {
      setLoading(false);
      setTimeout(() => setMessage(null), 4000);
    }
  };

  return (
    <div className="mx-auto max-w-6xl space-y-8 py-2 px-4">
      <header className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
        <p className="text-sm font-semibold uppercase tracking-wider text-[#2f6f62]">Personal Medico</p>
        <h2 className="mt-2 text-3xl font-bold text-slate-950">Doctores y Horarios</h2>
        <p className="mt-2 text-slate-600">Registre especialistas y gestione sus estados de disponibilidad.</p>
      </header>

      <div className="grid gap-8 lg:grid-cols-[420px_1fr]">
        <section className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
          <h3 className="mb-5 flex items-center gap-2 text-lg font-bold text-slate-950">
            <UserPlus size={20} className="text-[#2f6f62]" />
            Nuevo Doctor
          </h3>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-semibold text-slate-700">Nombre completo</label>
              <input
                required
                className="mt-2 w-full rounded-md border border-slate-300 p-3 text-sm focus:border-[#2f6f62] focus:ring-2 focus:ring-[#2f6f62]/20 outline-none"
                value={form.nombre}
                onChange={e => setForm({ ...form, nombre: e.target.value })}
              />
            </div>
            <div>
              <label className="block text-sm font-semibold text-slate-700">Especialidad</label>
              <select
                required
                className="mt-2 w-full rounded-md border border-slate-300 p-3 text-sm focus:border-[#2f6f62] outline-none"
                value={form.specialtyId}
                onChange={e => setForm({ ...form, specialtyId: e.target.value })}
              >
                {especialidades.map(esp => (
                  <option key={esp.id} value={esp.id}>{esp.name} - Q {Number(esp.consultationPrice).toFixed(2)}</option>
                ))}
              </select>
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <label className="block text-sm font-semibold text-slate-700">Telefono</label>
                <input
                  className="mt-2 w-full rounded-md border border-slate-300 p-3 text-sm outline-none"
                  value={form.telefono}
                  onChange={e => setForm({ ...form, telefono: e.target.value })}
                />
              </div>
              <div>
                <label className="block text-sm font-semibold text-slate-700">Citas diarias</label>
                <input
                  type="number"
                  min="1"
                  className="mt-2 w-full rounded-md border border-slate-300 p-3 text-sm outline-none"
                  value={form.maxAppointmentsPerDay}
                  onChange={e => setForm({ ...form, maxAppointmentsPerDay: parseInt(e.target.value) })}
                />
              </div>
            </div>

            <div className="space-y-3 border-t border-slate-200 pt-4">
              <div className="flex items-center justify-between">
                <p className="text-sm font-bold text-slate-900">Horarios Disponibles</p>
                <button type="button" onClick={addSchedule} className="inline-flex items-center gap-2 rounded-md bg-[#e0eee8] px-3 py-2 text-xs font-bold text-[#12312b]">
                  <Plus size={14} /> Agregar
                </button>
              </div>

              {form.horarios.map((horario, index) => (
                <div key={index} className="rounded-md border border-slate-200 bg-slate-50 p-3">
                  <div className="grid gap-3 sm:grid-cols-[1fr_90px_90px_36px]">
                    <select
                      className="rounded-md border border-slate-300 p-2 text-sm outline-none"
                      value={horario.diaSemana}
                      onChange={e => updateSchedule(index, { diaSemana: e.target.value })}
                    >
                      {dias.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
                    </select>
                    <input type="time" className="p-2 rounded border border-slate-300 text-sm" value={horario.horaInicio} onChange={e => updateSchedule(index, { horaInicio: e.target.value })} />
                    <input type="time" className="p-2 rounded border border-slate-300 text-sm" value={horario.horaFin} onChange={e => updateSchedule(index, { horaFin: e.target.value })} />
                    <button type="button" onClick={() => removeSchedule(index)} disabled={form.horarios.length === 1} className="text-slate-400 hover:text-red-500 disabled:opacity-20"><Trash2 size={18} /></button>
                  </div>
                </div>
              ))}
            </div>

            <button type="submit" disabled={loading} className="w-full rounded-md bg-[#12312b] px-6 py-3 text-sm font-bold text-white hover:bg-[#1b493f] transition disabled:opacity-50">
              {loading ? 'Guardando...' : 'Registrar Especialista'}
            </button>
          </form>
        </section>

        <section className="space-y-4">
          <h3 className="text-lg font-bold text-slate-950">Listado de Personal</h3>
          <div className="grid gap-4">
            {doctores.map(doctor => (
              <article key={doctor.id} className={`rounded-md bg-white p-5 shadow-sm ring-1 ring-slate-200 transition-all ${!doctor.activo ? 'opacity-60 grayscale' : ''}`}>
                <div className="flex flex-col justify-between gap-3 sm:flex-row">
                  <div>
                    <div className="flex items-center gap-2">
                      <p className="text-lg font-bold text-slate-950">{doctor.nombre}</p>
                      <span className={`text-[10px] px-2 py-0.5 rounded-full font-bold uppercase ${doctor.activo ? 'bg-green-100 text-green-700' : 'bg-slate-200 text-slate-600'}`}>
                        {doctor.activo ? 'Activo' : 'Inactivo'}
                      </span>
                    </div>
                    <p className="text-sm font-medium text-[#2f6f62]">
                      {doctor.specialtyName} · Q {Number(doctor.consultationPrice || 0).toFixed(2)} · {doctor.maxAppointmentsPerDay} citas/día
                    </p>
                  </div>
                  <div className="flex flex-col items-end gap-2">
                    <p className="font-mono text-[10px] text-slate-400">ID: {doctor.id}</p>
                    <button 
                      onClick={() => openConfirmModal(doctor)}
                      className={`text-xs px-4 py-1.5 rounded-md font-bold transition border ${doctor.activo ? 'border-red-200 text-red-600 hover:bg-red-50' : 'border-green-200 text-green-600 hover:bg-green-50'}`}
                    >
                      {doctor.activo ? 'Desactivar' : 'Activar'}
                    </button>
                  </div>
                </div>
                <div className="mt-4 grid gap-2 md:grid-cols-2">
                  {doctor.horarios?.map(horario => (
                    <div key={horario.id} className="flex items-center gap-3 rounded-md bg-slate-50 px-3 py-2 text-xs text-slate-700">
                      <Calendar size={14} className="text-[#2f6f62]" />
                      <span className="font-bold">{dias.find(([v]) => v === horario.diaSemana)?.[1]}</span>
                      <Clock size={14} className="ml-auto text-slate-400" />
                      <span>{horario.horaInicio} - {horario.horaFin}</span>
                    </div>
                  ))}
                </div>
              </article>
            ))}
          </div>
        </section>
      </div>

      {/* Confirmation Modal */}
      {confirmModal.show && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-slate-900/60 backdrop-blur-sm p-4">
          <div className="w-full max-w-md rounded-xl bg-white p-8 shadow-2xl ring-1 ring-slate-200 animate-in zoom-in-95 duration-200">
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-amber-100 text-amber-600 mb-4">
              <AlertCircle size={28} />
            </div>
            <h3 className="text-xl font-black text-slate-950">¿Confirmar acción?</h3>
            <p className="mt-3 text-slate-600 leading-relaxed">
              Está a punto de <strong>{confirmModal.action}</strong> al doctor <strong>{confirmModal.nombre}</strong>. 
              {confirmModal.action === 'desactivar' && ' El especialista no podrá recibir nuevas citas hasta ser reactivado.'}
            </p>
            <div className="mt-8 flex justify-end gap-3">
              <button onClick={() => setConfirmModal({ show: false, doctorId: null, nombre: '', action: '' })} className="rounded-lg px-5 py-2.5 text-sm font-bold text-slate-500 hover:bg-slate-100 transition">Cancelar</button>
              <button onClick={handleToggleStatus} className={`rounded-lg px-6 py-2.5 text-sm font-bold text-white shadow-md transition ${confirmModal.action === 'desactivar' ? 'bg-red-600 hover:bg-red-700' : 'bg-green-600 hover:bg-green-700'}`}>
                Sí, {confirmModal.action}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Custom Floating Alerts */}
      {message && (
        <div className="fixed bottom-8 right-8 z-[110] animate-in slide-in-from-right-8 duration-300">
          <div className={`flex items-center gap-4 rounded-xl p-5 shadow-2xl ring-1 ${message.type === 'success' ? 'bg-[#12312b] text-white ring-white/10' : 'bg-red-600 text-white ring-white/10'}`}>
            {message.type === 'success' ? <CheckCircle2 size={24} className="text-green-400" /> : <AlertCircle size={24} />}
            <div>
              <p className="text-xs font-black uppercase opacity-60">Notificación</p>
              <p className="text-sm font-bold">{message.text}</p>
            </div>
            <button onClick={() => setMessage(null)} className="ml-4 rounded-full p-1 hover:bg-white/10 transition"><X size={16} /></button>
          </div>
        </div>
      )}
    </div>
  );
}
