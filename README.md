# Clash Dashboard

Panel para seguir el progreso de varias cuentas de Clash of Clans: qué nivel
tiene cada defensa, tropa, héroe y hechizo, y cuánto falta para el máximo.

Empezó leyendo un Google Sheet desde el navegador. Hoy **la fuente de verdad es
PostgreSQL**: el Sheet se importó una vez y no se vuelve a mirar.

| Carpeta     | Qué es                       | Puerto | Detalle |
|-------------|------------------------------|--------|---------|
| `frontend/` | React + Vite + Tailwind      | 5173   | [README](frontend/README.md) |
| `backend/`  | API en Rails 8 + PostgreSQL  | 3000   | Devise + JWT, `/api/v1/*` |

## Cómo está armado

El navegador habla **solo con Rails**. Rails habla con PostgreSQL y con la API
oficial de Clash.

```
navegador ──→ /api/v1/*  ──→  Rails ──→ PostgreSQL
                                 └────→ api.clashofclans.com
```

El token de la API oficial **nunca llega al navegador**: está atado a una IP, así
que vive solo en el servidor. En desarrollo, Vite hace de proxy de `/api` hacia
Rails; en producción lo resuelve un rewrite.

**Leer es público, escribir exige sesión.** El dashboard era público cuando leía
un Sheet compartido y se mantuvo así.

## Levantar todo

```bash
cp .env.example .env   # opcional: pegá tu COC_TOKEN
docker compose up
```

Frontend en <http://localhost:5173>, API en <http://localhost:3000>.

Las dos carpetas se montan como volumen, así que **editar código recarga solo**.
Solo hace falta reconstruir si cambian las dependencias (`package.json` o
`Gemfile`), y en ese caso `docker compose up --build`.

PostgreSQL se publica en el **5433** del host, no en el 5432, para no chocar con
un PostgreSQL instalado de forma nativa. Los datos viven en el volumen `db_data`;
para empezar de cero, `docker compose down -v`.

## Cargar los datos

La base arranca vacía. El Google Sheet se importa una sola vez:

```bash
docker compose exec backend ./bin/rails sheet:importar
```

Trae una cuenta por pestaña, el catálogo del juego y el progreso de cada cuenta.
Es idempotente, y reimportar no pisa lo que ya se sincronizó con la API ni lo que
se corrigió a mano.

Para entrar al panel hace falta un usuario, que **no tiene registro público**:

```bash
docker compose exec -e ADMIN_EMAIL=vos@ejemplo.com -e ADMIN_PASSWORD=... \
  backend ./bin/rails db:seed
```

La contraseña necesita 12 caracteres como mínimo.

## Qué se puede hacer con sesión iniciada

- **Corregir niveles** desde el detalle de una cuenta. Lo editado a mano queda
  marcado como manual, y el candado lo protege de que la sincronización lo pise.
- **Dar de alta, editar y borrar cuentas.** Al crear una, el inventario se genera
  a partir del catálogo y del ayuntamiento; subir de ayuntamiento lo repuebla.
  Borrar se lleva puesto todo el progreso de esa cuenta.
- **Sincronizar con la API oficial**, si la cuenta tiene tag cargado.

## Sincronización con la API oficial

```bash
docker compose exec backend ./bin/rails clash:sincronizar        # todas
docker compose exec backend ./bin/rails 'clash:sincronizar[#TAG]'  # una
```

Alcanza a héroes, tropas, hechizos, máquinas de asedio, mascotas y equipamiento.
**Las defensas, las trampas y los muros no**: la API oficial no los expone, así
que siguen siendo carga manual. Tampoco toca lo que tiene candado.

El catálogo salió del Sheet en español y la API responde en inglés, así que hace
falta un puente: `backend/db/nombres_api.yml`, que se aplica con
`bin/rails clash:mapear`. Los nombres que faltan se sacan de un jugador real con
`bin/rails 'clash:nombres[#TAG]'`, que imprime los que devuelve la API y marca
los ya mapeados. **Adivinarlos es mala idea**: un nombre mal escrito no da error,
deja ese elemento sin sincronizar para siempre.

### El token

Es opcional: sin él funciona todo salvo la búsqueda de clan y jugador, que
responde 503 explicando que falta.

Se genera en <https://developer.clashofclans.com/> y **queda atado a la IP
pública desde la que se consulta**. Si la IP cambia, la API responde 403
`accessDenied.invalidIp` y hay que declarar la nueva. La IP actual se ve con
`curl -s https://api.ipify.org`.

## Levantar sin Docker

```bash
npm install --prefix frontend && npm run dev --prefix frontend           # :5173
cd backend && bundle install && bin/rails db:prepare && bin/rails server # :3000
```

El frontend necesita **Node 22 o superior** (lo exige Vite 8). El backend,
Ruby 3.3.5 y un PostgreSQL accesible.

## Tests

```bash
docker compose exec frontend npm test                                # 39, Vitest
docker compose exec -e RAILS_ENV=test backend bundle exec rspec      # 241, RSpec
```

Los del frontend conviene correrlos **dentro del contenedor**: fuera fallan si la
máquina tiene Node 20, porque Vite 8 y jsdom piden 22.

## Deploy

`render.yaml` describe los tres servicios en Render: PostgreSQL, la API como
servicio Docker y el frontend como sitio estático con un rewrite de `/api`.

Todavía no está aplicado: lo que hay publicado es una versión anterior a la base
de datos. Ver el issue #7.

Dos cosas para tener en cuenta al desplegar:

- **No sobreescribir el comando del contenedor.** El entrypoint corre
  `db:prepare` solo cuando los dos últimos argumentos son `./bin/rails server`,
  que es el `CMD` por defecto. Cambiarlo deja la base sin migrar. El puerto se
  ajusta con `HTTP_PORT`.
- **`SECRET_KEY_BASE` va por variable de entorno**, no `RAILS_MASTER_KEY`: la
  master key se sacó del repo y se rotó, así que `credentials.yml.enc` no se
  puede desencriptar.

## Decisiones que a alguien que llega le van a resultar raras

- **El report no se guarda.** Se recalcula a demanda desde el progreso.
  Almacenarlo obligaría a recalcular en cada edición y en cada sincronización, y
  un solo olvido dejaría la base mintiendo.
- **El token de sesión vive en `localStorage`.** Así la sesión sobrevive a
  recargar la página, a costa de quedar al alcance del JavaScript de la página.
  La alternativa sería una cookie `httpOnly`, y eso cambia el backend: hoy
  `devise-jwt` entrega el token por el header `Authorization`.
- **Hay dos Dockerfiles en `backend/`.** El `Dockerfile` es el de producción que
  genera Rails y omite el grupo `development` del Gemfile; sin `Dockerfile.dev`
  no habría rspec ni debug.
- **Las claves del JSON mezclan idiomas.** Los serializers devuelven `nombre` y
  `secciones` junto a `currentLevel` y `maxLevel`. Los nombres en inglés vienen
  de la época del Sheet y renombrarlos obligaría a tocar los componentes sin
  ganar nada.
