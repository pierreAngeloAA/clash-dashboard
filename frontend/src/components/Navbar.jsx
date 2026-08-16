import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export default function Navbar() {
  const { user, autenticado, cargando, logout } = useAuth();
  const navigate = useNavigate();

  const salir = async () => {
    await logout();
    navigate('/');
  };

  return (
    <header className="sticky top-0 z-20 bg-gradient-to-r from-brand-800 to-brand-600 shadow-card">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between gap-4">
        <Link to="/" className="flex items-center gap-2">
          <span className="h-9 w-9 rounded-lg bg-white/15 backdrop-blur grid place-items-center text-white font-bold">
            C
          </span>
          <p className="text-base font-bold text-white tracking-wide">Clash</p>
        </Link>

        {/* Mientras se comprueba si el token sigue vivo no se muestra ni
            "Login" ni el usuario: cualquiera de los dos podria ser mentira por
            un instante. */}
        {cargando ? null : autenticado ? (
          <div className="flex items-center gap-3">
            <span className="hidden sm:block text-sm text-white/80 truncate max-w-[16rem]">
              {user.email}
            </span>
            <button
              type="button"
              onClick={salir}
              className="rounded-lg bg-white/15 hover:bg-white/25 backdrop-blur px-4 py-1.5 text-sm font-semibold text-white transition"
            >
              Salir
            </button>
          </div>
        ) : (
          <Link
            to="/login"
            className="rounded-lg bg-white/15 hover:bg-white/25 backdrop-blur px-4 py-1.5 text-sm font-semibold text-white transition"
          >
            Login
          </Link>
        )}
      </div>
    </header>
  );
}
