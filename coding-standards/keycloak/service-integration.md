# Keycloak Service Integration Standards

## 🎯 Overview

Standard patterns for integrating backend services with Keycloak authentication using REST API calls. This guide is language-agnostic and can be implemented in any programming language.

## 🏗️ Architecture

### Realm Structure
- **Realm**: `peopleops` (custom realm, not master)
- **Web Client**: `peopleops-web` (shared across all UI applications)
- **Service Clients**: Auto-registered by each service on startup

### Client Types
```
peopleops-web (Web Client)
├── Shared by all UI applications
├── Standard flow enabled
└── Used for user authentication

service-name (Service Client)
├── Auto-registered by service
├── Service accounts enabled
└── Client-specific roles
```

## 🔧 REST API Integration Pattern

### 1. Admin Authentication

**Get Admin Token:**
```http
POST /realms/master/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=password&client_id=admin-cli&username=admin&password=admin
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIs...",
  "token_type": "Bearer",
  "expires_in": 300
}
```

### 2. Check if Client Exists

**Request:**
```http
GET /admin/realms/peopleops/clients?clientId=service-name
Authorization: Bearer {admin_token}
```

**Response (if exists):**
```json
[
  {
    "id": "uuid-here",
    "clientId": "service-name",
    "name": "Service Name"
  }
]
```

### 3. Create Service Client

**Request:**
```http
POST /admin/realms/peopleops/clients
Authorization: Bearer {admin_token}
Content-Type: application/json

{
  "clientId": "service-name",
  "name": "Service Display Name",
  "description": "Service description",
  "enabled": true,
  "clientAuthenticatorType": "client-secret",
  "secret": "service-secret",
  "protocol": "openid-connect",
  "publicClient": false,
  "serviceAccountsEnabled": true,
  "standardFlowEnabled": false,
  "directAccessGrantsEnabled": false,
  "fullScopeAllowed": true,
  "attributes": {
    "service.name": "service-name",
    "service.version": "1.0.0"
  }
}
```

**Response:**
```http
HTTP/1.1 201 Created
Location: /admin/realms/peopleops/clients/{client-uuid}
```

### 4. Create Client Roles

**For each role (admin, manager, employee):**
```http
POST /admin/realms/peopleops/clients/{client-uuid}/roles
Authorization: Bearer {admin_token}
Content-Type: application/json

{
  "name": "admin",
  "description": "Full access to service"
}
```

## 📋 Configuration Standards

### Environment Variables
```bash
# Keycloak Configuration
KEYCLOAK_REALM=peopleops
KEYCLOAK_CLIENT_ID=service-name
KEYCLOAK_CLIENT_SECRET=service-secret
KEYCLOAK_SERVER_URL=http://localhost:8080
KEYCLOAK_ADMIN_USERNAME=admin
KEYCLOAK_ADMIN_PASSWORD=admin
```

### Client Naming Convention
- **Pattern**: `{service-name}-service`
- **Examples**: `employee-service`, `project-service`, `finance-service`

### Standard Client Roles
Each service should create these roles:
- `admin`: Full access to service
- `manager`: Team/department management access
- `employee`: Basic user access

## 🔐 Security Standards

### Authentication Flow
1. **Master Realm**: Used only for service registration
2. **PeopleOps Realm**: Used for all application authentication
3. **Admin Credentials**: Stored in environment variables

### Client Configuration Template
```json
{
  "clientId": "{service-name}",
  "enabled": true,
  "clientAuthenticatorType": "client-secret",
  "secret": "{service-secret}",
  "protocol": "openid-connect",
  "publicClient": false,
  "serviceAccountsEnabled": true,
  "standardFlowEnabled": false,
  "directAccessGrantsEnabled": false,
  "fullScopeAllowed": true
}
```

## 🔄 Implementation Flow

### Service Startup Sequence
1. **Load Configuration** from environment variables
2. **Authenticate** with Keycloak master realm
3. **Check Client Existence** in peopleops realm
4. **Create Client** if it doesn't exist
5. **Create Standard Roles** (admin, manager, employee)
6. **Continue Service Startup** (graceful degradation if Keycloak fails)

### Error Handling
- **Connection Failures**: Log error, continue startup
- **Authentication Failures**: Log error, continue startup
- **Client Creation Failures**: Log detailed error, continue startup
- **Role Creation Failures**: Log warning, continue startup

## 📊 Monitoring & Logging

### Success Logs
```
🔐 Authenticating with Keycloak...
✅ Authentication successful
🔍 Checking if service-name client exists...
📝 Client does not exist, creating...
✅ Service client registered successfully
🔑 Creating client roles...
✅ Created client role: admin
✅ Created client role: manager
✅ Created client role: employee
```

### Error Logs
```
❌ Failed to authenticate with Keycloak: Connection refused
⚠️  Failed to register service: 400 Bad Request - Invalid client configuration
⚠️  Failed to create client roles: 404 Not Found - Client not found
```

## 🧪 Testing

### Local Development
```bash
# Start Keycloak
docker-compose -f docker-compose.dev.yml up -d

# Verify Keycloak is ready
curl http://localhost:8080/

# Run service (will auto-register)
./start-service.sh
```

### Integration Tests
- Mock Keycloak REST API responses
- Test client registration flow
- Verify role creation
- Test error handling scenarios

## 🌐 Language Examples

### cURL Example
```bash
# Get admin token
TOKEN=$(curl -s -X POST http://localhost:8080/realms/master/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=admin-cli&username=admin&password=admin" \
  | jq -r '.access_token')

# Create client
curl -X POST http://localhost:8080/admin/realms/peopleops/clients \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"clientId":"my-service","enabled":true,"serviceAccountsEnabled":true}'
```

### Python Example
```python
import requests

# Get admin token
token_response = requests.post(
    "http://localhost:8080/realms/master/protocol/openid-connect/token",
    data={
        "grant_type": "password",
        "client_id": "admin-cli",
        "username": "admin",
        "password": "admin"
    }
)
token = token_response.json()["access_token"]

# Create client
client_response = requests.post(
    "http://localhost:8080/admin/realms/peopleops/clients",
    headers={"Authorization": f"Bearer {token}"},
    json={"clientId": "my-service", "enabled": True}
)
```

## 📚 References

- [Keycloak Admin REST API](https://www.keycloak.org/docs-api/latest/rest-api/)
- [Client Registration](https://www.keycloak.org/docs/latest/securing_apps/#_client_registration)
- [Service Accounts](https://www.keycloak.org/docs/latest/server_admin/#_service_accounts)