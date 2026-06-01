import React from 'react';
import { BrowserRouter as Router, Routes, Route, NavLink } from 'react-router-dom';
import { Calendar, CreditCard, LayoutDashboard, Stethoscope, Users } from 'lucide-react';
import Dashboard from './pages/Dashboard';
import Pacientes from './pages/Pacientes';
import Citas from './pages/Citas';
import Pagos from './pages/Pagos';

function App() {
  return (
    <Router>
      <div className="min-h-screen bg-[#f5f7f4] text-slate-900 lg:flex">
        <aside className="bg-[#12312b] p-5 text-white lg:w-72 lg:p-7">
          <div className="mb-8 flex items-center gap-3">
            <div className="grid h-11 w-11 place-items-center rounded-md bg-[#f6c85f] text-[#12312b]">
              <Stethoscope size={24} />
            </div>
            <div>
              <h1 className="text-2xl font-bold tracking-tight">Mediqueue</h1>
              <p className="text-sm text-white/65">Gestion clinica</p>
            </div>
          </div>

          <nav className="grid gap-2 sm:grid-cols-4 lg:grid-cols-1">
            <SidebarLink to="/" icon={<LayoutDashboard size={20} />} label="Inicio" />
            <SidebarLink to="/pacientes" icon={<Users size={20} />} label="Pacientes" />
            <SidebarLink to="/citas" icon={<Calendar size={20} />} label="Citas" />
            <SidebarLink to="/pagos" icon={<CreditCard size={20} />} label="Pagos" />
          </nav>
        </aside>

        <main className="flex-1 overflow-auto p-4 sm:p-6 lg:p-8">
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
    <NavLink
      to={to}
      className={({ isActive }) =>
        `flex items-center gap-3 rounded-md px-4 py-3 text-sm font-semibold transition ${
          isActive ? 'bg-white text-[#12312b]' : 'text-white/80 hover:bg-white/10 hover:text-white'
        }`
      }
    >
      {icon}
      <span>{label}</span>
    </NavLink>
  );
}

export default App;
