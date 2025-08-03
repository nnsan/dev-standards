# RESTful API Standards

This document outlines standards for building RESTful APIs across all microservices, regardless of implementation language.

## URL Design

### Resource Naming
✅ **Use nouns, not verbs:**
```
GET /employees          # ✅ Good
GET /getEmployees       # ❌ Avoid
```

✅ **Use plural nouns for collections:**
```
GET /employees          # Collection
GET /employees/123      # Individual resource
```

✅ **Use kebab-case for multi-word resources:**
```
GET /employee-contracts
GET /performance-reviews
GET /leave-requests
```

### Nested Resources
```
GET /employees/123/contracts        # Employee's contracts
GET /employees/123/skills          # Employee's skills
POST /employees/123/performance-reviews
GET /departments/456/employees     # Department's employees
```

## HTTP Methods

### Standard CRUD Operations
```
// GET - Retrieve resources
GET /employees                     // List all employees
GET /employees/123                 // Get specific employee
GET /employees?department=IT       // Filtered list

// POST - Create new resource
POST /employees                    // Create new employee

// PUT - Update entire resource
PUT /employees/123                 // Update entire employee

// PATCH - Partial update
PATCH /employees/123               // Update specific fields

// DELETE - Remove resource
DELETE /employees/123              // Delete employee
```

### Non-CRUD Operations
```
// Use verbs for actions that don't fit CRUD
POST /employees/123/activate
POST /employees/123/deactivate
POST /employees/123/promote
GET /employees/123/calculate-tenure
POST /leave-requests/123/approve
POST /leave-requests/123/reject
```

## Response Format

### Success Responses
```json
// Single resource
{
  "data": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "employee_id": "EMP001",
    "first_name": "John",
    "last_name": "Doe",
    "email": "john.doe@company.com",
    "created_at": "2024-01-15T10:30:00Z",
    "updated_at": "2024-01-15T10:30:00Z"
  }
}

// Collection with pagination
{
  "data": [
    {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "employee_id": "EMP001",
      "first_name": "John",
      "last_name": "Doe"
    }
  ],
  "pagination": {
    "page": 1,
    "per_page": 20,
    "total": 150,
    "total_pages": 8
  }
}
```

### Error Responses
```json
// Validation errors
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input data",
    "details": [
      {
        "field": "email",
        "message": "Invalid email format"
      },
      {
        "field": "hire_date",
        "message": "Date cannot be in the future"
      }
    ]
  }
}

// Not found
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Employee not found",
    "resource": "employee",
    "resource_id": "123"
  }
}

// Server error
{
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "An unexpected error occurred",
    "request_id": "req_123456789"
  }
}
```

## Status Codes

### Success Codes
- `200 OK` - Successful GET, PUT, PATCH
- `201 Created` - Successful POST
- `204 No Content` - Successful DELETE

### Client Error Codes
- `400 Bad Request` - Invalid request data
- `401 Unauthorized` - Authentication required
- `403 Forbidden` - Access denied
- `404 Not Found` - Resource not found
- `409 Conflict` - Resource conflict (duplicate email)
- `422 Unprocessable Entity` - Validation errors

### Server Error Codes
- `500 Internal Server Error` - Unexpected server error
- `503 Service Unavailable` - Service temporarily unavailable

## Request/Response Models

### Employee Resource
```json
{
  "id": "uuid",
  "employee_id": "string",
  "first_name": "string",
  "last_name": "string",
  "email": "string",
  "department_id": "uuid|null",
  "position": "string|null",
  "employment_status": "active|inactive|terminated",
  "hire_date": "date",
  "created_at": "datetime",
  "updated_at": "datetime"
}
```

### Create Employee Request
```json
{
  "employee_id": "string",
  "first_name": "string",
  "last_name": "string",
  "email": "string",
  "department_id": "uuid|null",
  "position": "string|null",
  "hire_date": "date"
}
```

### Update Employee Request (PATCH)
```json
{
  "first_name": "string|null",
  "last_name": "string|null",
  "email": "string|null",
  "department_id": "uuid|null",
  "position": "string|null"
}
```

## Validation Rules

### Common Validations
- **Required Fields**: Mark required fields clearly
- **String Length**: Enforce min/max length constraints
- **Email Format**: Validate email addresses
- **Date Validation**: Ensure dates are valid and logical
- **UUID Format**: Validate UUID fields
- **Enum Values**: Restrict to predefined values

### Employee Validation Examples
```json
{
  "employee_id": {
    "required": true,
    "type": "string",
    "min_length": 1,
    "max_length": 50,
    "pattern": "^[A-Z]{3}[0-9]{3}$"
  },
  "email": {
    "required": true,
    "type": "email",
    "unique": true
  },
  "hire_date": {
    "required": true,
    "type": "date",
    "max": "today"
  },
  "employment_status": {
    "type": "enum",
    "values": ["active", "inactive", "terminated"],
    "default": "active"
  }
}
```

