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
import { createAccount } from '../services/accountsService';

export default function Dashboard() {
  // La lista ya trae el progreso de cada cuenta. Antes habia que pedir el
  // REPORT de cada pestaña del Sheet por separado, una peticion por tarjeta.
  const { accounts, loading, error, refetch } = useAccountList();
  const { autenticado } = useAuth();
  const [creando, setCreando] = useState(false);

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
          <button
            type="button"
            onClick={() => setCreando(true)}
            className="rounded-lg bg-brand-600 hover:bg-brand-700 text-white px-4 py-2 text-sm font-semibold whitespace-nowrap transition"
          >
            Nueva cuenta
          </button>
        )}
      </section>

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
