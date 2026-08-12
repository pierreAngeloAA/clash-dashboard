# Imagen de desarrollo: Vite en modo dev con hot reload.
# Node 22 porque Vite 8 lo exige (^22.13.0 || >=24).
FROM node:22-slim

WORKDIR /app

# Las dependencias se instalan antes de copiar el codigo para que editar un
# componente no invalide la capa de npm.
COPY package.json package-lock.json ./
RUN npm ci

COPY . .

EXPOSE 5173

# --host expone el server fuera del contenedor; sin eso Vite solo escucha en
# loopback y el puerto publicado no responde.
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
