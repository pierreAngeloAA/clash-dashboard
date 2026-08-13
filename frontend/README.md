# Clash Dashboard

Aplicación web moderna construida con **React + Vite + TailwindCSS** que consume datos
desde un Google Sheets público y los muestra como un dashboard de jugadores.

- Sin backend. Todo corre en el navegador.
- Búsqueda, filtro por rango numérico, ordenamiento y paginación.
- Vista de detalle por usuario con todas sus columnas.
- Cache en `localStorage` (5 minutos) para evitar re-fetch innecesarios.

## 1. Cómo se consume el Google Sheet

El proyecto usa el endpoint público `gviz` de Google Sheets, que no requiere
autenticación ni API key.

### Pasos para publicarlo

1. Abrí el Sheet → **Archivo → Compartir → Compartir con otras personas**.
2. En **Acceso general** elegí **"Cualquiera con el enlace" (Lector)**.
3. Tomá de la URL del navegador estos dos valores:
   - `SHEET_ID` → el bloque entre `/d/` y `/edit`.
   - `GID` → el número que aparece después de `#gid=`.

### Transformación del link

Pasás de la URL del navegador:

```
https://docs.google.com/spreadsheets/d/{SHEET_ID}/edit?gid={GID}#gid={GID}
```

A la URL del endpoint JSON `gviz`:

```
https://docs.google.com/spreadsheets/d/{SHEET_ID}/gviz/tq?tqx=out:json&gid={GID}
```

La respuesta llega envuelta en un wrapper:

```
/*O_o*/
google.visualization.Query.setResponse({ ...JSON... });
```

`src/services/sheetsService.js` recorta el wrapper y parsea el JSON con
`JSON.parse(text.slice(text.indexOf('{'), text.lastIndexOf('}') + 1))`.

### Cambiar el sheet usado

Editá las constantes `SHEET_ID` y `SHEET_GID` en `src/services/sheetsService.js`.

```js
export const SHEET_ID = '1gosF9F2mdWuQRH2ubcsc39WRy66x81K9UjRlFdwNbpo';
export const SHEET_GID = '840746911';
```

## 2. Cómo se actualizan los datos

- **Automático:** los datos se cachean en `localStorage` durante 5 minutos. Pasado
  ese tiempo, la siguiente carga vuelve a leer el Sheet.
- **Manual:** botón **"Refrescar"** en la barra superior. Limpia la caché y
  vuelve a leer el Sheet inmediatamente.
- **Cambios de columnas:** la app detecta dinámicamente los encabezados, así
  que si agregás o renombrás columnas en el Sheet, aparecen automáticamente
  como filtros y como campos en la vista de detalle. La detección de "Nombre",
  "Clan" y "Nivel/Puntos" se hace por nombre de columna (case-insensitive),
  ver `src/hooks/useFilteredUsers.js → detectColumns`.

## 3. Estructura del proyecto

```
src/
├── components/         # UI reutilizable
│   ├── ErrorMessage.jsx
│   ├── Filters.jsx
│   ├── Loader.jsx
│   ├── Navbar.jsx
│   ├── Pagination.jsx
│   ├── SearchBar.jsx
│   └── UserCard.jsx
├── hooks/
│   ├── useFilteredUsers.js   # search + sort + filter
│   └── useSheetData.js       # fetch + cache + loading/error
├── pages/
│   ├── Dashboard.jsx         # lista + controles
│   └── UserDetail.jsx        # ficha completa
├── services/
│   └── sheetsService.js      # fetch + parser gviz + cache
├── App.jsx                   # router + layout
├── main.jsx                  # entry point
└── index.css                 # tailwind base
```

## 4. Instalación

Requisitos: Node.js 18+ y npm.

```bash
npm install
```

## 5. Desarrollo

```bash
npm run dev
```

Abre http://localhost:5173 (Vite lo abre automáticamente).

## 6. Build de producción

```bash
npm run build
npm run preview   # sirve el build localmente
```

El bundle se genera en `dist/`.

## 7. Deploy en Vercel

### Opción A — Desde la web (más simple)

