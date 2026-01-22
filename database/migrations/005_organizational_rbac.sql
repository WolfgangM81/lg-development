-- ============================================================================
-- Migration 005: Multi-Tenant Organizational RBAC System
-- ============================================================================
-- Destruktive Migration: Ersetzt alte perm_* Tabellen mit org_* + rbac_*
-- Ermöglicht Matrix-Organisation und Field-Level Permissions
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: BACKUP & DROP OLD TABLES
-- ============================================================================

-- Optional Backup (auskommentiert falls nicht benötigt)
-- CREATE TABLE _backup_perm_variants AS SELECT * FROM perm_variants;
-- CREATE TABLE _backup_perm_groups AS SELECT * FROM perm_groups;
-- CREATE TABLE _backup_perm_modules AS SELECT * FROM perm_modules;

-- Destruktiv: Alte Tabellen löschen
DROP TABLE IF EXISTS perm_user_overrides CASCADE;
DROP TABLE IF EXISTS perm_variant_rules CASCADE;
DROP TABLE IF EXISTS perm_group_variants CASCADE;
DROP TABLE IF EXISTS perm_user_groups CASCADE;
DROP TABLE IF EXISTS perm_group_closure CASCADE;
DROP TABLE IF EXISTS perm_group_edges CASCADE;
DROP TABLE IF EXISTS perm_groups CASCADE;
DROP TABLE IF EXISTS perm_variants CASCADE;
DROP TABLE IF EXISTS perm_group_permissions CASCADE;
DROP TABLE IF EXISTS perm_permissions CASCADE;
DROP TABLE IF EXISTS perm_actions CASCADE;
DROP TABLE IF EXISTS perm_modules CASCADE;

-- ============================================================================
-- STEP 2: ORGANIZATIONAL STRUCTURE TABLES
-- ============================================================================

-- Organizational Unit Types (Company, Subsidiary, Branch, Department, Team)
CREATE TABLE org_unit_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key VARCHAR(50) NOT NULL UNIQUE,
  display_name VARCHAR(100) NOT NULL,
  hierarchy_level INT NOT NULL CHECK (hierarchy_level > 0),
  allows_multi_parent BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE org_unit_types IS 'Defines types of organizational units (Company, Branch, Department, Team)';
COMMENT ON COLUMN org_unit_types.allows_multi_parent IS 'Whether units of this type can have multiple parent units (matrix organization)';

-- Organizational Units (Matrix-capable hierarchy)
CREATE TABLE org_units (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_unit_type_id UUID NOT NULL REFERENCES org_unit_types(id) ON DELETE RESTRICT,
  tenant_id UUID NOT NULL,
  key VARCHAR(100) NOT NULL,
  display_name VARCHAR(255) NOT NULL,
  description TEXT,
  metadata JSONB,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tenant_id, key)
);

CREATE INDEX idx_org_units_tenant ON org_units(tenant_id);
CREATE INDEX idx_org_units_type ON org_units(org_unit_type_id);
CREATE INDEX idx_org_units_active ON org_units(is_active) WHERE is_active = true;

COMMENT ON TABLE org_units IS 'Organizational units within the hierarchy';
COMMENT ON COLUMN org_units.metadata IS 'Flexible JSON field for custom attributes';

-- OU Hierarchy Edges (Multi-Parent Support)
CREATE TABLE org_unit_edges (
  parent_unit_id UUID NOT NULL REFERENCES org_units(id) ON DELETE CASCADE,
  child_unit_id UUID NOT NULL REFERENCES org_units(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (parent_unit_id, child_unit_id),
  CHECK (parent_unit_id != child_unit_id)
);

CREATE INDEX idx_org_unit_edges_parent ON org_unit_edges(parent_unit_id);
CREATE INDEX idx_org_unit_edges_child ON org_unit_edges(child_unit_id);

COMMENT ON TABLE org_unit_edges IS 'Direct parent-child relationships between organizational units';

-- OU Closure Table (Transitive Closure for Performance)
CREATE TABLE org_unit_closure (
  ancestor_unit_id UUID NOT NULL REFERENCES org_units(id) ON DELETE CASCADE,
  descendant_unit_id UUID NOT NULL REFERENCES org_units(id) ON DELETE CASCADE,
  depth INT NOT NULL CHECK (depth >= 0),
  PRIMARY KEY (ancestor_unit_id, descendant_unit_id)
);

CREATE INDEX idx_org_unit_closure_ancestor ON org_unit_closure(ancestor_unit_id);
CREATE INDEX idx_org_unit_closure_descendant ON org_unit_closure(descendant_unit_id);
CREATE INDEX idx_org_unit_closure_depth ON org_unit_closure(depth);

COMMENT ON TABLE org_unit_closure IS 'Transitive closure for efficient ancestor/descendant queries (O(1) lookup)';
COMMENT ON COLUMN org_unit_closure.depth IS 'Distance from ancestor to descendant (0 = self-reference)';

-- ============================================================================
-- STEP 3: RBAC CORE TABLES
-- ============================================================================

-- Roles (What users can DO)
CREATE TABLE rbac_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  key VARCHAR(100) NOT NULL,
  display_name VARCHAR(255) NOT NULL,
  description TEXT,
  is_system_role BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tenant_id, key)
);

