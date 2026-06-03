import React from 'react';
import { Calendar, CreditCard, LayoutGrid, UserRound, Users } from 'lucide-react';
import { NavLink } from 'react-router-dom';

export default function Dashboard() {
  return (
    <div className="mx-auto max-w-6xl space-y-8 py-2">
      <header className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
        <p className="text-sm font-semibold uppercase tracking-wider text-[#2f6f62]">Recepcion y admision</p>
        <h2 className="mt-2 text-3xl font-bold text-slate-950">Centro de trabajo Mediqueue</h2>
        <p className="mt-2 max-w-2xl text-slate-600">
          Acceso directo a expedientes, agenda medica y pagos por cita.
        </p>
      </header>

      <section className="space-y-5">
        <h3 className="flex items-center gap-2 text-lg font-semibold text-slate-900">
          <LayoutGrid size={20} className="text-[#2f6f62]" />
          Operaciones frecuentes
        </h3>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-4">
          <NavLink to="/pacientes" className="rounded-md bg-white p-5 shadow-sm ring-1 ring-slate-200 transition hover:-translate-y-0.5 hover:ring-[#2f6f62]">
            <div className="mb-5 flex h-12 w-12 items-center justify-center rounded-md bg-[#e0eee8] text-[#12312b]">
              <Users />
            </div>
            <p className="text-lg font-bold text-slate-950">Registrar paciente</p>
            <p className="mt-2 text-sm text-slate-600">Alta de expediente clinico y datos de contacto.</p>
          </NavLink>

          <NavLink to="/doctores" className="rounded-md bg-white p-5 shadow-sm ring-1 ring-slate-200 transition hover:-translate-y-0.5 hover:ring-[#2f6f62]">
            <div className="mb-5 flex h-12 w-12 items-center justify-center rounded-md bg-[#f2e8dc] text-[#664318]">
              <UserRound />
            </div>
            <p className="text-lg font-bold text-slate-950">Registrar doctor</p>
            <p className="mt-2 text-sm text-slate-600">Alta de especialistas y bloques de atencion.</p>
          </NavLink>

          <NavLink to="/citas" className="rounded-md bg-white p-5 shadow-sm ring-1 ring-slate-200 transition hover:-translate-y-0.5 hover:ring-[#2f6f62]">
            <div className="mb-5 flex h-12 w-12 items-center justify-center rounded-md bg-[#fff1cf] text-[#6f4b00]">
              <Calendar />
            </div>
            <p className="text-lg font-bold text-slate-950">Agendar cita</p>
            <p className="mt-2 text-sm text-slate-600">Validacion de paciente, doctor y horario disponible.</p>
          </NavLink>

          <NavLink to="/pagos" className="rounded-md bg-white p-5 shadow-sm ring-1 ring-slate-200 transition hover:-translate-y-0.5 hover:ring-[#2f6f62]">
            <div className="mb-5 flex h-12 w-12 items-center justify-center rounded-md bg-[#e8edf6] text-[#253a63]">
              <CreditCard />
            </div>
            <p className="text-lg font-bold text-slate-950">Pago por cita</p>
            <p className="mt-2 text-sm text-slate-600">Consulta y registro de cobros usando el ID de la cita.</p>
          </NavLink>
        </div>
      </section>

      <section className="rounded-md bg-[#12312b] p-6 text-white">
        <h3 className="text-xl font-bold">Flujo recomendado</h3>
        <div className="mt-5 grid gap-4 md:grid-cols-3">
          <div className="border-l-4 border-[#f6c85f] pl-4">
            <p className="font-semibold">1. Expediente</p>
            <p className="mt-1 text-sm text-white/70">Registre o ubique al paciente por DPI.</p>
          </div>
          <div className="border-l-4 border-[#f6c85f] pl-4">
            <p className="font-semibold">2. Cita</p>
            <p className="mt-1 text-sm text-white/70">Valide disponibilidad y cree la cita pendiente.</p>
          </div>
          <div className="border-l-4 border-[#f6c85f] pl-4">
            <p className="font-semibold">3. Pago</p>
            <p className="mt-1 text-sm text-white/70">Procese el cobro para confirmar la cita.</p>
          </div>
        </div>
      </section>
    </div>
  );
}
