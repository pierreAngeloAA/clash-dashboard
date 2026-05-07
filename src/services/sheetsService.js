/**
 * sheetsService.js
 * --------------------------------------------------------------------------
 * Lee un Google Sheet PUBLICO (cualquiera con el link puede ver).
 *
 * Cada pestaña del Sheet representa una cuenta de Clash of Clans. Servicios:
 *
 *   - fetchAccountList()          -> lista pestañas (cuentas)
 *   - fetchAccountReport(gid)     -> bloque REPORT (totales por categoria, %)
 *   - fetchAccountDetails(gid)    -> niveles de cada item por categoria,
 *                                    leidos del HTML coloreado del Sheet
 *                                    (verde = hecho, amarillo = en curso)
 *   - clearSheetCache()           -> invalida todo el cache local del Sheet
 */

export const SHEET_ID = '1gosF9F2mdWuQRH2ubcsc39WRy66x81K9UjRlFdwNbpo';

const CACHE_PREFIX = `clash-sheet:${SHEET_ID}:`;
const CACHE_TTL_MS = 5 * 60 * 1000;

const HTMLVIEW_URL = `https://docs.google.com/spreadsheets/d/${SHEET_ID}/htmlview`;
const sheetHtmlUrl = (gid) =>
  `https://docs.google.com/spreadsheets/d/${SHEET_ID}/htmlview/sheet?headers=true&gid=${gid}`;
const gvizUrl = (gid) =>
  `https://docs.google.com/spreadsheets/d/${SHEET_ID}/gviz/tq?tqx=out:json&gid=${gid}`;

// ---------- cache helpers ----------

function readCache(key) {
  try {
    const raw = localStorage.getItem(key);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (!parsed?.timestamp || parsed?.data === undefined) return null;
    if (Date.now() - parsed.timestamp > CACHE_TTL_MS) return null;
    return parsed.data;
  } catch {
    return null;
  }
}

function writeCache(key, data) {
  try {
    localStorage.setItem(key, JSON.stringify({ timestamp: Date.now(), data }));
  } catch {
    /* localStorage lleno o deshabilitado */
  }
}

export function clearSheetCache() {
  try {
    const toDelete = [];
    for (let i = 0; i < localStorage.length; i++) {
      const k = localStorage.key(i);
      if (k && k.startsWith(CACHE_PREFIX)) toDelete.push(k);
    }
    toDelete.forEach((k) => localStorage.removeItem(k));
  } catch {
    /* noop */
  }
}

// ---------- gviz helper ----------

function parseGvizText(rawText) {
  const start = rawText.indexOf('{');
  const end = rawText.lastIndexOf('}');
  if (start === -1 || end === -1) {
    throw new Error('Respuesta gviz invalida: no se encontro JSON.');
  }
  return JSON.parse(rawText.slice(start, end + 1));
}

// ---------- pestañas (cuentas) ----------

function parseTabName(rawName) {
  const m = String(rawName).match(/^(.*?)\s+TH\s*(\d+)\s*$/i);
  if (m) return { playerName: m[1].trim(), townHall: Number(m[2]) };
  return { playerName: String(rawName).trim(), townHall: null };
}

export async function fetchAccountList({ force = false } = {}) {
  const cacheKey = `${CACHE_PREFIX}tabs`;
  if (!force) {
    const cached = readCache(cacheKey);
    if (cached) return cached;
  }

  const res = await fetch(HTMLVIEW_URL);
  if (!res.ok) {
    throw new Error(
      `No se pudo leer el Google Sheet (HTTP ${res.status}). ¿Esta compartido como publico?`
    );
  }
  const html = await res.text();

  const accounts = [];
  const seen = new Set();
  const re = /items\.push\(\{name:\s*"([^"]+)",[^}]*gid:\s*"(\d+)"/g;
  let m;
  while ((m = re.exec(html)) !== null) {
    const gid = m[2];
    if (seen.has(gid)) continue;
    seen.add(gid);
    const name = m[1];
    accounts.push({ gid, name, ...parseTabName(name) });
  }

  if (accounts.length === 0) {
    throw new Error('No se encontraron pestañas en el Sheet.');
  }

  writeCache(cacheKey, accounts);
  return accounts;
}

// ---------- bloque REPORT ----------

