# Microservice Database Design Standards

This document outlines database design principles for microservices architecture.

## Domain Separation

### Database Per Domain
Each domain/microservice must have its own database:
- **Employee Domain**: Employee service database
- **Project Domain**: Project management database  
- **Contract Domain**: Contract management database
- **Reporting Domain**: Reporting and analytics database

### No Cross-Domain Foreign Keys

❌ **Avoid cross-domain foreign key constraints:**
```sql
-- DON'T DO THIS
CREATE TABLE assignments (
    id UUID PRIMARY KEY,
    employee_id UUID REFERENCES employees(id),  -- ❌ Cross-domain FK
    project_id UUID REFERENCES projects.projects(id)  -- ❌ Cross-domain FK
);
```

✅ **Use UUID references without constraints:**
```sql
-- DO THIS INSTEAD
CREATE TABLE assignments (
    id UUID PRIMARY KEY,
    employee_id UUID,  -- ✅ UUID reference, no FK constraint
    project_id UUID,   -- ✅ UUID reference, no FK constraint
    project_name VARCHAR(100),  -- ✅ Denormalized for performance
    -- other fields...
);
```

## Data Consistency Strategies

### 1. Eventual Consistency
Accept that data across domains may be temporarily inconsistent:
- Use event-driven architecture for synchronization
- Implement compensation patterns for failures
- Design for idempotent operations

### 2. Denormalization
Store frequently accessed cross-domain data locally:
```sql
CREATE TABLE assignments (
    id UUID PRIMARY KEY,
    employee_id UUID,
    project_id UUID,
    project_name VARCHAR(100),    -- Denormalized from project domain
    employee_name VARCHAR(200),   -- Denormalized from employee domain
    -- other fields...
);
```

### 3. API-Based Validation
Validate cross-domain references through API calls:
```rust
// Validate employee exists before creating assignment
pub async fn create_assignment(assignment: CreateAssignmentRequest) -> Result<Assignment> {
    // Validate employee exists via Employee Service API
    let employee = employee_service.get_employee(assignment.employee_id).await?;
    
    // Validate project exists via Project Service API  
    let project = project_service.get_project(assignment.project_id).await?;
    
    // Create assignment with denormalized data
    let assignment = Assignment {
        employee_id: assignment.employee_id,
        project_id: assignment.project_id,
        project_name: project.name,  // Denormalized
        employee_name: format!("{} {}", employee.first_name, employee.last_name),
        // ...
    };
    
    repository.create_assignment(assignment).await
}
```

## Event-Driven Synchronization

### Domain Events
Each domain publishes events for significant changes:

```rust
// Employee domain publishes events
#[derive(Serialize)]
pub enum EmployeeEvent {
    EmployeeCreated { id: UUID, name: String, email: String },
    EmployeeUpdated { id: UUID, name: String, email: String },
    EmployeeDeactivated { id: UUID },
}

// Project domain publishes events
#[derive(Serialize)]
pub enum ProjectEvent {
    ProjectCreated { id: UUID, name: String, client: String },
    ProjectUpdated { id: UUID, name: String, status: String },
    ProjectCompleted { id: UUID },
}
```

### Event Handlers
Other domains subscribe to relevant events:

```rust
// Assignment service listens to employee events
pub async fn handle_employee_updated(event: EmployeeUpdated) -> Result<()> {
    // Update denormalized employee data in assignments
    assignment_repository
        .update_employee_name(event.id, &event.name)
        .await?;
    
    Ok(())
}

// Assignment service listens to project events
pub async fn handle_project_updated(event: ProjectUpdated) -> Result<()> {
    // Update denormalized project data in assignments
    assignment_repository
        .update_project_name(event.id, &event.name)
        .await?;
    
    Ok(())
}
```

## Data Integrity Patterns

### 1. Saga Pattern
For complex cross-domain transactions:
```rust
pub struct CreateEmployeeProjectAssignmentSaga {
    employee_service: EmployeeService,
    project_service: ProjectService,
    assignment_service: AssignmentService,
}

impl CreateEmployeeProjectAssignmentSaga {
    pub async fn execute(&self, request: AssignmentRequest) -> Result<()> {
        // Step 1: Validate employee exists
        let employee = self.employee_service.get_employee(request.employee_id).await?;
        
        // Step 2: Validate project exists and has capacity
        let project = self.project_service.get_project(request.project_id).await?;
        
        // Step 3: Create assignment
        let assignment = self.assignment_service.create_assignment(request).await?;
        
        // Step 4: Update project capacity (if needed)
        self.project_service.update_capacity(request.project_id, -1).await?;
        
        Ok(())
    }
}
```

### 2. Compensation Actions
Handle failures with compensating transactions:
```rust
pub async fn compensate_assignment_creation(&self, assignment_id: UUID) -> Result<()> {
    let assignment = self.assignment_service.get_assignment(assignment_id).await?;
    
    // Compensate: Remove assignment
    self.assignment_service.delete_assignment(assignment_id).await?;
    
    // Compensate: Restore project capacity
    self.project_service.update_capacity(assignment.project_id, 1).await?;
    
    Ok(())
}
```

## Best Practices

### 1. UUID as Primary Keys
Always use UUIDs for cross-domain references:
```sql
CREATE TABLE assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL,  -- UUID reference
    project_id UUID NOT NULL,   -- UUID reference
    -- other fields...
);
```

### 2. Denormalize Frequently Accessed Data
Store commonly needed cross-domain data locally:
- Employee name in assignments
- Project name in assignments  
- Client name in project assignments

### 3. Implement Soft Deletes
Use soft deletes to maintain referential integrity:
```sql
CREATE TABLE assignments (
    id UUID PRIMARY KEY,
    employee_id UUID,
    project_id UUID,
    deleted_at TIMESTAMPTZ,  -- Soft delete
    sys_period tstzrange,    -- Audit trail
    -- other fields...
);
```

### 4. API-First Validation
Always validate cross-domain references via API calls before creating relationships.

### 5. Event Sourcing for Critical Data
Consider event sourcing for domains with complex state changes and audit requirements.

## Anti-Patterns to Avoid

❌ **Cross-Domain Foreign Keys**: Never create FK constraints across domains
❌ **Shared Databases**: Each domain must have its own database
❌ **Synchronous Cross-Domain Calls in Transactions**: Use async patterns
❌ **Assuming Strong Consistency**: Design for eventual consistency
❌ **Ignoring Compensation**: Always plan for failure scenarios

## Monitoring and Observability

### Track Cross-Domain Consistency
- Monitor event processing delays
- Alert on failed cross-domain validations
- Track compensation action executions
- Measure API response times for validation calls

### Data Quality Metrics
- Orphaned references (employee_id with no corresponding employee)
- Stale denormalized data
- Failed event processing rates