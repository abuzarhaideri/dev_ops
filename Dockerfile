# =============================================================================
# ShopSmart Backend — Multi-Stage Dockerfile
# Requirements: Multi-stage build, Non-root user, Healthcheck
# =============================================================================

# ---------------------
# Stage 1: Frontend Builder
# ---------------------
FROM node:20-alpine AS frontend-builder
WORKDIR /app/client
COPY client/package*.json ./
RUN npm ci
COPY client/ ./
RUN npm run build

# ---------------------
# Stage 2: Backend Builder
# ---------------------
FROM node:20-alpine AS builder
WORKDIR /app
COPY server/package*.json ./
RUN npm ci --only=production
COPY server/ ./
RUN npx prisma generate

# ---------------------
# Stage 3: Production
# ---------------------
FROM node:20-alpine AS production

# Install dependencies needed for Prisma and healthcheck
RUN apk add --no-cache wget openssl

# Create non-root user and group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy built application from builder stage
COPY --from=builder /app /app

# Copy built frontend files to public directory
COPY --from=frontend-builder /app/client/dist /app/public

# Ensure the prisma directory exists for the SQLite database and fix permissions for everything
RUN mkdir -p /app/prisma && chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose the application port
EXPOSE 5001

# Set environment variables
ENV PORT=5001
ENV NODE_ENV=production
ENV DATABASE_URL=file:/app/prisma/dev.db

# Healthcheck — verifies the service is running
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:5001/api/health || exit 1

# Start the application: Run migrations then start the server
# Using the direct path to prisma binary for better reliability
CMD ./node_modules/.bin/prisma migrate deploy && node src/index.js