function classifyCell(cell) {
  if (!cell || cell.v === undefined || cell.v === null || cell.v === '') {
    return { kind: 'empty' };
  }
  if (typeof cell.v === 'number') {
    if (typeof cell.f === 'string' && /%\s*$/.test(cell.f)) {
      return { kind: 'percent', value: cell.v * 100 };
    }
    return { kind: 'number', value: cell.v };
  }
  const s = String(cell.v).trim();
  const pct = s.match(/^(-?[\d.,]+)\s*%$/);
  if (pct) return { kind: 'percent', value: Number(pct[1].replace(',', '.')) };
  const numOnly = s.match(/^-?[\d.,]+$/);
  if (numOnly) return { kind: 'number', value: Number(s.replace(',', '.')) };
  return { kind: 'text', value: s };
}

function findReportAnchor(rows) {
  for (let r = 0; r < rows.length; r++) {
    const cells = rows[r]?.c || [];
    for (let c = 0; c < cells.length; c++) {
      const v = cells[c]?.v;
      if (typeof v === 'string' && v.trim().toUpperCase() === 'REPORT') {
        return { row: r, col: c };
      }
    }
  }
  return null;
}

const HERO_LABELS = [
  'REY BARBARO',
  'REINA ARQUERA',
  'PRINCIPE ESBIRROS',
  'GRAN CENTINELA',
  'LUCHADORA REAL',
  'DUQUE DRAGON',
];

const KNOWN_CATEGORIES = [
  'NIVELES DEFENSAS',
  'TROPAS CLARAS',
  'TROPAS OSCURAS',
  'HECHIZOS CLAROS',
  'HECHIZOS OSCUROS',
  'MAQUINAS DE ASEDIO',
  ...HERO_LABELS,
  'ANIMALES',
  'NIVELES TRAMPAS',
  'GUARDIANES',
];

// Los TOTAL_* aparecen truncados a veces ("TOTAL LEVEL HERO" en lugar de
// "TOTAL LEVEL HEROES"), asi que matcheamos por prefijo.
const TOTAL_PREFIXES = [
  ['TOTAL LEVEL HERO', 'heroes'],
  ['TOTAL INVESTIG', 'investigacion'],
  ['TOTAL DEFENS', 'defensas'],
  ['TOTAL TOTAL', 'total'],
];

function classifyLabel(norm) {
  if (!norm) return null;
  if (norm === 'PROGRESO') return { type: 'progreso' };
  if (norm === 'FALTANTE') return { type: 'faltante' };
  if (norm === 'TOTAL REPORT') return { type: 'skip' };
  for (const [prefix, key] of TOTAL_PREFIXES) {
    if (norm.startsWith(prefix)) return { type: 'total', key };
  }
  for (const cat of KNOWN_CATEGORIES) {
    if (norm === cat || cat.startsWith(norm) || norm.startsWith(cat)) {
      return { type: 'category', label: cat };
    }
  }
  return null;
}

