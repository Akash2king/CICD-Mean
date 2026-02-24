# ── Stage 1: Install production dependencies ──────────────────────────────────
FROM node:18-alpine AS deps
WORKDIR /app

# Copy manifests first for better layer cache reuse
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force


# ── Stage 2: Production image ──────────────────────────────────────────────────
FROM node:18-alpine AS production

# tini provides proper PID-1 signal handling inside Docker
RUN apk add --no-cache tini wget

# Create a non-root user/group
RUN addgroup -g 1001 -S nodejs \
 && adduser  -u 1001 -S nodeuser -G nodejs

WORKDIR /app

# Copy pruned node_modules from deps stage
COPY --from=deps --chown=nodeuser:nodejs /app/node_modules ./node_modules

# Copy application source
COPY --chown=nodeuser:nodejs . .

# Runtime environment defaults (overridden by docker-compose / CI secrets)
ENV NODE_ENV=production \
    PORT=8080 \
    # Cap Node.js heap to 512 MB — adjust for your EC2 instance size
    NODE_OPTIONS="--max-old-space-size=512"

USER nodeuser

EXPOSE 8080

# Let Docker restart the container if the health endpoint stops responding
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Use tini as PID 1 to forward signals correctly
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "server.js"]
