import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import Loader from '../components/Loader';
import ErrorMessage from '../components/ErrorMessage';
import CategoryDetailModal from '../components/CategoryDetailModal';
import AccountFormModal from '../components/AccountFormModal';
import Modal from '../components/Modal';
import { useAccount } from '../hooks/useAccount';
import { useAuth } from '../context/AuthContext';
import { deleteAccount, updateAccount } from '../services/accountsService';

const initialsOf = (name) => {
  if (!name) return '?';
  const parts = String(name).trim().split(/\s+/);
  return (parts[0][0] + (parts[1]?.[0] || '')).toUpperCase();
};

const TOTALS_ORDER = [
  ['heroes', 'Héroes'],
  ['investigacion', 'Investigación'],
  ['defensas', 'Defensas'],
  ['total', 'Total'],
];

export default function UserDetail() {
  const { id } = useParams();
  const { account, secciones, report, loading, error, refetch, editarItem } =
    useAccount(id);
  const [openCategory, setOpenCategory] = useState(null);
  const { autenticado } = useAuth();
  const navigate = useNavigate();
  const [editando, setEditando] = useState(false);
  const [borrando, setBorrando] = useState(false);

  const guardar = async (datos) => {
    await updateAccount(id, datos);
    // Cambiar el ayuntamiento repuebla el inventario, asi que se vuelve a pedir
    // la cuenta entera en vez de parchear lo que ya estaba en pantalla.
    refetch();
  };

  const borrar = async () => {
    await deleteAccount(id);
    navigate('/');
  };

  if (loading && !account) return <Loader />;

  // El backend responde 404 con su propio mensaje cuando el id no existe, asi
  // que no hace falta distinguir "no encontrada" de cualquier otro fallo.
  if (error) return <ErrorMessage message={error} onRetry={refetch} />;
  if (!account) return null;

  const { nombre, townHall } = account;

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8 animate-fadeIn">
      <div className="mb-4 flex items-center justify-between gap-3">
        <Link to="/" className="btn-ghost">
          ← Volver
        </Link>
        {autenticado && (
          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => setEditando(true)}
              className="rounded-lg border border-slate-300 hover:bg-slate-50 px-3 py-1.5 text-sm font-semibold text-slate-700 transition"
            >
              Editar
            </button>
            <button
              type="button"
              onClick={() => setBorrando(true)}
              className="rounded-lg border border-red-200 text-red-700 hover:bg-red-50 px-3 py-1.5 text-sm font-semibold transition"
            >
              Borrar
            </button>
          </div>
        )}
      </div>

      <section className="bg-gradient-to-br from-brand-600 to-brand-800 text-white rounded-2xl p-6 sm:p-8 shadow-card">
        <div className="flex flex-col sm:flex-row items-start sm:items-center gap-5">
          <div className="h-20 w-20 rounded-2xl bg-white/15 backdrop-blur grid place-items-center text-3xl font-bold">
            {initialsOf(nombre)}
          </div>
          <div className="flex-1 min-w-0">
            <h1 className="text-2xl sm:text-3xl font-bold truncate">{nombre}</h1>
            {townHall != null && (
              <p className="mt-1 text-brand-100 text-sm">Town Hall {townHall}</p>
            )}
          </div>
          {report?.progresoPct != null && (
            <div className="text-right">
              <p className="text-xs uppercase tracking-wider text-brand-100">
                Progreso
              </p>
              <p className="text-3xl font-bold">
                {report.progresoPct.toFixed(1)}%
              </p>
            </div>
          )}
        </div>
      </section>

      {report && !report.hasReport && (
        <section className="mt-6 bg-white rounded-2xl shadow-card border border-slate-100 p-6 text-center text-slate-500">
          Esta cuenta todavía no tiene progreso cargado, así que no hay nada que
          agregar.
        </section>
      )}

      {editando && (
        <AccountFormModal
          account={account}
          onGuardar={guardar}
          onClose={() => setEditando(false)}
        />
      )}

      {borrando && (
        <ConfirmarBorrado
          account={account}
          onConfirmar={borrar}
          onClose={() => setBorrando(false)}
        />
      )}

      {openCategory && (
        <CategoryDetailModal
          category={openCategory.label}
          // Una fila puede agregar varias secciones: HEROES son seis.
          items={openCategory.secciones.flatMap((s) => secciones?.[s] ?? [])}
          summary={openCategory}
          onEditar={editarItem}
          onClose={() => setOpenCategory(null)}
        />
      )}

      {report?.hasReport && (
        <>
          {report.categories.length > 0 && (
            <section className="mt-6 bg-white rounded-2xl shadow-card border border-slate-100 overflow-hidden">
              <h2 className="px-5 py-4 border-b border-slate-100 font-semibold text-slate-900">
                Categorías
              </h2>
              <ul className="divide-y divide-slate-100">
                {report.categories.map((c) => (
                  <CategoryRow
                    key={c.label}
                    category={c}
                    onClick={() => setOpenCategory(c)}
                  />
                ))}
              </ul>
            </section>
          )}

          {Object.keys(report.totals).length > 0 && (
            <section className="mt-6 bg-white rounded-2xl shadow-card border border-slate-100 overflow-hidden">
              <h2 className="px-5 py-4 border-b border-slate-100 font-semibold text-slate-900">
                Totales
              </h2>
              <dl className="grid grid-cols-2 sm:grid-cols-4 divide-x divide-slate-100">
                {TOTALS_ORDER.map(([key, label]) => {
                  const t = report.totals[key];
                  if (!t) return null;
                  const done = t.total - t.faltante;
                  return (
                    <div key={key} className="px-5 py-4 text-center">
                      <dt className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                        {label}
                      </dt>
                      <dd className="mt-1 text-lg font-bold text-slate-900">
                        {done} / {t.total}
                      </dd>
                      <p className="text-xs text-slate-500">
                        faltan {t.faltante}
                      </p>
                    </div>
                  );
                })}
              </dl>
            </section>
          )}
        </>
      )}
    </div>
  );
}