export async function fetchAccountReport(gid, { force = false } = {}) {
  if (!gid) throw new Error('gid requerido');
  const cacheKey = `${CACHE_PREFIX}report:${gid}`;
  if (!force) {
    const cached = readCache(cacheKey);
    if (cached) return cached;
  }

  const res = await fetch(gvizUrl(gid));
  if (!res.ok) {
    throw new Error(`No se pudo leer la pestaña (HTTP ${res.status}).`);
  }
  const text = await res.text();
  const gviz = parseGvizText(text);
  if (gviz.status && gviz.status !== 'ok') {
    const msg = gviz.errors?.[0]?.detailed_message || 'Error desconocido en gviz.';
    throw new Error(msg);
  }

  const rows = gviz.table.rows || [];
  const anchor = findReportAnchor(rows);

  const result = {
    hasReport: false,
    categories: [],
    totals: {},
    progresoPct: null,
    faltantePct: null,
  };

  if (!anchor) {
    writeCache(cacheKey, result);
    return result;
  }

  const minCol = anchor.col; // labels viven en esta columna o un par mas a la derecha

  for (let r = anchor.row + 1; r < rows.length; r++) {
    const cells = rows[r]?.c || [];
    let found = null;
    for (let c = minCol; c < cells.length; c++) {
      const v = cells[c]?.v;
      if (typeof v !== 'string') continue;
      const norm = v.trim().replace(/[:.\s]+$/, '').toUpperCase();
      const cls = classifyLabel(norm);
      if (cls) {
        found = { col: c, raw: v, ...cls };
        break;
      }
    }
    if (!found || found.type === 'skip') continue;

    const after = cells.slice(found.col + 1).map(classifyCell);
    const nonEmpty = after.filter((c) => c.kind !== 'empty');

    if (found.type === 'progreso' || found.type === 'faltante') {
      const pct = nonEmpty.find((c) => c.kind === 'percent');
      if (pct) {
        if (found.type === 'progreso') result.progresoPct = pct.value;
        else result.faltantePct = pct.value;
      }
      continue;
    }

    if (found.type === 'total') {
      const nums = nonEmpty.filter((c) => c.kind === 'number').map((c) => c.value);
      if (nums.length >= 1) {
        result.totals[found.key] = {
          total: nums[0],
          faltante: nums[1] ?? 0,
        };
      }
      continue;
    }

    // Categoria: 2 numeros + 2 porcentajes en orden.
    if (
      nonEmpty.length >= 4 &&
      nonEmpty[0].kind === 'number' &&
      nonEmpty[1].kind === 'number' &&
      nonEmpty[2].kind === 'percent'
    ) {
      result.categories.push({
        label: found.label,
        total: nonEmpty[0].value,
        faltante: nonEmpty[1].value,
        pctDone: nonEmpty[2].value,
        pctMissing:
          nonEmpty[3]?.kind === 'percent'
            ? nonEmpty[3].value
            : Math.max(0, 100 - nonEmpty[2].value),
      });
    }
  }

  // Colapsar las 6 categorias de heroes en una sola "HEROES".
  const heroCats = result.categories.filter((c) => HERO_LABELS.includes(c.label));
  if (heroCats.length > 0) {
    const total = heroCats.reduce((s, c) => s + c.total, 0);
    const faltante = heroCats.reduce((s, c) => s + c.faltante, 0);
    const pctDone = total > 0 ? ((total - faltante) / total) * 100 : 0;
    result.categories = result.categories.filter(
      (c) => !HERO_LABELS.includes(c.label)
    );
    result.categories.push({
      label: 'HEROES',
      total,
      faltante,
      pctDone,
      pctMissing: Math.max(0, 100 - pctDone),
    });
  }

  result.hasReport =
    result.categories.length > 0 ||
    result.progresoPct != null ||
    Object.keys(result.totals).length > 0;

  writeCache(cacheKey, result);
  return result;
}

// ---------- detalle por item (HTML coloreado) ----------

const COLOR_DONE = '#34a853'; // verde - nivel completado
const COLOR_NEXT = '#ffff00'; // amarillo - nivel proximo / en curso

const HEROES = HERO_LABELS;

// Categorias con layout "fila por item": idx | nombre | TH... TH...
const ROW_PER_ITEM_CATS = [
  'NIVELES DEFENSAS',
  'TROPAS CLARAS',
  'TROPAS OSCURAS',
  'HECHIZOS CLAROS',
  'HECHIZOS OSCUROS',
  'MAQUINAS DE ASEDIO',
  'ANIMALES',
  'NIVELES TRAMPAS',
];

const ALL_DETAIL_CATS = [...ROW_PER_ITEM_CATS, ...HEROES, 'GUARDIANES'];

function matchDetailCat(text, list = ALL_DETAIL_CATS) {
  const norm = (text || '').trim().toUpperCase();
  if (!norm) return null;
  return list.find((c) => c === norm || c.startsWith(norm) || norm.startsWith(c)) || null;
}

function parseStyledRows(html) {
  const classToBg = {};
  const styleRe = /\.(s\d+)\s*\{[^}]*background-color:\s*([^;]+);/g;
  let m;
  while ((m = styleRe.exec(html)) !== null) {
    classToBg[m[1]] = m[2].trim().toLowerCase();
  }

  const rows = [];
  const trRe = /<tr[^>]*>([\s\S]*?)<\/tr>/g;
  while ((m = trRe.exec(html)) !== null) {
    const cells = [];
    const tdRe = /<t[hd]([^>]*?)>([\s\S]*?)<\/t[hd]>/g;
    let cm;
    while ((cm = tdRe.exec(m[1])) !== null) {
      const attrs = cm[1] || '';
      const klass = (attrs.match(/class="([^"]*)"/) || [])[1] || '';
      const span = Number((attrs.match(/colspan="(\d+)"/) || [])[1]) || 1;
      const text = cm[2]
        .replace(/<[^>]+>/g, '')
        .replace(/&nbsp;/g, ' ')
        .replace(/&amp;/g, '&')
        .trim();
      const cell = { class: klass, bg: classToBg[klass] || null, text };
      for (let s = 0; s < span; s++) cells.push(cell);
    }
    rows.push(cells);
  }
  return rows;
}

