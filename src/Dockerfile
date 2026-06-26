# syntax=docker/dockerfile:1

# --- Build stage ---
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY src/ ./src/

# --- Runtime stage ---
FROM node:18-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/src ./src
COPY package.json ./
EXPOSE 3000
USER node
CMD ["node", "src/index.js"]
