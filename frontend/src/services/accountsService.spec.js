import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  createAccount,
  deleteAccount,
  fetchAccount,
  fetchAccountList,
  syncAccount,
  updateAccount,
  updateAccountItem,
} from './accountsService';

// El contrato con Rails: de donde cuelga la API, que parte de la respuesta se
// devuelve y que pasa cuando el backend contesta con un error.
describe('cliente de las cuentas', () => {
  const responder = (body, { ok = true, status = 200 } = {}) => {
    global.fetch = vi.fn().mockResolvedValue({ ok, status, json: async () => body });
  };

  const urlLlamada = () => global.fetch.mock.calls[0][0];
  const opcionesDelFetch = () => global.fetch.mock.calls[0][1];

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

  describe('alta, edicion y borrado de cuentas', () => {
    it('crea la cuenta con los datos anidados bajo account', async () => {
      responder({ account: { id: 14, nombre: 'PIERRE' } });

      await createAccount({ nombre: 'PIERRE', town_hall: 15 });

      expect(urlLlamada()).toBe('/api/v1/accounts');
      expect(opcionesDelFetch().method).toBe('POST');
      expect(JSON.parse(opcionesDelFetch().body)).toEqual({
        account: { nombre: 'PIERRE', town_hall: 15 },
      });
    });

    it('devuelve la cuenta creada, no el sobre', async () => {
      responder({ account: { id: 14, nombre: 'PIERRE', tagCoc: '#LJ8V90G0' } });

      await expect(createAccount({ nombre: 'PIERRE' })).resolves.toEqual({
        id: 14,
        nombre: 'PIERRE',
        tagCoc: '#LJ8V90G0',
      });
    });

    it('edita la cuenta por id', async () => {
      responder({ account: { id: 14, townHall: 16 } });

      await updateAccount(14, { town_hall: 16 });

      expect(urlLlamada()).toBe('/api/v1/accounts/14');
      expect(opcionesDelFetch().method).toBe('PATCH');
    });

    it('borra la cuenta por id', async () => {
      responder({});

      await deleteAccount(14);

      expect(urlLlamada()).toBe('/api/v1/accounts/14');
      expect(opcionesDelFetch().method).toBe('DELETE');
    });

    // El 204 no trae cuerpo: si el cliente esperara JSON, borrar reventaria.
    it('no se rompe con el 204 sin cuerpo del borrado', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        status: 204,
        headers: { get: () => null },
        json: async () => {
          throw new Error('sin cuerpo');
        },
      });

      await expect(deleteAccount(14)).resolves.toBeUndefined();
    });
  });

  describe('syncAccount', () => {
    it('dispara la sincronizacion de la cuenta', async () => {
      responder({ resumen: { actualizados: 3 }, account: {} });

      await syncAccount(5);

      expect(urlLlamada()).toBe('/api/v1/accounts/5/sincronizar');
      expect(opcionesDelFetch().method).toBe('POST');
    });

    // El resumen importa tanto como el resultado: la API no expone defensas ni
    // trampas, asi que una sincronizacion normal deja mucho sin tocar.
    it('devuelve el resumen junto con la cuenta', async () => {
      const respuesta = {
        resumen: { actualizados: 3, sinMapear: 29 },
        account: { account: { id: 5 }, report: {} },
      };
      responder(respuesta);

      await expect(syncAccount(5)).resolves.toEqual(respuesta);
    });

    it('propaga el mensaje cuando la API rechaza el token', async () => {
      responder(
        { error: 'Invalid authorization: API key does not allow access from IP' },
        { ok: false, status: 502 }
      );

      await expect(syncAccount(5)).rejects.toThrow(/Invalid authorization/);
    });
  });

  describe('updateAccountItem', () => {
    it('edita el elemento dentro de su cuenta, no por su id suelto', async () => {
      responder({ item: { id: 12, currentLevel: 6 } });

      await updateAccountItem(7, 12, { current_level: 6 });

      expect(global.fetch.mock.calls[0][0]).toBe('/api/v1/accounts/7/items/12');
      expect(opcionesDelFetch().method).toBe('PATCH');
    });

    it('manda los cambios anidados bajo item', async () => {
      responder({ item: { id: 12 } });

      await updateAccountItem(7, 12, { current_level: 6 });

      expect(JSON.parse(opcionesDelFetch().body)).toEqual({
        item: { current_level: 6 },
      });
    });

    it('devuelve el elemento actualizado, no el sobre', async () => {
      responder({ item: { id: 12, currentLevel: 6, faltante: 15 } });

      await expect(updateAccountItem(7, 12, { current_level: 6 })).resolves.toEqual({
        id: 12,
        currentLevel: 6,
        faltante: 15,
      });
    });
  });

  describe('errores', () => {
    it('usa el mensaje que manda el backend', async () => {
      responder({ error: 'Cuenta no encontrada.' }, { ok: false, status: 404 });

      await expect(fetchAccount(99)).rejects.toThrow('Cuenta no encontrada.');
    });

    // Las validaciones no vuelven como `error` sino como `errors`, y ya vienen
    // en español con el nombre del campo traducido.
    it('muestra los errores de validacion tal cual los manda Rails', async () => {
      responder(
        { errors: ['nivel actual debe ser menor que o igual a 21'] },
        { ok: false, status: 422 }
      );

      await expect(updateAccountItem(7, 12, { current_level: 99 })).rejects.toThrow(
        'nivel actual debe ser menor que o igual a 21'
      );
    });

    it('junta varios errores de validacion en un solo mensaje', async () => {
      responder({ errors: ['primero', 'segundo'] }, { ok: false, status: 422 });

      await expect(updateAccountItem(7, 12, {})).rejects.toThrow('primero. segundo');
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
