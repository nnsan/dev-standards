# Rust Microservice Project Structure

This document defines the standard project structure for Rust microservices to ensure consistency and scalability.

## Folder Structure

```
service-name/
├── src/
│   ├── contract/
│   │   └── openapi.yml          # OpenAPI 3.0 specification
│   ├── routes/
│   │   ├── mod.rs
│   │   ├── api.rs               # OpenAPI documentation setup
│   │   └── {domain}.rs          # Route definitions per domain
│   ├── models/
│   │   ├── mod.rs
│   │   ├── {domain}.rs          # Domain-specific models
│   │   └── common.rs            # Common API models (ApiResponse, ApiError, etc.)
│   ├── handlers/
│   │   ├── mod.rs
│   │   └── {domain}.rs          # Business logic handlers
│   ├── middleware/
│   │   ├── mod.rs
│   │   ├── auth.rs              # Authentication middleware
│   │   ├── cors.rs              # CORS middleware
│   │   └── logging.rs           # Request logging
│   ├── config/
│   │   ├── mod.rs
│   │   ├── database.rs          # Database configuration
│   │   └── app.rs               # Application configuration
│   ├── utils/
│   │   ├── mod.rs
│   │   ├── validation.rs        # Custom validation functions
│   │   └── helpers.rs           # Utility functions
│   └── main.rs                  # Application entry point
├── db-schema/                   # Database schema (Liquibase)
│   ├── {service}.changelog.yml  # Master changelog
│   ├── tables.changelog.yml     # Table changes
│   ├── database-objects.changelog.yml  # DB objects
│   ├── tables/
│   │   ├── latest/              # Latest DDL reference
│   │   └── *.001.sql            # Versioned table files
│   └── database-objects/
│       └── *.sql                # Functions, views, procedures
├── tests/
│   ├── integration/
│   └── unit/
├── Cargo.toml
├── Dockerfile
├── liquibase.properties
└── README.md
```

## Module Responsibilities

### contract/
- **Purpose**: API contract definitions
- **Contents**: OpenAPI YAML specifications
- **Naming**: `openapi.yml` for main API contract

### routes/
- **Purpose**: HTTP route definitions and grouping
- **Contents**: Route registration, path definitions
- **Naming**: `{domain}.rs` (e.g., `employees.rs`, `departments.rs`)
- **Responsibilities**: 
  - Route registration
  - Path parameter extraction
  - Route grouping

### models/
- **Purpose**: Data structures and validation
- **Contents**: Request/response models, database entities
- **Naming**: `{domain}.rs` for domain models, `common.rs` for shared types
- **Responsibilities**:
  - Data serialization/deserialization
  - Input validation
  - OpenAPI schema definitions

### handlers/
- **Purpose**: Business logic implementation
- **Contents**: Request processing, business rules
- **Naming**: `{domain}.rs` matching route modules
- **Responsibilities**:
  - Business logic execution
  - Database operations
  - Error handling
  - Response formatting

### middleware/
- **Purpose**: Cross-cutting concerns
- **Contents**: Authentication, logging, CORS, etc.
- **Naming**: `{concern}.rs` (e.g., `auth.rs`, `logging.rs`)
- **Responsibilities**:
  - Request/response processing
  - Security enforcement
  - Logging and monitoring

### config/
- **Purpose**: Application configuration
- **Contents**: Database, app settings, environment variables
- **Naming**: `{component}.rs` (e.g., `database.rs`, `app.rs`)
- **Responsibilities**:
  - Configuration loading
  - Environment variable handling
  - Connection setup

### utils/
- **Purpose**: Utility functions and helpers
- **Contents**: Common functions, custom validators
- **Naming**: `{category}.rs` (e.g., `validation.rs`, `helpers.rs`)
- **Responsibilities**:
  - Reusable functions
  - Custom validation logic
  - Helper utilities

## Required Dependencies

### Core Dependencies
```toml
[dependencies]
# Core async runtime - use latest 1.x
tokio = { version = "^1.0", features = ["full"] }
# Web framework - use latest compatible with tokio
axum = "^0.7"
# Serialization - use latest 1.x
serde = { version = "^1.0", features = ["derive"] }
serde_json = "^1.0"
# UUID generation - use latest 1.x
uuid = { version = "^1.0", features = ["v4", "serde"] }
# Date/time handling - use latest 0.4.x
chrono = { version = "^0.4", features = ["serde"] }
# Error handling - use latest 1.x
anyhow = "^1.0"
```

### API Documentation
```toml
# OpenAPI documentation - use latest 4.x compatible with axum
utoipa = { version = "^4.0", features = ["axum_extras", "chrono", "uuid"] }
utoipa-swagger-ui = { version = "^4.0", features = ["axum"] }
```

