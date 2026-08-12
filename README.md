# Clash Dashboard

Monorepo con tres piezas independientes, cada una en su carpeta:

| Carpeta      | Qué es                              | Puerto | Detalle |
|--------------|-------------------------------------|--------|---------|
| `frontend/`  | React + Vite + Tailwind             | 5173   | [README](frontend/README.md) |
| `backend/`   | API en Rails 8 + PostgreSQL         | 3000   | Devise + JWT, `/api/v1/*` |
| `coc-proxy/` | Proxy Node/Express a la API de CoC  | 3001   | Guarda el `COC_TOKEN`, que va atado a una IP |

El proxy existe aparte del backend porque el token de la API oficial de Clash of
Clans no puede viajar al navegador. El frontend nunca llama a
`api.clashofclans.com` directamente.

## Levantar todo con Docker

```bash
cp coc-proxy/.env.example coc-proxy/.env   # pegá tu COC_TOKEN
docker compose up
```

Queda el frontend en <http://localhost:5173>, la API de Rails en
<http://localhost:3000> y el proxy en <http://localhost:3001>.

Las tres carpetas se montan como volumen, así que **editar código recarga solo**:
no hace falta reconstruir salvo que cambien las dependencias
(`package.json` o `Gemfile`), y en ese caso:

```bash
docker compose up --build
```

PostgreSQL se publica en el **5433** del host, no en el 5432, para no chocar con
un PostgreSQL instalado de forma nativa. Los datos viven en el volumen `db_data`;
para empezar de cero: `docker compose down -v`.

## Levantar sin Docker

Cada servicio en su terminal:

```bash
npm install --prefix frontend && npm run dev --prefix frontend    # :5173
npm install --prefix coc-proxy && npm run dev --prefix coc-proxy  # :3001
cd backend && bundle install && bin/rails db:prepare && bin/rails server  # :3000
```

El frontend necesita **Node 22 o superior** (lo exige Vite 8). El backend,
Ruby 3.3.5 y un PostgreSQL accesible.

## Tests

```bash
npm test --prefix frontend   # Vitest sobre los servicios de datos
cd backend && bundle exec rspec
```
