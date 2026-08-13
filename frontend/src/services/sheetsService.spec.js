import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  clearSheetCache,
  fetchAccountList,
  fetchAccountReport,
} from './sheetsService';

// El htmlview del Sheet trae la lista de pestañas como llamadas a items.push().
const htmlviewCon = (tabs) =>
  `<html><script>${tabs
    .map(({ name, gid }) => `items.push({name: "${name}", gid: "${gid}"});`)
    .join('\n')}</script></html>`;

// gviz responde el JSON envuelto en un wrapper que hay que recortar.
const gvizCon = (rows) =>
  `/*O_o*/\ngoogle.visualization.Query.setResponse(${JSON.stringify({
    version: '0.6',
    status: 'ok',
    table: { cols: [], rows },
  })});`;

const fila = (...celdas) => ({
  c: celdas.map((v) => {
    if (v === null) return null;
    if (typeof v === 'object') return v;
    return { v };
  }),
});

const pct = (n) => ({ v: n / 100, f: `${n}%` });

// Bloque REPORT tipico: dos heroes por separado, una categoria normal,
// los porcentajes globales y los totales.
const REPORT_ROWS = [
  fila('REPORT'),
  fila('NIVELES DEFENSAS', 100, 20, pct(80), pct(20)),
  fila('REY BARBARO', 10, 2, pct(80), pct(20)),
  fila('REINA ARQUERA', 10, 3, pct(70), pct(30)),
  fila('PROGRESO', pct(75)),
  fila('FALTANTE', pct(25)),
  fila('TOTAL LEVEL HEROES', 20, 5),
  fila('TOTAL DEFENSAS', 100, 20),
];

function mockFetchTexto(texto, { ok = true, status = 200 } = {}) {
  global.fetch = vi.fn().mockResolvedValue({
    ok,
    status,
    text: async () => texto,
  });
}

