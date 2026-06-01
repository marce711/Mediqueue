import React, { useEffect, useState } from 'react';
import { Calendar, Clock, Plus, Trash2, UserPlus } from 'lucide-react';
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
  const [form, setForm] = useState({
    nombre: '',
    specialtyId: '',
    telefono: '',
    correo: '',
    horarios: [emptySchedule],
  });

  useEffect(() => {
    fetchDoctores();
    fetchEspecialidades();
  }, []);

  const fetchDoctores = async () => {
    try {
      setLoading(true);
      const res = await doctorService.listar();
      setDoctores(res.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const fetchEspecialidades = async () => {
    try {
      const res = await doctorService.listarEspecialidades();
      setEspecialidades(res.data);
      if (res.data.length > 0 && !form.specialtyId) {
        setForm(prev => ({ ...prev, specialtyId: res.data[0].id }));
      }
    } catch (err) {
      console.error('Error fetching specialties:', err);
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
        specialtyId: parseInt(form.specialtyId),
        telefono: form.telefono || null,
        correo: form.correo || null,
        activo: true,
      });
      setMessage({ type: 'success', text: 'Doctor y horarios registrados correctamente.' });
      setForm({ nombre: '', specialtyId: especialidades[0]?.id || '', telefono: '', correo: '', horarios: [{ ...emptySchedule }] });
      fetchDoctores();
    } catch (err) {
      const validationErrors = err.response?.data?.validationErrors;
      const detail = validationErrors
        ? Object.values(validationErrors).join(' ')
        : err.response?.data?.message || err.response?.data?.error;
      setMessage({ type: 'error', text: detail || 'No se pudo registrar el doctor.' });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="mx-auto max-w-6xl space-y-8 py-2">
      <header className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
        <p className="text-sm font-semibold uppercase tracking-wider text-[#2f6f62]">Personal medico</p>
        <h2 className="mt-2 text-3xl font-bold text-slate-950">Doctores y horarios</h2>
        <p className="mt-2 text-slate-600">Registre especialistas y sus bloques de atencion disponibles.</p>
      </header>

      <div className="grid gap-8 lg:grid-cols-[420px_1fr]">
        <section className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
          <h3 className="mb-5 flex items-center gap-2 text-lg font-bold text-slate-950">
            <UserPlus size={20} className="text-[#2f6f62]" />
            Nuevo doctor
          </h3>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-semibold text-slate-700">Nombre completo</label>
              <input
                required
                className="mt-2 w-full rounded-md border border-slate-300 p-3 text-sm focus:border-[#2f6f62] focus:outline-none focus:ring-2 focus:ring-[#2f6f62]/20"
                value={form.nombre}
                onChange={e => setForm({ ...form, nombre: e.target.value })}
              />
            </div>
            <div>
              <label className="block text-sm font-semibold text-slate-700">Especialidad</label>
              <select
                required
                className="mt-2 w-full rounded-md border border-slate-300 p-3 text-sm focus:border-[#2f6f62] focus:outline-none focus:ring-2 focus:ring-[#2f6f62]/20"
                value={form.specialtyId}
                onChange={e => setForm({ ...form, specialtyId: e.target.value })}
              >
                {especialidades.map(esp => (
                  <option key={esp.id} value={esp.id}>{esp.name}</option>
                ))}
              </select>
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <label className="block text-sm font-semibold text-slate-700">Telefono</label>
                <input
                  className="mt-2 w-full rounded-md border border-slate-300 p-3 text-sm focus:border-[#2f6f62] focus:outline-none focus:ring-2 focus:ring-[#2f6f62]/20"
                  value={form.telefono}
                  onChange={e => setForm({ ...form, telefono: e.target.value })}
                />
              </div>
              <div>
                <label className="block text-sm font-semibold text-slate-700">Correo</label>
                <input
                  type="email"
                  className="mt-2 w-full rounded-md border border-slate-300 p-3 text-sm focus:border-[#2f6f62] focus:outline-none focus:ring-2 focus:ring-[#2f6f62]/20"
                  value={form.correo}
                  onChange={e => setForm({ ...form, correo: e.target.value })}
                />
              </div>
            </div>

            <div className="space-y-3 border-t border-slate-200 pt-4">
              <div className="flex items-center justify-between">
                <p className="text-sm font-bold text-slate-900">Horarios</p>
                <button type="button" onClick={addSchedule} className="inline-flex items-center gap-2 rounded-md bg-[#e0eee8] px-3 py-2 text-xs font-bold text-[#12312b]">
                  <Plus size={14} />
                  Agregar
                </button>
              </div>

              {form.horarios.map((horario, index) => (
                <div key={index} className="rounded-md border border-slate-200 bg-slate-50 p-3">
                  <div className="grid gap-3 sm:grid-cols-[1fr_96px_96px_36px]">
                    <select
                      className="rounded-md border border-slate-300 p-2 text-sm"
                      value={horario.diaSemana}
                      onChange={e => updateSchedule(index, { diaSemana: e.target.value })}
                    >
                      {dias.map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                    </select>
                    <input
                      type="time"
                      className="rounded-md border border-slate-300 p-2 text-sm"
                      value={horario.horaInicio}
                      onChange={e => updateSchedule(index, { horaInicio: e.target.value })}
                    />
                    <input
                      type="time"
                      className="rounded-md border border-slate-300 p-2 text-sm"
                      value={horario.horaFin}
                      onChange={e => updateSchedule(index, { horaFin: e.target.value })}
                    />
                    <button
                      type="button"
                      onClick={() => removeSchedule(index)}
                      disabled={form.horarios.length === 1}
                      className="grid h-10 place-items-center rounded-md text-slate-500 hover:bg-white disabled:opacity-40"
                      title="Eliminar horario"
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                </div>
              ))}
            </div>

            <button
              type="submit"
              disabled={loading || especialidades.length === 0}
              className="w-full rounded-md bg-[#12312b] px-6 py-3 text-sm font-semibold text-white transition hover:bg-[#1b493f] disabled:opacity-50"
            >
              {loading ? 'Guardando...' : 'Registrar doctor'}
            </button>

            {message && (
              <div className={`rounded-md p-3 text-sm ${
                message.type === 'success' ? 'bg-green-50 text-green-800 ring-1 ring-green-200' : 'bg-red-50 text-red-800 ring-1 ring-red-200'
              }`}>
                {message.text}
              </div>
            )}
          </form>
        </section>

        <section className="space-y-4">
          <h3 className="text-lg font-bold text-slate-950">Doctores registrados</h3>
          <div className="grid gap-4">
            {doctores.map(doctor => (
              <article key={doctor.id} className="rounded-md bg-white p-5 shadow-sm ring-1 ring-slate-200">
                <div className="flex flex-col justify-between gap-3 sm:flex-row">
                  <div>
                    <p className="text-lg font-bold text-slate-950">{doctor.nombre}</p>
                    <p className="text-sm text-[#2f6f62]">{doctor.specialtyName}</p>
                  </div>
                  <p className="font-mono text-xs text-slate-400">ID {doctor.id}</p>
                </div>
                <div className="mt-4 grid gap-2 md:grid-cols-2">
                  {doctor.horarios?.map(horario => (
                    <div key={horario.id} className="flex items-center gap-3 rounded-md bg-slate-50 px-3 py-2 text-sm text-slate-700">
                      <Calendar size={16} className="text-[#2f6f62]" />
                      <span>{dias.find(([value]) => value === horario.diaSemana)?.[1] || horario.diaSemana}</span>
                      <Clock size={16} className="ml-auto text-slate-400" />
                      <span>{horario.horaInicio} - {horario.horaFin}</span>
                    </div>
                  ))}
                </div>
              </article>
            ))}

            {doctores.length === 0 && !loading && (
              <div className="rounded-md border-2 border-dashed border-slate-300 bg-white py-14 text-center text-slate-500">
                No hay doctores registrados.
              </div>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}
