-- Rollback RBAC Test Data
-- Removes all test data created by seed_rbac_test_data.sql

BEGIN;

DO $$
DECLARE
    test_tenant_id UUID := '00000000-0000-0000-0000-000000000001';
    deleted_count INT;
BEGIN
    RAISE NOTICE '=== Rolling Back RBAC Test Data ===';

    -- Delete test user
    DELETE FROM users WHERE email = 'max.mustermann@acme.test';
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % test user(s)', deleted_count;

    -- Delete user assignments (cascades from users)
    DELETE FROM org_user_assignments WHERE user_id IN (SELECT id FROM users WHERE email = 'max.mustermann@acme.test');
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % user assignments', deleted_count;

    -- Delete user role assignments
    DELETE FROM rbac_user_role_assignments WHERE user_id IN (SELECT id FROM users WHERE email = 'max.mustermann@acme.test');
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % user role assignments', deleted_count;

    -- Delete user permission overrides
    DELETE FROM rbac_user_permission_overrides WHERE user_id IN (SELECT id FROM users WHERE email = 'max.mustermann@acme.test');
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % user permission overrides', deleted_count;

    -- Delete OU role assignments for test tenant
    DELETE FROM org_unit_role_assignments WHERE org_unit_id IN (SELECT id FROM org_units WHERE tenant_id = test_tenant_id);
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % OU role assignments', deleted_count;

    -- Delete role permissions for test roles
    DELETE FROM rbac_role_permissions WHERE role_id IN (SELECT id FROM rbac_roles WHERE tenant_id = test_tenant_id);
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % role permissions', deleted_count;

    -- Delete permission fields
    DELETE FROM rbac_permission_fields WHERE permission_id IN (SELECT id FROM rbac_permissions WHERE resource_id IN (SELECT id FROM rbac_resources WHERE tenant_id = test_tenant_id));
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % permission fields', deleted_count;

    -- Delete permissions for test resources
    DELETE FROM rbac_permissions WHERE resource_id IN (SELECT id FROM rbac_resources WHERE tenant_id = test_tenant_id);
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % permissions', deleted_count;

    -- Delete resource fields
    DELETE FROM rbac_resource_fields WHERE resource_id IN (SELECT id FROM rbac_resources WHERE tenant_id = test_tenant_id);
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % resource fields', deleted_count;

    -- Delete resources
    DELETE FROM rbac_resources WHERE tenant_id = test_tenant_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % resources', deleted_count;

    -- Delete roles
    DELETE FROM rbac_roles WHERE tenant_id = test_tenant_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % roles', deleted_count;

    -- Delete org unit closure for test tenant
    DELETE FROM org_unit_closure WHERE ancestor_unit_id IN (SELECT id FROM org_units WHERE tenant_id = test_tenant_id);
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % closure table entries', deleted_count;

    -- Delete org unit edges for test tenant
    DELETE FROM org_unit_edges WHERE parent_unit_id IN (SELECT id FROM org_units WHERE tenant_id = test_tenant_id);
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % org unit edges', deleted_count;

    -- Delete org units
    DELETE FROM org_units WHERE tenant_id = test_tenant_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % organizational units', deleted_count;

    RAISE NOTICE '=== Rollback Complete ===';
    RAISE NOTICE 'All test data for tenant % has been removed', test_tenant_id;
END$$;

COMMIT;

-- Verification
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== Verification ===';
    RAISE NOTICE 'Run these queries to verify rollback:';
    RAISE NOTICE 'SELECT COUNT(*) FROM org_units WHERE tenant_id = ''00000000-0000-0000-0000-000000000001''; -- Should be 0';
    RAISE NOTICE 'SELECT COUNT(*) FROM rbac_roles WHERE tenant_id = ''00000000-0000-0000-0000-000000000001''; -- Should be 0';
    RAISE NOTICE 'SELECT COUNT(*) FROM rbac_resources WHERE tenant_id = ''00000000-0000-0000-0000-000000000001''; -- Should be 0';
    RAISE NOTICE 'SELECT email FROM users WHERE email = ''max.mustermann@acme.test''; -- Should be empty';
END$$;
