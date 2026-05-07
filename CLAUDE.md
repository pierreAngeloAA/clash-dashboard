# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
npm install                  # install frontend deps (root) — server has its own
npm install --prefix server  # install proxy deps

npm run dev                  # frontend (Vite) on :5173, opens browser
npm run dev:server           # CoC proxy (node --watch) on :3001
npm run build                # production build to dist/
npm run preview              # serve the built bundle
```

There is no test runner and no linter configured. A typical dev session runs **two terminals**: `npm run dev:server` and `npm run dev`. Vite proxies `/api/*` to the Node server (see `vite.config.js`).

## Architecture

This is a **React + Vite + Tailwind** dashboard with **two independent data sources** living side-by-side:

### 1. Google Sheets (no auth) — routes `/` and `/user/:id`

`src/services/sheetsService.js` hits the public **gviz endpoint** (`/spreadsheets/{id}/gviz/tq?tqx=out:json&gid=...`). The response is wrapped in `/*O_o*/google.visualization.Query.setResponse({...})`; we slice from the first `{` to the last `}` and `JSON.parse` the middle. `gvizToRecords` flattens the table assuming row-1 = headers; if gviz fails to detect labels it falls back to the first data row. Records are cached in `localStorage` for 5 min (key `clash-sheet:{ID}:{GID}`).

`src/hooks/useFilteredUsers.js → detectColumns` does **fuzzy header matching** (`name/nombre`, `clan/guild`, `trophies/level/puntos/...`) so the dashboard adapts to whatever columns the Sheet has. Don't hardcode column names; pass through `detected.{nameKey,clanKey,metricKey}`.

The current Sheet flattening assumes one flat table per tab. Real member tabs in this Sheet are **multi-block layouts** (defensas, tropas, héroes, REPORT, etc. side-by-side); the current parser does **not** understand that structure.

### 2. Clash of Clans official API — routes `/clan` and `/player/:tag`

The CoC API requires a **JWT token bound to specific IPs**, so it can't be called from the browser. The `server/` directory holds a tiny Express proxy that:

- Reads `COC_TOKEN` from `server/.env` (gitignored).
- Exposes `/api/clan/:tag`, `/api/player/:tag`, `/api/clan/:tag/currentwar`, `/api/health`, `DELETE /api/cache`.
- `/api/clan/:tag` does a **fan-out**: 1 call to `/clans/{tag}` then `Promise.all` over `memberList` to enrich each member with `/players/{tag}`.
- In-memory cache (10 min default, `CACHE_TTL_MS`) plus an **in-flight map** that deduplicates concurrent requests for the same path.
- Tags are normalized: leading `#` is added if missing, then URL-encoded once.

Frontend never talks to `api.clashofclans.com` directly — `src/services/cocService.js` only calls `/api/*`. Vite's dev proxy forwards to `:3001`; in production these have to be co-deployed or the frontend pointed at the proxy URL.

`src/pages/PlayerDetail.jsx` groups troops into `normal / super / siege` heuristically by name (the API has no flag for this) and computes `% maxed` per section as the average of `level / maxLevel`.

**Limits of the official API** (drives architecture decisions): the API does **not** expose individual defense buildings, traps, or walls. Anything beyond heroes/troops/spells/pets/equipment must come from the Sheet or from a future manual-entry path.

### Token / IP gotcha

If a request returns `403` with `accessDenied.invalidIp`, the developer's outbound IP doesn't match what's whitelisted on the token in https://developer.clashofclans.com/. The token has to be re-issued with the new IP. Get current public IP with `curl -s https://api.ipify.org`.

## Routing

`src/App.jsx` mounts:

| Path             | Page              | Source           |
|------------------|-------------------|------------------|
| `/`              | `Dashboard`       | Sheet            |
| `/user/:id`      | `UserDetail`      | Sheet            |
| `/clan`          | `ClanDashboard`   | API (via proxy)  |
| `/player/:tag`   | `PlayerDetail`    | API (via proxy)  |

The two halves don't share state. The Navbar's "Refrescar" button only clears the **Sheet** cache (`clearSheetCache`).

## Styling

Tailwind with a custom `brand` palette (blue) and a `card` shadow defined in `tailwind.config.js`. There's a `.btn-ghost` class used widely; keep buttons consistent with that look.