function extractRowPerItemSections(rows) {
  const sections = {};
  const active = []; // bloques activos: { name, nameCol, idxCol, levelCols }

  for (const row of rows) {
    const cells = row.slice(1); // saltamos el <th> con el numero de fila

    // detectar headers de seccion en cualquier columna
    for (let c = 1; c < cells.length; c++) {
      const cat = matchDetailCat(cells[c]?.text, ROW_PER_ITEM_CATS);
      if (!cat) continue;
      const levelCols = [];
      for (let lc = c + 1; lc < cells.length; lc++) {
        if (/^\d+$/.test(cells[lc]?.text || '')) levelCols.push(lc);
        else if (levelCols.length > 0) break;
      }
      if (!levelCols.length) continue;
      // reemplazar bloque previo en la misma columna
      const prev = active.findIndex((b) => b.nameCol === c);
      if (prev >= 0) active.splice(prev, 1);
      active.push({ name: cat, nameCol: c, idxCol: c - 1, levelCols });
      sections[cat] = sections[cat] || [];
    }

    // extraer datos para cada bloque activo
    for (const blk of active) {
      const idx = cells[blk.idxCol]?.text || '';
      const name = cells[blk.nameCol]?.text || '';
      if (!/^\d+$/.test(idx) || !name) continue;
      if (matchDetailCat(name, ROW_PER_ITEM_CATS) === blk.name) continue;

      let currentLevel = 0;
      let maxLevel = 0;
      const levels = [];
      for (let i = 0; i < blk.levelCols.length; i++) {
        const cell = cells[blk.levelCols[i]];
        const text = cell?.text || '';
        if (!text) {
          levels.push({ text: '', state: 'na' });
          continue;
        }
        maxLevel = i + 1;
        const state =
          cell.bg === COLOR_DONE
            ? 'done'
            : cell.bg === COLOR_NEXT
              ? 'next'
              : 'pending';
        if (state === 'done') currentLevel = i + 1;
        levels.push({ text, state });
      }
      if (maxLevel === 0) continue;
      sections[blk.name].push({ idx, name, currentLevel, maxLevel, levels });
    }
  }

  return sections;
}


function extractHeroSections(rows) {
  // Las etiquetas en el bloque REPORT tienen numeros / porcentajes inmediatamente
  // a la derecha. Los headers de heroes en el catalogo tienen blanks. Asi
  // descartamos los falsos positivos sin depender de columnas absolutas.
  const looksLikeReportRow = (cells, fromCol) => {
    const window = cells.slice(fromCol + 1, fromCol + 8);
    return window.some((cell) => /^-?\d+(\.\d+)?\s*%?$/.test(cell?.text || ''));
  };

  const anchors = [];
  rows.forEach((row, ri) => {
    const cells = row.slice(1);
    let lastHeroCol = -2;
    for (let c = 1; c < cells.length; c++) {
      const hero = matchDetailCat(cells[c]?.text, HEROES);
      if (!hero) continue;
      // colspan duplica la misma celda en columnas consecutivas
      if (c === lastHeroCol + 1) {
        lastHeroCol = c;
        continue;
      }
      lastHeroCol = c;
      if (looksLikeReportRow(cells, c)) continue;
      anchors.push({ name: hero, row: ri, col: c });
    }
  });

  // Limites: hasta el siguiente anclaje (cualquier heroe) o fin
  const sections = {};
  for (let i = 0; i < anchors.length; i++) {
    const anchor = anchors[i];
    const nextRow = anchors[i + 1]?.row ?? rows.length;
    let currentLevel = 0;
    let maxLevel = 0;
    for (let r = anchor.row + 1; r < nextRow; r++) {
      const cells = (rows[r] || []).slice(1);
      // las celdas de nivel viven en el mismo rango de columnas que el ancla
      for (let c = anchor.col; c < cells.length; c++) {
        const cell = cells[c];
        const text = cell?.text || '';
        if (!/^\d+$/.test(text)) continue;
        const num = Number(text);
        if (num > maxLevel) maxLevel = num;
        if (cell.bg === COLOR_DONE && num > currentLevel) currentLevel = num;
      }
    }
    if (maxLevel > 0) {
      sections.HEROES = sections.HEROES || [];
      sections.HEROES.push({
        idx: '',
        name: anchor.name,
        currentLevel,
        maxLevel,
      });
    }
  }
  // ordenar segun la lista canonica
  if (sections.HEROES) {
    sections.HEROES.sort(
      (a, b) => HEROES.indexOf(a.name) - HEROES.indexOf(b.name)
    );
  }
  return sections;
}

