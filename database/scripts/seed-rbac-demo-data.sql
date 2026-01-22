-- ============================================================================
-- RBAC Demo Data Generator
-- Creates a complete test scenario for a distributor with matrix organization
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: Create Tenant (using default tenant)
-- ============================================================================
-- Tenant ID: 00000000-0000-0000-0000-000000000001 (already exists in users)

-- ============================================================================
-- STEP 2: Create Organizational Structure
-- ============================================================================

-- Company Level
INSERT INTO org_units (org_unit_type_id, tenant_id, key, display_name, description) VALUES
((SELECT id FROM org_unit_types WHERE key = 'company'), '00000000-0000-0000-0000-000000000001', 'acme-corp', 'Acme Corporation', 'Top-level company')
RETURNING id;

-- Store company ID
DO $$
DECLARE
  company_id UUID;
  acme_germany_id UUID;
  acme_austria_id UUID;
  berlin_branch_id UUID;
  hamburg_branch_id UUID;
  vienna_branch_id UUID;
  sales_dept_id UUID;
  it_dept_id UUID;
  sales_team_id UUID;
BEGIN
  SELECT id INTO company_id FROM org_units WHERE key = 'acme-corp';

  -- Subsidiaries
  INSERT INTO org_units (org_unit_type_id, tenant_id, key, display_name, description) VALUES
  ((SELECT id FROM org_unit_types WHERE key = 'subsidiary'), '00000000-0000-0000-0000-000000000001', 'acme-germany', 'Acme Germany GmbH', 'German subsidiary')
  RETURNING id INTO acme_germany_id;

  INSERT INTO org_units (org_unit_type_id, tenant_id, key, display_name, description) VALUES
  ((SELECT id FROM org_unit_types WHERE key = 'subsidiary'), '00000000-0000-0000-0000-000000000001', 'acme-austria', 'Acme Austria GmbH', 'Austrian subsidiary')
  RETURNING id INTO acme_austria_id;

  -- Branches
  INSERT INTO org_units (org_unit_type_id, tenant_id, key, display_name, description) VALUES
  ((SELECT id FROM org_unit_types WHERE key = 'branch'), '00000000-0000-0000-0000-000000000001', 'berlin-branch', 'Berlin Branch', 'Berlin office')
  RETURNING id INTO berlin_branch_id;

  INSERT INTO org_units (org_unit_type_id, tenant_id, key, display_name, description) VALUES
  ((SELECT id FROM org_unit_types WHERE key = 'branch'), '00000000-0000-0000-0000-000000000001', 'hamburg-branch', 'Hamburg Branch', 'Hamburg office')
  RETURNING id INTO hamburg_branch_id;

  INSERT INTO org_units (org_unit_type_id, tenant_id, key, display_name, description) VALUES
  ((SELECT id FROM org_unit_types WHERE key = 'branch'), '00000000-0000-0000-0000-000000000001', 'vienna-branch', 'Vienna Branch', 'Vienna office')
  RETURNING id INTO vienna_branch_id;

  -- Departments (multi-parent support!)
  INSERT INTO org_units (org_unit_type_id, tenant_id, key, display_name, description) VALUES
  ((SELECT id FROM org_unit_types WHERE key = 'department'), '00000000-0000-0000-0000-000000000001', 'sales-dept', 'Sales Department', 'Sales team across branches')
  RETURNING id INTO sales_dept_id;

  INSERT INTO org_units (org_unit_type_id, tenant_id, key, display_name, description) VALUES
  ((SELECT id FROM org_unit_types WHERE key = 'department'), '00000000-0000-0000-0000-000000000001', 'it-dept', 'IT Department', 'IT support team')
  RETURNING id INTO it_dept_id;

  -- Teams
  INSERT INTO org_units (org_unit_type_id, tenant_id, key, display_name, description) VALUES
  ((SELECT id FROM org_unit_types WHERE key = 'team'), '00000000-0000-0000-0000-000000000001', 'sales-team-a', 'Sales Team A', 'First sales team')
  RETURNING id INTO sales_team_id;

  -- Create edges (hierarchy)
  INSERT INTO org_unit_edges (parent_unit_id, child_unit_id) VALUES
  (company_id, acme_germany_id),
  (company_id, acme_austria_id),
  (acme_germany_id, berlin_branch_id),
  (acme_germany_id, hamburg_branch_id),
  (acme_austria_id, vienna_branch_id),
  -- Sales Department has multiple parents (Matrix!)
  (berlin_branch_id, sales_dept_id),
  (hamburg_branch_id, sales_dept_id),
  (berlin_branch_id, it_dept_id),
  (sales_dept_id, sales_team_id);

  -- Rebuild closure table
  PERFORM rebuild_org_unit_closure();

  RAISE NOTICE 'Organizational structure created successfully';