CREATE INDEX idx_rbac_roles_tenant ON rbac_roles(tenant_id);
CREATE INDEX idx_rbac_roles_system ON rbac_roles(is_system_role) WHERE is_system_role = true;

COMMENT ON TABLE rbac_roles IS 'Roles define what users are allowed to do';
COMMENT ON COLUMN rbac_roles.is_system_role IS 'System roles cannot be deleted';

-- Resources (users, orders, invoices, etc.)
CREATE TABLE rbac_resources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  key VARCHAR(100) NOT NULL,
  display_name VARCHAR(255) NOT NULL,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tenant_id, key)
);

CREATE INDEX idx_rbac_resources_tenant ON rbac_resources(tenant_id);

COMMENT ON TABLE rbac_resources IS 'Resources that can be accessed (e.g., users, orders, invoices)';

-- Actions (read, write, delete, approve, etc.)
CREATE TABLE rbac_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key VARCHAR(50) NOT NULL UNIQUE,
  display_name VARCHAR(100) NOT NULL,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE rbac_actions IS 'Actions that can be performed on resources';

-- Resource Fields (email, name, salary - for field-level permissions)
CREATE TABLE rbac_resource_fields (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  resource_id UUID NOT NULL REFERENCES rbac_resources(id) ON DELETE CASCADE,
  key VARCHAR(100) NOT NULL,
  display_name VARCHAR(255) NOT NULL,
  field_type VARCHAR(50),
  is_sensitive BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(resource_id, key)
);

CREATE INDEX idx_rbac_resource_fields_resource ON rbac_resource_fields(resource_id);
CREATE INDEX idx_rbac_resource_fields_sensitive ON rbac_resource_fields(is_sensitive) WHERE is_sensitive = true;

COMMENT ON TABLE rbac_resource_fields IS 'Individual fields within resources for field-level access control';
COMMENT ON COLUMN rbac_resource_fields.is_sensitive IS 'Marks sensitive fields (salary, SSN, etc.)';

-- Permissions (resource:action combinations)
CREATE TABLE rbac_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  resource_id UUID NOT NULL REFERENCES rbac_resources(id) ON DELETE CASCADE,
  action_id UUID NOT NULL REFERENCES rbac_actions(id) ON DELETE CASCADE,
  permission_key VARCHAR(200) NOT NULL UNIQUE,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(resource_id, action_id)
);

CREATE INDEX idx_rbac_permissions_resource ON rbac_permissions(resource_id);
CREATE INDEX idx_rbac_permissions_action ON rbac_permissions(action_id);
CREATE INDEX idx_rbac_permissions_key ON rbac_permissions(permission_key);

COMMENT ON TABLE rbac_permissions IS 'Atomic permissions (resource:action pairs)';
COMMENT ON COLUMN rbac_permissions.permission_key IS 'Format: resource:action (e.g., users:read)';

-- Field-Level Permission Restrictions (optional whitelist)
CREATE TABLE rbac_permission_fields (
  permission_id UUID NOT NULL REFERENCES rbac_permissions(id) ON DELETE CASCADE,
  field_id UUID NOT NULL REFERENCES rbac_resource_fields(id) ON DELETE CASCADE,
  PRIMARY KEY (permission_id, field_id)
);

