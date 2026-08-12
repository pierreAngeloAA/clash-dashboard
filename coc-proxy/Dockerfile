# Proxy hacia la API oficial de Clash of Clans.
# Existe porque el token de la API va atado a una IP y no puede viajar al
# navegador: el frontend solo habla con este servicio.
FROM node:22-slim

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

EXPOSE 3001

# node --watch reinicia el proceso al guardar, igual que en local.
CMD ["npm", "run", "dev"]
