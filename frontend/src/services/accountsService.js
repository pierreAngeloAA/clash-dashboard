/**
 * Las cuentas y su progreso, leidos de la base.
 *
 * Reemplaza al viejo sheetsService, que parseaba el HTML del Google Sheet
 * desde el navegador. Esa data ya vive en PostgreSQL (`rails sheet:importar`)
 * y la base es ahora la fuente de verdad: el Sheet no se vuelve a mirar.
 *
 * Tampoco hay cache en localStorage. Existia porque cada pantalla implicaba
 * bajar y parsear el Sheet entero; contra la API propia la respuesta ya viene
 * armada, y cachear solo serviria para mostrar niveles viejos despues de
 * editarlos.
 */

import { getJson, sendJson } from './http';

// Una fila por cuenta, con el porcentaje de progreso ya calculado: es lo que
// pinta las tarjetas del dashboard.
export async function fetchAccountList() {
  const { accounts } = await getJson('/accounts');

  return accounts;
}

// Todo lo de una cuenta en una sola peticion: { account, secciones, report }.
// Antes eran dos lecturas distintas del Sheet, una para el REPORT y otra para
// el desglose; el backend arma las dos cosas de la misma consulta.
export function fetchAccount(id) {
  return getJson(`/accounts/${id}`);
}

/**
 * Alta de una cuenta. Exige sesion.
 *
 * No se le pasa inventario: al crearla, el backend le genera los elementos que
 * su ayuntamiento habilita. `gid_origen` tampoco, que lo escribe el importador
 * del Sheet para saber de que pestaña vino y no es un dato que se edite.
 */
export async function createAccount(datos) {
  const { body } = await sendJson('/accounts', 'POST', { account: datos });

  return body.account;
}

/**
 * Edicion de una cuenta. Exige sesion.
 *
 * Cambiar el ayuntamiento no es un cambio cosmetico: el backend vuelve a poblar
 * el inventario, agregando lo que el nivel nuevo habilita y subiendo el tope de
 * lo que ya estaba.
 */
export async function updateAccount(id, datos) {
  const { body } = await sendJson(`/accounts/${id}`, 'PATCH', { account: datos });

  return body.account;
}

// Se lleva puesto el progreso de la cuenta, no solo la fila.
export async function deleteAccount(id) {
  await sendJson(`/accounts/${id}`, 'DELETE');
}

/**
 * Trae el progreso real desde la API oficial de Clash y lo aplica. Exige sesion
 * y que la cuenta tenga tag.
 *
 * Devuelve `{ resumen, account }`. El resumen importa tanto como el resultado:
 * la API no expone defensas ni trampas, y el catalogo todavia tiene elementos
 * sin mapear al nombre en ingles, asi que una sincronizacion normal deja mucho
 * sin tocar. Decir solo "listo" ocultaria eso.
 */
export async function syncAccount(id) {
  const { body } = await sendJson(`/accounts/${id}/sincronizar`, 'POST');

  return body;
}

/**
 * Corrige a mano el progreso de un elemento. Exige sesion.
 *
 * El elemento se pide dentro de su cuenta y no por su id suelto: es como lo
 * busca el backend, que con el id global se podria editar el elemento de otra
 * cuenta.
 *
 * `fuente` no se manda nunca: si alguien edita el nivel a mano, el dato es
 * manual por definicion y eso lo decide el backend.
 */
export async function updateAccountItem(accountId, itemId, cambios) {
  const { body } = await sendJson(
    `/accounts/${accountId}/items/${itemId}`,
    'PATCH',
    { item: cambios }
  );

  return body.item;
}
