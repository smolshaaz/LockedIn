FROM oven/bun:1.3.10-alpine

WORKDIR /app/backend

COPY backend/package.json backend/bun.lock ./
RUN bun install --frozen-lockfile

COPY backend/ ./

ENV NODE_ENV=production
EXPOSE 3000

CMD ["bun", "run", "start"]
