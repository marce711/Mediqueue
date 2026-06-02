export default function Pagos() {
  const [searchParams] = useSearchParams();
  const [appointmentId, setAppointmentId] = useState('');
  const [amount, setAmount] = useState('');
  const [pagos, setPagos] = useState([]); // Listado visual actual (vacio al inicio)
  const [pagosHistory, setPagosHistory] = useState([]); // Historial persistente
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [message, setMessage] = useState(null);
  const [citaDetalle, setCitaDetalle] = useState(null);

  useEffect(() => {
    // No cargamos todos al inicio para permitir que el historial se construya por consultas
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
        setMessage({ type: 'success', text: 'Se encontraron registros de pago previos para esta cita.' });
      } else {
        setError('No hay pagos registrados aun para esta cita.');
      }
    } catch (err) {
      console.error(err);
      setError('Cita no encontrada. Verifique el ID ingresado.');
    } finally {
      setLoading(false);
    }
  };

  const handlePayment = async (e) => {
    e.preventDefault();
    if (!appointmentId.trim() || !amount) return;

    // Verificar si ya existe en el historial local
    const alreadyPaid = pagosHistory.some(p => p.appointmentId === appointmentId.trim() && p.status === 'SUCCESS');
    if (alreadyPaid) {
      setMessage({ type: 'error', text: 'Atención: Esta cita ya figura como PAGADA en su historial.' });
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
      
      setMessage({ type: 'success', text: '¡Pago registrado con exito! La cita ha sido confirmada.' });
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
    <div className="mx-auto max-w-6xl space-y-8 py-2">
      <header className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
        <p className="text-sm font-semibold uppercase tracking-wider text-[#2f6f62]">Modulo de Caja</p>
        <h2 className="mt-2 text-3xl font-bold text-slate-950">Gestion de Pagos</h2>
        <p className="mt-2 text-slate-600">Historial de transacciones y registro de cobros.</p>
      </header>

      <div className="grid gap-6 lg:grid-cols-2">
        <section className="rounded-md bg-white p-6 shadow-sm ring-1 ring-slate-200">
          <div className="mb-6 flex items-center gap-3">
            <div className="rounded-md bg-[#e0eee8] p-2 text-[#12312b]">
              <Hash size={20} />
            </div>
            <h3 className="text-lg font-bold text-slate-950">Consultar Estado de Cita</h3>
          </div>

          <div className="space-y-4">
            <label className="block text-sm font-semibold text-slate-700">ID de Cita (UUID)</label>
            <div className="flex flex-col gap-3 sm:flex-row">
              <input
                type="text"
                placeholder="Pegue el ID de la cita aqui..."
                className="flex-1 rounded-md border border-slate-300 p-3 text-sm focus:border-[#2f6f62] focus:outline-none focus:ring-2 focus:ring-[#2f6f62]/20"
                value={appointmentId}
                onChange={e => setAppointmentId(e.target.value)}
              />
              <button
                onClick={handleSearch}
                disabled={loading}
                className="rounded-md bg-[#12312b] px-6 py-3 text-sm font-semibold text-white transition hover:bg-[#1b493f] disabled:opacity-50"
              >
                {loading ? 'Buscando...' : 'Consultar'}
              </button>
            </div>
            {error && <p className="text-xs font-bold text-red-600 bg-red-50 p-2 rounded border border-red-100">{error}</p>}
            
            {citaDetalle && (
              <div className="mt-4 rounded-md bg-slate-50 p-5 ring-1 ring-slate-200 shadow-inner">
                <p className="text-[10px] font-black uppercase tracking-widest text-slate-400">Detalles Recuperados</p>
                <div className="mt-3 space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span className="text-slate-500 font-medium">Paciente</span>
                    <span className="font-bold text-slate-900">{citaDetalle.patientName}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500 font-medium">Especialista</span>
                    <span className="font-bold text-slate-900">{citaDetalle.doctorName}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500 font-medium">Fecha</span>
                    <span className="text-slate-900 font-bold">{new Date(citaDetalle.appointmentDate).toLocaleString()}</span>
                  </div>
                  <div className="flex justify-between border-t border-slate-200 pt-3 mt-1 font-black">
                    <span className="text-slate-900">Monto Sugerido</span>
                    <span className="text-[#2f6f62] text-lg">Q {Number(citaDetalle.consultationPrice).toFixed(2)}</span>
                  </div>
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
            <h3 className="text-lg font-bold text-slate-950">Nuevo Registro de Cobro</h3>
          </div>

          <form onSubmit={handlePayment} className="space-y-4">
            <div>
              <label className="block text-xs font-bold uppercase text-slate-500">ID de Cita</label>
              <input
                required
                type="text"
                className="mt-1 w-full rounded-md border border-slate-300 p-3 text-sm focus:border-[#f6c85f] focus:outline-none focus:ring-2 focus:ring-[#f6c85f]/20"
                value={appointmentId}
                onChange={e => setAppointmentId(e.target.value)}
              />
            </div>
            <div>
              <label className="block text-xs font-bold uppercase text-slate-500">Monto a Cobrar (Q)</label>
              <input
                required
                type="number"
                min="0.01"
                step="0.01"
                className="mt-1 w-full rounded-md border border-slate-300 p-3 text-sm font-bold text-slate-900 focus:border-[#f6c85f] focus:outline-none"
                value={amount}
                onChange={e => setAmount(e.target.value)}
              />
            </div>
            <button
              type="submit"
              disabled={loading}
              className="w-full rounded-md bg-[#f6c85f] px-6 py-4 text-sm font-black text-[#12312b] uppercase tracking-widest transition hover:bg-[#e9b94b] shadow-md disabled:opacity-50"
            >
              {loading ? 'Validando...' : 'Finalizar Transaccion'}
            </button>
            {message && (
              <div className={`rounded-md p-3 text-xs font-bold ring-1 ${
                message.type === 'success' ? 'bg-green-50 text-green-800 ring-green-200' : 'bg-red-50 text-red-800 ring-red-200'
              }`}>
                {message.text}
              </div>
            )}
          </form>
        </section>
      </div>

      <div className="pt-4">
        <div className="mb-4 flex items-center justify-between border-b border-slate-200 pb-4">
          <h4 className="text-xl font-black text-slate-950 flex items-center gap-3">
            <Activity size={24} className="text-[#2f6f62]" />
            Historial de Consultas y Pagos
          </h4>
          <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-bold text-slate-600">{pagosHistory.length} transacciones</span>
        </div>

        <div className="grid grid-cols-1 gap-5 md:grid-cols-2">
          {pagosHistory.map(pago => (
            <div key={pago.id} className="flex items-start gap-4 rounded-md bg-white p-6 shadow-md ring-1 ring-slate-200 hover:ring-[#2f6f62]/30 transition-all">
              <div className={`rounded-lg p-3 ${pago.status === 'SUCCESS' ? 'bg-green-100 text-green-700' : 'bg-slate-100 text-slate-500'}`}>
                <DollarSign size={28} />
              </div>
              <div className="min-w-0 flex-1">
                <div className="mb-3 flex items-center justify-between gap-3">
                  <p className="text-2xl font-black text-slate-950">Q {Number(pago.amount).toFixed(2)}</p>
                  <span className={`rounded-md px-2 py-1 text-[10px] font-black uppercase tracking-tighter ${
                    pago.status === 'SUCCESS' ? 'bg-green-600 text-white shadow-sm' : 'bg-slate-600 text-white'
                  }`}>
                    {pago.status}
                  </span>
                </div>
                <div className="space-y-1.5 border-t border-slate-50 pt-3">
                   <div className="flex justify-between text-[11px]">
                     <span className="text-slate-400 font-bold uppercase">Referencia</span>
                     <span className="font-mono font-bold text-slate-800">{String(pago.id).substring(0, 12)}...</span>
                   </div>
                   <div className="flex justify-between text-[11px]">
                     <span className="text-slate-400 font-bold uppercase">Cita ID</span>
                     <span className="font-mono font-bold text-slate-800">{String(pago.appointmentId).substring(0, 8)}...</span>
                   </div>
                </div>
              </div>
            </div>
          ))}

          {pagosHistory.length === 0 && (
            <div className="col-span-full rounded-xl border-2 border-dashed border-slate-200 bg-slate-50/50 py-20 text-center">
              <Search size={48} className="mx-auto mb-4 text-slate-200" />
              <p className="font-bold text-slate-400 uppercase tracking-widest">El historial esta vacio</p>
              <p className="text-slate-400 text-sm mt-1">Realice una busqueda para ver detalles de pagos.</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
