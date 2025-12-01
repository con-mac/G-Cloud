# Multi-stage build for React application

# Stage 1: Build
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Stage 2: Production
FROM nginx:alpine

# Install sed for entrypoint script
RUN apk add --no-cache sed

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built assets from builder
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy entrypoint script for runtime env injection (verify it exists)
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && \
    ls -la /entrypoint.sh && \
    head -3 /entrypoint.sh || (echo "ERROR: entrypoint.sh not found!" && exit 1)

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

# Use entrypoint script if it exists, otherwise start nginx directly
CMD ["sh", "-c", "if [ -f /entrypoint.sh ]; then /entrypoint.sh; else echo 'WARNING: entrypoint.sh not found, starting nginx directly'; nginx -g 'daemon off;'; fi"]

