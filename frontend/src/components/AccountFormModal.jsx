import { useState } from 'react';
import Modal from './Modal';

/**
 * Alta y edicion de una cuenta, con el mismo formulario.
 *
 * Los campos son los que el backend acepta. `gid_origen` queda afuera a
 * proposito: lo escribe el importador del Sheet para saber de que pestaña vino
 * la cuenta, y no es un dato que se edite.
 */
export default function AccountFormModal({ account, onGuardar, onClose }) {
  const editando = Boolean(account);

  const [campos, setCampos] = useState({
    nombre: account?.nombre ?? '',
    town_hall: account?.townHall ?? '',
    builder_hall: account?.builderHall ?? '',
    tag_coc: account?.tagCoc ?? '',
    orden: account?.orden ?? 0,
  });
  const [error, setError] = useState(null);
  const [guardando, setGuardando] = useState(false);

  const cambiar = (campo) => (e) =>
    setCampos((previo) => ({ ...previo, [campo]: e.target.value }));

  // Subir de ayuntamiento habilita elementos nuevos y sube el tope de los que ya
  // estaban, asi que el inventario se repuebla. Conviene decirlo antes y no que
  // aparezcan filas de la nada.
  const cambiaElAyuntamiento =
    editando && String(campos.town_hall) !== String(account.townHall ?? '');

  const enviar = async (e) => {
    e.preventDefault();
    setError(null);
    setGuardando(true);
    try {
      // Los numericos van como numero o como null: el string vacio no es "sin
      // ayuntamiento" para el backend, es un valor que no valida.
      await onGuardar({
        nombre: campos.nombre.trim(),
        town_hall: numeroONulo(campos.town_hall),
        builder_hall: numeroONulo(campos.builder_hall),
        tag_coc: campos.tag_coc.trim() || null,
        orden: numeroONulo(campos.orden) ?? 0,
      });
      onClose();
    } catch (err) {
      setError(err.message || 'No se pudo guardar la cuenta.');
    } finally {
      setGuardando(false);
    }
  };

  return (
    <Modal
      title={editando ? `Editar ${account.nombre}` : 'Nueva cuenta'}
      maxWidth="max-w-lg"
      onClose={onClose}
    >
      <form onSubmit={enviar} className="space-y-4">
        <Campo
          id="nombre"
          etiqueta="Nombre"
          value={campos.nombre}
          onChange={cambiar('nombre')}
          required
          autoFocus
        />

        <div className="grid grid-cols-2 gap-4">
          <Campo
            id="town_hall"
            etiqueta="Ayuntamiento"
            type="number"
            min="1"
            value={campos.town_hall}
            onChange={cambiar('town_hall')}
          />
          <Campo
            id="builder_hall"
            etiqueta="Taller del constructor"
            type="number"
            min="1"
            value={campos.builder_hall}
            onChange={cambiar('builder_hall')}
          />
        </div>

        {cambiaElAyuntamiento && (
          <p className="rounded-lg bg-amber-50 border border-amber-100 px-3 py-2 text-sm text-amber-800">
            Cambiar el ayuntamiento vuelve a poblar el inventario: se agregan los
            elementos que el nivel nuevo habilita y sube el tope de los que ya
            estaban. El progreso cargado no se pierde.
          </p>
        )}

        <Campo
          id="tag_coc"
          etiqueta="Tag de Clash"
          value={campos.tag_coc}
          onChange={cambiar('tag_coc')}
          placeholder="#LJ8V90G0"
          ayuda="Sin tag, la cuenta no se puede sincronizar con la API oficial. Se normaliza solo."
        />

        <Campo
          id="orden"
          etiqueta="Orden en la lista"
          type="number"
          value={campos.orden}
          onChange={cambiar('orden')}
          ayuda="Menor primero. A igual orden se desempata por nombre."
        />

        {error && (
          <p
            role="alert"
            className="rounded-lg bg-red-50 border border-red-100 px-3 py-2 text-sm text-red-700"
          >
            {error}
          </p>
        )}

        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={onClose} className="btn-ghost">
            Cancelar
          </button>
          <button
            type="submit"
            disabled={guardando}
            className="rounded-lg bg-brand-600 hover:bg-brand-700 text-white px-4 py-2 text-sm font-semibold disabled:opacity-60 disabled:cursor-not-allowed transition"
          >
            {guardando ? 'Guardando…' : editando ? 'Guardar' : 'Crear'}
          </button>
        </div>
      </form>
    </Modal>
  );
}

function numeroONulo(valor) {
  if (valor === '' || valor === null || valor === undefined) return null;
  const numero = Number(valor);

  return Number.isFinite(numero) ? numero : null;
}

function Campo({ id, etiqueta, ayuda, ...props }) {
  return (
    <div>
      <label
        htmlFor={id}
        className="block text-xs font-semibold uppercase tracking-wider text-slate-500"
      >
        {etiqueta}
      </label>
      <input
        id={id}
        {...props}
        className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
      />
      {ayuda && <p className="mt-1 text-xs text-slate-400">{ayuda}</p>}
    </div>
  );
}
