/**
 * Cliente del proxy local que consume la API de Clash of Clans.
 * El token vive solo en el servidor (server/.env).
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
    throw new Error(body?.error || `Error ${res.status} desde el proxy.`);
  }
  return body;
}

export function fetchClan(tag) {
  const t = encodeURIComponent(normalizeTag(tag));
  return getJson(`/api/clan/${t}`);
}

export function fetchPlayer(tag) {
  const t = encodeURIComponent(normalizeTag(tag));
  return getJson(`/api/player/${t}`);
}

export function fetchCurrentWar(clanTag) {
  const t = encodeURIComponent(normalizeTag(clanTag));
  return getJson(`/api/clan/${t}/currentwar`);
}
