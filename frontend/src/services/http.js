/**
 * El unico lugar donde se decide como se le habla al backend: donde vive la
 * API y como se convierte una respuesta con error en una excepcion.
 *
 * El mensaje importa: los hooks lo muestran tal cual en pantalla, asi que
 * cuando Rails explica el fallo se usa lo que mando, y solo si no dijo nada se
 * cae al status.
 */

const BASE = '/api/v1';

export async function getJson(path) {
  const res = await fetch(`${BASE}${path}`);
  const body = await res.json().catch(() => ({}));

  if (!res.ok) {
    throw new Error(body?.error || `Error ${res.status} desde el backend.`);
  }

  return body;
}
