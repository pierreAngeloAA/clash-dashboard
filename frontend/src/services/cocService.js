/**
 * Cliente de la API de Clash of Clans, que se consume a traves del backend.
 * El token vive solo ahi: esta atado a una IP y no puede viajar al navegador.
 */

const normalizeTag = (tag) => {
  const clean = String(tag || '').trim().toUpperCase();
  if (!clean) return '';
  return clean.startsWith('#') ? clean : `#${clean}`;
};

async function getJson(url) {
  const res = await fetch(url);
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(body?.error || `Error ${res.status} desde el backend.`);
  }
  return body;
}

export function fetchClan(tag) {
  const t = encodeURIComponent(normalizeTag(tag));
  return getJson(`/api/v1/clan/${t}`);
}

export function fetchPlayer(tag) {
  const t = encodeURIComponent(normalizeTag(tag));
  return getJson(`/api/v1/player/${t}`);
}

export function fetchCurrentWar(clanTag) {
  const t = encodeURIComponent(normalizeTag(clanTag));
  return getJson(`/api/v1/clan/${t}/currentwar`);
}
