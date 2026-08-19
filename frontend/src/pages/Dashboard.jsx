import { useState } from 'react';
import { Link } from 'react-router-dom';
import Loader from '../components/Loader';
import ErrorMessage from '../components/ErrorMessage';
import ClanSearchPanel from '../components/ClanSearchPanel';
import PlayerSearchPanel from '../components/PlayerSearchPanel';
import Modal from '../components/Modal';
import AccountFormModal from '../components/AccountFormModal';
import { useAccountList } from '../hooks/useAccountList';
import { useAuth } from '../context/AuthContext';
import { createAccount, syncAllAccounts } from '../services/accountsService';

export default function Dashboard() {
  // La lista ya trae el progreso de cada cuenta. Antes habia que pedir el
  // REPORT de cada pestaña del Sheet por separado, una peticion por tarjeta.
  const { accounts, loading, error, refetch } = useAccountList();
  const { autenticado } = useAuth();
  const [creando, setCreando] = useState(false);
  const [sincronizando, setSincronizando] = useState(false);
  const [resultado, setResultado] = useState(null);

  // Las cuentas sin tag ni se intentan: el backend las deja afuera, y decirlo
  // antes evita que parezca que se saltearon por un error.
  const conTag = accounts.filter((a) => a.sincronizable).length;

  const sincronizarTodas = async () => {
    setSincronizando(true);
    setResultado(null);
    try {
      setResultado(await syncAllAccounts());
      refetch();
    } catch (err) {
      setResultado({ error: err.message || 'No se pudo sincronizar.' });
    } finally {
      setSincronizando(false);
    }
  };

  const crear = async (datos) => {
    await createAccount(datos);
    // La cuenta nueva arranca con el inventario que le genera el backend, asi
    // que la lista se vuelve a pedir en vez de agregarla a mano.
    refetch();
  };

  const [clanInput, setClanInput] = useState('');
  const [clanTag, setClanTag] = useState('');
  const [playerInput, setPlayerInput] = useState('');
  const [playerTag, setPlayerTag] = useState('');

  const submitClan = (e) => {
    e.preventDefault();
    setClanTag(clanInput.trim());
  };
  const submitPlayer = (e) => {
    e.preventDefault();
    setPlayerTag(playerInput.trim());
  };
  const selectMember = (memberTag) => {
    setClanTag('');
    setClanInput('');
    setPlayerInput(memberTag);
    setPlayerTag(memberTag);
  };

  if (loading && accounts.length === 0) return <Loader />;
  if (error) return <ErrorMessage message={error} onRetry={refetch} />;

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-8">
        <SearchBox
          label="Buscar clan"
          placeholder="Tag del clan (ej. #2PP)"
          value={clanInput}
          onChange={setClanInput}
          onSubmit={submitClan}
        />
        <SearchBox
          label="Buscar jugador"
          placeholder="Tag del jugador (ej. #ABC123)"
          value={playerInput}
          onChange={setPlayerInput}
          onSubmit={submitPlayer}
        />
      </div>

      <section className="mb-4 flex items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-bold text-slate-900">Cuentas</h1>
          <p className="mt-1 text-sm text-slate-500">
            {accounts.length} cuentas.
          </p>
        </div>
        {autenticado && (
          <div className="flex gap-2">
            {conTag > 0 && (
              <button
                type="button"
                onClick={sincronizarTodas}
                disabled={sincronizando}
                title={`Traer los niveles reales de las ${conTag} cuentas con tag`}
                className="rounded-lg border border-brand-300 text-brand-700 hover:bg-brand-50 px-4 py-2 text-sm font-semibold whitespace-nowrap disabled:opacity-60 transition"
              >
                {sincronizando
                  ? 'Sincronizando…'
                  : `Sincronizar ${conTag}`}
              </button>
            )}
            <button
              type="button"
              onClick={() => setCreando(true)}
              className="rounded-lg bg-brand-600 hover:bg-brand-700 text-white px-4 py-2 text-sm font-semibold whitespace-nowrap transition"
            >
              Nueva cuenta
            </button>
          </div>
        )}
      </section>

      {resultado && (
        <ResultadoSincronizacion
          {...resultado}
          onCerrar={() => setResultado(null)}
        />
      )}

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        {accounts.map((a) => (
          <AccountCard key={a.id} account={a} />
        ))}
      </div>

      {creando && (
        <AccountFormModal onGuardar={crear} onClose={() => setCreando(false)} />
      )}

      {clanTag && (
        <Modal
          title={`Clan ${clanTag}`}
          maxWidth="max-w-5xl"
          onClose={() => setClanTag('')}
        >
          <ClanSearchPanel tag={clanTag} onSelectPlayer={selectMember} />
        </Modal>
      )}

      {playerTag && (
        <Modal
          title={`Jugador ${playerTag}`}
          maxWidth="max-w-4xl"
          onClose={() => setPlayerTag('')}
        >
          <PlayerSearchPanel tag={playerTag} />
        </Modal>
      )}
    </div>
  );
}

/**
 * Que dejo la sincronizacion, cuenta por cuenta.
 *
 * No se muestra un total global a proposito: si una cuenta fallo porque la API
 * rechazo el token, un "12 actualizados" taparia justamente eso. Las que se
 * actualizaron se resumen en una linea; las que fallaron se listan con su
 * motivo.
 */
