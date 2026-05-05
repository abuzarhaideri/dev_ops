# =============================================================================
# ShopSmart Backend — Multi-Stage Dockerfile
# Requirements: Multi-stage build, Non-root user, Healthcheck
# =============================================================================

# ---------------------
# Stage 1: Builder
# ---------------------
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files and install production dependencies
COPY server/package*.json ./
RUN npm ci --only=production

# Copy server source code
COPY server/ .

# Generate Prisma client
RUN npx prisma generate

# ---------------------
# Stage 2: Production
# ---------------------
FROM node:20-alpine AS production

# Install dependencies needed for Prisma and healthcheck
RUN apk add --no-cache wget openssl

# Create non-root user and group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy built application from builder stage
COPY --from=builder /app ./

# Ensure the prisma directory exists for the SQLite database
RUN mkdir -p prisma && chown -R appuser:appgroup /app

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