1. Subí el repo a GitHub/GitLab/Bitbucket.
2. Entrá a [vercel.com/new](https://vercel.com/new) y conectá el repo.
3. Vercel autodetecta Vite. Si no:
   - **Build command:** `npm run build`
   - **Output directory:** `dist`
   - **Install command:** `npm install`
4. Click en **Deploy**. Listo.

### Opción B — Desde la CLI

```bash
npm install -g vercel
vercel            # primer deploy (preview)
vercel --prod     # deploy a producción
```

### Notas

- No hace falta configurar variables de entorno: el Sheet es público.
- Como usamos `react-router-dom`, todas las rutas deben caer en `index.html`.
  Vercel ya hace eso por defecto en proyectos Vite, pero si lo movés a otro
  hosting (Netlify, S3, etc.) configurá un rewrite `/*  →  /index.html`.

## 8. Funcionalidad incluida

- [x] Fetch desde Google Sheets (gviz JSON, sin auth).
- [x] Listado tipo grilla de tarjetas con hover suave.
- [x] Vista de detalle (`/user/:id`) con todos los campos.
- [x] Buscador por nombre.
- [x] Filtro por rango (min / max) sobre cualquier columna numérica.
- [x] Ordenamiento ascendente / descendente por cualquier columna.
- [x] Paginación (12 por página).
- [x] Cache en `localStorage` con TTL de 5 min + botón de refresco manual.
- [x] Manejo de loading y errores.
- [x] Responsive (mobile + desktop).

## 9. Integración con la API oficial de Clash of Clans

Además del Sheet, el backend consume la API oficial
(`https://api.clashofclans.com/v1`) y la expone bajo `/api/v1/*`. Vite redirige
todo `/api` al backend en `:3000` durante el desarrollo.

**¿Por qué pasa por el backend?** Los tokens de la API están **ligados a IPs
concretas**, así que no se pueden poner en el navegador. El backend guarda el
token y solo expone JSON al frontend.

### Setup del token (una vez)

1. Registrate en https://developer.clashofclans.com/.
2. Averiguá la IP pública desde donde vas a correr el backend:
   ```bash
   curl -s https://api.ipify.org
   ```
3. En el portal: **My Account → Create New Key**. Pegá esa IP en *Allowed IP Addresses*.
4. Copiá el token JWT generado.
5. Creá `.env` en la raíz del repo a partir del ejemplo y pegá el token:
   ```bash
   cp .env.example .env
   # y editá COC_TOKEN=...
   ```

### Correr en desarrollo

Con Docker levanta todo junto:

```bash
docker compose up
```

Sin Docker, en dos terminales: `bin/rails server` en `backend/` y `npm run dev`
acá.

Abrí http://localhost:5173/clan e ingresá tu tag de clan (ej. `#2PP`).

Tip: si querés que cargue uno por defecto, definilo en `.env.local` del root:

```
VITE_DEFAULT_CLAN_TAG=#2PP
```

### Endpoints de Clash en el backend

| Método | Path                              | Devuelve                                         |
|--------|-----------------------------------|--------------------------------------------------|
| GET    | `/api/v1/clan/:tag`               | Clan + detalle de cada miembro (fan-out + caché) |
| GET    | `/api/v1/player/:tag`             | Detalle de un jugador                             |
| GET    | `/api/v1/clan/:tag/currentwar`    | Guerra actual                                     |
| GET    | `/api/v1/coc/health`              | Si hay token configurado                          |

El backend cachea cada consulta 10 minutos y pide los miembros del clan en
paralelo. Sin `COC_TOKEN` estos endpoints responden 503 explicando que falta;
el resto de la app no depende de ellos.

### Qué expone la API y qué no

| Sección           | API oficial |
|-------------------|-------------|
| Héroes, mascotas, equipamiento | Sí |
| Tropas / hechizos / máquinas de asedio | Sí |
| Donaciones, copas, war stars   | Sí |
| Guerra actual y warlog         | Sí |
| **Defensas, trampas, muros**   | **No** — siguen necesitando Sheet o entrada manual |

## 10. Troubleshooting

- **"No se pudo leer el Google Sheet (HTTP 401/403)":** el sheet no está
  compartido como público. Repetí el paso 1.
- **Veo columnas raras (`col_0`, `col_1`...):** la primera fila del sheet
  no tiene encabezados. Agregá una fila de cabecera con los nombres de columna.
- **No aparece el filtro/orden que esperaba:** los selects de "Ordenar" y
  "Filtrar columna" se construyen con todas las cabeceras del sheet, así
  que basta con ajustar la fila de encabezados.