function ResultadoSincronizacion({ total, cuentas, error, onCerrar }) {
  if (error) {
    return (
      <section
        role="alert"
        className="mb-6 rounded-2xl border border-red-100 bg-red-50 p-4 text-sm text-red-800 flex justify-between gap-4"
      >
        <span>{error}</span>
        <button onClick={onCerrar} aria-label="Cerrar" className="shrink-0">
          ✕
        </button>
      </section>
    );
  }

  const fallaron = cuentas.filter((c) => !c.ok);
  const cambiadas = cuentas.filter((c) => c.ok && c.resumen.actualizados > 0);
  // Subir de ayuntamiento agrega elementos y hace bajar el porcentaje. Sin
  // decirlo, parece que la cuenta retrocedio.
  const subieron = cuentas.filter((c) => c.ok && c.resumen.ayuntamiento);
  const actualizados = cambiadas.reduce((n, c) => n + c.resumen.actualizados, 0);
  const ok = total - fallaron.length;

  // El titulo cuenta las que se sincronizaron de verdad, no las que se
  // intentaron: decir "sincronizadas 2" cuando las dos fallaron es mentir.
  const titulo =
    ok === 0
      ? `No se pudo sincronizar ninguna de las ${total} cuentas`
      : `Sincronizadas ${ok} de ${total} cuentas`;

  const detalle =
    ok === 0
      ? 'Ninguna llegó a actualizarse.'
      : actualizados === 0
        ? 'Ya estaban al día.'
        : `Se actualizaron ${actualizados} elementos en ${cambiadas.length} cuentas.`;

  return (
    <section className="mb-6 rounded-2xl border border-slate-100 bg-white shadow-card p-5">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h2 className="font-semibold text-slate-900">{titulo}</h2>
          <p className="mt-1 text-sm text-slate-500">{detalle}</p>
        </div>
        <button
          onClick={onCerrar}
          aria-label="Cerrar"
          className="rounded-full h-8 w-8 grid place-items-center text-slate-500 hover:bg-slate-100 shrink-0"
        >
          ✕
        </button>
      </div>

      {cambiadas.length > 0 && (
        <ul className="mt-4 flex flex-wrap gap-2">
          {cambiadas.map((c) => (
            <li
              key={c.id}
              className="rounded-lg bg-slate-50 px-3 py-1.5 text-sm text-slate-700"
            >
              {c.nombre}{' '}
              <span className="font-semibold tabular-nums">
                +{c.resumen.actualizados}
              </span>
            </li>
          ))}
        </ul>
      )}

      {subieron.length > 0 && (
        <div className="mt-4 rounded-xl bg-amber-50 border border-amber-100 p-3">
          <p className="text-sm font-semibold text-amber-900">
            {subieron.length === 1
              ? 'Una cuenta subió de ayuntamiento'
              : `${subieron.length} cuentas subieron de ayuntamiento`}
          </p>
          <ul className="mt-1 space-y-0.5 text-sm text-amber-800">
            {subieron.map((c) => (
              <li key={c.id}>
                <span className="font-medium">{c.nombre}</span>: TH
                {c.resumen.ayuntamiento.antes} → TH{c.resumen.ayuntamiento.ahora}
                , +{c.resumen.elementosNuevos} elementos
              </li>
            ))}
          </ul>
          <p className="mt-2 text-xs text-amber-700">
            Su porcentaje baja porque ahora se mide contra todo lo que pueden
            tener. No se perdió progreso.
          </p>
        </div>
      )}

      {fallaron.length > 0 && (
        <div className="mt-4 rounded-xl bg-red-50 border border-red-100 p-3">
          <p className="text-sm font-semibold text-red-800">
            {fallaron.length} no se pudieron sincronizar
          </p>
          <ul className="mt-1 space-y-0.5 text-sm text-red-700">
            {fallaron.map((c) => (
              <li key={c.id}>
                <span className="font-medium">{c.nombre}</span>: {c.error}
              </li>
            ))}
          </ul>
        </div>
      )}
    </section>
  );
}

function SearchBox({ label, placeholder, value, onChange, onSubmit }) {
  return (
    <form
      onSubmit={onSubmit}
      className="bg-white rounded-2xl shadow-card border border-slate-100 p-4 flex flex-col gap-2"
    >
      <label className="text-xs font-semibold uppercase tracking-wider text-slate-500">
        {label}
      </label>
      <div className="flex gap-2">
        <input
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          className="flex-1 rounded-lg border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
        />
        <button
          type="submit"
          className="rounded-lg bg-brand-600 hover:bg-brand-700 text-white px-4 py-2 text-sm font-semibold"
        >
          Buscar
        </button>
      </div>
    </form>
  );
}

function AccountCard({ account }) {
  const pct = account.progresoPct;

  return (
    <Link
      to={`/user/${account.id}`}
      className="bg-white rounded-2xl shadow-card border border-slate-100 p-4 hover:border-brand-300 hover:shadow-md transition"
    >
      <div className="flex items-center justify-between">
        <div className="min-w-0">
          <p className="font-semibold text-slate-900 truncate">
            {account.nombre}
          </p>
          {/* Sin tag la cuenta no se puede sincronizar con la API oficial. */}
          <p className="text-xs text-slate-500 truncate">
            {account.tagCoc || 'sin tag'}
          </p>
        </div>
        {account.townHall != null && (
          <div className="text-right">
            <p className="text-xs text-slate-500">TH</p>
            <p className="font-bold text-brand-700">{account.townHall}</p>
          </div>
        )}
      </div>

      <div className="mt-3">
        <div className="flex justify-between text-xs text-slate-500 mb-1">
          <span>Progreso</span>
          <span className="font-medium text-slate-700">
            {pct == null ? 's/d' : `${pct.toFixed(1)}%`}
          </span>
        </div>
        <div className="h-2 rounded-full bg-slate-100 overflow-hidden">
          {pct != null && (
            <div
              className="h-full bg-brand-500 transition-all"
              style={{ width: `${Math.max(0, Math.min(100, pct))}%` }}
            />
          )}
        </div>
      </div>
    </Link>
  );
}
