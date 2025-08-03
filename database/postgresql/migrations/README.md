# PostgreSQL Migration Strategy with Liquibase

This document outlines the migration strategy for PostgreSQL databases using Liquibase for DDL management.

## Migration Organization

DDL files are categorized into two main parts:

### 1. Tables
- Table creation and modifications
- Column additions, modifications, and deletions
- Primary keys, foreign keys, and constraints
- Indexes and unique constraints
- **Idempotent Principle**: Files can be run multiple times with consistent output
- **Version Control**: Use incremental indicators for post-release changes

### 2. Database Objects
- **Functions**: Stored functions and user-defined functions
- **Trigger Functions**: Functions specifically designed for triggers
- **Triggers**: Database triggers for automated actions
- **Views**: Database views for data abstraction
- **Procedures**: Stored procedures for complex operations
- **Run Strategy**: Set `runOnChange="true"` to execute on every deployment

## File Naming Convention

### Tables
```
table_name.XXX.sql
```
Where XXX is a 3-digit version indicator:
- `.001.sql` - Original table definition (idempotent)
- `.002.sql` - First modification after release
- `.003.sql` - Second modification after release

Examples:
- `employees.001.sql` - Initial employees table
- `employees.002.sql` - Add department_id column
- `projects.001.sql` - Initial projects table

**Rules:**
- Original `.001` file can be modified until release
- After release, create new file with incremented indicator
- Each file must be idempotent (safe to run multiple times)

### Database Objects
```
object_type_object_name.sql
```
Where object_type uses short prefixes:
- `fn` - Functions
- `vw` - Views  
- `trigger` - Triggers (keep full name)
- `sp` - Stored Procedures

Examples:
- `fn_calculate_employee_tenure.sql`
- `trigger_employee_audit_log.sql`
- `vw_employee_summary.sql`
- `sp_monthly_report.sql`

## Liquibase Changelog Structure

### Master Changelog (domain_name.changelog.yml)
```yaml
databaseChangeLog:
  - include:
      file: tables.changelog.yml
      relativeToChangelogFile: true
  - include:
      file: database-objects.changelog.yml
      relativeToChangelogFile: true
```

### Tables Changelog (tables.changelog.yml)
```yaml
databaseChangeLog:
  - changeSet:
      id: core_tables.001
      author: developer
      runOnChange: false
      changes:
        - sqlFile:
            path: tables/departments.001.sql
            relativeToChangelogFile: true
        - sqlFile:
            path: tables/employees.001.sql
            relativeToChangelogFile: true
  - changeSet:
      id: project_tables.001
      author: developer
      runOnChange: false
      changes:
        - sqlFile:
            path: tables/projects.001.sql
            relativeToChangelogFile: true
```

### Database Objects Changelog (database-objects.changelog.yml)
```yaml
databaseChangeLog:
  - changeSet:
      id: fn_calculate_tenure
      author: developer
      runOnChange: true
      changes:
        - sqlFile:
            path: database-objects/fn_calculate_employee_tenure.sql
            relativeToChangelogFile: true
  - changeSet:
      id: vw_employee_summary
      author: developer
      runOnChange: true
      changes:
        - sqlFile:
            path: database-objects/vw_employee_summary.sql
            relativeToChangelogFile: true
```

## Migration Best Practices

1. **Separate Concerns**: Keep table definitions separate from database objects
2. **Dependency Order**: Create tables before dependent objects (triggers, views)
3. **Group Related Changes**: Combine related database objects in single changesets
4. **Rollback Strategy**: Always include rollback statements where possible
5. **Testing**: Test migrations on development environment first
6. **Documentation**: Include comments explaining complex changes

### Changeset Grouping Guidelines

**Group together:**
- Related audit triggers (all `*_audit` triggers)
- Related views that depend on same tables
- Related functions that work together
- Permission grants for same role

**Keep separate:**
- Table creation (different changeset per table group)
- Functions with different purposes
- Objects with different rollback requirements

**Example:**
```yaml
# ✅ Good - Group related audit triggers
- changeSet:
    id: audit_triggers
    changes:
      - sqlFile: trigger_employees_audit.sql
      - sqlFile: trigger_competencies_audit.sql
      - sqlFile: trigger_assignments_audit.sql

# ❌ Avoid - Separate changesets for each trigger
- changeSet:
    id: trigger_employees_audit
- changeSet:
    id: trigger_competencies_audit
```
6. **DDL Naming Convention**: Use lowercase for field types and DDL variable types (e.g., `uuid`, `varchar`, `timestamp`). Use uppercase for PostgreSQL keywords and functions (e.g., `CREATE TABLE`, `PRIMARY KEY`, `REFERENCES`)

## Folder Structure

```
db-schema/
├── README.md
├── domain_name.changelog.yml          # Master changelog (entry point)
├── tables.changelog.yml               # All table changes
├── database-objects.changelog.yml     # All database object changes
├── tables/
│   ├── latest/                        # Latest DDL for each table
│   │   ├── employees.sql
│   │   └── projects.sql
│   ├── employees.001.sql              # Version history
│   ├── employees.002.sql
│   └── projects.001.sql
└── database-objects/
    ├── fn_calculate_employee_tenure.sql
    ├── trigger_employee_audit_log.sql
    ├── vw_employee_summary.sql
    └── sp_monthly_report.sql
```

**Folder Purpose:**
- **db-schema/**: Contains all database schema definitions and migrations
- **tables/latest/**: Contains the most current DDL for each table (for reference)
- **tables/**: Contains versioned table migration files
- **database-objects/**: Contains all database objects (functions, views, triggers, procedures)

## Usage Guidelines

### Table Management
1. **Idempotent Design**: Write CREATE OR REPLACE or IF NOT EXISTS statements
2. **Version Control**: Modify `.001` files freely until release, then create `.002`
3. **Release Discipline**: Never modify released table files
4. **Dependency Order**: Create tables before dependent objects
5. **One Table Per File**: Each table gets its own DDL file
6. **Separate Audit Tables**: Audit tables (`*_hist`) must be in separate files from main tables
7. **Group Related Changes**: Include multiple related tables in one changeSet for logical grouping and dependency management

### File Separation Rules

**One Table Per File:**
- Each table definition goes in its own file
- Never mix multiple table definitions in one file
- Audit tables separated from main tables

**Example Structure:**
```
tables/
├── employees.001.sql           # Main table only
├── employees_hist.001.sql      # Audit table only
├── assignments.001.sql         # Main table only
└── assignments_hist.001.sql    # Audit table only
```

**Changeset Organization:**
```yaml
databaseChangeLog:
  - changeSet:
      id: core_tables.001
      changes:
        - sqlFile: tables/employees.001.sql
        - sqlFile: tables/assignments.001.sql
  - changeSet:
      id: audit_tables.001
      changes:
        - sqlFile: tables/employees_hist.001.sql
        - sqlFile: tables/assignments_hist.001.sql
```

### Database Object Management
1. **Always Deployable**: Set `runOnChange="true"` for all database objects
2. **CREATE OR REPLACE**: Use replaceable syntax for functions, views, procedures
3. **Drop and Recreate**: For triggers, use DROP IF EXISTS then CREATE
4. **Single Responsibility**: One object per file
5. **Variable Naming**: Use `p_` prefix for input parameters and `l_` prefix for local variables

### General Rules
1. **Version Control**: All migration files must be committed to version control
2. **No Direct DB Changes**: All schema changes must go through Liquibase migrations
3. **Testing**: Test migrations on development environment first
4. **Documentation**: Include comments explaining complex changes