/**
 * Sesion contra Rails: Devise + JWT.
 *
 * El token no viene en el cuerpo sino en el header Authorization de la
 * respuesta al login, ya con el prefijo "Bearer". Se guarda tal cual llega y se
 * reenvia igual, para no tener que rearmar el prefijo en cada peticion.
 *
 * No hay registro publico: los usuarios los crea un superadmin.
 */

import { borrarToken, getJson, guardarToken, sendJson } from './http';

export async function login(email, password) {
  // Devise espera las credenciales anidadas bajo el scope del modelo.
  const { body, res } = await sendJson(
    '/login',
    'POST',
    { user: { email, password } },
    { ignorar401: true }
  );

  const token = res.headers.get('Authorization');
  if (!token) {
    throw new Error('El backend no devolvio el token de sesion.');
  }

  guardarToken(token);

  return body.user;
}

/**
 * Cierra la sesion en el servidor, que rota el jti del usuario y con eso
 * invalida el token emitido.
 *
 * El token local se borra pase lo que pase: si la peticion falla porque el
 * token ya estaba vencido, dejarlo guardado seria peor que perderlo.
 */
export async function logout() {
  try {
    await sendJson('/logout', 'DELETE');
  } finally {
    borrarToken();
  }
}

// Con quien esta logueado se recupera la sesion despues de recargar la pagina,
// sin decodificar el token del lado del cliente.
export async function fetchCurrentUser() {
  const { user } = await getJson('/me');

  return user;
}
