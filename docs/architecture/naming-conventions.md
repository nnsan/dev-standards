# Microservice Naming Conventions

This document outlines naming conventions for microservice directories and backend components.

**Note**: This does not apply to frontend framework conventions (e.g., Angular's `.service.ts`, `.component.ts` files).

## Microservice Directory Naming

When organizing services in a `services/` folder, avoid redundant naming:

✅ **Correct:**
- `services/employee/`
- `services/recruitment/`
- `services/payroll/`
- `services/performance/`

❌ **Avoid:**
- `services/employee-service/`
- `services/recruitment-service/`
- `services/payroll-service/`

## Database Changelog Naming

The changelog file should match the service name:
- `services/employee/` → `employee.changelog.yml`
- `services/recruitment/` → `recruitment.changelog.yml`
- `services/payroll/` → `payroll.changelog.yml`

## Package/Binary Naming

In `Cargo.toml`, use the service name without suffix:
```toml
[package]
name = "employee"  # not "employee-service"
```

## Benefits

- **Cleaner Structure**: Reduces redundant naming
- **Consistency**: Clear pattern for all services
- **Maintainability**: Easier to navigate and understand