describe('sheetsService', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('fetchAccountList', () => {
    it('extrae las pestañas del htmlview', async () => {
      mockFetchTexto(
        htmlviewCon([
          { name: 'Pierre TH15', gid: '111' },
          { name: 'Segunda TH12', gid: '222' },
        ])
      );

      const cuentas = await fetchAccountList();

      expect(cuentas).toHaveLength(2);
      expect(cuentas[0]).toMatchObject({ gid: '111', name: 'Pierre TH15' });
    });

    it('separa el nombre del jugador del nivel de ayuntamiento', async () => {
      mockFetchTexto(htmlviewCon([{ name: 'Pierre TH15', gid: '111' }]));

      const [cuenta] = await fetchAccountList();

      expect(cuenta.playerName).toBe('Pierre');
      expect(cuenta.townHall).toBe(15);
    });

    it('deja townHall en null cuando el nombre no trae TH', async () => {
      mockFetchTexto(htmlviewCon([{ name: 'Resumen', gid: '111' }]));

      const [cuenta] = await fetchAccountList();

      expect(cuenta.playerName).toBe('Resumen');
      expect(cuenta.townHall).toBeNull();
    });

    it('descarta gids repetidos: el htmlview los lista mas de una vez', async () => {
      mockFetchTexto(
        htmlviewCon([
          { name: 'Pierre TH15', gid: '111' },
          { name: 'Pierre TH15', gid: '111' },
          { name: 'Otra TH9', gid: '222' },
        ])
      );

      const cuentas = await fetchAccountList();

      expect(cuentas.map((c) => c.gid)).toEqual(['111', '222']);
    });

    it('avisa cuando el Sheet no es publico', async () => {
      mockFetchTexto('', { ok: false, status: 403 });

      await expect(fetchAccountList()).rejects.toThrow('403');
    });

    it('avisa cuando no encuentra ninguna pestaña', async () => {
      mockFetchTexto('<html>sin pestañas</html>');

      await expect(fetchAccountList()).rejects.toThrow('No se encontraron');
    });
  });

  describe('fetchAccountReport', () => {
    it('parsea una categoria con sus totales y porcentajes', async () => {
      mockFetchTexto(gvizCon(REPORT_ROWS));

      const report = await fetchAccountReport('111');
      const defensas = report.categories.find(
        (c) => c.label === 'NIVELES DEFENSAS'
      );

      expect(defensas).toEqual({
        label: 'NIVELES DEFENSAS',
        total: 100,
        faltante: 20,
        pctDone: 80,
        pctMissing: 20,
      });
    });

    it('colapsa los heroes sueltos en una sola categoria HEROES', async () => {
      mockFetchTexto(gvizCon(REPORT_ROWS));

      const report = await fetchAccountReport('111');
      const etiquetas = report.categories.map((c) => c.label);

      expect(etiquetas).toContain('HEROES');
      expect(etiquetas).not.toContain('REY BARBARO');
      expect(etiquetas).not.toContain('REINA ARQUERA');
    });

    it('suma los heroes y recalcula el porcentaje sobre el total sumado', async () => {
      mockFetchTexto(gvizCon(REPORT_ROWS));

      const report = await fetchAccountReport('111');
      const heroes = report.categories.find((c) => c.label === 'HEROES');

      // 10+10 niveles, faltan 2+3 => 15 de 20 hechos = 75%
      expect(heroes).toMatchObject({ total: 20, faltante: 5, pctDone: 75 });
    });

    it('lee los porcentajes globales de progreso y faltante', async () => {
      mockFetchTexto(gvizCon(REPORT_ROWS));

      const report = await fetchAccountReport('111');

      expect(report.progresoPct).toBe(75);
      expect(report.faltantePct).toBe(25);
    });

    it('lee los totales reconociendo etiquetas truncadas', async () => {
      mockFetchTexto(gvizCon(REPORT_ROWS));

      const report = await fetchAccountReport('111');

      expect(report.totals.heroes).toEqual({ total: 20, faltante: 5 });
      expect(report.totals.defensas).toEqual({ total: 100, faltante: 20 });
    });

    it('devuelve hasReport false cuando la pestaña no tiene bloque REPORT', async () => {
      mockFetchTexto(gvizCon([fila('OTRA COSA', 1, 2)]));

      const report = await fetchAccountReport('111');

      expect(report.hasReport).toBe(false);
      expect(report.categories).toEqual([]);
    });

    it('propaga el error que reporta gviz', async () => {
      global.fetch = vi.fn().mockResolvedValue({
        ok: true,
        status: 200,
        text: async () =>
          `/*O_o*/google.visualization.Query.setResponse(${JSON.stringify({
            status: 'error',
            errors: [{ detailed_message: 'Pestaña inexistente' }],
          })});`,
      });

      await expect(fetchAccountReport('999')).rejects.toThrow(
        'Pestaña inexistente'
      );
    });

    it('exige el gid', async () => {
      await expect(fetchAccountReport('')).rejects.toThrow('gid requerido');
    });
  });

  describe('cache en localStorage', () => {
    it('no vuelve a pedir el Sheet dentro de la ventana de cache', async () => {
      mockFetchTexto(gvizCon(REPORT_ROWS));

      await fetchAccountReport('111');
      await fetchAccountReport('111');

      expect(global.fetch).toHaveBeenCalledTimes(1);
    });

    it('force: true ignora el cache y vuelve a pedir', async () => {
      mockFetchTexto(gvizCon(REPORT_ROWS));

      await fetchAccountReport('111');
      await fetchAccountReport('111', { force: true });

      expect(global.fetch).toHaveBeenCalledTimes(2);
    });

    it('cachea cada pestaña por separado', async () => {
      mockFetchTexto(gvizCon(REPORT_ROWS));

      await fetchAccountReport('111');
      await fetchAccountReport('222');

      expect(global.fetch).toHaveBeenCalledTimes(2);
    });

    it('clearSheetCache obliga a releer', async () => {
      mockFetchTexto(gvizCon(REPORT_ROWS));

      await fetchAccountReport('111');
      clearSheetCache();
      await fetchAccountReport('111');

      expect(global.fetch).toHaveBeenCalledTimes(2);
    });
  });
});
