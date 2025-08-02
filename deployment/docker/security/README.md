# Docker Security Best Practices

This document outlines security practices for Docker containers in development and production environments.

## Development Security

### 1. Secrets Management
❌ **Never do this:**
```dockerfile
ENV DATABASE_PASSWORD=mysecretpassword
ENV API_KEY=abc123xyz
```

✅ **Use Docker secrets or environment files:**
```yaml
# docker-compose.yml
services:
  app:
    environment:
      - DATABASE_PASSWORD_FILE=/run/secrets/db_password
    secrets:
      - db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

### 2. Non-Root User
❌ **Avoid running as root:**
```dockerfile
# This runs as root by default
COPY app /app
CMD ["./app"]
```

✅ **Create and use non-root user:**
```dockerfile
# Create non-root user
RUN addgroup --system --gid 1001 appgroup
RUN adduser --system --uid 1001 --ingroup appgroup appuser

# Switch to non-root user
USER appuser
WORKDIR /home/appuser/app
COPY --chown=appuser:appgroup app .
CMD ["./app"]
```

### 3. Minimal Base Images
❌ **Avoid full OS images:**
```dockerfile
FROM ubuntu:latest
```

✅ **Use minimal base images:**
```dockerfile
# For Rust applications
FROM rust:1.75-alpine as builder
# ... build steps ...
FROM alpine:3.18
RUN apk add --no-cache ca-certificates

# For Node.js applications  
FROM node:18-alpine
```

### 4. Image Scanning
```bash
# Scan images for vulnerabilities
docker scout cves your-image:tag

# Using Trivy
trivy image your-image:tag

# Using Snyk
snyk container test your-image:tag
```

## Production Security

### 1. Multi-Stage Builds
```dockerfile
# Build stage
FROM rust:1.75 as builder
WORKDIR /app
COPY Cargo.toml Cargo.lock ./
COPY src ./src
RUN cargo build --release

# Runtime stage - minimal image
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN adduser --disabled-password --gecos '' appuser
USER appuser
WORKDIR /home/appuser

# Copy only the binary
COPY --from=builder --chown=appuser:appuser /app/target/release/app ./
CMD ["./app"]
```

### 2. Resource Limits
```yaml
# docker-compose.yml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE  # Only if needed
```

### 3. Network Security
```yaml
# docker-compose.yml
version: '3.8'
services:
  app:
    networks:
      - app-network
  
  postgres:
    networks:
      - app-network
    # Don't expose database port externally
    # ports:
    #   - "5432:5432"

networks:
  app-network:
    driver: bridge
    internal: true  # No external access
```

## Security Scanning Automation

### 1. Pre-commit Hooks
```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: docker-security-scan
        name: Docker Security Scan
        entry: trivy config .
        language: system
        files: Dockerfile|docker-compose.*\.yml$
```

### 2. CI/CD Security Checks
```yaml
# .github/workflows/security.yml
name: Security Scan
on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build Docker image
        run: docker build -t test-image .
        
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'test-image'
          format: 'sarif'
          output: 'trivy-results.sarif'
          
      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'
```

## Development Environment Security

### 1. Local Development
```bash
# .env.example (commit this)
DATABASE_URL=postgresql://user:password@localhost:5432/myapp_dev
API_KEY=your_api_key_here
JWT_SECRET=your_jwt_secret_here

# .env (never commit this)
DATABASE_URL=postgresql://admin:realpassword@localhost:5432/myapp_dev
API_KEY=real_api_key_123
JWT_SECRET=real_jwt_secret_456
```

### 2. Docker Compose for Development
```yaml
# docker-compose.dev.yml
version: '3.8'
services:
  app:
    build: .
    environment:
      - RUST_LOG=debug
    env_file:
      - .env  # Load from file, not inline
    volumes:
      - ./src:/app/src:ro  # Read-only source mounting
    networks:
      - dev-network

  postgres:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
    secrets:
      - postgres_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - dev-network

secrets:
  postgres_password:
    file: ./secrets/postgres_dev_password.txt

networks:
  dev-network:
    driver: bridge

volumes:
  postgres_data:
```

## Security Checklist

### Development
- [ ] Use `.env` files for secrets (never commit them)
- [ ] Run containers as non-root users
- [ ] Use minimal base images
- [ ] Scan images regularly
- [ ] Keep dependencies updated
- [ ] Use read-only file systems where possible

### Production
- [ ] Use multi-stage builds
- [ ] Implement resource limits
- [ ] Use private networks
- [ ] Enable security options (`no-new-privileges`, `cap-drop`)
- [ ] Regular security audits
- [ ] Monitor container behavior
- [ ] Use image signing and verification

## Tools and Resources

### Security Scanning Tools
- **Trivy**: Vulnerability scanner for containers
- **Docker Scout**: Docker's built-in security scanning
- **Snyk**: Commercial security platform
- **Clair**: Open-source vulnerability scanner

### Security Hardening
- **Distroless Images**: Google's minimal container images
- **Docker Bench**: Security audit tool for Docker
- **Falco**: Runtime security monitoring

### Best Practices References
- [OWASP Docker Security](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [NIST Container Security Guide](https://csrc.nist.gov/publications/detail/sp/800-190/final)