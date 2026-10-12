# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Serve stage
FROM pierrezemb/gostatic
COPY --from=builder /app/dist /srv/http/
CMD ["-port","8080","-https-promote", "-enable-logging"]
