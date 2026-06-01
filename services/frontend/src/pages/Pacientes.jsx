import React, { useState, useEffect } from 'react';
import { Mail, Phone, Search, UserPlus } from 'lucide-react';
import { pacienteService } from '../services/api';

export default function Pacientes() {
  const [pacientes, setPacientes] = useState([]);
  const [loading, setLoading] = useState(false);
  const [form, setForm] = useState({ dpi: '', nombre: '', telefono: '', correo: '' });
  const [message, setMessage] = useState(null);

  useEffect(() => {
    fetchPacientes();
  }, []);

  const fetchPacientes = async () => {
    try {
      setLoading(true);
      const res = await pacienteService.listar();
      setPacientes(res.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      await pacienteService.crear(form);
      setMessage({ type: 'success', text: 'Paciente registrado exitosamente en el sistema.' });
      setForm({ dpi: '', nombre: '', telefono: '', correo: '' });
      fetchPacientes();
    } catch (err) {
      const validationErrors = err.response?.data?.validationErrors;
      const detail = validationErrors
        ? Object.values(validationErrors).join(' ')
        : err.response?.data?.message || err.response?.data?.error;
      setMessage({ type: 'error', text: detail || 'Error al procesar el registro. Verifique DPI, correo y telefono.' });
    }
  };

  return (
    <div className="max-w-6xl mx-auto space-y-10 py-6">
      <header className="border-b border-gray-200 pb-6">
        <h2 className="text-2xl font-semibold text-gray-900">Registro de Pacientes</h2>
        <p className="text-gray-500 mt-1">Gestión de expedientes y nuevos ingresos a la clínica.</p>
      </header>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-10">
        {/* Formulario Profesional */}
        <div className="lg:col-span-1">
          <div className="bg-white p-6 rounded-lg border border-gray-200 shadow-sm sticky top-6">
            <h3 className="text-lg font-medium text-gray-900 mb-6 flex items-center gap-2">
              <UserPlus size={20} className="text-blue-600" />
              Nuevo Ingreso
            </h3>
            
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-gray-500 uppercase mb-1 tracking-wider">CUI / DPI</label>
                <input 
                  required
                  type="text" 
                  className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 p-2.5 text-sm border"
                  value={form.dpi}
                  onChange={e => setForm({...form, dpi: e.target.value})}
                  placeholder="0000 00000 0000"
                />
              </div>
              <div>
                <label className="block text-xs font-semibold text-gray-500 uppercase mb-1 tracking-wider">Nombre Completo</label>
                <input 
                  required
                  type="text" 
                  className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 p-2.5 text-sm border"
                  value={form.nombre}
                  onChange={e => setForm({...form, nombre: e.target.value})}
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-gray-500 uppercase mb-1 tracking-wider">Teléfono</label>
                  <input
                    required
                    type="text" 
                    className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 p-2.5 text-sm border"
                    value={form.telefono}
                    onChange={e => setForm({...form, telefono: e.target.value})}
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-gray-500 uppercase mb-1 tracking-wider">Email</label>
                  <input
                    required
                    type="email" 
                    className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 p-2.5 text-sm border"
                    value={form.correo}
                    onChange={e => setForm({...form, correo: e.target.value})}
                  />
                </div>
              </div>
              
              <button 
                type="submit"
                className="w-full bg-blue-600 text-white py-3 rounded-md hover:bg-blue-700 transition font-medium text-sm mt-4 shadow-sm"
              >
                Registrar Expediente
              </button>

              {message && (
                <div className={`p-4 rounded-md text-sm mt-4 ${
                  message.type === 'success' ? 'bg-green-50 text-green-700 border border-green-200' : 'bg-red-50 text-red-700 border border-red-200'
                }`}>
                  {message.text}
                </div>
              )}
            </form>
          </div>
        </div>

        {/* Listado Profesional */}
        <div className="lg:col-span-2 space-y-6">
          <div className="flex justify-between items-center">
            <h3 className="text-lg font-medium text-gray-900">Expedientes Registrados</h3>
            <div className="relative">
              <span className="absolute inset-y-0 left-0 pl-3 flex items-center text-gray-400">
                <Search size={16} />
              </span>
              <input 
                type="text" 
                placeholder="Buscar por DPI o nombre..."
                className="pl-10 pr-4 py-2 border border-gray-200 rounded-full text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 w-64 shadow-sm"
              />
            </div>
          </div>

          <div className="bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden">
            <table className="min-w-full divide-y divide-gray-200 text-sm">
              <thead className="bg-gray-50 text-gray-500">
                <tr>
                  <th className="px-6 py-4 text-left font-semibold uppercase tracking-wider">Paciente</th>
                  <th className="px-6 py-4 text-left font-semibold uppercase tracking-wider">CUI / DPI</th>
                  <th className="px-6 py-4 text-left font-semibold uppercase tracking-wider">Contacto</th>
                  <th className="px-6 py-4 text-center font-semibold uppercase tracking-wider">Estado</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {pacientes.map(p => (
                  <tr key={p.id} className="hover:bg-gray-50 transition">
                    <td className="px-6 py-4">
                      <div className="font-medium text-gray-900">{p.nombre}</div>
                      <div className="text-xs text-gray-400 font-mono">{p.id}</div>
                    </td>
                    <td className="px-6 py-4 text-gray-600 font-medium">{p.dpi}</td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-2 text-gray-600">
                        <Phone size={14} className="text-gray-400" /> {p.telefono}
                      </div>
                      <div className="flex items-center gap-2 text-gray-600">
                        <Mail size={14} className="text-gray-400" /> {p.correo}
                      </div>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <span className="px-2.5 py-1 bg-green-100 text-green-800 rounded-full text-xs font-medium border border-green-200">
                        ACTIVO
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {pacientes.length === 0 && !loading && (
              <div className="py-20 text-center text-gray-400 italic">
                No se han encontrado expedientes clínicos registrados.
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