## Pagination

### Query Parameters
```
GET /employees?page=1&per_page=20&sort=last_name&order=asc
```

### Standard Parameters
- `page`: Page number (default: 1)
- `per_page`: Items per page (default: 20, max: 100)
- `sort`: Sort field (default: id)
- `order`: Sort order (asc/desc, default: asc)

### Response Format
```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "per_page": 20,
    "total": 150,
    "total_pages": 8,
    "has_next": true,
    "has_prev": false
  }
}
```

## Filtering and Search

### Query Parameters
```
GET /employees?department=IT&status=active&search=john
GET /employees?hire_date_from=2024-01-01&hire_date_to=2024-12-31
```

### Standard Filters
- **Exact Match**: `field=value`
- **Date Range**: `field_from=date&field_to=date`
- **Search**: `search=term` (searches across multiple fields)
- **Multiple Values**: `field=value1,value2`

## Versioning

### URL Versioning (Recommended)
```
GET /v1/employees
GET /v2/employees
```

### Header Versioning (Alternative)
```
GET /employees
Accept: application/vnd.api+json;version=1
```

## Security

### Authentication
```
Authorization: Bearer <jwt_token>
```

### Rate Limiting
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1640995200
```

## Headers

### Request Headers
- `Content-Type: application/json`
- `Accept: application/json`
- `Authorization: Bearer <token>`

### Response Headers
- `Content-Type: application/json`
- `X-Request-ID: <unique_id>`
- `X-Response-Time: <milliseconds>`

## Error Codes

### Standard Error Codes
- `VALIDATION_ERROR` - Input validation failed
- `NOT_FOUND` - Resource not found
- `UNAUTHORIZED` - Authentication required
- `FORBIDDEN` - Access denied
- `CONFLICT` - Resource conflict
- `INTERNAL_ERROR` - Server error
- `SERVICE_UNAVAILABLE` - Service temporarily down

## Best Practices

1. **Consistent Naming**: Use plural nouns for collections
2. **HTTP Methods**: Use appropriate methods for operations
3. **Status Codes**: Return meaningful HTTP status codes
4. **Error Handling**: Provide detailed error messages
5. **Validation**: Validate all input data
6. **Pagination**: Implement pagination for collections
7. **Filtering**: Support filtering and sorting
8. **Versioning**: Version your APIs
9. **Swagger Integration**: Auto-generate OpenAPI documentation from code
10. **Security**: Implement proper authentication and authorization
11. **Idempotency**: Ensure PUT and DELETE operations are idempotent
12. **Caching**: Use appropriate cache headers
13. **Logging**: Log all API requests and responses
14. **Monitoring**: Monitor API performance and errors
15. **Contract Testing**: Use OpenAPI spec for API contract testing

## Swagger/OpenAPI Integration

### Mandatory Documentation
All APIs **MUST** be documented using OpenAPI 3.0 specification with auto-generated Swagger UI.

### OpenAPI Contract Requirements
- All APIs must provide OpenAPI 3.0 specification in YAML format
- Contracts must be stored in `examples/openapi/` directory
- See `examples/openapi/employee-service.yml` for complete contract example

### Implementation Requirements

#### 1. Auto-Generated Documentation
- OpenAPI spec must be generated from code annotations
- Swagger UI must be available at `/docs` endpoint
- ReDoc alternative at `/redoc` endpoint

#### 2. Code-First Approach
- Generate OpenAPI spec from code annotations
- Language-specific examples available in `examples/` directory
- See `examples/rust/openapi-integration.rs` for Rust implementation

#### 3. Validation Integration
- OpenAPI schema constraints must match validation rules
- Error responses must include field-level validation details
- Examples must be provided for all request/response models

#### 4. Development Workflow
1. Write API endpoint with annotations
2. Generate OpenAPI spec automatically
3. Swagger UI updates automatically
4. Frontend teams use generated spec for client code
5. API testing uses spec for contract testing

### Benefits of Integration

1. **Living Documentation**: Always up-to-date with code
2. **Client Generation**: Auto-generate client SDKs
3. **API Testing**: Contract testing and validation
4. **Developer Experience**: Interactive API exploration
5. **Team Collaboration**: Clear API contracts
6. **Validation**: Consistent request/response validation

### Mandatory Elements

Every API endpoint must include:
- [ ] Summary and description
- [ ] Request/response schemas
- [ ] All possible HTTP status codes
- [ ] Authentication requirements
- [ ] Parameter validation rules
- [ ] Realistic examples
- [ ] Error response formats