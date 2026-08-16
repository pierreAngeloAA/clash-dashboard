import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { fetchCurrentUser, login, logout } from './authService';
import { leerToken } from './http';

// Lo que mas facil se rompe aca es de donde sale el token: no viene en el
// cuerpo sino en el header Authorization de la respuesta al login.
describe('sesion', () => {
  const TOKEN = 'Bearer eyJhbGciOiJIUzI1NiJ9.abc.def';

  const responder = (body, { ok = true, status = 200, headers = {} } = {}) => {
    global.fetch = vi.fn().mockResolvedValue({
      ok,
      status,
      headers: { get: (nombre) => headers[nombre] ?? null },
      json: async () => body,
    });
  };

  const opcionesDelFetch = () => global.fetch.mock.calls[0][1];

  beforeEach(() => {
    localStorage.clear();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('login', () => {
    const responderLoginOk = () =>
      responder(
        { user: { id: 1, email: 'admin@clash.local', superadmin: true } },
        { headers: { Authorization: TOKEN } }
      );

    it('manda las credenciales anidadas como las espera Devise', async () => {
      responderLoginOk();

      await login('admin@clash.local', 'clashdev123456');

      expect(global.fetch.mock.calls[0][0]).toBe('/api/v1/login');
      expect(JSON.parse(opcionesDelFetch().body)).toEqual({
        user: { email: 'admin@clash.local', password: 'clashdev123456' },
      });
    });

    it('guarda el token que llega en el header Authorization', async () => {
      responderLoginOk();

      await login('admin@clash.local', 'clashdev123456');

      expect(leerToken()).toBe(TOKEN);
    });

    it('devuelve el usuario que mando el backend', async () => {
      responderLoginOk();

      await expect(login('admin@clash.local', 'clashdev123456')).resolves.toEqual({
        id: 1,
        email: 'admin@clash.local',
        superadmin: true,
      });
    });

    it('usa el mensaje del backend cuando las credenciales no sirven', async () => {
      responder({ error: 'Email o contraseña invalidos.' }, { ok: false, status: 401 });

      await expect(login('admin@clash.local', 'mala')).rejects.toThrow(
        'Email o contraseña invalidos.'
      );
      expect(leerToken()).toBeNull();
    });

    // Sin token la sesion no sirve de nada, y un 200 sin header dejaria al
    // usuario "logueado" pero incapaz de escribir.
    it('falla si el backend responde 200 pero sin token', async () => {
      responder({ user: { id: 1 } });

      await expect(login('admin@clash.local', 'clashdev123456')).rejects.toThrow(
        /token/i
      );
    });
  });

  describe('peticiones autenticadas', () => {
    it('manda el token guardado en el header Authorization', async () => {
      localStorage.setItem('clash-dashboard:token', TOKEN);
      responder({ user: { id: 1, email: 'admin@clash.local' } });

      await fetchCurrentUser();

      expect(opcionesDelFetch().headers.Authorization).toBe(TOKEN);
    });

    it('no manda el header cuando no hay sesion', async () => {
      responder({ accounts: [] });

      await fetchCurrentUser().catch(() => {});

      expect(opcionesDelFetch().headers.Authorization).toBeUndefined();
    });

    // El token dura 12 horas: puede vencer con la app abierta.
    it('borra el token si el backend responde 401', async () => {
      localStorage.setItem('clash-dashboard:token', TOKEN);
      responder({ error: 'Necesitas iniciar sesion.' }, { ok: false, status: 401 });

      await expect(fetchCurrentUser()).rejects.toThrow('Necesitas iniciar sesion.');
      expect(leerToken()).toBeNull();
    });
  });

  describe('logout', () => {
    it('avisa al backend para que revoque el token', async () => {
      localStorage.setItem('clash-dashboard:token', TOKEN);
      responder({ mensaje: 'Sesion cerrada.' });

      await logout();

      expect(global.fetch.mock.calls[0][0]).toBe('/api/v1/logout');
      expect(opcionesDelFetch().method).toBe('DELETE');
    });

    // Si el token ya estaba vencido, la peticion falla; dejarlo guardado seria
    // peor que perderlo.
    it('borra el token local aunque la peticion falle', async () => {
      localStorage.setItem('clash-dashboard:token', TOKEN);
      global.fetch = vi.fn().mockRejectedValue(new Error('sin red'));

      await expect(logout()).rejects.toThrow('sin red');
      expect(leerToken()).toBeNull();
    });
  });
});
