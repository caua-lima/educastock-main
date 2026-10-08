# ── stage 1: build TypeScript ─────────────────────────────────────────────────
FROM node:20-slim AS builder
WORKDIR /app

COPY package*.json tsconfig.json ./
COPY src/ ./src/

RUN npm install && npm run build

# ── stage 2: imagem de produção ───────────────────────────────────────────────
FROM node:20-slim
WORKDIR /app

COPY package*.json ./
RUN npm install --omit=dev

COPY --from=builder /app/lib ./lib

ENV NODE_ENV=production
EXPOSE 8080

CMD ["node", "lib/index.js"]
