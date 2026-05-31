import React, { useState } from 'react';
import { CreditCard, DollarSign, CheckCircle, Search, Hash } from 'lucide-react';
import { pagoService } from '../services/api';

export default function Pagos() {
  const [appointmentId, setAppointmentId] = useState('');
  const [pagos, setPagos] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const handleSearch = async () => {
    if (!appointmentId.trim()) return;
    
    try {
      setLoading(true);
      setError(null);
      const res = await pagoService.obtenerPorCita(appointmentId);
      setPagos(Array.isArray(res.data) ? res.data : [res.data]);
    } catch (err) {
      console.error(err);
      setPagos([]);
      setError('No se encontraron registros para esta cita.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-6xl mx-auto space-y-8 py-6">
      <header className="border-b border-gray-200 pb-6">
        <h2 className="text-2xl font-semibold text-gray-900">Gestión de Cobros y Pagos</h2>
        <p className="text-gray-500 mt-1">Portal administrativo para la conciliación de citas médicas.</p>
      </header>

      <div className="bg-white p-8 rounded-lg shadow-sm border border-gray-200 max-w-2xl mx-auto">
        <div className="flex items-center gap-3 mb-6">
          <div className="p-2 bg-blue-50 rounded-lg text-blue-600">
            <Hash size={20} />
          </div>
          <h3 className="text-lg font-medium text-gray-900">Validación de Cita</h3>
        </div>
        
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">ID de la Cita Médica</label>
            <div className="flex gap-3">
              <input 
                type="text" 
                placeholder="Ej: uuid-de-la-cita"
                className="flex-1 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 p-2.5 text-sm border"
                value={appointmentId}
                onChange={e => setAppointmentId(e.target.value)}
              />
              <button 
                onClick={handleSearch}
                disabled={loading}
                className="bg-blue-600 text-white px-8 py-2.5 rounded-md hover:bg-blue-700 transition font-medium text-sm disabled:opacity-50"
              >
                {loading ? 'Consultando...' : 'Consultar'}
              </button>
            </div>
          </div>
          {error && <p className="text-sm text-red-600">{error}</p>}
        </div>
      </div>

      <div className="mt-8">
        <div className="flex items-center justify-between mb-4">
          <h4 className="text-lg font-medium text-gray-900">Resultados de Transacción</h4>
          <span className="text-sm text-gray-500">{pagos.length} registro(s) encontrado(s)</span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {pagos.map(pago => (
            <div key={pago.id} className="bg-white p-6 rounded-lg border border-gray-200 shadow-sm flex items-start gap-4">
              <div className={`p-3 rounded-full ${pago.status === 'SUCCESS' ? 'bg-green-100 text-green-600' : 'bg-blue-100 text-blue-600'}`}>
                <DollarSign size={24} />
              </div>
              <div className="flex-1">
                <div className="flex justify-between items-center mb-2">
                  <p className="text-xl font-bold text-gray-900">Q {pago.amount ? pago.amount.toFixed(2) : '0.00'}</p>
                  <span className={`px-2.5 py-0.5 rounded-full text-xs font-semibold uppercase tracking-wider ${
                    pago.status === 'SUCCESS' ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800'
                  }`}>
                    {pago.status || 'PROCESADO'}
                  </span>
                </div>
                <div className="grid grid-cols-2 gap-y-2 text-sm">
                  <p className="text-gray-500">Referencia:</p>
                  <p className="text-gray-900 font-mono">{pago.transactionId || pago.id.toString().substring(0,12)}</p>
                  <p className="text-gray-500">Fecha Valor:</p>
                  <p className="text-gray-900">{new Date(pago.creadoEn || Date.now()).toLocaleDateString()}</p>
                  <p className="text-gray-500">Paciente ID:</p>
                  <p className="text-gray-900 text-xs truncate">{pago.patientId}</p>
                </div>
              </div>
            </div>
          ))}

          {pagos.length === 0 && !loading && (
            <div className="col-span-full py-16 text-center bg-gray-50 rounded-lg border-2 border-dashed border-gray-200">
              <div className="mx-auto w-12 h-12 text-gray-300 mb-4">
                <Search size={48} />
              </div>
              <p className="text-gray-500 font-medium">Búsqueda de conciliación bancaria</p>
              <p className="text-gray-400 text-sm mt-1">Ingrese el ID de cita para visualizar el estado del pago correspondiente.</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
