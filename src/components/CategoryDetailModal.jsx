import { useEffect } from 'react';

export default function CategoryDetailModal({
  category,
  items,
  summary,
  onClose,
}) {
  useEffect(() => {
    const onKey = (e) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-sm p-0 sm:p-4 animate-fadeIn"
      onClick={onClose}
    >
      <div
        className="bg-white w-full sm:max-w-2xl sm:rounded-2xl shadow-card border border-slate-100 max-h-[90vh] flex flex-col"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-5 py-4 border-b border-slate-100">
          <h2 className="font-semibold text-slate-900">{category}</h2>
          <button
            onClick={onClose}
            className="rounded-full h-9 w-9 grid place-items-center text-slate-500 hover:bg-slate-100"
            aria-label="Cerrar"
          >
            ✕
          </button>
        </div>

        <div className="flex-1 overflow-y-auto">
          {!items || items.length === 0 ? (
            <div className="px-5 py-10 text-center text-slate-500 space-y-3">
              {summary ? (
                <>
                  <p className="text-sm">
                    El Sheet no tiene un desglose ítem-por-ítem para esta
                    categoría. El REPORT agrega:
                  </p>
                  <div className="inline-flex flex-col items-center bg-slate-50 rounded-xl px-6 py-4">
                    <p className="text-3xl font-bold text-slate-900 tabular-nums">
                      {summary.total - summary.faltante}/{summary.total}
                    </p>
                    <p className="text-xs text-slate-500 mt-1">
                      faltan {summary.faltante} ·{' '}
                      {(summary.pctDone ?? 0).toFixed(1)}% hecho
                    </p>
                  </div>
                </>
              ) : (
                <p>Esta categoría no tiene desglose disponible todavía.</p>
              )}
            </div>
          ) : (
            <ul className="divide-y divide-slate-100">
              {items.map((item, i) => (
                <ItemRow key={`${item.name}-${item.idx || i}`} item={item} />
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>
  );
}

function ItemRow({ item }) {
  const pct = item.maxLevel > 0 ? (item.currentLevel / item.maxLevel) * 100 : 0;
  const isMaxed = item.currentLevel === item.maxLevel && item.maxLevel > 0;
  return (
    <li className="px-5 py-3.5">
      <div className="flex items-center justify-between gap-3">
        <div className="min-w-0 flex items-center gap-2">
          {item.idx && (
            <span className="text-xs text-slate-400 tabular-nums">#{item.idx}</span>
          )}
          <p className="font-medium text-slate-900 truncate">{item.name}</p>
        </div>
        <p
          className={`text-sm font-semibold tabular-nums whitespace-nowrap ${
            isMaxed ? 'text-emerald-600' : 'text-slate-700'
          }`}
        >
          {item.currentLevel}/{item.maxLevel}
        </p>
      </div>
      <div className="mt-2 h-1.5 rounded-full bg-slate-100 overflow-hidden">
        <div
          className={`h-full transition-all ${
            isMaxed ? 'bg-emerald-500' : 'bg-brand-500'
          }`}
          style={{ width: `${Math.max(0, Math.min(100, pct))}%` }}
        />
      </div>
    </li>
  );
}
