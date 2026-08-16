import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { fetchAccount, fetchAccountList } from './accountsService';

// El contrato con Rails: de donde cuelga la API, que parte de la respuesta se
// devuelve y que pasa cuando el backend contesta con un error.
describe('cliente de las cuentas', () => {
  const responder = (body, { ok = true, status = 200 } = {}) => {
    global.fetch = vi.fn().mockResolvedValue({ ok, status, json: async () => body });
  };

  const urlLlamada = () => global.fetch.mock.calls[0][0];

  beforeEach(() => {
    responder({ accounts: [] });
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('fetchAccountList', () => {
    it('pide la lista a la API', async () => {
      await fetchAccountList();

      expect(urlLlamada()).toBe('/api/v1/accounts');
    });

    it('devuelve las cuentas, no el sobre que las envuelve', async () => {
      responder({ accounts: [{ id: 1, nombre: 'PIERRE', progresoPct: 91.78 }] });

      await expect(fetchAccountList()).resolves.toEqual([
        { id: 1, nombre: 'PIERRE', progresoPct: 91.78 },
      ]);
    });

    it('devuelve una lista vacia cuando no hay cuentas', async () => {
      await expect(fetchAccountList()).resolves.toEqual([]);
    });
  });

  describe('fetchAccount', () => {
    it('pide el detalle por id', async () => {
      responder({ account: { id: 7 }, secciones: {}, report: {} });

      await fetchAccount(7);

      expect(urlLlamada()).toBe('/api/v1/accounts/7');
    });

    // La cuenta, el desglose y el report vienen juntos: el detalle se pinta con
    // una sola peticion.
    it('devuelve la respuesta entera', async () => {
      const detalle = {
        account: { id: 7, nombre: 'PIERRE' },
        secciones: { 'NIVELES DEFENSAS': [{ id: 1, nombre: 'Cañón' }] },
        report: { hasReport: true },
      };
      responder(detalle);

      await expect(fetchAccount(7)).resolves.toEqual(detalle);
    });
  });

  describe('errores', () => {
    it('usa el mensaje que manda el backend', async () => {
      responder({ error: 'Cuenta no encontrada.' }, { ok: false, status: 404 });

      await expect(fetchAccount(99)).rejects.toThrow('Cuenta no encontrada.');
    });

    it('cae a un mensaje con el status cuando el cuerpo no es JSON', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: false,
        status: 500,
        json: async () => {
          throw new Error('no es JSON');
        },
      });

      await expect(fetchAccountList()).rejects.toThrow('500');
    });
  });

  // El Sheet quedo atras: la data vive en PostgreSQL y se importa una sola vez
  // desde Rails. Si alguien vuelve a pegarle a Google desde el navegador, esto
  // lo delata.
  it('no consulta el Google Sheet', async () => {
    await fetchAccountList();

    expect(urlLlamada()).not.toContain('docs.google.com');
  });
});
