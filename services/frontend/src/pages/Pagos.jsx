import React, { useEffect, useState } from 'react';
import { DollarSign, FileText, Hash, Search, Activity, CheckCircle2, AlertCircle, X } from 'lucide-react';
import { useSearchParams } from 'react-router-dom';
import { citaService, pagoService } from '../services/api';

export default function Pagos() {
  const [searchParams] = useSearchParams();
  const [appointmentId, setAppointmentId] = useState('');
  const [amount, setAmount] = useState('');
  const [pagosHistory, setPagosHistory] = useState([]); // Historial persistente
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [message, setMessage] = useState(null);
  const [citaDetalle, setCitaDetalle] = useState(null);

  useEffect(() => {
    const appointmentFromQuery = searchParams.get('appointmentId');
    const amountFromQuery = searchParams.get('amount');
    if (appointmentFromQuery) {
      setAppointmentId(appointmentFromQuery);
      if (amountFromQuery) {
        setAmount(amountFromQuery);
      }
      setMessage({ type: 'success', text: 'Cita pendiente recibida. Registre el pago para confirmarla.' });
    }
  }, [searchParams]);

  const addToHistory = (nuevosPagos) => {
    const data = Array.isArray(nuevosPagos) ? nuevosPagos : [nuevosPagos];
    setPagosHistory(prev => {
      // Filtrar duplicados por ID
      const filtered = data.filter(p => !prev.some(h => h.id === p.id));
      return [...filtered, ...prev];
    });
  };

  const handleSearch = async () => {
    if (!appointmentId.trim()) return;

    try {
      setLoading(true);
      setError(null);
      setMessage(null);
      setCitaDetalle(null);
      
      const resCita = await citaService.obtener(appointmentId.trim());
      setCitaDetalle(resCita.data);
      setAmount(String(resCita.data.consultationPrice));
      
      const resPagos = await pagoService.obtenerPorCita(appointmentId.trim());
      const dataPagos = Array.isArray(resPagos.data) ? resPagos.data : [resPagos.data];
      
      if (dataPagos.length > 0) {
        addToHistory(dataPagos);
        setMessage({ type: 'success', text: 'Se encontraron registros de pago previos.' });
      } else {
        setError('No hay pagos registrados para esta cita.');
      }
    } catch (err) {
      console.error(err);
      setError('Cita no encontrada. Verifique el ID.');
    } finally {
      setLoading(false);
    }
  };

  const handlePayment = async (e) => {
    e.preventDefault();
    if (!appointmentId.trim() || !amount) return;

    // Prevencion de duplicados local
    if (pagosHistory.some(p => p.appointmentId === appointmentId.trim() && p.status === 'SUCCESS')) {
      setMessage({ type: 'error', text: 'Esta cita ya figura como PAGADA en su historial.' });
      return;
    }

    try {
      setLoading(true);
      setError(null);
      setMessage(null);
      const normalizedAppointmentId = appointmentId.trim();
      const res = await pagoService.procesar({
        appointmentId: normalizedAppointmentId,
        amount: Number(amount),
      }, `pago-${normalizedAppointmentId}`);
      
      setMessage({ type: 'success', text: '¡Pago registrado con éxito!' });
      setAmount('');
      addToHistory(res.data);
    } catch (err) {
      console.error(err);
      const detail = err.response?.data?.message || err.response?.data?.error;
      setMessage({ type: 'error', text: detail || 'No se pudo procesar el pago. Posiblemente ya fue pagado.' });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="mx-auto max-w-6xl space-y-8 py-2 px-4">
      <header className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
        <p className="text-sm font-semibold uppercase tracking-wider text-[#2f6f62]">Módulo de Caja</p>
        <h2 className="mt-2 text-3xl font-bold text-slate-950">Gestión de Pagos</h2>
        <p className="mt-2 text-slate-600">Historial de transacciones y registro de cobros.</p>
      </header>

      <div className="grid gap-6 lg:grid-cols-2">
        <section className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
          <div className="mb-6 flex items-center gap-3">
            <div className="rounded-md bg-[#e0eee8] p-2 text-[#12312b]">
              <Hash size={20} />
            </div>
            <h3 className="text-lg font-bold text-slate-950">Consultar Cita</h3>
          </div>

          <div className="space-y-4">
            <label className="block text-sm font-semibold text-slate-700">ID de Cita (UUID)</label>
            <div className="flex flex-col gap-3 sm:flex-row">
              <input
                type="text"
                placeholder="Pegue el ID de la cita..."
                className="flex-1 rounded-md border border-slate-300 p-3 text-sm focus:border-[#2f6f62] outline-none"
                value={appointmentId}
                onChange={e => setAppointmentId(e.target.value)}
              />
              <button
                onClick={handleSearch}
                disabled={loading}
                className="rounded-md bg-[#12312b] px-6 py-3 text-sm font-semibold text-white hover:bg-[#1b493f] transition disabled:opacity-50"
              >
                Consultar
              </button>
            </div>
            {error && <p className="text-xs font-bold text-red-600 bg-red-50 p-2 rounded">{error}</p>}
            
            {citaDetalle && (
              <div className="mt-4 rounded-md bg-slate-50 p-5 ring-1 ring-slate-200">
                <p className="text-[10px] font-black uppercase text-slate-400">Detalles</p>
                <div className="mt-3 space-y-2 text-sm text-slate-900">
                  <div className="flex justify-between"><span>Paciente</span><span className="font-bold">{citaDetalle.patientName}</span></div>
                  <div className="flex justify-between"><span>Especialista</span><span className="font-bold">{citaDetalle.doctorName}</span></div>
                  <div className="flex justify-between"><span>Fecha</span><span className="font-bold">{new Date(citaDetalle.appointmentDate).toLocaleString()}</span></div>
                  <div className="flex justify-between border-t pt-3 font-black text-lg"><span>Monto</span><span className="text-[#2f6f62]">Q {Number(citaDetalle.consultationPrice).toFixed(2)}</span></div>
                </div>
              </div>
            )}
          </div>
        </section>

        <section className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200 border-l-4 border-l-[#f6c85f]">
          <div className="mb-6 flex items-center gap-3">
            <div className="rounded-md bg-[#fff1cf] p-2 text-[#6f4b00]">
              <FileText size={20} />
            </div>
            <h3 className="text-lg font-bold text-slate-950">Nuevo Cobro</h3>
          </div>

          <form onSubmit={handlePayment} className="space-y-4">
            <div>
              <label className="block text-xs font-bold uppercase text-slate-500">ID de Cita</label>
              <input required type="text" className="mt-1 w-full rounded-md border border-slate-300 p-3 text-sm outline-none" value={appointmentId} onChange={e => setAppointmentId(e.target.value)} />
            </div>
            <div>
              <label className="block text-xs font-bold uppercase text-slate-500">Monto (Q)</label>
              <input required type="number" step="0.01" className="mt-1 w-full rounded-md border border-slate-300 p-3 text-sm font-bold outline-none" value={amount} onChange={e => setAmount(e.target.value)} />
            </div>
            <button type="submit" disabled={loading} className="w-full rounded-md bg-[#f6c85f] px-6 py-4 text-sm font-black text-[#12312b] uppercase tracking-widest hover:bg-[#e9b94b] transition shadow-md">
              Finalizar Transacción
            </button>
          </form>
        </section>
      </div>

      <div className="pt-4">
        <div className="mb-6 flex items-center justify-between border-b pb-4">
          <h4 className="text-xl font-black text-slate-950 flex items-center gap-3"><Activity size={24} className="text-[#2f6f62]" /> Historial de Caja</h4>
          <span className="text-xs font-bold bg-slate-100 px-3 py-1 rounded-full">{pagosHistory.length} transacciones</span>
        </div>

        <div className="rounded-xl bg-white shadow-sm ring-1 ring-slate-200 overflow-hidden">
          <table className="w-full text-left text-sm">
            <thead className="bg-slate-50 text-[10px] font-black uppercase text-slate-500 tracking-widest">
              <tr>
                <th className="px-6 py-4">Ref. Pago</th>
                <th className="px-6 py-4">ID Cita Relacionada</th>
                <th className="px-6 py-4">Monto</th>
                <th className="px-6 py-4 text-center">Estado</th>
                <th className="px-6 py-4 text-right">Acción</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {pagosHistory.map(pago => (
                <tr key={pago.id} className="hover:bg-slate-50 transition-colors">
                  <td className="px-6 py-4">
                    <div className="font-mono text-[11px] font-bold text-slate-700">{pago.id}</div>
                  </td>
                  <td className="px-6 py-4">
                    <div className="font-mono text-[11px] text-slate-500">{pago.appointmentId}</div>
                  </td>
                  <td className="px-6 py-4">
                    <div className="text-lg font-black text-slate-950">Q {Number(pago.amount).toFixed(2)}</div>
                  </td>
                  <td className="px-6 py-4 text-center">
                    <span className={`px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-tighter ${
                      pago.status === 'SUCCESS' ? 'bg-green-100 text-green-700' : 'bg-slate-100 text-slate-600'
                    }`}>
                      {pago.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-right">
                    <button onClick={() => {navigator.clipboard.writeText(pago.id); alert('Referencia copiada');}} className="text-xs font-bold text-blue-600 hover:underline">Copiar Ref</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {pagosHistory.length === 0 && (
            <div className="py-24 text-center text-slate-300 italic">
              <Search size={48} className="mx-auto mb-4 opacity-10" />
              No hay registros en el historial de esta sesión.
            </div>
          )}
        </div>
      </div>

      {/* Floating Notifications */}
      {message && (
        <div className="fixed bottom-8 right-8 z-[110] animate-in slide-in-from-right-8">
          <div className={`flex items-center gap-4 rounded-xl p-5 shadow-2xl ring-1 ${message.type === 'success' ? 'bg-[#12312b] text-white' : 'bg-red-600 text-white'}`}>
            {message.type === 'success' ? <CheckCircle2 size={24} className="text-green-400" /> : <AlertCircle size={24} />}
            <p className="text-sm font-bold">{message.text}</p>
            <button onClick={() => setMessage(null)} className="ml-4 hover:opacity-70"><X size={16} /></button>
          </div>
        </div>
      )}
    </div>
  );
}
