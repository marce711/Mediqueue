import React from 'react';
import { LayoutGrid, Users, Calendar, CreditCard, Activity, Bell, Settings } from 'lucide-react';
import { NavLink } from 'react-router-dom';

export default function Dashboard() {
  const stats = [
    { label: 'Pacientes Registrados', value: '0', icon: Users, color: 'text-blue-600', bg: 'bg-blue-50' },
    { label: 'Citas Hoy', value: '0', icon: Calendar, color: 'text-indigo-600', bg: 'bg-indigo-50' },
    { label: 'Pagos Pendientes', value: '0', icon: CreditCard, color: 'text-emerald-600', bg: 'bg-emerald-50' },
    { label: 'Alertas Médicas', value: '0', icon: Bell, color: 'text-amber-600', bg: 'bg-amber-50' },
  ];

  return (
    <div className="max-w-6xl mx-auto space-y-10 py-6">
      <header className="flex justify-between items-end border-b border-gray-200 pb-6">
        <div>
          <h2 className="text-3xl font-bold text-gray-900">Panel de Control</h2>
          <p className="text-gray-500 mt-1">Bienvenido al Sistema de Gestión Clínica Mediqueue.</p>
        </div>
        <div className="text-right">
          <p className="text-sm font-medium text-gray-900">{new Date().toLocaleDateString('es-ES', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}</p>
          <p className="text-xs text-gray-400">Estado del Sistema: <span className="text-green-500 font-bold">OPERATIVO</span></p>
        </div>
      </header>

      {/* Estadísticas Profesionales */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {stats.map((stat, i) => (
          <div key={i} className="bg-white p-6 rounded-lg border border-gray-200 shadow-sm hover:shadow-md transition group">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-500 mb-1">{stat.label}</p>
                <p className="text-2xl font-bold text-gray-900">{stat.value}</p>
              </div>
              <div className={`p-3 rounded-lg ${stat.bg} ${stat.color} group-hover:scale-110 transition-transform`}>
                <stat.icon size={24} />
              </div>
            </div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Acceso Rápido */}
        <div className="lg:col-span-2 space-y-6">
          <h3 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
            <LayoutGrid size={20} className="text-blue-600" />
            Operaciones Frecuentes
          </h3>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <NavLink to="/pacientes" className="flex items-center gap-4 p-4 bg-white border border-gray-200 rounded-lg hover:border-blue-300 hover:bg-blue-50 transition group">
              <div className="p-3 bg-gray-50 rounded-full group-hover:bg-white transition-colors">
                <Users className="text-gray-600 group-hover:text-blue-600" />
              </div>
              <div>
                <p className="font-semibold text-gray-900 text-sm">Nuevo Paciente</p>
                <p className="text-xs text-gray-500">Alta de expediente clínico</p>
              </div>
            </NavLink>
            <NavLink to="/citas" className="flex items-center gap-4 p-4 bg-white border border-gray-200 rounded-lg hover:border-indigo-300 hover:bg-indigo-50 transition group">
              <div className="p-3 bg-gray-50 rounded-full group-hover:bg-white transition-colors">
                <Calendar className="text-gray-600 group-hover:text-indigo-600" />
              </div>
              <div>
                <p className="font-semibold text-gray-900 text-sm">Agenda Médica</p>
                <p className="text-xs text-gray-500">Programación de consultas</p>
              </div>
            </NavLink>
            <NavLink to="/pagos" className="flex items-center gap-4 p-4 bg-white border border-gray-200 rounded-lg hover:border-emerald-300 hover:bg-emerald-50 transition group">
              <div className="p-3 bg-gray-50 rounded-full group-hover:bg-white transition-colors">
                <CreditCard className="text-gray-600 group-hover:text-emerald-600" />
              </div>
              <div>
                <p className="font-semibold text-gray-900 text-sm">Caja y Cobros</p>
                <p className="text-xs text-gray-500">Conciliación de pagos</p>
              </div>
            </NavLink>
            <div className="flex items-center gap-4 p-4 bg-gray-50 border border-gray-100 rounded-lg opacity-60 cursor-not-allowed">
              <div className="p-3 bg-white rounded-full">
                <Settings className="text-gray-400" />
              </div>
              <div>
                <p className="font-semibold text-gray-400 text-sm">Configuración</p>
                <p className="text-xs text-gray-400">Próximamente</p>
              </div>
            </div>
          </div>
        </div>

        {/* Resumen de Actividad */}
        <div className="space-y-6">
          <h3 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
            <Activity size={20} className="text-red-600" />
            Actividad Reciente
          </h3>
          <div className="bg-white rounded-lg border border-gray-200 shadow-sm divide-y divide-gray-100">
            <div className="p-4 text-center py-10">
              <p className="text-sm text-gray-400 italic">No hay actividad registrada en la última hora.</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
