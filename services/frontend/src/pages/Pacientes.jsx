import React, { useState, useEffect } from 'react';
import { pacienteService } from '../services/api';
import { UserPlus, Search, List as ListIcon } from 'lucide-react';

export default function Pacientes() {
  const [pacientes, setPacientes] = useState([]);
  const [loading, setLoading] = useState(false);
  const [form, setForm] = useState({ dpi: '', nombre: '', correo: '', telefono: '' });
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

  const handleCreate = async (e) => {
    e.preventDefault();
    try {
      await pacienteService.crear(form);
      setMessage({ type: 'success', text: 'Paciente registrado exitosamente' });
      setForm({ dpi: '', nombre: '', correo: '', telefono: '' });
      fetchPacientes();
    } catch (err) {
      setMessage({ type: 'error', text: 'Error al registrar paciente' });
    }
  };

  return (
    <div className="space-y-8">
      <header>
        <h2 className="text-3xl font-bold text-gray-800">Gestión de Pacientes</h2>
        <p className="text-gray-500">Registra y administra los datos de los pacientes.</p>
      </header>

      {message && (
        <div className={`p-4 rounded-lg ${message.type === 'success' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
          {message.text}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Formulario */}
        <section className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
          <div className="flex items-center gap-2 mb-6 border-b pb-4">
            <UserPlus className="text-indigo-600" />
            <h3 className="text-xl font-semibold">Nuevo Paciente</h3>
          </div>
          <form onSubmit={handleCreate} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700">DPI</label>
              <input 
                type="text" 
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 bg-gray-50 p-2"
                value={form.dpi}
                onChange={e => setForm({...form, dpi: e.target.value})}
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">Nombre Completo</label>
              <input 
                type="text" 
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 bg-gray-50 p-2"
                value={form.nombre}
                onChange={e => setForm({...form, nombre: e.target.value})}
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">Correo Electrónico</label>
              <input 
                type="email" 
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 bg-gray-50 p-2"
                value={form.correo}
                onChange={e => setForm({...form, correo: e.target.value})}
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700">Teléfono</label>
              <input 
                type="text" 
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 bg-gray-50 p-2"
                value={form.telefono}
                onChange={e => setForm({...form, telefono: e.target.value})}
                required
              />
            </div>
            <button 
              type="submit" 
              className="w-full bg-indigo-600 text-white py-2 px-4 rounded-md hover:bg-indigo-700 transition font-semibold"
            >
              Registrar Paciente
            </button>
          </form>
        </section>

        {/* Listado */}
        <section className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
          <div className="flex items-center gap-2 mb-6 border-b pb-4">
            <ListIcon className="text-indigo-600" />
            <h3 className="text-xl font-semibold">Pacientes Recientes</h3>
          </div>
          {loading ? (
            <div className="text-center py-10">Cargando...</div>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead>
                  <tr>
                    <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Nombre</th>
                    <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">DPI</th>
                    <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Estado</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {pacientes.map(p => (
                    <tr key={p.id}>
                      <td className="px-4 py-3 text-sm font-medium text-gray-900">{p.nombre}</td>
                      <td className="px-4 py-3 text-sm text-gray-500">{p.dpi}</td>
                      <td className="px-4 py-3 text-sm text-gray-500">
                        <span className="px-2 py-1 bg-green-100 text-green-700 rounded-full text-xs font-bold">ACTIVO</span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      </div>
    </div>
  );
}
