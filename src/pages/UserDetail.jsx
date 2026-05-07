import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import Loader from '../components/Loader';
import ErrorMessage from '../components/ErrorMessage';
import CategoryDetailModal from '../components/CategoryDetailModal';
import { useAccountList } from '../hooks/useAccountList';
import { useAccountReport } from '../hooks/useAccountReport';
import { useAccountDetails } from '../hooks/useAccountDetails';

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
  const { accounts } = useAccountList();
  const { report, loading, error, refetch } = useAccountReport(id);
  const { details } = useAccountDetails(id);
  const [openCategory, setOpenCategory] = useState(null);

  const account = accounts.find((a) => a.gid === id);

  if (loading && !report) return <Loader />;
  if (error) return <ErrorMessage message={error} onRetry={refetch} />;

  if (!account && !report) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-16 text-center">
        <h2 className="text-xl font-bold text-slate-900">Cuenta no encontrada</h2>
        <p className="text-slate-500 mt-2">
          No existe una pestaña con id <code>{id}</code>.
        </p>
        <Link to="/" className="btn-ghost mt-6 inline-flex">
          ← Volver al dashboard
        </Link>
      </div>
    );
  }

  const playerName = account?.playerName || `Cuenta ${id}`;
  const townHall = account?.townHall;

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8 animate-fadeIn">
      <Link to="/" className="btn-ghost mb-4">
        ← Volver
      </Link>

      <section className="bg-gradient-to-br from-brand-600 to-brand-800 text-white rounded-2xl p-6 sm:p-8 shadow-card">
        <div className="flex flex-col sm:flex-row items-start sm:items-center gap-5">
          <div className="h-20 w-20 rounded-2xl bg-white/15 backdrop-blur grid place-items-center text-3xl font-bold">
            {initialsOf(playerName)}
          </div>
          <div className="flex-1 min-w-0">
            <h1 className="text-2xl sm:text-3xl font-bold truncate">{playerName}</h1>
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
          Esta pestaña no tiene un bloque <code>REPORT</code> en el Sheet, así
          que no hay agregado para mostrar.
        </section>
      )}

      {openCategory && (
        <CategoryDetailModal
          category={openCategory}
          items={details?.sections?.[openCategory] ?? []}
          summary={report?.categories.find((c) => c.label === openCategory)}
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
                    onClick={() => setOpenCategory(c.label)}
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
