import { useEffect } from 'react';

/**
 * Ventana modal.
 *
 * `maxWidth` es el ancho maximo; el alto lo pone el contenido y solo se corta al
 * llegar al tope. Antes era `max-h-[90vh]` fijo, que en pantallas grandes hacia
 * que un modal de tres campos ocupara casi toda la altura.
 */
export default function Modal({ title, onClose, children, maxWidth = 'max-w-xl' }) {
  useEffect(() => {
    const onKey = (e) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-slate-900/40 backdrop-blur-[2px] p-0 sm:p-6 animate-fadeIn"
      onClick={onClose}
    >
      <div
        className={`bg-white w-full ${maxWidth} rounded-t-2xl sm:rounded-2xl shadow-cardHover border border-slate-200/80 max-h-[85vh] sm:max-h-[75vh] flex flex-col`}
        onClick={(e) => e.stopPropagation()}
      >
        <header className="flex items-center justify-between gap-3 px-5 py-3.5 border-b border-slate-100">
          <h2 className="font-semibold text-slate-900 truncate">{title}</h2>
          <button
            onClick={onClose}
            className="rounded-lg h-8 w-8 grid place-items-center text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition shrink-0"
            aria-label="Cerrar"
          >
            ✕
          </button>
        </header>
        <div className="flex-1 overflow-y-auto p-5">{children}</div>
      </div>
    </div>
  );
}
