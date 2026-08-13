import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Todo /api va al backend de Rails: las cuentas y tambien la API de Clash, que
// antes atendia un proxy Express aparte. Fuera de Docker corre en la misma
// maquina; dentro de compose hay que apuntar al nombre del servicio.
const PROXY_TARGET = process.env.VITE_PROXY_TARGET || 'http://localhost:3000';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // Dentro de un contenedor no hay navegador que abrir: el intento ensucia
    // los logs con un error de xdg-open.
    open: process.env.VITE_OPEN !== 'false',
    proxy: {
      '/api': {
        target: PROXY_TARGET,
        changeOrigin: true,
      },
    },
  },
  test: {
    environment: 'jsdom',
    include: ['src/**/*.spec.js'],
  },
});
