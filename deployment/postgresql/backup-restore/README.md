# PostgreSQL Backup & Restore Strategy

This document outlines backup and restore procedures for PostgreSQL databases.

## Backup Types

### 1. Logical Backups (pg_dump)
- **Use Case**: Development, testing, data migration
- **Advantages**: Cross-version compatibility, selective restore
- **Disadvantages**: Slower for large databases

### 2. Physical Backups (pg_basebackup)
- **Use Case**: Production, disaster recovery
- **Advantages**: Fast backup/restore, point-in-time recovery
- **Disadvantages**: Same PostgreSQL version required

## Backup Scripts

### Daily Logical Backup
```bash
#!/bin/bash
# daily-backup.sh
DB_NAME="peopleops"
BACKUP_DIR="/backups/logical"
DATE=$(date +%Y%m%d_%H%M%S)

pg_dump -h postgres -U admin -d $DB_NAME \
  --no-password \
  --format=custom \
  --compress=9 \
  --file="$BACKUP_DIR/${DB_NAME}_${DATE}.dump"

# Keep only last 7 days
find $BACKUP_DIR -name "*.dump" -mtime +7 -delete
```

### Schema-Only Backup
```bash
#!/bin/bash
# schema-backup.sh
pg_dump -h postgres -U admin -d peopleops \
  --schema-only \
  --format=plain \
  --file="schema_$(date +%Y%m%d).sql"
```

## Restore Procedures

### Full Database Restore
```bash
# Drop and recreate database
dropdb -h postgres -U admin peopleops
createdb -h postgres -U admin peopleops

# Restore from custom format
pg_restore -h postgres -U admin -d peopleops \
  --verbose \
  --clean \
  --if-exists \
  backup_file.dump
```

### Selective Table Restore
```bash
# Restore specific tables only
pg_restore -h postgres -U admin -d peopleops \
  --table=employees \
  --table=departments \
  backup_file.dump
```

## Docker Integration

### Backup Container
```yaml
# docker-compose.backup.yml
version: '3.8'
services:
  backup:
    image: postgres:15
    environment:
      PGPASSWORD: password
    volumes:
      - ./backups:/backups
      - ./scripts:/scripts
    command: /scripts/daily-backup.sh
    depends_on:
      - postgres
```

### Automated Backup with Cron
```dockerfile
# Dockerfile.backup
FROM postgres:15
RUN apt-get update && apt-get install -y cron
COPY backup-scripts/ /scripts/
COPY crontab /etc/cron.d/backup-cron
RUN chmod 0644 /etc/cron.d/backup-cron
RUN crontab /etc/cron.d/backup-cron
CMD ["cron", "-f"]
```

## Environment-Specific Strategies

### Development
- **Frequency**: Weekly or on-demand
- **Retention**: 2-3 backups
- **Method**: Logical backup (pg_dump)

### Staging
- **Frequency**: Daily
- **Retention**: 7 days
- **Method**: Logical backup with compression

### Production
- **Frequency**: 
  - Full backup: Daily
  - Incremental: Every 4 hours
  - WAL archiving: Continuous
- **Retention**: 30 days full, 7 days incremental
- **Method**: Physical backup + WAL archiving

## Monitoring & Alerts

### Backup Verification
```bash
#!/bin/bash
# verify-backup.sh
BACKUP_FILE=$1

# Test restore to temporary database
createdb -h postgres -U admin test_restore
pg_restore -h postgres -U admin -d test_restore $BACKUP_FILE

if [ $? -eq 0 ]; then
  echo "Backup verification successful"
  dropdb -h postgres -U admin test_restore
else
  echo "Backup verification failed"
  exit 1
fi
```

### Health Check Script
```bash
#!/bin/bash
# backup-health.sh
BACKUP_DIR="/backups/logical"
LATEST_BACKUP=$(ls -t $BACKUP_DIR/*.dump | head -1)
BACKUP_AGE=$(find $BACKUP_DIR -name "*.dump" -mtime -1 | wc -l)

if [ $BACKUP_AGE -eq 0 ]; then
  echo "ALERT: No recent backups found"
  exit 1
fi

echo "Latest backup: $LATEST_BACKUP"
echo "Backup health: OK"
```

## Security Considerations

1. **Encryption**: Encrypt backups at rest and in transit
2. **Access Control**: Limit backup file access to authorized users
3. **Network Security**: Use SSL connections for remote backups
4. **Credential Management**: Use environment variables or secrets management

## Recovery Testing

### Monthly Recovery Drill
1. Restore backup to isolated environment
2. Verify data integrity
3. Test application connectivity
4. Document recovery time
5. Update procedures if needed

## Best Practices

1. **Test Restores Regularly**: Backup is only as good as your ability to restore
2. **Multiple Locations**: Store backups in different physical locations
3. **Automate Everything**: Reduce human error with automation
4. **Monitor Backup Jobs**: Set up alerts for failed backups
5. **Document Procedures**: Keep recovery procedures up-to-date