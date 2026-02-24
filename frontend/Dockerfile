# ── Stage 1: Build Angular application ────────────────────────────────────────
FROM node:18-alpine AS builder
WORKDIR /app

# Copy manifests first — this layer is cached unless dependencies change
COPY package*.json ./
RUN npm ci

# Copy source and compile with production optimisations (AOT, tree-shaking, etc.)
COPY . .
RUN npm run build -- --configuration=production


# ── Stage 2: Serve with Nginx ──────────────────────────────────────────────────
FROM nginx:1.25-alpine AS production

# Remove the default site
RUN rm /etc/nginx/conf.d/default.conf

# Copy our hardened nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy only the compiled assets — the Node.js toolchain stays behind
COPY --from=builder /app/dist/angular-15-crud /usr/share/nginx/html

# Fix permissions so the nginx worker (non-root) can read files
RUN chown -R nginx:nginx /usr/share/nginx/html \
 && chmod -R 755        /usr/share/nginx/html

EXPOSE 80

# nginx master runs as root to bind :80; workers run as the `nginx` user
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