END $$;

-- ============================================================================
-- STEP 3: Create Roles
-- ============================================================================

INSERT INTO rbac_roles (tenant_id, key, display_name, description, is_system_role) VALUES
('00000000-0000-0000-0000-000000000001', 'super_admin', 'Super Administrator', 'Full system access', true),
('00000000-0000-0000-0000-000000000001', 'manager', 'Manager', 'Can view and manage team data', false),
('00000000-0000-0000-0000-000000000001', 'editor', 'Editor', 'Can create and edit content', false),
('00000000-0000-0000-0000-000000000001', 'viewer', 'Viewer', 'Read-only access', false),
('00000000-0000-0000-0000-000000000001', 'sales_rep', 'Sales Representative', 'Sales operations access', false);

-- ============================================================================
-- STEP 4: Create Resources, Actions, and Permissions
-- ============================================================================

-- Resources
INSERT INTO rbac_resources (tenant_id, key, display_name, description) VALUES
('00000000-0000-0000-0000-000000000001', 'users', 'Users', 'User management'),
('00000000-0000-0000-0000-000000000001', 'orders', 'Orders', 'Order management'),
('00000000-0000-0000-0000-000000000001', 'invoices', 'Invoices', 'Invoice management'),
('00000000-0000-0000-0000-000000000001', 'reports', 'Reports', 'Reporting and analytics');

-- Fields for Users resource
DO $$
DECLARE
  users_resource_id UUID;
BEGIN
  SELECT id INTO users_resource_id FROM rbac_resources WHERE key = 'users';

  INSERT INTO rbac_resource_fields (resource_id, key, display_name, field_type, is_sensitive) VALUES
  (users_resource_id, 'email', 'Email', 'string', false),
  (users_resource_id, 'name', 'Name', 'string', false),
  (users_resource_id, 'phone', 'Phone', 'string', false),
  (users_resource_id, 'salary', 'Salary', 'number', true),
  (users_resource_id, 'ssn', 'Social Security Number', 'string', true);
END $$;

-- Create Permissions (resource:action combinations)
DO $$
DECLARE
  resource_rec RECORD;
  action_rec RECORD;
BEGIN
  FOR resource_rec IN SELECT id, key FROM rbac_resources LOOP
    FOR action_rec IN SELECT id, key FROM rbac_actions WHERE key IN ('read', 'write', 'delete') LOOP
      INSERT INTO rbac_permissions (resource_id, action_id, permission_key)
      VALUES (resource_rec.id, action_rec.id, resource_rec.key || ':' || action_rec.key)
      ON CONFLICT (permission_key) DO NOTHING;
    END LOOP;
  END LOOP;

  RAISE NOTICE 'Permissions created successfully';
END $$;

-- ============================================================================
-- STEP 5: Assign Permissions to Roles
-- ============================================================================

DO $$
DECLARE
  super_admin_role_id UUID;
  manager_role_id UUID;
  editor_role_id UUID;
  viewer_role_id UUID;
  sales_rep_role_id UUID;
BEGIN
  SELECT id INTO super_admin_role_id FROM rbac_roles WHERE key = 'super_admin';
  SELECT id INTO manager_role_id FROM rbac_roles WHERE key = 'manager';
  SELECT id INTO editor_role_id FROM rbac_roles WHERE key = 'editor';
  SELECT id INTO viewer_role_id FROM rbac_roles WHERE key = 'viewer';
  SELECT id INTO sales_rep_role_id FROM rbac_roles WHERE key = 'sales_rep';

  -- Super Admin: All permissions (allow)
  INSERT INTO rbac_role_permissions (role_id, permission_id, effect)
  SELECT super_admin_role_id, id, 'allow'
  FROM rbac_permissions;

  -- Manager: Read all, write orders/reports
  INSERT INTO rbac_role_permissions (role_id, permission_id, effect)
  SELECT manager_role_id, id, 'allow'
  FROM rbac_permissions
  WHERE permission_key LIKE '%:read';

  INSERT INTO rbac_role_permissions (role_id, permission_id, effect)
  SELECT manager_role_id, id, 'allow'
  FROM rbac_permissions
  WHERE permission_key IN ('orders:write', 'reports:write');

  -- Editor: Read all, write orders
  INSERT INTO rbac_role_permissions (role_id, permission_id, effect)
  SELECT editor_role_id, id, 'allow'
  FROM rbac_permissions
  WHERE permission_key LIKE '%:read' OR permission_key = 'orders:write';

  -- Viewer: Read only
  INSERT INTO rbac_role_permissions (role_id, permission_id, effect)
  SELECT viewer_role_id, id, 'allow'
  FROM rbac_permissions
  WHERE permission_key LIKE '%:read';

  -- Sales Rep: Orders and reports
  INSERT INTO rbac_role_permissions (role_id, permission_id, effect)
  SELECT sales_rep_role_id, id, 'allow'
  FROM rbac_permissions
  WHERE permission_key IN ('orders:read', 'orders:write', 'reports:read');

  RAISE NOTICE 'Role permissions assigned successfully';
