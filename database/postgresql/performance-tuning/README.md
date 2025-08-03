# PostgreSQL Performance Tuning

This document outlines performance optimization strategies and best practices for PostgreSQL databases.

## Foreign Key Constraints

### Avoid CASCADE Operations
❌ **Avoid:**
```sql
CREATE TABLE employee_contracts (
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE
);
```

✅ **Preferred:**
```sql
CREATE TABLE employee_contracts (
    employee_id UUID REFERENCES employees(id)
);
```

### Manual Deletion with CTE
Use Common Table Expressions (CTEs) for controlled deletion leveraging PostgreSQL's deferred constraints:

```sql
-- Delete employee and related records in single transaction
WITH deleted_contracts AS (
    DELETE FROM employee_contracts 
    WHERE employee_id = $1
    RETURNING id
),
deleted_skills AS (
    DELETE FROM employee_skills 
    WHERE employee_id = $1
    RETURNING id
),
deleted_performance AS (
    DELETE FROM performance_reviews 
    WHERE employee_id = $1
    RETURNING id
)
DELETE FROM employees 
WHERE id = $1
RETURNING id;
```

**Benefits:**
- **Explicit Control**: Clear understanding of what gets deleted
- **Performance**: Single transaction, better query planning
- **Audit Trail**: Can log each deletion step
- **Error Handling**: Granular error control per table

## Index Optimization

### Essential Indexes
```sql
-- Foreign key indexes (PostgreSQL doesn't auto-create these)
CREATE INDEX idx_employee_contracts_employee_id ON employee_contracts(employee_id);
CREATE INDEX idx_employee_skills_employee_id ON employee_skills(employee_id);

-- Composite indexes for common queries
CREATE INDEX idx_employees_dept_status ON employees(department_id, employment_status);
CREATE INDEX idx_employees_hire_date_status ON employees(hire_date, employment_status);

-- Partial indexes for filtered queries
CREATE INDEX idx_active_employees ON employees(id) WHERE employment_status = 'active';
```

### Index Monitoring
```sql
-- Find unused indexes
SELECT schemaname, tablename, indexname, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes 
WHERE idx_tup_read = 0 AND idx_tup_fetch = 0;

-- Find missing indexes on foreign keys
SELECT c.conrelid::regclass AS table_name,
       a.attname AS column_name
FROM pg_constraint c
JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
WHERE c.contype = 'f'
AND NOT EXISTS (
    SELECT 1 FROM pg_index i 
    WHERE i.indrelid = c.conrelid 
    AND a.attnum = ANY(i.indkey)
);
```

## Query Optimization

### Efficient Pagination
❌ **Avoid OFFSET for large datasets:**
```sql
SELECT * FROM employees ORDER BY id LIMIT 20 OFFSET 10000;
```

✅ **Use cursor-based pagination:**
```sql
SELECT * FROM employees 
WHERE id > $last_seen_id 
ORDER BY id LIMIT 20;
```

### Bulk Operations
```sql
-- Bulk insert with ON CONFLICT
INSERT INTO employee_skills (employee_id, skill_name, proficiency_level)
VALUES 
    ($1, 'PostgreSQL', 'advanced'),
    ($1, 'Rust', 'intermediate'),
    ($1, 'Docker', 'beginner')
ON CONFLICT (employee_id, skill_name) 
DO UPDATE SET 
    proficiency_level = EXCLUDED.proficiency_level,
    updated_at = CURRENT_TIMESTAMP;

-- Bulk update with CTE
WITH skill_updates AS (
    SELECT unnest($1::uuid[]) as employee_id,
           unnest($2::text[]) as skill_name,
           unnest($3::text[]) as proficiency_level
)
UPDATE employee_skills es
SET proficiency_level = su.proficiency_level,
    updated_at = CURRENT_TIMESTAMP
FROM skill_updates su
WHERE es.employee_id = su.employee_id 
AND es.skill_name = su.skill_name;
```

## Connection Management

### Connection Pooling Configuration
```sql
-- PostgreSQL settings
max_connections = 200
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB
maintenance_work_mem = 64MB

-- Connection pool settings (PgBouncer)
pool_mode = transaction
default_pool_size = 20
max_client_conn = 100
```

### Application-Level Pooling
```rust
// Rust SQLx example
let pool = PgPoolOptions::new()
    .max_connections(20)
    .min_connections(5)
    .acquire_timeout(Duration::from_secs(30))
    .idle_timeout(Duration::from_secs(600))
    .max_lifetime(Duration::from_secs(1800))
    .connect(&database_url)
    .await?;
```

## Monitoring Queries

### Slow Query Analysis
```sql
-- Enable slow query logging
ALTER SYSTEM SET log_min_duration_statement = 1000; -- 1 second
SELECT pg_reload_conf();

-- Find slow queries
SELECT query, mean_exec_time, calls, total_exec_time
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC 
LIMIT 10;
```

### Lock Monitoring
```sql
-- Check for blocking queries
SELECT 
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement,
    blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```

## Table Maintenance

### Regular Maintenance Tasks
```sql
-- Analyze tables for query planner
ANALYZE employees;
ANALYZE employee_contracts;

-- Vacuum to reclaim space
VACUUM (ANALYZE, VERBOSE) employees;

-- Reindex if needed
REINDEX INDEX CONCURRENTLY idx_employees_email;
```

### Automated Maintenance
```sql
-- Enable autovacuum (default in modern PostgreSQL)
ALTER TABLE employees SET (autovacuum_vacuum_scale_factor = 0.1);
ALTER TABLE employees SET (autovacuum_analyze_scale_factor = 0.05);
```

## Audit Trail Implementation

### Automatic Audit Triggers
Use PostgreSQL triggers to automatically populate `_hist` tables:

```sql
-- Audit trigger function template
CREATE OR REPLACE FUNCTION fn_{table}_audit_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO {table}_hist (..., operation, changed_by, changed_at)
        VALUES (NEW.*, 'INSERT', NEW.updated_by, CURRENT_TIMESTAMP);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO {table}_hist (..., operation, changed_by, changed_at)
        VALUES (NEW.*, 'UPDATE', NEW.updated_by, CURRENT_TIMESTAMP);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO {table}_hist (..., operation, changed_by, changed_at)
        VALUES (OLD.*, 'DELETE', OLD.updated_by, CURRENT_TIMESTAMP);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER trigger_{table}_audit
    AFTER INSERT OR UPDATE OR DELETE ON {table}
    FOR EACH ROW EXECUTE FUNCTION fn_{table}_audit_trigger();
```

**Benefits:**
- **Automatic**: No application code needed
- **Consistent**: All changes captured
- **Performance**: Minimal overhead
- **Reliable**: Database-level guarantee

## Best Practices

1. **Avoid CASCADE**: Use explicit CTE-based deletions
2. **Index Foreign Keys**: PostgreSQL doesn't auto-create these
3. **Monitor Query Performance**: Use pg_stat_statements
4. **Use Connection Pooling**: Prevent connection exhaustion
5. **Regular Maintenance**: VACUUM and ANALYZE tables
6. **Cursor Pagination**: Avoid OFFSET for large datasets
7. **Bulk Operations**: Use batch inserts/updates when possible
8. **Partial Indexes**: For frequently filtered columns
9. **Audit Triggers**: Use database triggers for automatic audit trails
9. **DDL Naming Convention**: Use lowercase for field types (`uuid`, `varchar`, `timestamp`) and UPPERCASE for PostgreSQL keywords (`CREATE TABLE`, `PRIMARY KEY`, `REFERENCES`)