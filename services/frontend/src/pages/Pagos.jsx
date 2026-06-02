import React, { useEffect, useState } from 'react';
import { DollarSign, FileText, Hash, Search } from 'lucide-react';
import { useSearchParams } from 'react-router-dom';
import { citaService, pagoService } from '../services/api';

export default function Pagos() {
  const [searchParams] = useSearchParams();
  const [appointmentId, setAppointmentId] = useState('');
  const [amount, setAmount] = useState('');
  const [pagos, setPagos] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [message, setMessage] = useState(null);

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

  const handleSearch = async () => {
    if (!appointmentId.trim()) return;

    try {
      setLoading(true);
      setError(null);
      setMessage(null);
      const res = await pagoService.obtenerPorCita(appointmentId.trim());
      setPagos(Array.isArray(res.data) ? res.data : [res.data]);
    } catch (err) {
      console.error(err);
      setPagos([]);
      try {
        const cita = await citaService.obtener(appointmentId.trim());
        if (cita.data?.consultationPrice) {
          setAmount(String(cita.data.consultationPrice));
          setMessage({ type: 'success', text: 'Cita encontrada. El monto fue cargado automaticamente.' });
          setError(null);
          return;
        }
      } catch (lookupError) {
        console.error(lookupError);
      }
      setError('No se encontraron pagos para esta cita.');
    } finally {
      setLoading(false);
    }
  };

  const handlePayment = async (e) => {
    e.preventDefault();
    if (!appointmentId.trim() || !amount) return;

    try {
      setLoading(true);
      setError(null);
      setMessage(null);
      const normalizedAppointmentId = appointmentId.trim();
      const res = await pagoService.procesar({
        appointmentId: normalizedAppointmentId,
        amount: Number(amount),
      }, `pago-${normalizedAppointmentId}`);
      setPagos([res.data]);
      setMessage({ type: 'success', text: 'Pago registrado. La cita fue confirmada.' });
      setAmount('');
    } catch (err) {
      console.error(err);
      const detail = err.response?.data?.message || err.response?.data?.error;
      setMessage({ type: 'error', text: detail || 'No se pudo registrar el pago. Verifique que el ID de cita exista.' });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="mx-auto max-w-6xl space-y-8 py-2">
      <header className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
        <p className="text-sm font-semibold uppercase tracking-wider text-[#2f6f62]">Caja</p>
        <h2 className="mt-2 text-3xl font-bold text-slate-950">Pagos por cita</h2>
        <p className="mt-2 text-slate-600">Consulte o registre pagos usando el ID de la cita medica.</p>
      </header>

      <div className="grid gap-6 lg:grid-cols-2">
        <section className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
          <div className="mb-6 flex items-center gap-3">
            <div className="rounded-md bg-[#e0eee8] p-2 text-[#12312b]">
              <Hash size={20} />
            </div>
            <h3 className="text-lg font-bold text-slate-950">Consultar cita</h3>
          </div>

          <div className="space-y-4">
            <label className="block text-sm font-semibold text-slate-700">ID de la cita medica</label>
            <div className="flex flex-col gap-3 sm:flex-row">
              <input
                type="text"
                placeholder="UUID de la cita"
                className="flex-1 rounded-md border border-slate-300 p-3 text-sm focus:border-[#2f6f62] focus:outline-none focus:ring-2 focus:ring-[#2f6f62]/20"
                value={appointmentId}
                onChange={e => setAppointmentId(e.target.value)}
              />
              <button
                onClick={handleSearch}
                disabled={loading}
                className="rounded-md bg-[#12312b] px-6 py-3 text-sm font-semibold text-white transition hover:bg-[#1b493f] disabled:opacity-50"
              >
                {loading ? 'Consultando...' : 'Consultar'}
              </button>
            </div>
            {error && <p className="text-sm text-red-700">{error}</p>}
          </div>
        </section>

        <section className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
          <div className="mb-6 flex items-center gap-3">
            <div className="rounded-md bg-[#fff1cf] p-2 text-[#6f4b00]">
              <FileText size={20} />
            </div>
            <h3 className="text-lg font-bold text-slate-950">Registrar pago</h3>
          </div>

          <form onSubmit={handlePayment} className="space-y-4">
            <div>
              <label className="block text-sm font-semibold text-slate-700">ID de la cita medica</label>
              <input
                required
                type="text"
                placeholder="UUID de la cita"
                className="mt-2 w-full rounded-md border border-slate-300 p-3 text-sm focus:border-[#2f6f62] focus:outline-none focus:ring-2 focus:ring-[#2f6f62]/20"
                value={appointmentId}
                onChange={e => setAppointmentId(e.target.value)}
              />
            </div>
            <div>
              <label className="block text-sm font-semibold text-slate-700">Monto</label>
              <input
                required
                type="number"
                min="0.01"
                step="0.01"
                placeholder="0.00"
                className="mt-2 w-full rounded-md border border-slate-300 p-3 text-sm focus:border-[#2f6f62] focus:outline-none focus:ring-2 focus:ring-[#2f6f62]/20"
                value={amount}
                onChange={e => setAmount(e.target.value)}
              />
            </div>
            <button
              type="submit"
              disabled={loading}
              className="w-full rounded-md bg-[#f6c85f] px-6 py-3 text-sm font-bold text-[#12312b] transition hover:bg-[#e9b94b] disabled:opacity-50"
            >
              {loading ? 'Procesando...' : 'Registrar pago'}
            </button>
            {message && (
              <div className={`rounded-md p-3 text-sm ${
                message.type === 'success' ? 'bg-green-50 text-green-800 ring-1 ring-green-200' : 'bg-red-50 text-red-800 ring-1 ring-red-200'
              }`}>
                {message.text}
              </div>
            )}
          </form>
        </section>
      </div>

      <div>
        <div className="mb-4 flex items-center justify-between">
          <h4 className="text-lg font-bold text-slate-950">Pagos encontrados</h4>
          <span className="text-sm text-slate-500">{pagos.length} registro(s)</span>
        </div>

        <div className="grid grid-cols-1 gap-5 md:grid-cols-2">
          {pagos.map(pago => (
            <div key={pago.id} className="flex items-start gap-4 rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
              <div className={`rounded-md p-3 ${pago.status === 'SUCCESS' ? 'bg-green-100 text-green-700' : 'bg-[#e8edf6] text-[#253a63]'}`}>
                <DollarSign size={24} />
              </div>
              <div className="min-w-0 flex-1">
                <div className="mb-3 flex items-center justify-between gap-3">
                  <p className="text-xl font-bold text-slate-950">Q {pago.amount ? Number(pago.amount).toFixed(2) : '0.00'}</p>
                  <span className={`rounded-full px-3 py-1 text-xs font-bold uppercase ${
                    pago.status === 'SUCCESS' ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800'
                  }`}>
                    {pago.status || 'PROCESADO'}
                  </span>
                </div>
                <div className="grid grid-cols-[110px_1fr] gap-y-2 text-sm">
                  <p className="text-slate-500">Referencia</p>
                  <p className="truncate font-mono text-slate-900">{pago.id}</p>
                  <p className="text-slate-500">Cita</p>
                  <p className="truncate font-mono text-slate-900">{pago.appointmentId}</p>
                </div>
              </div>
            </div>
          ))}

          {pagos.length === 0 && !loading && (
            <div className="col-span-full rounded-md border-2 border-dashed border-slate-300 bg-white py-14 text-center">
              <Search size={40} className="mx-auto mb-3 text-slate-300" />
              <p className="font-semibold text-slate-600">Ingrese el ID de cita para consultar o registrar un pago.</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