CREATE INDEX idx_rbac_permission_fields_permission ON rbac_permission_fields(permission_id);
CREATE INDEX idx_rbac_permission_fields_field ON rbac_permission_fields(field_id);

COMMENT ON TABLE rbac_permission_fields IS 'Field-level restrictions: if present, limits permission to specified fields only';

-- ============================================================================
-- STEP 4: ROLE-PERMISSION ASSIGNMENTS
-- ============================================================================

-- Role → Permission Assignment (with allow/deny effects)
CREATE TABLE rbac_role_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  role_id UUID NOT NULL REFERENCES rbac_roles(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES rbac_permissions(id) ON DELETE CASCADE,
  effect VARCHAR(10) NOT NULL CHECK (effect IN ('allow', 'deny')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(role_id, permission_id)
);

CREATE INDEX idx_rbac_role_permissions_role ON rbac_role_permissions(role_id);
CREATE INDEX idx_rbac_role_permissions_permission ON rbac_role_permissions(permission_id);

COMMENT ON TABLE rbac_role_permissions IS 'Grants or denies permissions to roles';

-- ============================================================================
-- STEP 5: USER ASSIGNMENTS
-- ============================================================================

-- User → OU Assignment (WHO belongs where)
CREATE TABLE org_user_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  org_unit_id UUID NOT NULL REFERENCES org_units(id) ON DELETE CASCADE,
  is_primary BOOLEAN DEFAULT false,
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  assigned_by UUID REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE(user_id, org_unit_id)
);

CREATE INDEX idx_org_user_assignments_user ON org_user_assignments(user_id);
CREATE INDEX idx_org_user_assignments_org_unit ON org_user_assignments(org_unit_id);
CREATE INDEX idx_org_user_assignments_primary ON org_user_assignments(is_primary) WHERE is_primary = true;

COMMENT ON TABLE org_user_assignments IS 'Assigns users to organizational units';
COMMENT ON COLUMN org_user_assignments.is_primary IS 'User primary/home organizational unit';

-- User → Role (Direct Assignment with optional scope)
CREATE TABLE rbac_user_role_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES rbac_roles(id) ON DELETE CASCADE,
  scope_type VARCHAR(20) NOT NULL CHECK (scope_type IN ('global', 'org_unit')),
  scope_org_unit_id UUID REFERENCES org_units(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  assigned_by UUID REFERENCES users(id) ON DELETE SET NULL,
  expires_at TIMESTAMPTZ,
  CHECK (
    (scope_type = 'global' AND scope_org_unit_id IS NULL) OR
    (scope_type = 'org_unit' AND scope_org_unit_id IS NOT NULL)
  )
);

-- Separate UNIQUE constraints for global and org_unit scoped roles
CREATE UNIQUE INDEX uniq_user_role_global
  ON rbac_user_role_assignments(user_id, role_id, scope_type)
  WHERE scope_type = 'global';

CREATE UNIQUE INDEX uniq_user_role_org_unit
  ON rbac_user_role_assignments(user_id, role_id, scope_type, scope_org_unit_id)
  WHERE scope_type = 'org_unit';

CREATE INDEX idx_rbac_user_role_assignments_user ON rbac_user_role_assignments(user_id);
CREATE INDEX idx_rbac_user_role_assignments_role ON rbac_user_role_assignments(role_id);
CREATE INDEX idx_rbac_user_role_assignments_expires ON rbac_user_role_assignments(expires_at) WHERE expires_at IS NOT NULL;

COMMENT ON TABLE rbac_user_role_assignments IS 'Direct role assignments to users (bypasses OU hierarchy)';
COMMENT ON COLUMN rbac_user_role_assignments.scope_type IS 'global = applies everywhere, org_unit = only within specific OU';

-- OU → Role Assignment (Everyone in OU gets Role)
CREATE TABLE org_unit_role_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_unit_id UUID NOT NULL REFERENCES org_units(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES rbac_roles(id) ON DELETE CASCADE,
  is_inherited BOOLEAN DEFAULT true,
  priority INT DEFAULT 1000,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE(org_unit_id, role_id)
);

CREATE INDEX idx_org_unit_role_assignments_org_unit ON org_unit_role_assignments(org_unit_id);
CREATE INDEX idx_org_unit_role_assignments_role ON org_unit_role_assignments(role_id);

