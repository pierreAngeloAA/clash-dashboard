import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react';
import {
  fetchCurrentUser,
  login as loginRequest,
  logout as logoutRequest,
} from '../services/authService';
import { cuandoSePierdaLaSesion, leerToken } from '../services/http';

const AuthContext = createContext(null);

/**
 * Quien esta logueado, disponible en toda la app.
 *
 * Al arrancar hay token pero no usuario: el token solo dice que hubo una sesion,
 * no si sigue viva. Por eso se le pregunta a `/me` antes de dar por buena la
 * sesion, y mientras tanto `cargando` es true. Sin ese estado intermedio la
 * interfaz parpadearia mostrando "deslogueado" en cada recarga.
 */
export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [cargando, setCargando] = useState(Boolean(leerToken()));

  useEffect(() => {
    if (!leerToken()) return;

    let cancelado = false;

    fetchCurrentUser()
      .then((usuario) => {
        if (!cancelado) setUser(usuario);
      })
      // El token estaba vencido o revocado. http.js ya lo borro; aca solo queda
      // seguir sin sesion, que es el estado normal de la app.
      .catch(() => {})
      .finally(() => {
        if (!cancelado) setCargando(false);
      });

    return () => {
      cancelado = true;
    };
  }, []);

  // Cualquier peticion que vuelva 401 cierra la sesion, aunque no haya sido el
  // usuario quien la cerro: el token dura 12 horas y puede vencer con la app
  // abierta.
  useEffect(() => {
    cuandoSePierdaLaSesion(() => setUser(null));

    return () => cuandoSePierdaLaSesion(null);
  }, []);

  const login = useCallback(async (email, password) => {
    const usuario = await loginRequest(email, password);
    setUser(usuario);

    return usuario;
  }, []);

  const logout = useCallback(async () => {
    await logoutRequest();
    setUser(null);
  }, []);

  const valor = useMemo(
    () => ({ user, cargando, login, logout, autenticado: Boolean(user) }),
    [user, cargando, login, logout]
  );

  return <AuthContext.Provider value={valor}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const contexto = useContext(AuthContext);

  if (!contexto) {
    throw new Error('useAuth necesita estar dentro de <AuthProvider>.');
  }

  return contexto;
}
