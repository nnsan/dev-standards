# PostgreSQL Setup Guide

This document provides setup instructions for PostgreSQL in different environments.

## Docker Setup

### Basic PostgreSQL Container
```yaml
# docker-compose.yml
version: '3.8'
services:
  postgres:
    image: postgres:15
    container_name: postgres
    environment:
      POSTGRES_DB: peopleops
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-scripts:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U admin -d peopleops"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  postgres_data:
```

### Production-Ready Configuration
```yaml
# docker-compose.prod.yml
version: '3.8'
services:
  postgres:
    image: postgres:15
    container_name: postgres
    environment:
      POSTGRES_DB: peopleops
      POSTGRES_USER: admin
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./postgresql.conf:/etc/postgresql/postgresql.conf
      - ./pg_hba.conf:/etc/postgresql/pg_hba.conf
    command: postgres -c config_file=/etc/postgresql/postgresql.conf
    secrets:
      - postgres_password
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U admin -d peopleops"]
      interval: 30s
      timeout: 10s
      retries: 3

secrets:
  postgres_password:
    file: ./secrets/postgres_password.txt

volumes:
  postgres_data:
```

## Configuration Files

### postgresql.conf
```ini
# Connection settings
listen_addresses = '*'
port = 5432
max_connections = 200

# Memory settings
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB
maintenance_work_mem = 64MB

# WAL settings
wal_level = replica
max_wal_size = 1GB
min_wal_size = 80MB
checkpoint_completion_target = 0.9

# Logging
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_min_duration_statement = 1000
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '

# Performance monitoring
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all
pg_stat_statements.max = 10000

# Autovacuum
autovacuum = on
autovacuum_max_workers = 3
autovacuum_naptime = 1min
```

### pg_hba.conf
```ini
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Local connections
local   all             all                                     trust

# IPv4 local connections
host    all             all             127.0.0.1/32            md5
host    all             all             0.0.0.0/0               md5

# IPv6 local connections
host    all             all             ::1/128                 md5

# Replication connections
host    replication     all             0.0.0.0/0               md5
```

## Initialization Scripts

### Database Setup
```sql
-- init-scripts/01-create-extensions.sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Create application user
CREATE USER app_user WITH PASSWORD 'app_password';
GRANT CONNECT ON DATABASE peopleops TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT CREATE ON SCHEMA public TO app_user;
```

**DDL Naming Convention:**
- Use **lowercase** for field types and DDL variable types: `uuid`, `varchar`, `timestamp`, `boolean`
- Use **UPPERCASE** for PostgreSQL keywords and functions: `CREATE TABLE`, `PRIMARY KEY`, `REFERENCES`, `NOT NULL`

### User Permissions
```sql
-- init-scripts/02-setup-permissions.sql
-- Grant permissions on existing tables
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;

-- Grant permissions on future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public 
GRANT USAGE, SELECT ON SEQUENCES TO app_user;
```

## Environment-Specific Setup

### Development Environment
```bash
#!/bin/bash
# setup-dev.sh
docker-compose -f docker-compose.dev.yml up -d postgres

# Wait for PostgreSQL to be ready
until docker exec postgres pg_isready -U admin -d peopleops; do
  echo "Waiting for PostgreSQL..."
  sleep 2
done

echo "PostgreSQL is ready for development"
```

### Production Environment
```bash
#!/bin/bash
# setup-prod.sh

# Create secrets directory
mkdir -p secrets
echo "your_secure_password" > secrets/postgres_password.txt
chmod 600 secrets/postgres_password.txt

# Start PostgreSQL with production config
docker-compose -f docker-compose.prod.yml up -d postgres

# Wait for PostgreSQL to be ready
until docker exec postgres pg_isready -U admin -d peopleops; do
  echo "Waiting for PostgreSQL..."
  sleep 2
done

echo "PostgreSQL is ready for production"
```

## Liquibase Integration

### Liquibase Container Setup
```yaml
# docker-compose.liquibase.yml
version: '3.8'
services:
  liquibase:
    image: liquibase/liquibase:4.25
    volumes:
      - ./db-schema:/liquibase/changelog
      - ./liquibase.properties:/liquibase/liquibase.properties
    command: --defaults-file=/liquibase/liquibase.properties update
    depends_on:
      postgres:
        condition: service_healthy
```

### Migration Script
```bash
#!/bin/bash
# run-migrations.sh
SERVICE_NAME=${1:-employee}

echo "Running migrations for $SERVICE_NAME service..."

docker run --rm \
  --network peopleops-network \
  -v $(pwd)/services/$SERVICE_NAME/db-schema:/liquibase/changelog \
  -v $(pwd)/services/$SERVICE_NAME/liquibase.properties:/liquibase/liquibase.properties \
  liquibase/liquibase:4.25 \
  --defaults-file=/liquibase/liquibase.properties update

echo "Migrations completed for $SERVICE_NAME"
```

## Health Checks

### Database Health Check
```sql
-- health-check.sql
SELECT 
    'PostgreSQL' as service,
    version() as version,
    current_database() as database,
    current_user as user,
    now() as timestamp,
    CASE 
        WHEN pg_is_in_recovery() THEN 'standby'
        ELSE 'primary'
    END as role;
```

### Connection Test Script
```bash
#!/bin/bash
# test-connection.sh
DB_HOST=${1:-localhost}
DB_PORT=${2:-5432}
DB_NAME=${3:-peopleops}
DB_USER=${4:-admin}

echo "Testing connection to PostgreSQL..."

if pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USER; then
    echo "✅ PostgreSQL is accepting connections"
    
    # Test database access
    if psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1;" > /dev/null 2>&1; then
        echo "✅ Database access successful"
    else
        echo "❌ Database access failed"
        exit 1
    fi
else
    echo "❌ PostgreSQL is not accepting connections"
    exit 1
fi
```

## Monitoring Setup

### Basic Monitoring Queries
```sql
-- monitoring-queries.sql

-- Active connections
SELECT count(*) as active_connections 
FROM pg_stat_activity 
WHERE state = 'active';

-- Database size
SELECT pg_size_pretty(pg_database_size('peopleops')) as database_size;

-- Table sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

## Backup Setup Integration

### Automated Backup Service
```yaml
# docker-compose.backup.yml
version: '3.8'
services:
  postgres-backup:
    image: postgres:15
    environment:
      PGPASSWORD: password
    volumes:
      - ./backups:/backups
      - ./backup-scripts:/scripts
    command: /scripts/backup-cron.sh
    depends_on:
      - postgres
```

## Security Hardening

### SSL Configuration
```ini
# postgresql.conf additions for SSL
ssl = on
ssl_cert_file = '/etc/ssl/certs/server.crt'
ssl_key_file = '/etc/ssl/private/server.key'
ssl_ca_file = '/etc/ssl/certs/ca.crt'
ssl_crl_file = '/etc/ssl/certs/server.crl'
```

### Network Security
```yaml
# docker-compose.secure.yml
version: '3.8'
services:
  postgres:
    image: postgres:15
    networks:
      - postgres-network
    # Remove port mapping for internal-only access
    # ports:
    #   - "5432:5432"

networks:
  postgres-network:
    driver: bridge
    internal: true
```

## Troubleshooting

### Common Issues
```bash
# Check PostgreSQL logs
docker logs postgres

# Connect to PostgreSQL container
docker exec -it postgres psql -U admin -d peopleops

# Check disk space
docker exec postgres df -h

# Check PostgreSQL configuration
docker exec postgres cat /var/lib/postgresql/data/postgresql.conf
```