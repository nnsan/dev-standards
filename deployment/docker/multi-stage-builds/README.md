# Docker Multi-Stage Builds

This document provides guidelines and examples for implementing multi-stage Docker builds to optimize image size and security.

## Why Multi-Stage Builds?

### Benefits
- **Smaller Images**: Remove build tools and dependencies from final image
- **Security**: Reduce attack surface by excluding build-time tools
- **Performance**: Faster deployment and reduced storage costs
- **Clean Separation**: Build and runtime environments are isolated

### Before vs After
❌ **Single-stage (large image):**
```dockerfile
FROM rust:1.75
WORKDIR /app
COPY . .
RUN cargo build --release
CMD ["./target/release/app"]
# Result: ~1.5GB image with Rust toolchain
```

✅ **Multi-stage (optimized):**
```dockerfile
FROM rust:1.75 as builder
WORKDIR /app
COPY . .
RUN cargo build --release

FROM debian:bookworm-slim
COPY --from=builder /app/target/release/app /usr/local/bin/app
CMD ["app"]
# Result: ~100MB image without Rust toolchain
```

## Rust Applications

### Basic Multi-Stage Build
```dockerfile
# Build stage
FROM rust:1.75 as builder
WORKDIR /app

# Copy dependency files first for better caching
COPY Cargo.toml Cargo.lock ./
RUN cargo fetch

# Copy source code and build
COPY src ./src
RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim as runtime

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN adduser --disabled-password --gecos '' appuser
USER appuser
WORKDIR /home/appuser

# Copy only the binary from builder stage
COPY --from=builder --chown=appuser:appuser /app/target/release/app ./app

EXPOSE 3000
CMD ["./app"]
```

### Optimized Rust Build with Alpine
```dockerfile
# Build stage with musl for static linking
FROM rust:1.75-alpine as builder
WORKDIR /app

# Install build dependencies
RUN apk add --no-cache musl-dev pkgconfig openssl-dev

# Set target for static linking
ENV RUSTFLAGS="-C target-feature=-crt-static"

COPY Cargo.toml Cargo.lock ./
RUN cargo fetch

COPY src ./src
RUN cargo build --release --target x86_64-unknown-linux-musl

# Minimal runtime stage
FROM alpine:3.18 as runtime
RUN apk add --no-cache ca-certificates

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

USER appuser
WORKDIR /home/appuser

# Copy statically linked binary
COPY --from=builder --chown=appuser:appgroup \
    /app/target/x86_64-unknown-linux-musl/release/app ./app

EXPOSE 3000
CMD ["./app"]
```

## Node.js Applications

### Basic Node.js Multi-Stage
```dockerfile
# Build stage
FROM node:18-alpine as builder
WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm ci --only=production

# Copy source code
COPY . .
RUN npm run build

# Runtime stage
FROM node:18-alpine as runtime
WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

# Copy built application and dependencies
COPY --from=builder --chown=nextjs:nodejs /app/dist ./dist
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/package.json ./package.json

USER nextjs
EXPOSE 3000
CMD ["node", "dist/index.js"]
```

### TypeScript Build
```dockerfile
# Build stage
FROM node:18-alpine as builder
WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci

# Copy source and build
COPY . .
RUN npm run build
RUN npm prune --production

# Runtime stage
FROM node:18-alpine as runtime
WORKDIR /app

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodeuser -u 1001

# Copy built files and production dependencies
COPY --from=builder --chown=nodeuser:nodejs /app/dist ./dist
COPY --from=builder --chown=nodeuser:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodeuser:nodejs /app/package.json ./

USER nodeuser
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

## React Applications

### React with Nginx
```dockerfile
# Build stage
FROM node:18-alpine as builder
WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci

# Copy source and build
COPY . .
RUN npm run build

# Production stage with Nginx
FROM nginx:alpine as production

# Copy built React app to Nginx
COPY --from=builder /app/build /usr/share/nginx/html

# Copy custom Nginx config if needed
COPY nginx.conf /etc/nginx/nginx.conf

# Create non-root user for Nginx
RUN addgroup -g 1001 -S nginx && \
    adduser -S nginx -u 1001 -G nginx

# Change ownership of Nginx directories
RUN chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d

# Switch to non-root user
USER nginx

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

## Advanced Patterns

### Multi-Target Builds
```dockerfile
# Base stage with common dependencies
FROM rust:1.75 as base
WORKDIR /app
COPY Cargo.toml Cargo.lock ./
RUN cargo fetch

# Development stage
FROM base as development
COPY . .
RUN cargo build
CMD ["cargo", "run"]

# Test stage
FROM base as test
COPY . .
RUN cargo test

# Production build stage
FROM base as builder
COPY . .
RUN cargo build --release

# Production runtime
FROM debian:bookworm-slim as production
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/app /usr/local/bin/app
CMD ["app"]
```

### Build with Different Targets
```bash
# Build for development
docker build --target development -t myapp:dev .

# Build for testing
docker build --target test -t myapp:test .

# Build for production (default)
docker build -t myapp:prod .
```

## Optimization Techniques

### 1. Layer Caching
```dockerfile
# ✅ Copy dependency files first (changes less frequently)
COPY Cargo.toml Cargo.lock ./
RUN cargo fetch

# ✅ Copy source code after (changes more frequently)
COPY src ./src
RUN cargo build --release
```

### 2. Minimize Layers
```dockerfile
# ❌ Multiple RUN commands create multiple layers
RUN apt-get update
RUN apt-get install -y ca-certificates
RUN rm -rf /var/lib/apt/lists/*

# ✅ Combine into single layer
RUN apt-get update && \
    apt-get install -y ca-certificates && \
    rm -rf /var/lib/apt/lists/*
```

### 3. Use .dockerignore
```dockerignore
# .dockerignore
target/
node_modules/
.git/
.env
*.md
Dockerfile*
.dockerignore
```

## Build Scripts

### Makefile for Multi-Stage Builds
```makefile
# Makefile
.PHONY: build-dev build-prod build-test

build-dev:
	docker build --target development -t myapp:dev .

build-test:
	docker build --target test -t myapp:test .

build-prod:
	docker build --target production -t myapp:prod .

test:
	docker run --rm myapp:test

run-dev:
	docker run -p 3000:3000 myapp:dev

run-prod:
	docker run -p 3000:3000 myapp:prod
```

### Docker Compose with Multi-Stage
```yaml
# docker-compose.yml
version: '3.8'
services:
  app-dev:
    build:
      context: .
      target: development
    ports:
      - "3000:3000"
    volumes:
      - ./src:/app/src

  app-prod:
    build:
      context: .
      target: production
    ports:
      - "3000:3000"
```

## Best Practices

1. **Order Layers by Change Frequency**: Dependencies first, source code last
2. **Use Specific Base Images**: Avoid `latest` tags
3. **Minimize Final Image**: Only include runtime dependencies
4. **Security**: Run as non-root user in final stage
5. **Caching**: Structure builds to maximize Docker layer caching
6. **Documentation**: Comment each stage's purpose
7. **Testing**: Include test stages in multi-stage builds

## Size Comparison

| Build Type | Base Image | Final Size | Use Case |
|------------|------------|------------|----------|
| Single-stage | rust:1.75 | ~1.5GB | Development only |
| Multi-stage | debian:slim | ~100MB | Production |
| Multi-stage | alpine | ~20MB | Production (static) |
| Distroless | gcr.io/distroless | ~15MB | Production (minimal) |