END $$;

-- ============================================================================
-- STEP 6: Assign Roles to Organizational Units
-- ============================================================================

DO $$
DECLARE
  sales_dept_id UUID;
  it_dept_id UUID;
  manager_role_id UUID;
  editor_role_id UUID;
  viewer_role_id UUID;
BEGIN
  SELECT id INTO sales_dept_id FROM org_units WHERE key = 'sales-dept';
  SELECT id INTO it_dept_id FROM org_units WHERE key = 'it-dept';
  SELECT id INTO manager_role_id FROM rbac_roles WHERE key = 'manager';
  SELECT id INTO editor_role_id FROM rbac_roles WHERE key = 'editor';
  SELECT id INTO viewer_role_id FROM rbac_roles WHERE key = 'viewer';

  -- Sales Department gets Manager role (inherited to children)
  INSERT INTO org_unit_role_assignments (org_unit_id, role_id, is_inherited, priority)
  VALUES (sales_dept_id, manager_role_id, true, 2000);

  -- IT Department gets Editor role
  INSERT INTO org_unit_role_assignments (org_unit_id, role_id, is_inherited, priority)
  VALUES (it_dept_id, editor_role_id, true, 1500);

  RAISE NOTICE 'Roles assigned to organizational units';
END $$;

-- ============================================================================
-- STEP 7: Assign Users to Organizational Units
-- ============================================================================

DO $$
DECLARE
  admin_user_id UUID;
  sales_dept_id UUID;
BEGIN
  SELECT id INTO admin_user_id FROM users WHERE email = 'admin@licenseguard.local';
  SELECT id INTO sales_dept_id FROM org_units WHERE key = 'sales-dept';

  IF admin_user_id IS NOT NULL THEN
    INSERT INTO org_user_assignments (user_id, org_unit_id, is_primary)
    VALUES (admin_user_id, sales_dept_id, true);

    RAISE NOTICE 'Admin user assigned to Sales Department';
  END IF;
END $$;

-- ============================================================================
-- STEP 8: Create Permission Override Example
-- ============================================================================

DO $$
DECLARE
  admin_user_id UUID;
  users_delete_permission_id UUID;
BEGIN
  SELECT id INTO admin_user_id FROM users WHERE email = 'admin@licenseguard.local';
  SELECT id INTO users_delete_permission_id FROM rbac_permissions WHERE permission_key = 'users:delete';

  IF admin_user_id IS NOT NULL AND users_delete_permission_id IS NOT NULL THEN
    -- Override: Admin can delete users (even though Manager role doesn't allow it)
    INSERT INTO rbac_user_permission_overrides (user_id, permission_id, effect, reason)
    VALUES (admin_user_id, users_delete_permission_id, 'allow', 'Admin needs delete access for user management');

    RAISE NOTICE 'Permission override created for admin user';
  END IF;
END $$;

COMMIT;

-- ============================================================================
-- Verification Queries
-- ============================================================================

SELECT 'Demo data created successfully!' as status;

SELECT 'Organizational Units:' as info, COUNT(*) as count FROM org_units;
SELECT 'Org Unit Edges:' as info, COUNT(*) as count FROM org_unit_edges;
SELECT 'Org Unit Closure:' as info, COUNT(*) as count FROM org_unit_closure;
SELECT 'Roles:' as info, COUNT(*) as count FROM rbac_roles;
SELECT 'Resources:' as info, COUNT(*) as count FROM rbac_resources;
SELECT 'Permissions:' as info, COUNT(*) as count FROM rbac_permissions;
SELECT 'Role Permissions:' as info, COUNT(*) as count FROM rbac_role_permissions;
SELECT 'OU Role Assignments:' as info, COUNT(*) as count FROM org_unit_role_assignments;
SELECT 'User Assignments:' as info, COUNT(*) as count FROM org_user_assignments;
SELECT 'User Overrides:' as info, COUNT(*) as count FROM rbac_user_permission_overrides;

-- Show organizational hierarchy
SELECT
  ou.key,
  ou.display_name,
  ot.display_name as type,
  ot.hierarchy_level
FROM org_units ou
JOIN org_unit_types ot ON ot.id = ou.org_unit_type_id
ORDER BY ot.hierarchy_level, ou.display_name;