// Etiquetas que viven en el bloque REPORT y NO son items de catalogo.
const NON_GUARDIAN_LABELS = new Set([
  'REPORT',
  'PROGRESO',
  'FALTANTE',
  'TOTAL REPORT',
]);

function extractGuardianesSection(rows) {
  // Cada equipo guardian es 2 filas: nombre en mayusculas + fila "1 2 3 4 5"
  // con celdas verdes/amarillas. Detectamos el patron sin hardcodear nombres
  // para que sirva con cualquier set de equipos del jugador.
  const items = [];
  for (let r = 0; r < rows.length - 1; r++) {
    const cells = (rows[r] || []).slice(1);
    for (let c = 1; c < cells.length; c++) {
      const text = (cells[c]?.text || '').trim();
      if (!text || text.length < 5) continue;
      // Sólo nombres en mayúsculas y sin dígitos (excluye TH10, TH11, etc).
      if (text !== text.toUpperCase()) continue;
      if (/\d/.test(text)) continue;
      // Excluir categorias ya conocidas, héroes y etiquetas del REPORT.
      const upper = text.toUpperCase();
      if (NON_GUARDIAN_LABELS.has(upper)) continue;
      if (upper.startsWith('TOTAL ')) continue;
      if (matchDetailCat(text, [...ROW_PER_ITEM_CATS, ...HEROES, 'GUARDIANES']))
        continue;
      // Filas del REPORT tienen numeros/% justo a la derecha.
      const window = cells.slice(c + 1, c + 8);
      if (window.some((cc) => /^-?\d+(\.\d+)?\s*%?$/.test(cc?.text || '')))
        continue;
      // La siguiente fila debe tener una secuencia de niveles 1..N.
      const next = (rows[r + 1] || []).slice(1);
      const levelCols = [];
      for (let lc = c - 1; lc < next.length && levelCols.length < 10; lc++) {
        if (lc < 0) continue;
        if (/^\d+$/.test(next[lc]?.text || '')) levelCols.push(lc);
        else if (levelCols.length > 0) break;
      }
      if (levelCols.length < 3) continue;

      let currentLevel = 0;
      let maxLevel = 0;
      for (let i = 0; i < levelCols.length; i++) {
        const cell = next[levelCols[i]];
        if (!cell?.text) continue;
        maxLevel = i + 1;
        if (cell.bg === COLOR_DONE) currentLevel = i + 1;
      }
      if (maxLevel === 0) continue;
      items.push({ idx: '', name: text, currentLevel, maxLevel });
      break; // sólo un guardian por fila
    }
  }
  return items.length ? { GUARDIANES: items } : {};
}

export async function fetchAccountDetails(gid, { force = false } = {}) {
  if (!gid) throw new Error('gid requerido');
  const cacheKey = `${CACHE_PREFIX}details:${gid}`;
  if (!force) {
    const cached = readCache(cacheKey);
    if (cached) return cached;
  }

  const res = await fetch(sheetHtmlUrl(gid));
  if (!res.ok) {
    throw new Error(`No se pudo leer la pestaña (HTTP ${res.status}).`);
  }
  const html = await res.text();
  const rows = parseStyledRows(html);

  const sections = {
    ...extractRowPerItemSections(rows),
    ...extractHeroSections(rows),
    ...extractGuardianesSection(rows),
  };

  const result = { sections };
  writeCache(cacheKey, result);
  return result;
}
