-- RBAC Test Data Seed
-- Creates test data for testing the RBAC system
-- Can be rolled back using rollback_rbac_test_data.sql

BEGIN;

-- Test Tenant ID (using a fixed UUID for testing)
DO $$
DECLARE
    test_tenant_id UUID := '00000000-0000-0000-0000-000000000001';

    -- Organizational Units
    company_id UUID;
    subsidiary_de_id UUID;
    subsidiary_at_id UUID;
    branch_berlin_id UUID;
    branch_munich_id UUID;
    branch_vienna_id UUID;
    dept_sales_id UUID;
    dept_it_id UUID;
    dept_finance_id UUID;
    team_sales_berlin_id UUID;
    team_sales_munich_id UUID;

    -- Roles
    role_super_admin_id UUID;
    role_manager_id UUID;
    role_editor_id UUID;
    role_viewer_id UUID;

    -- Resources
    resource_users_id UUID;
    resource_orders_id UUID;
    resource_invoices_id UUID;

    -- Resource Fields
    field_user_email_id UUID;
    field_user_name_id UUID;
    field_user_salary_id UUID;
    field_order_amount_id UUID;
    field_order_customer_id UUID;
    field_invoice_total_id UUID;

    -- Actions
    action_read_id UUID;
    action_write_id UUID;
    action_delete_id UUID;
    action_approve_id UUID;

    -- Permissions
    perm_users_read_id UUID;
    perm_users_write_id UUID;
    perm_users_delete_id UUID;
    perm_orders_read_id UUID;
    perm_orders_write_id UUID;
    perm_orders_approve_id UUID;
    perm_invoices_read_id UUID;
    perm_invoices_write_id UUID;

    -- Test User
    test_user_id UUID;

    -- OU Type IDs
    company_type_id UUID;
    subsidiary_type_id UUID;
    branch_type_id UUID;
    department_type_id UUID;
    team_type_id UUID;
