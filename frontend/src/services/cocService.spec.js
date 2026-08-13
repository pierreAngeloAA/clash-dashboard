import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { fetchClan, fetchCurrentWar, fetchPlayer } from './cocService';

// La API exige el tag con "#" y URL-encodeado una sola vez. Como el usuario
// lo escribe a mano ("2pp", "#2PP", " 2pp "), la normalizacion es la parte
// del cliente que mas facil se rompe.
describe('cliente de la API de Clash of Clans', () => {
  beforeEach(() => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ tag: '#2PP' }),
    });
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  const urlLlamada = () => global.fetch.mock.calls[0][0];

  describe('normalizacion del tag', () => {
    it('agrega el # cuando falta', async () => {
      await fetchClan('2PP');

      expect(urlLlamada()).toBe('/api/v1/clan/%232PP');
    });

    it('no duplica el # cuando ya viene', async () => {
      await fetchClan('#2PP');

      expect(urlLlamada()).toBe('/api/v1/clan/%232PP');
    });

    it('pasa a mayusculas y recorta espacios', async () => {
      await fetchClan('  #2pp  ');

      expect(urlLlamada()).toBe('/api/v1/clan/%232PP');
    });
  });

  describe('rutas', () => {
    it('consulta el detalle de un jugador', async () => {
      await fetchPlayer('LJ8V90G0');

      expect(urlLlamada()).toBe('/api/v1/player/%23LJ8V90G0');
    });

    it('consulta la guerra actual de un clan', async () => {
      await fetchCurrentWar('2PP');

      expect(urlLlamada()).toBe('/api/v1/clan/%232PP/currentwar');
    });

    it('nunca llama directo a la API oficial: el token vive en el servidor', async () => {
      await fetchClan('2PP');

      expect(urlLlamada()).not.toContain('api.clashofclans.com');
      expect(urlLlamada().startsWith('/api/')).toBe(true);
    });
  });

  describe('errores', () => {
    it('usa el mensaje que manda el backend', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 403,
        json: async () => ({ error: 'accessDenied.invalidIp' }),
      });

      await expect(fetchClan('2PP')).rejects.toThrow('accessDenied.invalidIp');
    });

    it('cae a un mensaje con el status cuando el cuerpo no es JSON', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 502,
        json: async () => {
          throw new Error('no es JSON');
        },
      });

      await expect(fetchClan('2PP')).rejects.toThrow('502');
    });
  });
});
