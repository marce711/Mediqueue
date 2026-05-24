import React from 'react';
import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom';
import { LayoutDashboard, Users, Calendar, CreditCard, Activity } from 'lucide-react';
import Dashboard from './pages/Dashboard';
import Pacientes from './pages/Pacientes';
import Citas from './pages/Citas';
import Pagos from './pages/Pagos';

function App() {
  return (
    <Router>
      <div className="flex min-h-screen bg-gray-50">
        {/* Sidebar */}
        <aside className="w-64 bg-indigo-700 text-white p-6 shadow-xl">
          <div className="flex items-center gap-3 mb-10">
            <Activity size={32} className="text-indigo-200" />
            <h1 className="text-2xl font-bold tracking-tight">Mediqueue</h1>
          </div>
          
          <nav className="space-y-2">
            <SidebarLink to="/" icon={<LayoutDashboard size={20} />} label="Dashboard" />
            <SidebarLink to="/pacientes" icon={<Users size={20} />} label="Pacientes" />
            <SidebarLink to="/citas" icon={<Calendar size={20} />} label="Citas" />
            <SidebarLink to="/pagos" icon={<CreditCard size={20} />} label="Pagos" />
          </nav>
          
          <div className="mt-auto pt-10 border-t border-indigo-600 opacity-60 text-sm">
            <p>HA Infrastructure Active</p>
            <p className="text-xs">Cluster Mode: Swarm</p>
          </div>
        </aside>

        {/* Main Content */}
        <main className="flex-1 p-8 overflow-auto">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/pacientes" element={<Pacientes />} />
            <Route path="/citas" element={<Citas />} />
            <Route path="/pagos" element={<Pagos />} />
          </Routes>
        </main>
      </div>
    </Router>
  );
}

function SidebarLink({ to, icon, label }) {
  return (
    <Link 
      to={to} 
      className="flex items-center gap-3 px-4 py-3 rounded-lg hover:bg-indigo-600 transition-colors duration-200 font-medium"
    >
      {icon}
      <span>{label}</span>
    </Link>
  );
}

export default App;