/**
 * Borrar una cuenta se lleva puesto todo su progreso, no solo la fila. Es la
 * unica accion de la app que destruye datos que costaron cargar, asi que se
 * confirma y se dice exactamente que se pierde.
 */
function ConfirmarBorrado({ account, onConfirmar, onClose }) {
  const [error, setError] = useState(null);
  const [borrando, setBorrando] = useState(false);

  const confirmar = async () => {
    setError(null);
    setBorrando(true);
    try {
      await onConfirmar();
    } catch (err) {
      setError(err.message || 'No se pudo borrar la cuenta.');
      setBorrando(false);
    }
  };

  return (
    <Modal title={`Borrar ${account.nombre}`} maxWidth="max-w-md" onClose={onClose}>
      <p className="text-sm text-slate-700">
        Se borra la cuenta <strong>{account.nombre}</strong> y{' '}
        <strong>todo su progreso</strong>: los niveles de sus defensas, tropas,
        héroes y hechizos. No se puede deshacer.
      </p>

      {error && (
        <p
          role="alert"
          className="mt-4 rounded-lg bg-red-50 border border-red-100 px-3 py-2 text-sm text-red-700"
        >
          {error}
        </p>
      )}

      <div className="mt-6 flex justify-end gap-2">
        <button type="button" onClick={onClose} className="btn-ghost">
          Cancelar
        </button>
        <button
          type="button"
          onClick={confirmar}
          disabled={borrando}
          className="rounded-lg bg-red-600 hover:bg-red-700 text-white px-4 py-2 text-sm font-semibold disabled:opacity-60 disabled:cursor-not-allowed transition"
        >
          {borrando ? 'Borrando…' : 'Borrar la cuenta'}
        </button>
      </div>
    </Modal>
  );
}

function CategoryRow({ category, onClick }) {
  const pct = category.pctDone ?? 0;
  const done = category.total - category.faltante;
  return (
    <li>
      <button
        type="button"
        onClick={onClick}
        className="w-full text-left px-5 py-4 hover:bg-slate-50 transition focus:outline-none focus:bg-slate-50"
      >
        <div className="flex items-center justify-between gap-4">
          <p className="font-medium text-slate-900 truncate">{category.label}</p>
          <div className="flex items-center gap-2 whitespace-nowrap">
            <span className="text-sm font-semibold text-slate-700">
              {pct.toFixed(1)}%
            </span>
            <span className="text-slate-400">›</span>
          </div>
        </div>
        <div className="mt-2 h-2 rounded-full bg-slate-100 overflow-hidden">
          <div
            className="h-full bg-brand-500 transition-all"
            style={{ width: `${Math.max(0, Math.min(100, pct))}%` }}
          />
        </div>
        <p className="mt-1 text-xs text-slate-500">
          {done} / {category.total} listos · faltan {category.faltante}
        </p>
      </button>
    </li>
  );
}
