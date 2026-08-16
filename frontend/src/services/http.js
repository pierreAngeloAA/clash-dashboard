/**
 * El unico lugar donde se decide como se le habla al backend: donde vive la
 * API, como viaja el token y como se convierte una respuesta con error en una
 * excepcion.
 *
 * El mensaje importa: los hooks lo muestran tal cual en pantalla, asi que
 * cuando Rails explica el fallo se usa lo que mando, y solo si no dijo nada se
 * cae al status.
 */

const BASE = '/api/v1';

// El token se guarda en localStorage para que la sesion sobreviva a recargar la
// pagina. Queda al alcance del JavaScript de la pagina, que es el costo de esta
// decision; la alternativa seria una cookie httpOnly, y eso cambia el backend:
// devise-jwt hoy emite el token en el header Authorization.
const CLAVE_TOKEN = 'clash-dashboard:token';

export function leerToken() {
  try {
    return localStorage.getItem(CLAVE_TOKEN);
  } catch {
    return null;
  }
}

export function guardarToken(token) {
  try {
    localStorage.setItem(CLAVE_TOKEN, token);
  } catch {
    /* localStorage lleno o deshabilitado */
  }
}

export function borrarToken() {
  try {
    localStorage.removeItem(CLAVE_TOKEN);
  } catch {
    /* noop */
  }
}

// El token dura 12 horas y puede haber sido revocado desde otra pestaña, asi
// que cualquier peticion puede volver 401 con la sesion ya vencida. Quien avisa
// es el transporte; quien decide que hacer es AuthContext, que se registra aca.
// Es un callback y no un import para no acoplar el transporte a React.
let alPerderLaSesion = null;

export function cuandoSePierdaLaSesion(callback) {
  alPerderLaSesion = callback;
}

/**
 * Rails contesta de dos formas segun el tipo de fallo: un `error` suelto cuando
 * la peticion no procede (401, 404), y un `errors` con la lista de mensajes de
 * validacion cuando el dato no sirve (422). Los dos casos ya vienen en español
 * y con los nombres de los campos traducidos, asi que se muestran tal cual.
 */
function mensajeDeError(body, status) {
  if (body?.error) return body.error;
  if (Array.isArray(body?.errors) && body.errors.length > 0) {
    return body.errors.join('. ');
  }

  return `Error ${status} desde el backend.`;
}

/**
 * Devuelve { body, res }. La respuesta cruda hace falta para el login, que lee
 * el token del header Authorization en vez del cuerpo.
 *
 * `ignorar401` es para el propio login: ahi un 401 significa "esas credenciales
 * no sirven", no "se te vencio la sesion", y avisar de una sesion perdida que
 * nunca existio solo confundiria.
 */
async function pedir(path, { ignorar401 = false, ...opciones } = {}) {
  const token = leerToken();

  const res = await fetch(`${BASE}${path}`, {
    ...opciones,
    headers: {
      ...(opciones.body ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: token } : {}),
      ...opciones.headers,
    },
  });

  const body = await res.json().catch(() => ({}));

  if (res.status === 401 && !ignorar401) {
    borrarToken();
    alPerderLaSesion?.();
  }

  if (!res.ok) {
    throw new Error(mensajeDeError(body, res.status));
  }

  return { body, res };
}

export async function getJson(path) {
  const { body } = await pedir(path);

  return body;
}

export async function sendJson(path, method, cuerpo, opciones = {}) {
  return pedir(path, {
    ...opciones,
    method,
    body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
  });
}
