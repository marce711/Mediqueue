import React, { useState, useEffect } from 'react';
import { LayoutDashboard, Users, Calendar, CreditCard, Activity, Server, ShieldCheck, Database } from 'lucide-react';
import { pacienteService, citaService } from '../services/api';

export default function Dashboard() {
  const [stats, setStats] = useState({ pacientes: 0, citas: 0, pagos: 0 });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadStats() {
      try {
        const [p, c] = await Promise.all([pacienteService.listar(), citaService.listar()]);
        setStats({
          pacientes: p.data.length,
          citas: c.data.length,
          pagos: 0 // Mock por ahora
        });
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    }
    loadStats();
  }, []);

  return (
    <div className="space-y-8">
      <header className="flex justify-between items-center">
        <div>
          <h2 className="text-3xl font-bold text-gray-800">Panel de Control</h2>
          <p className="text-gray-500">Bienvenido al sistema de gestión Mediqueue HA.</p>
        </div>
        <div className="flex gap-2">
          <span className="flex items-center gap-1 bg-green-100 text-green-700 px-3 py-1 rounded-full text-xs font-bold border border-green-200">
            <ShieldCheck size={14} /> Database HA: Online
          </span>
          <span className="flex items-center gap-1 bg-indigo-100 text-indigo-700 px-3 py-1 rounded-full text-xs font-bold border border-indigo-200">
            <Server size={14} /> Nodes: 3 Active
          </span>
        </div>
      </header>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <StatCard icon={<Users className="text-blue-600" />} label="Pacientes Totales" value={stats.pacientes} color="blue" />
        <StatCard icon={<Calendar className="text-indigo-600" />} label="Citas Agendadas" value={stats.citas} color="indigo" />
        <StatCard icon={<CreditCard className="text-green-600" />} label="Pagos Procesados" value={stats.pagos} color="green" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Infra Status */}
        <section className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
          <h3 className="text-xl font-bold mb-6 flex items-center gap-2 border-b pb-4">
            <Activity className="text-indigo-600" /> Monitoreo de Infraestructura
          </h3>
          <div className="space-y-4">
            <InfraLink label="RabbitMQ Dashboard" url="http://localhost:15672" status="Operational" />
            <InfraLink label="HAProxy Stats (Database)" url="http://localhost:7000" status="Active" />
            <InfraLink label="pgAdmin Console" url="http://localhost:5050" status="Available" />
            <InfraLink label="Prometheus Metrics" url="http://localhost:9090" status="Collecting" />
          </div>
        </section>

        {/* Database Cluster Info */}
        <section className="bg-gradient-to-br from-indigo-700 to-indigo-900 p-6 rounded-xl shadow-lg text-white">
          <h3 className="text-xl font-bold mb-6 flex items-center gap-2 border-b border-indigo-500/50 pb-4">
            <Database className="text-indigo-200" /> Cluster de Base de Datos
          </h3>
          <div className="space-y-6">
            <div className="flex justify-between items-center">
              <div>
                <p className="text-indigo-200 text-sm">Tecnología Principal</p>
                <p className="font-bold text-lg">Patroni + etcd</p>
              </div>
              <div className="text-right">
                <p className="text-indigo-200 text-sm">Consistencia</p>
                <p className="font-bold text-lg">Sincrónica</p>
              </div>
            </div>
            <div className="bg-indigo-800/50 p-4 rounded-lg border border-indigo-400/20">
              <p className="text-sm italic opacity-80">
                "Si un nodo líder falla, Patroni elige un nuevo líder automáticamente. HAProxy redirige el tráfico de este frontend al nuevo líder sin pérdida de datos."
              </p>
            </div>
            <div className="flex gap-2">
              <div className="flex-1 h-2 bg-green-400 rounded-full" title="Node 1 OK"></div>
              <div className="flex-1 h-2 bg-green-400 rounded-full" title="Node 2 OK"></div>
              <div className="flex-1 h-2 bg-green-400 rounded-full" title="Node 3 OK"></div>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}

function StatCard({ icon, label, value, color }) {
  return (
    <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100 flex items-center gap-4 hover:border-indigo-200 transition-colors">
      <div className={`p-4 bg-${color}-50 rounded-lg`}>{icon}</div>
      <div>
        <p className="text-sm text-gray-500 font-medium">{label}</p>
        <p className="text-2xl font-bold text-gray-900">{value}</p>
      </div>
    </div>
  );
}

function InfraLink({ label, url, status }) {
  return (
    <div className="flex justify-between items-center p-3 hover:bg-gray-50 rounded-lg transition">
      <div>
        <p className="font-bold text-gray-800">{label}</p>
        <a href={url} target="_blank" rel="noreferrer" className="text-xs text-indigo-600 hover:underline">Acceder al panel &rarr;</a>
      </div>
      <span className="text-xs font-bold text-green-600 bg-green-50 px-2 py-1 rounded border border-green-100">{status}</span>
    </div>
  );
}
