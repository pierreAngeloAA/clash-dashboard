import { useEffect, useState } from 'react';
import Modal from './Modal';
import { useAuth } from '../context/AuthContext';

export default function CategoryDetailModal({
  category,
  items,
  summary,
  onEditar,
  onClose,
}) {
  const hechos = items?.filter((i) => i.currentLevel === i.maxLevel).length ?? 0;

  return (
    <Modal title={category} maxWidth="max-w-3xl" onClose={onClose}>
      {!items || items.length === 0 ? (
        <SinDesglose summary={summary} />
      ) : (
        <>
          <p className="mb-3 text-sm text-slate-500">
            {hechos} de {items.length} al máximo
            {summary && ` · ${(summary.pctDone ?? 0).toFixed(1)}% de la categoría`}
          </p>
          {/* Dos columnas desde sm: una categoria puede tener setenta elementos,
              y en una sola columna hay que recorrer toda la lista para ver algo. */}
          <ul className="grid sm:grid-cols-2 gap-1.5">
            {items.map((item) => (
              <ItemRow key={item.id} item={item} onEditar={onEditar} />
            ))}
          </ul>
        </>
      )}
    </Modal>
  );
}

function SinDesglose({ summary }) {
  if (!summary) {
    return (
      <p className="py-8 text-center text-slate-500">
        Esta categoría no tiene desglose disponible todavía.
      </p>
    );
  }

  return (
    <div className="py-6 text-center space-y-3">
      <p className="text-sm text-slate-500">
        No hay desglose ítem-por-ítem para esta categoría. El total agregado es:
      </p>
      <div className="inline-flex flex-col items-center bg-slate-50 rounded-xl px-6 py-4">
        <p className="text-3xl font-bold text-slate-900 tabular-nums">
          {summary.total - summary.faltante}/{summary.total}
        </p>
        <p className="text-xs text-slate-500 mt-1">
          faltan {summary.faltante} · {(summary.pctDone ?? 0).toFixed(1)}% hecho
        </p>
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
  const completo = item.currentLevel === item.maxLevel && item.maxLevel > 0;

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
    <li className="relative overflow-hidden rounded-lg border border-slate-100 bg-white">
      {/* El progreso es el fondo de la fila y no una barra aparte: asi cada
          elemento ocupa la mitad de alto y la lista entra sin tanto scroll. */}
      <div
        aria-hidden
        className={`absolute inset-y-0 left-0 ${completo ? 'bg-emerald-50' : 'bg-brand-50'}`}
        style={{ width: `${Math.max(0, Math.min(100, pct))}%` }}
      />

      <div className="relative flex items-center gap-2 px-3 py-2">
        {item.indice != null && (
          <span className="text-[11px] text-slate-400 tabular-nums w-5 shrink-0">
            {item.indice}
          </span>
        )}
        <p className="flex-1 min-w-0 truncate text-sm font-medium text-slate-800">
          {item.nombre}
        </p>

        {autenticado ? (
          <div className="flex items-center gap-1 shrink-0">
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
              className="w-12 rounded-md border border-slate-200 bg-white/80 px-1.5 py-0.5 text-sm text-right tabular-nums focus:outline-none focus:ring-2 focus:ring-brand-500/40 focus:border-brand-400 disabled:opacity-50"
            />
            <span className="text-xs text-slate-400 tabular-nums w-6">
              /{item.maxLevel}
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
              className="rounded px-1 text-xs opacity-60 hover:opacity-100 disabled:opacity-30 transition"
            >
              {item.bloqueado ? '🔒' : '🔓'}
            </button>
          </div>
        ) : (
          <span
            className={`text-sm font-semibold tabular-nums shrink-0 ${
              completo ? 'text-emerald-700' : 'text-slate-700'
            }`}
          >
            {item.currentLevel}
            <span className="text-slate-400 font-normal">/{item.maxLevel}</span>
            {item.bloqueado && <span className="ml-1 opacity-60">🔒</span>}
          </span>
        )}
      </div>

      {error && (
        <p role="alert" className="relative px-3 pb-1.5 text-xs text-red-700">
          {error}
        </p>
      )}
    </li>
  );
}
