-- Audit Trigger Template
-- Replace {TABLE_NAME} and {COLUMNS} with actual values

CREATE OR REPLACE FUNCTION fn_{TABLE_NAME}_audit_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO {TABLE_NAME}_hist (
            {COLUMNS},
            operation, changed_by, changed_at
        ) VALUES (
            {NEW_VALUES},
            'INSERT', NEW.updated_by, CURRENT_TIMESTAMP
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO {TABLE_NAME}_hist (
            {COLUMNS},
            operation, changed_by, changed_at
        ) VALUES (
            {NEW_VALUES},
            'UPDATE', NEW.updated_by, CURRENT_TIMESTAMP
        );
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO {TABLE_NAME}_hist (
            {COLUMNS},
            operation, changed_by, changed_at
        ) VALUES (
            {OLD_VALUES},
            'DELETE', OLD.updated_by, CURRENT_TIMESTAMP
        );
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_{TABLE_NAME}_audit
    AFTER INSERT OR UPDATE OR DELETE ON {TABLE_NAME}
    FOR EACH ROW EXECUTE FUNCTION fn_{TABLE_NAME}_audit_trigger();

-- Usage Examples:
-- For employees table:
-- Replace {TABLE_NAME} with 'employees'
-- Replace {COLUMNS} with 'id, employee_id, first_name, last_name, email, ...'
-- Replace {NEW_VALUES} with 'NEW.id, NEW.employee_id, NEW.first_name, ...'
-- Replace {OLD_VALUES} with 'OLD.id, OLD.employee_id, OLD.first_name, ...'