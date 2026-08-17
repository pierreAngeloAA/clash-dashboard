/**
 * Cliente de la API de Clash of Clans, que se consume a traves del backend.
 * El token vive solo ahi: esta atado a una IP y no puede viajar al navegador.
 */

import { getJson } from './http';

/**
 * El tag viaja **sin** el numeral, aunque la API oficial lo exija: lo agrega el
 * backend, que normaliza igual `98R828VJ`, `#98R828VJ` o ` 98r828vj `.
 *
 * Mandarlo con `#` codificado como `%23` funcionaba en desarrollo y fallaba en
 * produccion con un 404: el rewrite de Render decodifica `%23` a `#`, y todo lo
 * que va despues de un numeral en una URL no llega al servidor. Rails recibia
 * `/api/v1/player/` sin tag y no encontraba ruta.
 *
 * Sin `#` no hay nada que codificar, asi que el problema no puede reaparecer.
 */
const tagParam = (tag) =>
  encodeURIComponent(String(tag || '').trim().toUpperCase().replace(/^#/, ''));

export function fetchClan(tag) {
  return getJson(`/clan/${tagParam(tag)}`);
}

export function fetchPlayer(tag) {
  return getJson(`/player/${tagParam(tag)}`);
}

export function fetchCurrentWar(clanTag) {
  return getJson(`/clan/${tagParam(clanTag)}/currentwar`);
}
