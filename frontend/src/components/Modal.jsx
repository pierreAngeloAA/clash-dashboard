import { useEffect } from 'react';

export default function Modal({ title, onClose, children, maxWidth = 'max-w-3xl' }) {
  useEffect(() => {
    const onKey = (e) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-sm p-0 sm:p-4 animate-fadeIn"
      onClick={onClose}
    >
      <div
        className={`bg-white w-full ${maxWidth} sm:rounded-2xl shadow-card border border-slate-100 max-h-[90vh] flex flex-col`}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-5 py-4 border-b border-slate-100">
          <h2 className="font-semibold text-slate-900 truncate">{title}</h2>
          <button
            onClick={onClose}
            className="rounded-full h-9 w-9 grid place-items-center text-slate-500 hover:bg-slate-100"
            aria-label="Cerrar"
          >
            ✕
          </button>
        </div>
        <div className="flex-1 overflow-y-auto p-5">{children}</div>
      </div>
    </div>
  );
}
