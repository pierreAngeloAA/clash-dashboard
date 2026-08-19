import { useEffect } from 'react';
import { createPortal } from 'react-dom';

/**
 * Ventana modal.
 *
 * Se monta con un portal directo en el `body`, y eso no es un detalle: un
 * ancestro con `transform` —cualquiera de los que usan `animate-fadeIn`— hace
 * que `position: fixed` se ancle a ese ancestro en vez de a la ventana. El
 * modal quedaba entonces posicionado contra la pagina y se salia de la
 * pantalla: en un portatil, un modal de 576px empezaba en 332 y terminaba en
 * 908, con la ventana midiendo 768. Habia que scrollear la pagina de atras para
 * ver el final del modal.
 *
 * El portal lo saca de esa cadena, asi que queda fijo a la ventana pase lo que
 * pase con los estilos de la pagina que lo abre.
 */
export default function Modal({ title, onClose, children, maxWidth = 'max-w-xl' }) {
  useEffect(() => {
    const onKey = (e) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);

    // Con el modal abierto, la rueda del mouse movia la pagina de atras.
    const overflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    return () => {
      window.removeEventListener('keydown', onKey);
      document.body.style.overflow = overflow;
    };
  }, [onClose]);

  return createPortal(
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-slate-900/40 backdrop-blur-[2px] p-0 sm:p-6"
      onClick={onClose}
    >
      <div
        className={`bg-white w-full ${maxWidth} rounded-t-2xl sm:rounded-2xl shadow-cardHover border border-slate-200/80 max-h-[88vh] flex flex-col animate-fadeIn`}
        onClick={(e) => e.stopPropagation()}
      >
        <header className="flex items-center justify-between gap-3 px-5 py-3 border-b border-slate-100 shrink-0">
          <h2 className="font-semibold text-slate-900 truncate">{title}</h2>
          <button
            onClick={onClose}
            className="rounded-lg h-8 w-8 grid place-items-center text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition shrink-0"
            aria-label="Cerrar"
          >
            ✕
          </button>
        </header>
        <div className="flex-1 overflow-y-auto p-4">{children}</div>
      </div>
    </div>,
    document.body
  );
}
