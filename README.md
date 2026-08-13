# Clash Dashboard

Monorepo con dos piezas independientes, cada una en su carpeta:

| Carpeta     | Qué es                       | Puerto | Detalle |
|-------------|------------------------------|--------|---------|
| `frontend/` | React + Vite + Tailwind      | 5173   | [README](frontend/README.md) |
| `backend/`  | API en Rails 8 + PostgreSQL  | 3000   | Devise + JWT, `/api/v1/*` |

El backend guarda el progreso de las cuentas y además es la única puerta a la
API oficial de Clash of Clans: su token va atado a una IP y no puede viajar al
navegador, así que el frontend nunca llama a `api.clashofclans.com` directamente.

## Levantar todo con Docker

```bash
cp .env.example .env   # opcional: pegá tu COC_TOKEN
docker compose up
```

Queda el frontend en <http://localhost:5173> y la API en
<http://localhost:3000>.

El `COC_TOKEN` es opcional: sin él funciona todo salvo la consulta de clan y
jugador, que responde 503 explicando que falta. El token se genera en
<https://developer.clashofclans.com/> y hay que declarar ahí la IP pública desde
la que se consulta.

Las dos carpetas se montan como volumen, así que **editar código recarga solo**:
no hace falta reconstruir salvo que cambien las dependencias
(`package.json` o `Gemfile`), y en ese caso:

```bash
docker compose up --build
```

PostgreSQL se publica en el **5433** del host, no en el 5432, para no chocar con
un PostgreSQL instalado de forma nativa. Los datos viven en el volumen `db_data`;
para empezar de cero: `docker compose down -v`.

## Cargar los datos

La base arranca vacía. El Google Sheet que se usaba antes se importa una vez:

```bash
docker compose exec backend ./bin/rails sheet:importar
```

Trae una cuenta por pestaña, el catálogo del juego y el progreso de cada cuenta.
Es idempotente. A partir de ahí la fuente de verdad es la base: el Sheet no se
vuelve a mirar, y reimportar no pisa lo que ya se sincronizó con la API ni lo
que se corrigió a mano.

Para entrar al panel hace falta un usuario, que no tiene registro público:

```bash
docker compose exec -e ADMIN_EMAIL=vos@ejemplo.com -e ADMIN_PASSWORD=... \
  backend ./bin/rails db:seed
```

## Levantar sin Docker

Cada servicio en su terminal:

```bash
npm install --prefix frontend && npm run dev --prefix frontend           # :5173
cd backend && bundle install && bin/rails db:prepare && bin/rails server # :3000
```

El frontend necesita **Node 22 o superior** (lo exige Vite 8). El backend,
Ruby 3.3.5 y un PostgreSQL accesible.

## Tests

```bash
npm test --prefix frontend   # Vitest sobre los servicios de datos
cd backend && bundle exec rspec
```
