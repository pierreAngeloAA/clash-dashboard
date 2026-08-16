# CLAUDE.md

Guía para Claude Code (claude.ai/code) al trabajar en este repositorio.

El código, los comentarios y los mensajes de commit están **en español**. Seguir
esa convención, incluidos los mensajes de error que ve el usuario final.

## Qué es

Dashboard del progreso de varias cuentas de Clash of Clans. Nació leyendo un
Google Sheet desde el navegador; hoy **la fuente de verdad es PostgreSQL** y el
Sheet quedó atrás.

Dos carpetas hermanas:

| Carpeta     | Qué es                      | Puerto |
|-------------|-----------------------------|--------|
| `frontend/` | React + Vite + Tailwind     | 5173   |
| `backend/`  | API en Rails 8 + PostgreSQL | 3000   |

Hubo una tercera, `coc-proxy/` (Express), que se borró en 254f352: el proxy hacia
la API de Clash vive ahora dentro de Rails.

## Comandos

Todo corre en Docker. El stack levanta con `docker compose up`.

```bash
docker compose up -d --build            # levantar todo
docker compose exec frontend npm test   # Vitest  (26 ejemplos)
docker compose exec frontend npm run build
docker compose exec -e RAILS_ENV=test backend bundle exec rspec   # 221 ejemplos
docker compose exec backend ./bin/rails sheet:importar            # importar el Sheet
```

Para entrar al panel hace falta un usuario, que **no tiene registro público**:

```bash
docker compose exec -e ADMIN_EMAIL=vos@ejemplo.com -e ADMIN_PASSWORD=... \
  backend ./bin/rails db:seed
```

La contraseña necesita 12 caracteres como mínimo.

## Arquitectura

El navegador habla **solo con Rails**. Rails habla con PostgreSQL y con la API
oficial de Clash.

```
navegador → /api/v1/*  →  Rails ──→ PostgreSQL
                              └───→ api.clashofclans.com
```

El token de Clash nunca llega al navegador: está atado a una IP, así que vive
solo en el servidor. En desarrollo, Vite hace de proxy de `/api` hacia Rails.

### Los datos

El Google Sheet se importa **una vez** con `rails sheet:importar` (idempotente) y
después no se vuelve a mirar. Reimportar no pisa lo que ya se sincronizó con la
API ni lo que se corrigió a mano.

El progreso se modela como catálogo del juego (`GameItem`) más el inventario de
cada cuenta (`AccountItem`, con subclases por sección: `Heroe`, `Defensa`,
`TropaClara`…). `Account#poblar_inventario` genera los elementos que habilita el
ayuntamiento de la cuenta; subir de ayuntamiento vuelve a poblarlo.

**El report no se guarda.** `ReportCalculator` lo recalcula a demanda desde el
progreso: almacenarlo obligaría a recalcular en cada edición y un solo olvido
dejaría la base mintiendo.

### Sesión

Devise + `devise-jwt`, con revocación por JTIMatcher: al cerrar sesión se rota el
`jti` del usuario y el token anterior deja de validar.

- El token viaja en el header `Authorization`, ya con prefijo `Bearer`. Se guarda
  tal cual llega y se reenvía igual.
- Del lado del cliente vive en `localStorage` (clave `clash-dashboard:token`).
  Sobrevive a recargar la página, a costa de quedar al alcance del JavaScript de
  la página.
- Dura 12 horas. `frontend/src/services/http.js` borra el token y avisa ante
  **cualquier 401**, salvo en el propio login, donde un 401 significa
  "credenciales inválidas" y no "sesión vencida".
- Tener token guardado **no** es estar logueado: al arrancar, `AuthContext` le
  pregunta a `/api/v1/me`.
- **Leer es público, escribir exige sesión.** El dashboard era público cuando
  leía un Sheet compartido y se mantuvo así.

## Convenciones

- **Claves del JSON mezcladas.** Los serializers devuelven `nombre` y `secciones`
  junto a `currentLevel` y `maxLevel`. Los nombres en inglés vienen de la época
  del Sheet y renombrarlos obligaría a tocar los componentes sin ganar nada.
- **`frontend/src/services/http.js` es el único lugar** donde se arma un `fetch`:
  ahí se decide la URL base, cómo viaja el token y cómo un error del backend se
  convierte en el mensaje que se muestra en pantalla.
- Los mensajes de error de la API van en español (`JsonFailureApp`,
  `ApplicationController#no_encontrado`).

## Cosas que muerden

- **PostgreSQL se publica en el 5433**, no en el 5432, porque esta máquina corre
  un PostgreSQL 16 nativo.
- **Hay dos Dockerfiles en `backend/`.** El `Dockerfile` es el de producción que
  genera Rails y omite el grupo `development` del Gemfile: sin `Dockerfile.dev`
  no habría rspec ni debug.
- **El volumen `bundle_cache` puede quedar viejo.** Si el `Gemfile` suma gemas, el
  bind mount tapa lo que instaló la imagen y Rails no arranca
  (`Bundler::GemNotFound`). Se arregla con
  `docker compose run --rm --no-deps backend bundle install`.
- **Vite cachea los módulos.** Después de cambiar los `export` de un servicio
  puede seguir sirviendo la versión anterior y tirar un `SyntaxError` de export
  inexistente. Se arregla con `docker compose restart frontend`.
- **El bind mount se puede quedar con una copia vieja.** Pasó con
  `config/routes.rb`: el archivo estaba editado en el disco pero el contenedor
  seguía viendo el anterior, y la ruta nueva daba 404 sin ninguna otra señal. Si
  un cambio no aparece, comparar antes de dudar del código:
  `md5sum backend/config/routes.rb` contra
  `docker compose exec backend md5sum config/routes.rb`. Se arregla reiniciando
  el servicio.
- **No existe `backend/config/master.key`.** Se sacó del repo y se rotó en
  90bece5, así que `credentials.yml.enc` no se puede desencriptar. En producción
  hay que definir `SECRET_KEY_BASE` por variable de entorno.
- **`COC_TOKEN` está atado a una IP.** Si la API responde 403
  `accessDenied.invalidIp`, hay que declarar la IP actual en
  https://developer.clashofclans.com/. La IP pública se ve con
  `curl -s https://api.ipify.org`. Sin token, `Clash::Cliente` degrada a 503 con
  un mensaje explicándolo; el resto de la app funciona igual.
- **El nodo del host es viejo.** `npm test` fuera de Docker falla con
  `webidl.util.markAsUncloneable is not a function`: Vite 8 y jsdom piden Node 22
  y el host tiene 20. Correr los tests dentro del contenedor.

## Estado

- Ramas: se trabaja en `staging` y se mergea a `main` por PR. El CI corre tests
  y build de las dos puntas más Brakeman.
- **Producción**: hay un despliegue viejo en Render que sirve la versión anterior
  a la base de datos (Express + lectura del Sheet desde el navegador). Migrarlo
  al stack actual es el issue #7.
- Las tareas pendientes viven en los issues de GitHub y en el tablero
  https://github.com/users/pierreAngeloAA/projects/1
