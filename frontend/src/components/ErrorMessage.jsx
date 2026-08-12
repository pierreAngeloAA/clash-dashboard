export default function ErrorMessage({ message, onRetry }) {
  return (
    <div className="max-w-xl mx-auto my-12 p-6 rounded-xl border border-rose-200 bg-rose-50 animate-fadeIn">
      <div className="flex items-start gap-3">
        <div className="shrink-0 mt-0.5 h-8 w-8 rounded-full bg-rose-100 text-rose-600 grid place-items-center">
          !
        </div>
        <div className="flex-1">
          <h3 className="font-semibold text-rose-800">No se pudieron cargar los datos</h3>
          <p className="mt-1 text-sm text-rose-700">{message}</p>
          {onRetry && (
            <button
              type="button"
              onClick={onRetry}
              className="mt-4 inline-flex items-center gap-2 px-3 py-2 rounded-lg
                         bg-rose-600 text-white text-sm font-medium hover:bg-rose-700
                         transition"
            >
              Reintentar
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