### Validation
```toml
# Input validation - use latest 0.16.x
validator = { version = "^0.16", features = ["derive"] }
```

### Database (if needed)
```toml
# Database toolkit - use latest 0.7.x compatible with tokio
sqlx = { version = "^0.7", features = ["runtime-tokio-rustls", "postgres", "uuid", "chrono"] }
```

### HTTP & Middleware
```toml
# Service abstraction - use latest 0.4.x compatible with axum
tower = "^0.4"
tower-http = { version = "^0.5", features = ["cors", "trace"] }
```

### Logging
```toml
# Structured logging - use latest compatible versions
tracing = "^0.1"
tracing-subscriber = "^0.3"
```

## Version Strategy

- **Caret (^)**: Use compatible updates within the same major version
- **Core Dependencies**: Keep tokio, axum, and serde as the foundation
- **Comments**: Explain version constraints and compatibility requirements
- **Regular Updates**: Review and update versions quarterly
- **Testing**: Always test compatibility when updating versions

## File Templates

### main.rs Template
```rust
mod routes;
mod models;
mod handlers;
mod middleware;
mod config;
mod utils;

use axum::{http::StatusCode, response::Json, routing::get, Router};
use serde_json::{json, Value};
use utoipa::OpenApi;
use utoipa_swagger_ui::SwaggerUi;

use routes::api::ApiDoc;

#[tokio::main]
async fn main() {
    tracing_subscriber::init();
    
    let app = create_app();
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    
    println!("🚀 Service running on http://0.0.0.0:3000");
    println!("📚 API docs at http://0.0.0.0:3000/docs");
    
    axum::serve(listener, app).await.unwrap();
}

fn create_app() -> Router {
    Router::new()
        .route("/health", get(health_check))
        .nest("/v1", routes::create_routes())
        .merge(SwaggerUi::new("/docs").url("/api-docs/openapi.json", ApiDoc::openapi()))
}

async fn health_check() -> Result<Json<Value>, StatusCode> {
    Ok(Json(json!({
        "status": "healthy",
        "service": env!("CARGO_PKG_NAME"),
        "version": env!("CARGO_PKG_VERSION"),
        "timestamp": chrono::Utc::now()
    })))
}
```

### routes/mod.rs Template
```rust
pub mod api;
pub mod {domain};

use axum::Router;

pub fn create_routes() -> Router {
    Router::new()
        .merge({domain}::{domain}_routes())
        // Add more route modules here
}
```

### models/common.rs Template
```rust
use serde::Serialize;
use utoipa::ToSchema;

#[derive(Serialize, ToSchema)]
pub struct ApiResponse<T> {
    pub data: T,
}

#[derive(Serialize, ToSchema)]
pub struct PaginatedResponse<T> {
    pub data: Vec<T>,
    pub pagination: PaginationInfo,
}

#[derive(Serialize, ToSchema)]
pub struct PaginationInfo {
    pub page: u32,
    pub per_page: u32,
    pub total: u64,
    pub total_pages: u32,
}

#[derive(Serialize, ToSchema)]
pub struct ApiError {
    pub error: ErrorDetails,
}

#[derive(Serialize, ToSchema)]
pub struct ErrorDetails {
    pub code: String,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub details: Option<Vec<ValidationError>>,
}

#[derive(Serialize, ToSchema)]
pub struct ValidationError {
    pub field: String,
    pub message: String,
}
```

## Naming Conventions

### Files and Modules
- Use `snake_case` for file names
- Use `snake_case` for module names
- Domain modules should be plural (e.g., `employees.rs`, `departments.rs`)

### Functions and Variables
- Use `snake_case` for function names
- Use `snake_case` for variable names
- Handler functions should be descriptive (e.g., `list_employees`, `create_employee`)

### Structs and Enums
- Use `PascalCase` for struct names
- Use `PascalCase` for enum names
- Request/Response structs should be suffixed (e.g., `CreateEmployeeRequest`)

## Best Practices

1. **Separation of Concerns**: Keep routes, handlers, and models separate
2. **Domain Organization**: Group related functionality by domain
3. **Contract-First**: Define OpenAPI spec in dedicated contract folder
4. **Validation**: Use `validator` crate for input validation
5. **Error Handling**: Consistent error response format
6. **Documentation**: All endpoints must have OpenAPI annotations
7. **Testing**: Organize tests by integration and unit
8. **Configuration**: Environment-based configuration management
9. **Logging**: Structured logging with tracing
10. **Health Checks**: Always include health check endpoint

## Example Implementation

See `services/employee/` for a complete implementation following this structure.