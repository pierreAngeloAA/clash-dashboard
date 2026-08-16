/**
 * Cliente de la API de Clash of Clans, que se consume a traves del backend.
 * El token vive solo ahi: esta atado a una IP y no puede viajar al navegador.
 */

import { getJson } from './http';

const normalizeTag = (tag) => {
  const clean = String(tag || '').trim().toUpperCase();
  if (!clean) return '';
  return clean.startsWith('#') ? clean : `#${clean}`;
};

const tagParam = (tag) => encodeURIComponent(normalizeTag(tag));

export function fetchClan(tag) {
  return getJson(`/clan/${tagParam(tag)}`);
}

export function fetchPlayer(tag) {
  return getJson(`/player/${tagParam(tag)}`);
}

export function fetchCurrentWar(clanTag) {
  return getJson(`/clan/${tagParam(clanTag)}/currentwar`);
}
