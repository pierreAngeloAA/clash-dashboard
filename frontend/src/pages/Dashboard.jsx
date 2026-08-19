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
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 mb-5">
        <SearchBox
          placeholder="Buscar clan · #2PP"
          value={clanInput}
          onChange={setClanInput}
          onSubmit={submitClan}
        />
        <SearchBox
          placeholder="Buscar jugador · #ABC123"
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

      <div className="grid grid-cols-2 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6 gap-3">
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

function SearchBox({ placeholder, value, onChange, onSubmit }) {
  return (
    <form
      onSubmit={onSubmit}
      className="flex gap-1.5 bg-white/90 backdrop-blur rounded-lg border border-slate-200 shadow-card p-1.5"
    >
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        aria-label={placeholder}
        className="flex-1 min-w-0 rounded-md px-2.5 py-1.5 text-sm bg-transparent placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-brand-500/40"
      />
      <button
        type="submit"
        className="rounded-md bg-brand-600 hover:bg-brand-700 text-white px-3 py-1.5 text-sm font-semibold shrink-0 transition"
      >
        Buscar
      </button>
    </form>
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

function AccountCard({ account }) {
  const pct = account.progresoPct ?? 0;
  const completo = pct >= 100;

  return (
    <Link
      to={`/user/${account.id}`}
      className="group relative overflow-hidden bg-white rounded-xl border border-slate-200/70 shadow-tarjeta hover:shadow-tarjetaHover hover:border-brand-300 hover:-translate-y-1 transition-all duration-200 p-3"
    >
      <div className="flex items-center gap-2">
        {account.townHall != null && (
          <span className="shrink-0 grid place-items-center h-8 w-8 rounded-lg bg-brand-600 text-white text-xs font-bold tabular-nums">
            {account.townHall}
          </span>
        )}
        <div className="min-w-0 flex-1">
          <p className="font-semibold text-sm text-slate-900 truncate leading-tight">
            {account.nombre}
          </p>
          {/* Sin tag la cuenta no se puede sincronizar con la API oficial. */}
          <p className="text-[11px] text-slate-400 truncate leading-tight">
            {account.tagCoc || 'sin tag'}
          </p>
        </div>
      </div>

      <div className="mt-2.5 flex items-center gap-2">
        {/* Marca fina, anclada a la izquierda, con la punta redondeada. */}
        <div className="flex-1 h-1.5 rounded-full bg-slate-100 overflow-hidden">
          <div
            className={`h-full rounded-full transition-all duration-500 ${
              completo ? 'bg-emerald-500' : 'bg-brand-500'
            }`}
            style={{ width: `${Math.max(0, Math.min(100, pct))}%` }}
          />
        </div>
        <span
          className={`text-xs font-bold tabular-nums shrink-0 ${
            completo ? 'text-emerald-600' : 'text-slate-700'
          }`}
        >
          {pct.toFixed(0)}%
        </span>
      </div>
    </Link>
  );
}
