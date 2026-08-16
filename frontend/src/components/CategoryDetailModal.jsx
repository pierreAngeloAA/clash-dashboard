import { useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';

export default function CategoryDetailModal({
  category,
  items,
  summary,
  onEditar,
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
                    No hay desglose ítem-por-ítem para esta categoría. El total
                    agregado es:
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
              {items.map((item) => (
                <ItemRow key={item.id} item={item} onEditar={onEditar} />
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>
  );
}

function ItemRow({ item, onEditar }) {
  const { autenticado } = useAuth();
  const [nivel, setNivel] = useState(String(item.currentLevel));
  const [error, setError] = useState(null);
  const [guardando, setGuardando] = useState(false);

  // El nivel puede cambiar desde afuera: el hook recarga la cuenta despues de
  // cada edicion, y el backend pudo haberlo ajustado.
  useEffect(() => {
    setNivel(String(item.currentLevel));
  }, [item.currentLevel]);

  const pct = item.maxLevel > 0 ? (item.currentLevel / item.maxLevel) * 100 : 0;
  const isMaxed = item.currentLevel === item.maxLevel && item.maxLevel > 0;

  const guardar = async (cambios) => {
    setError(null);
    setGuardando(true);
    try {
      await onEditar(item.id, cambios);
    } catch (err) {
      setError(err.message || 'No se pudo guardar.');
      // El backend rechazo el cambio, asi que lo que hay en pantalla no es lo
      // que hay en la base: se vuelve al valor real para no mentir.
      setNivel(String(item.currentLevel));
    } finally {
      setGuardando(false);
    }
  };

  // Guarda al salir del campo o con Enter, no en cada tecla: escribir "12"
  // pasa por "1", y guardar eso mandaria un nivel que el usuario nunca quiso.
  const alConfirmar = () => {
    const valor = Number(nivel);
    if (nivel === '' || !Number.isFinite(valor) || valor === item.currentLevel) {
      setNivel(String(item.currentLevel));
      return;
    }

    guardar({ current_level: valor });
  };

  return (
    <li className="px-5 py-3.5">
      <div className="flex items-center justify-between gap-3">
        <div className="min-w-0 flex items-center gap-2">
          {item.indice != null && (
            <span className="text-xs text-slate-400 tabular-nums">
              #{item.indice}
            </span>
          )}
          <p className="font-medium text-slate-900 truncate">{item.nombre}</p>
          {item.bloqueado && (
            <span title="Protegido de la sincronizacion" aria-label="Bloqueado">
              🔒
            </span>
          )}
        </div>

        {autenticado ? (
          <div className="flex items-center gap-2 shrink-0">
            <input
              type="number"
              min="0"
              max={item.maxLevel}
              value={nivel}
              onChange={(e) => setNivel(e.target.value)}
              disabled={guardando}
              aria-label={`Nivel de ${item.nombre}`}
              onBlur={alConfirmar}
              onKeyDown={(e) => {
                if (e.key === 'Enter') e.target.blur();
              }}
              className="w-16 rounded-lg border border-slate-300 px-2 py-1 text-sm text-right tabular-nums focus:outline-none focus:ring-2 focus:ring-brand-500 disabled:opacity-50"
            />
            <span className="text-sm text-slate-500 tabular-nums">
              / {item.maxLevel}
            </span>
            <button
              type="button"
              disabled={guardando}
              onClick={() => guardar({ bloqueado: !item.bloqueado })}
              title={
                item.bloqueado
                  ? 'Desbloquear: la sincronizacion vuelve a poder pisarlo'
                  : 'Bloquear: la sincronizacion no lo va a pisar'
              }
              className="rounded-lg px-2 py-1 text-sm hover:bg-slate-100 disabled:opacity-50"
            >
              {item.bloqueado ? '🔒' : '🔓'}
            </button>
          </div>
        ) : (
          <p
            className={`text-sm font-semibold tabular-nums whitespace-nowrap ${
              isMaxed ? 'text-emerald-600' : 'text-slate-700'
            }`}
          >
            {item.currentLevel}/{item.maxLevel}
          </p>
        )}
      </div>

      <div className="mt-2 h-1.5 rounded-full bg-slate-100 overflow-hidden">
        <div
          className={`h-full transition-all ${
            isMaxed ? 'bg-emerald-500' : 'bg-brand-500'
          }`}
          style={{ width: `${Math.max(0, Math.min(100, pct))}%` }}
        />
      </div>

      {error && (
        <p role="alert" className="mt-2 text-xs text-red-700">
          {error}
        </p>
      )}
    </li>
  );
}