COMMENT ON TABLE org_unit_role_assignments IS 'Assigns roles to organizational units (all members inherit)';
COMMENT ON COLUMN org_unit_role_assignments.is_inherited IS 'Whether child OUs inherit this role assignment';
COMMENT ON COLUMN org_unit_role_assignments.priority IS 'Custom priority for conflict resolution';

-- User Permission Overrides (Highest Priority)
CREATE TABLE rbac_user_permission_overrides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES rbac_permissions(id) ON DELETE CASCADE,
  effect VARCHAR(10) NOT NULL CHECK (effect IN ('allow', 'deny')),
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  expires_at TIMESTAMPTZ,
  UNIQUE(user_id, permission_id)
);

CREATE INDEX idx_rbac_user_overrides_user ON rbac_user_permission_overrides(user_id);
CREATE INDEX idx_rbac_user_overrides_permission ON rbac_user_permission_overrides(permission_id);
CREATE INDEX idx_rbac_user_overrides_expires ON rbac_user_permission_overrides(expires_at) WHERE expires_at IS NOT NULL;

COMMENT ON TABLE rbac_user_permission_overrides IS 'Direct permission overrides for specific users (highest priority)';

-- ============================================================================
-- STEP 6: AUDIT LOG
-- ============================================================================

CREATE TABLE rbac_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  action VARCHAR(50) NOT NULL,
  entity_type VARCHAR(50) NOT NULL,
  entity_id UUID NOT NULL,
  details JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_rbac_audit_log_tenant ON rbac_audit_log(tenant_id, created_at DESC);
CREATE INDEX idx_rbac_audit_log_user ON rbac_audit_log(user_id, created_at DESC);
CREATE INDEX idx_rbac_audit_log_entity ON rbac_audit_log(entity_type, entity_id);

COMMENT ON TABLE rbac_audit_log IS 'Audit trail for all permission-related changes';

-- ============================================================================
-- STEP 7: SEED DEFAULT DATA
-- ============================================================================

-- Default OU Types
INSERT INTO org_unit_types (key, display_name, hierarchy_level, allows_multi_parent) VALUES
  ('company', 'Unternehmen', 1, false),
  ('subsidiary', 'Unterfirma', 2, false),
  ('branch', 'Zweigstelle', 3, false),
  ('department', 'Abteilung', 4, true),
  ('team', 'Team', 5, true);

-- Default Actions
INSERT INTO rbac_actions (key, display_name, description) VALUES
  ('read', 'Lesen', 'View and read data'),
  ('write', 'Schreiben', 'Create and update data'),
  ('delete', 'Löschen', 'Delete data'),
  ('approve', 'Genehmigen', 'Approve requests or changes'),
  ('export', 'Exportieren', 'Export data to external formats'),
  ('admin', 'Verwalten', 'Administrative access');

-- ============================================================================
-- STEP 8: HELPER FUNCTIONS
-- ============================================================================

-- Function to rebuild org unit closure table
CREATE OR REPLACE FUNCTION rebuild_org_unit_closure()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Clear existing closure
  DELETE FROM org_unit_closure;

  -- Insert self-references
  INSERT INTO org_unit_closure (ancestor_unit_id, descendant_unit_id, depth)
  SELECT id, id, 0 FROM org_units;

  -- Compute transitive closure
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
  )
  INSERT INTO org_unit_closure (ancestor_unit_id, descendant_unit_id, depth)
  SELECT ancestor_unit_id, descendant_unit_id, MIN(depth) as depth
  FROM paths
  GROUP BY ancestor_unit_id, descendant_unit_id
  ON CONFLICT (ancestor_unit_id, descendant_unit_id) DO UPDATE
  SET depth = LEAST(org_unit_closure.depth, EXCLUDED.depth);
END;
$$;

COMMENT ON FUNCTION rebuild_org_unit_closure() IS 'Rebuilds the organizational unit closure table after hierarchy changes';

-- ============================================================================
-- STEP 9: UPDATE TRIGGER FOR TIMESTAMPS
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_org_units_updated_at BEFORE UPDATE ON org_units
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_rbac_roles_updated_at BEFORE UPDATE ON rbac_roles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

COMMIT;

-- Verify migration
SELECT 'Migration 005 completed successfully. Tables created:' as status;
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND (table_name LIKE 'org_%' OR table_name LIKE 'rbac_%')
ORDER BY table_name;
