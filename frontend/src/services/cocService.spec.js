import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { fetchClan, fetchCurrentWar, fetchPlayer } from './cocService';

// El tag viaja sin el numeral: lo agrega el backend. Con "#" codificado como
// "%23" la ruta fallaba en produccion, porque el rewrite de Render lo decodifica
// y el servidor no recibe nada de lo que va despues.
//
// Como el usuario lo escribe a mano ("2pp", "#2PP", " 2pp "), la normalizacion
// sigue siendo la parte del cliente que mas facil se rompe.
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
    it('no manda el numeral cuando el usuario no lo escribe', async () => {
      await fetchClan('2PP');

      expect(urlLlamada()).toBe('/api/v1/clan/2PP');
    });

    it('le saca el numeral cuando el usuario si lo escribe', async () => {
      await fetchClan('#2PP');

      expect(urlLlamada()).toBe('/api/v1/clan/2PP');
    });

    it('pasa a mayusculas y recorta espacios', async () => {
      await fetchClan('  #2pp  ');

      expect(urlLlamada()).toBe('/api/v1/clan/2PP');
    });

    // El rewrite de Render decodifica %23 a # y el servidor deja de recibir el
    // tag. Que no viaje codificado es justamente el arreglo.
    it('nunca manda un numeral codificado en la ruta', async () => {
      await fetchClan('#2PP');

      expect(urlLlamada()).not.toContain('%23');
    });
  });

  describe('rutas', () => {
    it('consulta el detalle de un jugador', async () => {
      await fetchPlayer('LJ8V90G0');

      expect(urlLlamada()).toBe('/api/v1/player/LJ8V90G0');
    });

    it('consulta la guerra actual de un clan', async () => {
      await fetchCurrentWar('2PP');

      expect(urlLlamada()).toBe('/api/v1/clan/2PP/currentwar');
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
