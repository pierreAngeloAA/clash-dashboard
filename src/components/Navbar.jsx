import { Link } from 'react-router-dom';

export default function Navbar() {
  return (
    <header className="sticky top-0 z-20 bg-gradient-to-r from-brand-800 to-brand-600 shadow-card">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between gap-4">
        <Link to="/" className="flex items-center gap-2">
          <span className="h-9 w-9 rounded-lg bg-white/15 backdrop-blur grid place-items-center text-white font-bold">
            C
          </span>
          <p className="text-base font-bold text-white tracking-wide">Clash</p>
        </Link>

        <button
          type="button"
          disabled
          title="Disponible cuando integremos Rails"
          className="rounded-lg bg-white/15 hover:bg-white/25 backdrop-blur px-4 py-1.5 text-sm font-semibold text-white disabled:opacity-60 disabled:cursor-not-allowed transition"
        >
          Login
        </button>
      </div>
    </header>
  );
}
