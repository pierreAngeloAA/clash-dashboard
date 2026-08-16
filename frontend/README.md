# Frontend

React + Vite + TailwindCSS. Es la interfaz del panel; los datos salen todos de la
API en `backend/`. Para levantar el proyecto entero, ver el
[README de la raíz](../README.md).

> Este README describía una app **sin backend**, que leía un Google Sheet público
> desde el navegador. Eso dejó de ser cierto: el Sheet se importó a PostgreSQL y
> el navegador ya no le habla a Google.

## Levantar

Con Docker, desde la raíz, `docker compose up` levanta todo. Suelto:

```bash
npm install
npm run dev      # http://localhost:5173
```

Necesita **Node 22 o superior**: lo exige Vite 8.

```bash
npm run build    # bundle a dist/
npm run preview  # sirve el build
npm test         # Vitest
```

Los tests conviene correrlos dentro del contenedor (`docker compose exec frontend
npm test`): con Node 20 fallan con `webidl.util.markAsUncloneable is not a
function`, porque jsdom pide 22.

## Cómo se habla con el backend

`src/services/http.js` es **el único lugar donde se arma un `fetch`**. Ahí se
decide de dónde cuelga la API, cómo viaja el token y cómo un error del backend se
convierte en el mensaje que se muestra en pantalla.

En desarrollo, Vite redirige `/api` al backend en `:3000`
(`vite.config.js`), así que el navegador ve todo del mismo origen y CORS no entra
en juego. En producción lo resuelve un rewrite equivalente.

Rails contesta de dos formas según el fallo: un `error` suelto cuando la petición
no procede (401, 404) y un `errors` con la lista de mensajes cuando el dato no
sirve (422). Los dos vienen en español y con los nombres de los campos
traducidos, así que se muestran tal cual.

## Sesión

- El token llega en el header `Authorization` de la respuesta al login, ya con el
  prefijo `Bearer`. Se guarda tal cual y se reenvía igual.
- Vive en `localStorage`, bajo `clash-dashboard:token`.
- Dura 12 horas. **Cualquier 401 borra el token y cierra la sesión**, salvo en el
  propio login, donde un 401 significa "credenciales inválidas" y no "se te
  venció la sesión".
- **Tener token guardado no es estar logueado**: el token dice que *hubo* una
  sesión, no que siga viva. Al arrancar, `AuthContext` le pregunta a
  `/api/v1/me`. De ahí el estado `cargando`, sin el cual el navbar parpadearía
  mostrando "Login" en cada recarga.

No hay registro público: los usuarios los crea un superadmin con `db:seed`.

## Estructura

```
src/
├── components/
│   ├── AccountFormModal.jsx    # alta y edición de una cuenta
│   ├── CategoryDetailModal.jsx # desglose de una categoría, editable con sesión
│   ├── ClanSearchPanel.jsx     # búsqueda de clan (API oficial)
│   ├── PlayerSearchPanel.jsx   # búsqueda de jugador (API oficial)
│   ├── ErrorMessage.jsx  Loader.jsx  Modal.jsx  Navbar.jsx
├── context/
│   └── AuthContext.jsx         # quién está logueado, en toda la app
├── hooks/
│   ├── useAccount.js           # detalle de una cuenta + edición de niveles
│   ├── useAccountList.js       # la lista del dashboard
│   ├── useClan.js  usePlayer.js
├── pages/
│   ├── Dashboard.jsx           # las cuentas con su progreso
│   ├── Login.jsx
│   └── UserDetail.jsx          # una cuenta: categorías, totales, acciones
├── services/
│   ├── http.js                 # el único fetch
│   ├── accountsService.js      # cuentas, progreso y sincronización
│   ├── authService.js          # login, logout, /me
│   └── cocService.js           # API oficial, a través del backend
├── App.jsx  main.jsx  index.css
```

`useAccount` reemplazó a dos hooks separados (`useAccountReport` y
`useAccountDetails`). Eran dos porque el Sheet exponía el REPORT y el desglose en
dos lecturas distintas; el backend arma las dos cosas de la misma consulta.

## Editar el progreso

Con sesión, cada ítem del modal de categorías es editable.

- **Se guarda al salir del campo o con Enter**, no en cada tecla: escribir "12"
  pasa por "1", y guardar eso mandaría un nivel que nadie quiso.
- Si el backend lo rechaza, el campo vuelve al valor real en vez de quedarse
  mostrando algo que no está en la base.
- **El report se vuelve a pedir después de cada edición.** No está guardado: el
  backend lo recalcula a demanda, así que cambiar un nivel lo deja viejo. Esa
  recarga va en silencio, sin loader.
- Un poder de héroe aparece dos veces —suelto en `GUARDIANES` y colgado de su
  héroe—, así que al actualizar se reemplaza en los dos lados.

## Rutas

| Path          | Página      | Necesita sesión |
|---------------|-------------|-----------------|
| `/`           | Dashboard   | no |
| `/user/:id`   | UserDetail  | no para ver; sí para editar |
| `/login`      | Login       | — |

La búsqueda de clan y de jugador vive en el dashboard, como paneles en modal.

## Qué expone la API oficial y qué no

| Sección | ¿La API la trae? |
|---|---|
| Héroes, mascotas, equipamiento | Sí |
| Tropas, hechizos, máquinas de asedio | Sí |
| Donaciones, copas, war stars, guerra actual | Sí |
| **Defensas, trampas, muros** | **No** — carga manual |

Por eso el botón de sincronizar muestra un resumen y no un simple "listo": deja
sin tocar las defensas y las trampas, lo que tiene candado y lo que el catálogo
todavía no tiene mapeado al nombre en inglés.

## Si algo no anda

- **La pantalla queda en blanco y la consola dice `does not provide an export
  named ...`:** Vite está sirviendo una versión cacheada del módulo. Se arregla
  con `docker compose restart frontend`.
- **Un cambio no aparece por más que guardes:** el bind mount de Docker puede
  quedarse con una copia vieja. Comparar `md5sum` dentro y fuera del contenedor
  antes de dudar del código.
- **La búsqueda de clan o jugador da 503 o 403:** falta el `COC_TOKEN` o está
  registrado para otra IP. Ver el README de la raíz.