BEGIN
    -- Get OU Type IDs
    SELECT id INTO company_type_id FROM org_unit_types WHERE key = 'company';
    SELECT id INTO subsidiary_type_id FROM org_unit_types WHERE key = 'subsidiary';
    SELECT id INTO branch_type_id FROM org_unit_types WHERE key = 'branch';
    SELECT id INTO department_type_id FROM org_unit_types WHERE key = 'department';
    SELECT id INTO team_type_id FROM org_unit_types WHERE key = 'team';

    -- Get Action IDs
    SELECT id INTO action_read_id FROM rbac_actions WHERE key = 'read';
    SELECT id INTO action_write_id FROM rbac_actions WHERE key = 'write';
    SELECT id INTO action_delete_id FROM rbac_actions WHERE key = 'delete';
    SELECT id INTO action_approve_id FROM rbac_actions WHERE key = 'approve';

    RAISE NOTICE '=== Creating Test Organizational Structure ===';

    -- Create Company (Level 1)
    INSERT INTO org_units (id, org_unit_type_id, tenant_id, key, display_name, description, is_active)
    VALUES (gen_random_uuid(), company_type_id, test_tenant_id, 'acme_corp', 'Acme Corporation', 'Main company', true)
    RETURNING id INTO company_id;
    RAISE NOTICE 'Created Company: Acme Corporation (%)' , company_id;

    -- Create Subsidiaries (Level 2)
    INSERT INTO org_units (id, org_unit_type_id, tenant_id, key, display_name, description, is_active)
    VALUES (gen_random_uuid(), subsidiary_type_id, test_tenant_id, 'acme_germany', 'Acme Germany', 'German subsidiary', true)
    RETURNING id INTO subsidiary_de_id;

    INSERT INTO org_units (id, org_unit_type_id, tenant_id, key, display_name, description, is_active)
    VALUES (gen_random_uuid(), subsidiary_type_id, test_tenant_id, 'acme_austria', 'Acme Austria', 'Austrian subsidiary', true)
    RETURNING id INTO subsidiary_at_id;

    RAISE NOTICE 'Created Subsidiaries: Germany (%), Austria (%)', subsidiary_de_id, subsidiary_at_id;

    -- Create Branches (Level 3)
    INSERT INTO org_units (id, org_unit_type_id, tenant_id, key, display_name, description, is_active)
    VALUES (gen_random_uuid(), branch_type_id, test_tenant_id, 'berlin_branch', 'Berlin Branch', 'Berlin office', true)
    RETURNING id INTO branch_berlin_id;

    INSERT INTO org_units (id, org_unit_type_id, tenant_id, key, display_name, description, is_active)
    VALUES (gen_random_uuid(), branch_type_id, test_tenant_id, 'munich_branch', 'Munich Branch', 'Munich office', true)
    RETURNING id INTO branch_munich_id;

    INSERT INTO org_units (id, org_unit_type_id, tenant_id, key, display_name, description, is_active)
    VALUES (gen_random_uuid(), branch_type_id, test_tenant_id, 'vienna_branch', 'Vienna Branch', 'Vienna office', true)
    RETURNING id INTO branch_vienna_id;

    RAISE NOTICE 'Created Branches: Berlin (%), Munich (%), Vienna (%)', branch_berlin_id, branch_munich_id, branch_vienna_id;

    -- Create Departments (Level 4, multi-parent capable)
    INSERT INTO org_units (id, org_unit_type_id, tenant_id, key, display_name, description, is_active)
    VALUES (gen_random_uuid(), department_type_id, test_tenant_id, 'sales_dept', 'Sales Department', 'Sales team', true)
    RETURNING id INTO dept_sales_id;

    INSERT INTO org_units (id, org_unit_type_id, tenant_id, key, display_name, description, is_active)
    VALUES (gen_random_uuid(), department_type_id, test_tenant_id, 'it_dept', 'IT Department', 'IT team', true)
    RETURNING id INTO dept_it_id;

    INSERT INTO org_units (id, org_unit_type_id, tenant_id, key, display_name, description, is_active)
    VALUES (gen_random_uuid(), department_type_id, test_tenant_id, 'finance_dept', 'Finance Department', 'Finance team', true)
    RETURNING id INTO dept_finance_id;

    RAISE NOTICE 'Created Departments: Sales (%), IT (%), Finance (%)', dept_sales_id, dept_it_id, dept_finance_id;

    -- Create Teams (Level 5)
    INSERT INTO org_units (id, org_unit_type_id, tenant_id, key, display_name, description, is_active)
    VALUES (gen_random_uuid(), team_type_id, test_tenant_id, 'sales_berlin_team', 'Berlin Sales Team', 'Sales team in Berlin', true)
    RETURNING id INTO team_sales_berlin_id;

    INSERT INTO org_units (id, org_unit_type_id, tenant_id, key, display_name, description, is_active)
    VALUES (gen_random_uuid(), team_type_id, test_tenant_id, 'sales_munich_team', 'Munich Sales Team', 'Sales team in Munich', true)
    RETURNING id INTO team_sales_munich_id;

    RAISE NOTICE 'Created Teams: Berlin Sales (%), Munich Sales (%)', team_sales_berlin_id, team_sales_munich_id;

    -- Build Hierarchy Edges
    RAISE NOTICE '=== Building Hierarchy ===';

    -- Company → Subsidiaries
    INSERT INTO org_unit_edges (parent_unit_id, child_unit_id) VALUES (company_id, subsidiary_de_id);
    INSERT INTO org_unit_edges (parent_unit_id, child_unit_id) VALUES (company_id, subsidiary_at_id);

    -- Subsidiaries → Branches
    INSERT INTO org_unit_edges (parent_unit_id, child_unit_id) VALUES (subsidiary_de_id, branch_berlin_id);
    INSERT INTO org_unit_edges (parent_unit_id, child_unit_id) VALUES (subsidiary_de_id, branch_munich_id);
    INSERT INTO org_unit_edges (parent_unit_id, child_unit_id) VALUES (subsidiary_at_id, branch_vienna_id);

    -- Branches → Departments (multi-parent: Sales exists in multiple branches)
    INSERT INTO org_unit_edges (parent_unit_id, child_unit_id) VALUES (branch_berlin_id, dept_sales_id);
    INSERT INTO org_unit_edges (parent_unit_id, child_unit_id) VALUES (branch_berlin_id, dept_it_id);
    INSERT INTO org_unit_edges (parent_unit_id, child_unit_id) VALUES (branch_munich_id, dept_sales_id);
    INSERT INTO org_unit_edges (parent_unit_id, child_unit_id) VALUES (branch_munich_id, dept_finance_id);
    INSERT INTO org_unit_edges (parent_unit_id, child_unit_id) VALUES (branch_vienna_id, dept_sales_id);

    -- Departments → Teams
    INSERT INTO org_unit_edges (parent_unit_id, child_unit_id) VALUES (dept_sales_id, team_sales_berlin_id);
    INSERT INTO org_unit_edges (parent_unit_id, child_unit_id) VALUES (dept_sales_id, team_sales_munich_id);

    -- Rebuild closure table
    RAISE NOTICE '=== Rebuilding Closure Table ===';
    DELETE FROM org_unit_closure;

    -- Self-relations
    INSERT INTO org_unit_closure (ancestor_unit_id, descendant_unit_id, depth)
    SELECT id, id, 0 FROM org_units WHERE tenant_id = test_tenant_id;

    -- Transitive closure
    WITH RECURSIVE paths AS (
        SELECT parent_unit_id as ancestor_unit_id,
               child_unit_id as descendant_unit_id,
               1 as depth
        FROM org_unit_edges
        UNION ALL
        SELECT p.ancestor_unit_id,
               e.child_unit_id as descendant_unit_id,
               p.depth + 1 as depth
        FROM paths p
        JOIN org_unit_edges e ON e.parent_unit_id = p.descendant_unit_id
        WHERE p.depth < 10
    )
    INSERT INTO org_unit_closure (ancestor_unit_id, descendant_unit_id, depth)
    SELECT ancestor_unit_id, descendant_unit_id, MIN(depth) as depth
    FROM paths
    GROUP BY ancestor_unit_id, descendant_unit_id;

    RAISE NOTICE '=== Creating Test Roles ===';

    -- Create Roles
    INSERT INTO rbac_roles (id, tenant_id, key, display_name, description, is_system_role, is_active)
    VALUES (gen_random_uuid(), test_tenant_id, 'super_admin', 'Super Admin', 'Full system access', true, true)
    RETURNING id INTO role_super_admin_id;

    INSERT INTO rbac_roles (id, tenant_id, key, display_name, description, is_system_role, is_active)
    VALUES (gen_random_uuid(), test_tenant_id, 'manager', 'Manager', 'Manager role with approval rights', false, true)
    RETURNING id INTO role_manager_id;

    INSERT INTO rbac_roles (id, tenant_id, key, display_name, description, is_system_role, is_active)
    VALUES (gen_random_uuid(), test_tenant_id, 'editor', 'Editor', 'Can read and write data', false, true)
    RETURNING id INTO role_editor_id;

    INSERT INTO rbac_roles (id, tenant_id, key, display_name, description, is_system_role, is_active)
    VALUES (gen_random_uuid(), test_tenant_id, 'viewer', 'Viewer', 'Read-only access', false, true)
    RETURNING id INTO role_viewer_id;

    RAISE NOTICE 'Created Roles: Super Admin (%), Manager (%), Editor (%), Viewer (%)', role_super_admin_id, role_manager_id, role_editor_id, role_viewer_id;

    RAISE NOTICE '=== Creating Test Resources ===';

    -- Create Resources
    INSERT INTO rbac_resources (id, tenant_id, key, display_name, description, is_active)
    VALUES (gen_random_uuid(), test_tenant_id, 'users', 'Users', 'User management', true)
    RETURNING id INTO resource_users_id;

    INSERT INTO rbac_resources (id, tenant_id, key, display_name, description, is_active)
    VALUES (gen_random_uuid(), test_tenant_id, 'orders', 'Orders', 'Order management', true)
    RETURNING id INTO resource_orders_id;

    INSERT INTO rbac_resources (id, tenant_id, key, display_name, description, is_active)
    VALUES (gen_random_uuid(), test_tenant_id, 'invoices', 'Invoices', 'Invoice management', true)
    RETURNING id INTO resource_invoices_id;

    RAISE NOTICE 'Created Resources: Users (%), Orders (%), Invoices (%)', resource_users_id, resource_orders_id, resource_invoices_id;

    -- Create Resource Fields
    INSERT INTO rbac_resource_fields (id, resource_id, key, display_name, field_type, is_sensitive, is_active)
    VALUES (gen_random_uuid(), resource_users_id, 'email', 'Email', 'string', false, true)
    RETURNING id INTO field_user_email_id;

    INSERT INTO rbac_resource_fields (id, resource_id, key, display_name, field_type, is_sensitive, is_active)
    VALUES (gen_random_uuid(), resource_users_id, 'name', 'Name', 'string', false, true)
    RETURNING id INTO field_user_name_id;

    INSERT INTO rbac_resource_fields (id, resource_id, key, display_name, field_type, is_sensitive, is_active)
    VALUES (gen_random_uuid(), resource_users_id, 'salary', 'Salary', 'number', true, true)
    RETURNING id INTO field_user_salary_id;

    INSERT INTO rbac_resource_fields (id, resource_id, key, display_name, field_type, is_sensitive, is_active)
    VALUES (gen_random_uuid(), resource_orders_id, 'amount', 'Amount', 'number', false, true)
    RETURNING id INTO field_order_amount_id;

    INSERT INTO rbac_resource_fields (id, resource_id, key, display_name, field_type, is_sensitive, is_active)
    VALUES (gen_random_uuid(), resource_orders_id, 'customer', 'Customer', 'string', false, true)
    RETURNING id INTO field_order_customer_id;

    INSERT INTO rbac_resource_fields (id, resource_id, key, display_name, field_type, is_sensitive, is_active)
    VALUES (gen_random_uuid(), resource_invoices_id, 'total', 'Total', 'number', false, true)
    RETURNING id INTO field_invoice_total_id;

    RAISE NOTICE 'Created Resource Fields';

    RAISE NOTICE '=== Creating Permissions ===';

    -- Create Permissions
    INSERT INTO rbac_permissions (id, resource_id, action_id, permission_key, description, is_active)
    VALUES (gen_random_uuid(), resource_users_id, action_read_id, 'users:read', 'Read user data', true)
    RETURNING id INTO perm_users_read_id;

    INSERT INTO rbac_permissions (id, resource_id, action_id, permission_key, description, is_active)
    VALUES (gen_random_uuid(), resource_users_id, action_write_id, 'users:write', 'Modify user data', true)
    RETURNING id INTO perm_users_write_id;

    INSERT INTO rbac_permissions (id, resource_id, action_id, permission_key, description, is_active)
    VALUES (gen_random_uuid(), resource_users_id, action_delete_id, 'users:delete', 'Delete users', true)
    RETURNING id INTO perm_users_delete_id;

    INSERT INTO rbac_permissions (id, resource_id, action_id, permission_key, description, is_active)
    VALUES (gen_random_uuid(), resource_orders_id, action_read_id, 'orders:read', 'Read orders', true)
    RETURNING id INTO perm_orders_read_id;

    INSERT INTO rbac_permissions (id, resource_id, action_id, permission_key, description, is_active)
    VALUES (gen_random_uuid(), resource_orders_id, action_write_id, 'orders:write', 'Modify orders', true)
    RETURNING id INTO perm_orders_write_id;

    INSERT INTO rbac_permissions (id, resource_id, action_id, permission_key, description, is_active)
    VALUES (gen_random_uuid(), resource_orders_id, action_approve_id, 'orders:approve', 'Approve orders', true)
    RETURNING id INTO perm_orders_approve_id;

    INSERT INTO rbac_permissions (id, resource_id, action_id, permission_key, description, is_active)
    VALUES (gen_random_uuid(), resource_invoices_id, action_read_id, 'invoices:read', 'Read invoices', true)
    RETURNING id INTO perm_invoices_read_id;

    INSERT INTO rbac_permissions (id, resource_id, action_id, permission_key, description, is_active)
    VALUES (gen_random_uuid(), resource_invoices_id, action_write_id, 'invoices:write', 'Modify invoices', true)
    RETURNING id INTO perm_invoices_write_id;

    RAISE NOTICE 'Created Permissions';

    RAISE NOTICE '=== Assigning Permissions to Roles ===';

    -- Super Admin: Full access
    INSERT INTO rbac_role_permissions (role_id, permission_id, effect)
    VALUES
        (role_super_admin_id, perm_users_read_id, 'allow'),
        (role_super_admin_id, perm_users_write_id, 'allow'),
        (role_super_admin_id, perm_users_delete_id, 'allow'),
        (role_super_admin_id, perm_orders_read_id, 'allow'),
        (role_super_admin_id, perm_orders_write_id, 'allow'),
        (role_super_admin_id, perm_orders_approve_id, 'allow'),
        (role_super_admin_id, perm_invoices_read_id, 'allow'),
        (role_super_admin_id, perm_invoices_write_id, 'allow');

    -- Manager: Can approve orders
    INSERT INTO rbac_role_permissions (role_id, permission_id, effect)
    VALUES
        (role_manager_id, perm_users_read_id, 'allow'),
        (role_manager_id, perm_orders_read_id, 'allow'),
        (role_manager_id, perm_orders_write_id, 'allow'),
        (role_manager_id, perm_orders_approve_id, 'allow'),
        (role_manager_id, perm_invoices_read_id, 'allow');

    -- Editor: Read/Write but no delete or approve
    INSERT INTO rbac_role_permissions (role_id, permission_id, effect)
    VALUES
        (role_editor_id, perm_users_read_id, 'allow'),
        (role_editor_id, perm_users_write_id, 'allow'),
        (role_editor_id, perm_orders_read_id, 'allow'),
        (role_editor_id, perm_orders_write_id, 'allow'),
        (role_editor_id, perm_invoices_read_id, 'allow'),
        (role_editor_id, perm_invoices_write_id, 'allow');

    -- Viewer: Read-only
    INSERT INTO rbac_role_permissions (role_id, permission_id, effect)
    VALUES
        (role_viewer_id, perm_users_read_id, 'allow'),
        (role_viewer_id, perm_orders_read_id, 'allow'),
        (role_viewer_id, perm_invoices_read_id, 'allow');

    RAISE NOTICE 'Assigned Permissions to Roles';

    RAISE NOTICE '=== Assigning Roles to Organizational Units ===';

    -- Company level: Super Admin
    INSERT INTO org_unit_role_assignments (org_unit_id, role_id, is_inherited, priority)
    VALUES (company_id, role_super_admin_id, true, 1000);

    -- Sales Department: Editor role
    INSERT INTO org_unit_role_assignments (org_unit_id, role_id, is_inherited, priority)
    VALUES (dept_sales_id, role_editor_id, true, 2000);

    -- Berlin Branch: Manager role
    INSERT INTO org_unit_role_assignments (org_unit_id, role_id, is_inherited, priority)
    VALUES (branch_berlin_id, role_manager_id, true, 1500);

    RAISE NOTICE 'Assigned Roles to OUs';

    RAISE NOTICE '=== Creating Test User ===';

    -- Create a test user
    INSERT INTO users (id, email, name, is_active, password_hash, role)
    VALUES (gen_random_uuid(), 'max.mustermann@acme.test', 'Max Mustermann', true, '$2a$10$abcdefghijklmnopqrstuvwxyz', 'user')
    RETURNING id INTO test_user_id;

    RAISE NOTICE 'Created Test User: max.mustermann@acme.test (%)' , test_user_id;

    -- Assign user to Sales Department (multi-parent)
    INSERT INTO org_user_assignments (user_id, org_unit_id, is_primary)
    VALUES (test_user_id, dept_sales_id, true);

    -- Direct role assignment: Viewer role globally
    INSERT INTO rbac_user_role_assignments (user_id, role_id, scope_type, scope_org_unit_id)
    VALUES (test_user_id, role_viewer_id, 'global', NULL);

    -- User override: Deny users:delete
    INSERT INTO rbac_user_permission_overrides (user_id, permission_id, effect, reason)
    VALUES (test_user_id, perm_users_delete_id, 'deny', 'Test user should not delete users');

    RAISE NOTICE 'Assigned User to Sales Department and applied permissions';

    RAISE NOTICE '=== Test Data Seed Complete ===';
    RAISE NOTICE 'Summary:';
    RAISE NOTICE '- 11 Organizational Units created';
    RAISE NOTICE '- 4 Roles created';
    RAISE NOTICE '- 3 Resources with 6 Fields created';
    RAISE NOTICE '- 8 Permissions created';
    RAISE NOTICE '- 1 Test User created (max.mustermann@acme.test)';
END$$;

COMMIT;

-- Verification Queries
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== Verification ===';
    RAISE NOTICE 'Run these queries to verify:';
    RAISE NOTICE 'SELECT COUNT(*) FROM org_units; -- Should be 11';
    RAISE NOTICE 'SELECT COUNT(*) FROM rbac_roles; -- Should be 4';
    RAISE NOTICE 'SELECT COUNT(*) FROM rbac_resources; -- Should be 3';
    RAISE NOTICE 'SELECT COUNT(*) FROM rbac_permissions; -- Should be 8';
    RAISE NOTICE 'SELECT email FROM users WHERE email = ''max.mustermann@acme.test'';';
END$$;
