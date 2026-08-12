import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// El build vive en el repo del frontend, que es una carpeta hermana. En Docker
// el frontend es otro contenedor y no hay dist que servir, por eso es opcional.
const DIST_DIR = process.env.DIST_DIR
  ? path.resolve(process.env.DIST_DIR)
  : path.resolve(__dirname, '../frontend/dist');

const PORT = Number(process.env.PORT) || 3001;
const COC_TOKEN = process.env.COC_TOKEN;
const CACHE_TTL_MS = Number(process.env.CACHE_TTL_MS) || 10 * 60 * 1000;
const BASE_URL = 'https://api.clashofclans.com/v1';

if (!COC_TOKEN) {
  console.error('[server] Falta COC_TOKEN en coc-proxy/.env');
  process.exit(1);
}

const app = express();
app.use(cors());

const cache = new Map();
const inflight = new Map();

const normalizeTag = (tag) => {
  if (!tag) return '';
  const clean = decodeURIComponent(String(tag)).trim().toUpperCase();
  return clean.startsWith('#') ? clean : `#${clean}`;
};

const encodeTag = (tag) => encodeURIComponent(normalizeTag(tag));

async function cocFetch(path) {
  const cached = cache.get(path);
  if (cached && Date.now() - cached.ts < CACHE_TTL_MS) {
    return cached.data;
  }
  if (inflight.has(path)) {
    return inflight.get(path);
  }

  const promise = (async () => {
    const res = await fetch(`${BASE_URL}${path}`, {
      headers: {
        Authorization: `Bearer ${COC_TOKEN}`,
        Accept: 'application/json',
      },
    });
    const text = await res.text();
    let body;
    try {
      body = text ? JSON.parse(text) : null;
    } catch {
      body = { raw: text };
    }
    if (!res.ok) {
      const err = new Error(body?.message || body?.reason || `CoC API ${res.status}`);
      err.status = res.status;
      err.body = body;
      throw err;
    }
    cache.set(path, { ts: Date.now(), data: body });
    return body;
  })();

  inflight.set(path, promise);
  try {
    return await promise;
  } finally {
    inflight.delete(path);
  }
}

app.get('/api/health', (_req, res) => {
  res.json({ ok: true, cacheSize: cache.size });
});

app.get('/api/clan/:tag', async (req, res) => {
  try {
    const tag = encodeTag(req.params.tag);
    const clan = await cocFetch(`/clans/${tag}`);
    const players = await Promise.all(
      (clan.memberList || []).map((m) =>
        cocFetch(`/players/${encodeTag(m.tag)}`).catch((err) => ({
          __error: true,
          tag: m.tag,
          status: err.status || 500,
          message: err.message,
        }))
      )
    );
    res.json({ clan, players });
  } catch (err) {
    res.status(err.status || 500).json({ error: err.message, body: err.body });
  }
});

app.get('/api/player/:tag', async (req, res) => {
  try {
    const data = await cocFetch(`/players/${encodeTag(req.params.tag)}`);
    res.json(data);
  } catch (err) {
    res.status(err.status || 500).json({ error: err.message, body: err.body });
  }
});

app.get('/api/clan/:tag/currentwar', async (req, res) => {
  try {
    const data = await cocFetch(`/clans/${encodeTag(req.params.tag)}/currentwar`);
    res.json(data);
  } catch (err) {
    res.status(err.status || 500).json({ error: err.message, body: err.body });
  }
});

app.delete('/api/cache', (_req, res) => {
  cache.clear();
  res.json({ ok: true });
});

// En producción servimos el build del frontend desde el mismo proceso.
// El SPA fallback manda cualquier ruta no-/api a index.html para que el
// router del cliente la maneje.
//
// En desarrollo quien sirve el frontend es Vite, y montar el fallback sin dist
// haria que toda ruta no-/api respondiera un error de sendFile en vez de un 404
// honesto. Por eso solo se registra si el build existe.
if (fs.existsSync(path.join(DIST_DIR, 'index.html'))) {
  app.use(express.static(DIST_DIR));
  app.get(/^(?!\/api).*/, (_req, res) => {
    res.sendFile(path.join(DIST_DIR, 'index.html'));
  });
  console.log(`[server] sirviendo el build del frontend desde ${DIST_DIR}`);
} else {
  console.log('[server] sin build del frontend: solo se exponen las rutas /api');
}

app.listen(PORT, () => {
  console.log(`[server] escuchando en puerto ${PORT}`);
});
