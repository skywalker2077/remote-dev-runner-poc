# syntax=docker/dockerfile:1

# Stage 1 — deps
FROM node:18-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

# Stage 2 — runtime
FROM node:18-alpine AS runtime
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY src/ ./src/
COPY package.json ./
EXPOSE 3000
USER node
CMD ["node", "src/index.js"]
