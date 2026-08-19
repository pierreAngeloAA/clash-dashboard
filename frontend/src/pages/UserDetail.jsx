import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import Loader from '../components/Loader';
import ErrorMessage from '../components/ErrorMessage';
import CategoryDetailModal from '../components/CategoryDetailModal';
import AccountFormModal from '../components/AccountFormModal';
import Modal from '../components/Modal';
import { useAccount } from '../hooks/useAccount';
import { useAuth } from '../context/AuthContext';
import {
  deleteAccount,
  syncAccount,
  updateAccount,
} from '../services/accountsService';

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
  const [sincronizando, setSincronizando] = useState(false);
  const [resultado, setResultado] = useState(null);

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

  const sincronizar = async () => {
    setSincronizando(true);
    setResultado(null);
    try {
      const { resumen } = await syncAccount(id);
      setResultado({ resumen });
      refetch({ silencioso: true });
    } catch (err) {
      setResultado({ error: err.message || 'No se pudo sincronizar.' });
    } finally {
      setSincronizando(false);
    }
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
            {/* Sin tag no hay contra que sincronizar, asi que el boton no
                aparece en vez de aparecer y fallar. */}
            {account.sincronizable && (
              <button
                type="button"
                onClick={sincronizar}
                disabled={sincronizando}
                title="Traer los niveles reales desde la API oficial"
                className="rounded-lg border border-brand-300 text-brand-700 hover:bg-brand-50 px-3 py-1.5 text-sm font-semibold disabled:opacity-60 transition"
              >
                {sincronizando ? 'Sincronizando…' : 'Sincronizar'}
              </button>
            )}
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

      {resultado && (
        <ResultadoSincronizacion
          {...resultado}
          onCerrar={() => setResultado(null)}
        />
      )}

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
 * Que dejo la sincronizacion.
 *
 * Se muestra el detalle y no un "listo" porque la sincronizacion casi nunca
 * alcanza a todo: la API no expone defensas ni trampas, el candado protege lo
 * corregido a mano, y lo que el catalogo no tiene mapeado al nombre en ingles
 * queda afuera. Un cartel de exito escondiendo que se actualizaron tres de
 * setenta elementos seria mentir.
 */
function ResultadoSincronizacion({ resumen, error, onCerrar }) {
  if (error) {
    return (
      <section
        role="alert"
        className="mt-6 rounded-2xl border border-red-100 bg-red-50 p-4 text-sm text-red-800 flex justify-between gap-4"
      >
        <span>{error}</span>
        <button onClick={onCerrar} aria-label="Cerrar" className="shrink-0">
          ✕
        </button>
      </section>
    );
  }

  const subioDeTh = resumen.ayuntamiento != null;

  const filas = [
    ['Actualizados', resumen.actualizados],
    ['Ya estaban al día', resumen.sinCambios],
    ['Protegidos con candado', resumen.protegidos],
    ['Fuera del alcance de la API', resumen.sinMapear],
    ['La API no los devolvió', resumen.noEncontrados],
    ['Rechazados', resumen.rechazados],
  ].filter(([, valor]) => valor > 0);

  return (
    <section className="mt-6 rounded-2xl border border-slate-100 bg-white shadow-card p-5">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h2 className="font-semibold text-slate-900">
            Sincronizado con la API
          </h2>
          <p className="mt-1 text-sm text-slate-500">
            {resumen.actualizados === 0
              ? 'No hubo nada que actualizar.'
              : `Se actualizaron ${resumen.actualizados} elementos.`}
          </p>
        </div>
        <button
          onClick={onCerrar}
          aria-label="Cerrar"
          className="rounded-full h-8 w-8 grid place-items-center text-slate-500 hover:bg-slate-100 shrink-0"
        >
          ✕
        </button>
      </div>

      {subioDeTh && (
        <p className="mt-3 rounded-lg bg-amber-50 border border-amber-100 px-3 py-2 text-sm text-amber-800">
          El ayuntamiento pasó de {resumen.ayuntamiento.antes} a{' '}
          {resumen.ayuntamiento.ahora}, así que se agregaron{' '}
          {resumen.elementosNuevos} elementos al inventario. El porcentaje baja
          porque ahora se mide contra todo lo que la cuenta puede tener: no se
          perdió progreso.
        </p>
      )}

      <dl className="mt-4 grid grid-cols-2 sm:grid-cols-3 gap-3">
        {filas.map(([etiqueta, valor]) => (
          <div key={etiqueta} className="rounded-xl bg-slate-50 px-3 py-2">
            <dt className="text-xs text-slate-500">{etiqueta}</dt>
            <dd className="text-lg font-bold text-slate-900 tabular-nums">
              {valor}
            </dd>
          </div>
        ))}
      </dl>

      {resumen.sinMapear > 0 && (
        <p className="mt-3 text-xs text-slate-400">
          Las defensas y las trampas no las expone la API oficial: siguen siendo
          carga manual.
        </p>
      )}
    </section>
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
  const completo = category.faltante === 0;

  return (
    <li>
      <button
        type="button"
        onClick={onClick}
        className="group w-full text-left px-5 py-3 hover:bg-slate-50 transition focus:outline-none focus-visible:bg-slate-50"
      >
        <div className="flex items-center gap-4">
          <div className="min-w-0 flex-1">
            <div className="flex items-baseline gap-2">
              <p className="font-medium text-slate-900 truncate">{category.label}</p>
              <span className="text-xs text-slate-400 tabular-nums whitespace-nowrap">
                {done}/{category.total}
              </span>
            </div>
            {/* La barra va debajo del nombre y ocupa solo su columna: antes
                cruzaba la fila entera y cada categoria gastaba el doble de alto. */}
            <div className="mt-1.5 h-1 rounded-full bg-slate-100 overflow-hidden">
              <div
                className={`h-full rounded-full transition-all duration-500 ${
                  completo ? 'bg-emerald-500' : 'bg-brand-500'
                }`}
                style={{ width: `${Math.max(0, Math.min(100, pct))}%` }}
              />
            </div>
          </div>

          <div className="flex items-center gap-1 shrink-0">
            <span
              className={`text-sm font-semibold tabular-nums ${
                completo ? 'text-emerald-600' : 'text-slate-700'
              }`}
            >
              {pct.toFixed(1)}%
            </span>
            <span className="text-slate-300 group-hover:text-slate-400 transition">
              ›
            </span>
          </div>
        </div>
      </button>
    </li>
  );
}
