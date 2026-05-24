import React, { useState } from 'react';
import { CreditCard, DollarSign, CheckCircle, Search } from 'lucide-react';
import { pagoService } from '../services/api';

export default function Pagos() {
  const [pacienteId, setPacienteId] = useState('');
  const [pagos, setPagos] = useState([]);
  const [loading, setLoading] = useState(false);

  const handleSearch = async () => {
    try {
      setLoading(true);
      const res = await pagoService.listarPorPaciente(pacienteId);
      setPagos(res.data);
    } catch (err) {
      console.error(err);
      setPagos([]);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-8">
      <header>
        <h2 className="text-3xl font-bold text-gray-800">Módulo de Pagos</h2>
        <p className="text-gray-500">Consulta y gestiona las transacciones de los pacientes.</p>
      </header>

      <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100 max-w-2xl">
        <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
          <Search size={18} className="text-indigo-600" />
          Consultar por ID de Paciente
        </h3>
        <div className="flex gap-2">
          <input 
            type="text" 
            placeholder="Ingrese el UUID del paciente"
            className="flex-1 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 bg-gray-50 p-2 text-sm"
            value={pacienteId}
            onChange={e => setPacienteId(e.target.value)}
          />
          <button 
            onClick={handleSearch}
            className="bg-indigo-600 text-white px-6 py-2 rounded-md hover:bg-indigo-700 transition"
          >
            Buscar Pagos
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {pagos.map(pago => (
          <div key={pago.id} className="bg-white p-6 rounded-xl shadow-sm border border-gray-100 hover:shadow-md transition">
            <div className="flex justify-between items-start mb-4">
              <div className="p-3 bg-green-50 rounded-lg text-green-600">
                <DollarSign size={24} />
              </div>
              <span className={`px-2 py-1 rounded-full text-xs font-bold ${
                pago.estado === 'PAGADO' ? 'bg-green-100 text-green-700' : 'bg-yellow-100 text-yellow-700'
              }`}>
                {pago.estado}
              </span>
            </div>
            <div className="space-y-2">
              <p className="text-2xl font-bold text-gray-900">Q {pago.monto.toFixed(2)}</p>
              <p className="text-sm text-gray-500">ID Pago: {pago.id.substring(0,8)}...</p>
              <p className="text-xs text-gray-400">Fecha: {new Date(pago.creadoEn).toLocaleString()}</p>
            </div>
            <div className="mt-4 pt-4 border-t border-gray-50 flex items-center gap-2 text-sm text-gray-600">
              <CreditCard size={16} />
              <span>{pago.metodoPago || 'Efectivo / Transferencia'}</span>
            </div>
          </div>
        ))}
        {pagos.length === 0 && !loading && (
          <div className="col-span-full py-20 text-center bg-gray-50 rounded-xl border-2 border-dashed border-gray-200 text-gray-400">
            Realice una búsqueda para ver el historial de pagos.
          </div>
        )}
      </div>
    </div>
  );
}
