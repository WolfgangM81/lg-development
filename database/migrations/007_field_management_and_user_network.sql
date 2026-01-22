-- Migration 007: Field Management System + User Network
-- Created: 2026-01-15
-- Description:
--   - Field Types Library (global reusable fields)
--   - Field Groups (composite fields like address, bank_account)
--   - Nested Field Groups support
--   - Resource Field Assignment (single field or group)
--   - User Network (MLM sponsor/upline hierarchy)
--   - YAML-based System Fields

-- ============================================================================
-- PHASE 1: FIELD MANAGEMENT SYSTEM
-- ============================================================================

-- Field Types: Global library of reusable fields
CREATE TABLE IF NOT EXISTS field_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  key VARCHAR(100) NOT NULL,
  display_name VARCHAR(255) NOT NULL,
  description TEXT,
  data_type VARCHAR(50) NOT NULL, -- string, number, boolean, email, password, date, json, etc
  validation_rules JSONB,          -- {regex, min, max, required, custom}
  default_value TEXT,
  placeholder TEXT,
  help_text TEXT,
  is_sensitive BOOLEAN DEFAULT false,
  is_system_field BOOLEAN DEFAULT false, -- System fields managed via YAML
  category VARCHAR(50),            -- contact, financial, personal, address, etc
  icon VARCHAR(50),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tenant_id, key)
);

CREATE INDEX idx_field_types_tenant ON field_types(tenant_id);
CREATE INDEX idx_field_types_category ON field_types(category);
CREATE INDEX idx_field_types_is_system ON field_types(is_system_field);

-- Field Groups: Composite fields (e.g., address = street + city + postal_code + country)
CREATE TABLE IF NOT EXISTS field_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  key VARCHAR(100) NOT NULL,
  display_name VARCHAR(255) NOT NULL,
  description TEXT,
  icon VARCHAR(50),
  parent_group_id UUID REFERENCES field_groups(id) ON DELETE CASCADE, -- Nested groups support
  is_system_group BOOLEAN DEFAULT false,
  display_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tenant_id, key)
);

CREATE INDEX idx_field_groups_tenant ON field_groups(tenant_id);
CREATE INDEX idx_field_groups_parent ON field_groups(parent_group_id);

-- Field Group Members: Which fields/groups belong to which group
CREATE TABLE IF NOT EXISTS field_group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  field_group_id UUID NOT NULL REFERENCES field_groups(id) ON DELETE CASCADE,
  field_type_id UUID REFERENCES field_types(id) ON DELETE CASCADE,
  child_group_id UUID REFERENCES field_groups(id) ON DELETE CASCADE, -- Nested group reference
  display_order INT NOT NULL DEFAULT 0,
  is_required BOOLEAN DEFAULT false,
  validation_rules JSONB, -- Override group-level validation
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT check_field_or_group_member CHECK (
    (field_type_id IS NOT NULL AND child_group_id IS NULL) OR
    (field_type_id IS NULL AND child_group_id IS NOT NULL)
  ),
  UNIQUE(field_group_id, field_type_id),
  UNIQUE(field_group_id, child_group_id)
);

CREATE INDEX idx_field_group_members_group ON field_group_members(field_group_id);
CREATE INDEX idx_field_group_members_field ON field_group_members(field_type_id);
CREATE INDEX idx_field_group_members_child_group ON field_group_members(child_group_id);

-- YAML Field Definitions: System fields managed via YAML upload/download
CREATE TABLE IF NOT EXISTS field_yaml_definitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  name VARCHAR(100) NOT NULL,
  yaml_content TEXT NOT NULL,
  parsed_json JSONB,               -- Cached parsed YAML for fast queries
  version VARCHAR(50),
  uploaded_by UUID REFERENCES users(id),
  uploaded_at TIMESTAMPTZ DEFAULT NOW(),
  is_active BOOLEAN DEFAULT true,
  UNIQUE(tenant_id, name, version)
);

CREATE INDEX idx_field_yaml_tenant ON field_yaml_definitions(tenant_id);
CREATE INDEX idx_field_yaml_active ON field_yaml_definitions(is_active);

-- ============================================================================
-- PHASE 2: RESOURCE FIELD ASSIGNMENT UPDATE
-- ============================================================================

-- Update rbac_resource_fields to support field groups
ALTER TABLE rbac_resource_fields ADD COLUMN IF NOT EXISTS field_group_id UUID REFERENCES field_groups(id) ON DELETE CASCADE;
ALTER TABLE rbac_resource_fields ADD COLUMN IF NOT EXISTS is_group_assignment BOOLEAN DEFAULT false;

-- Add constraint: Either field_id OR field_group_id, not both
ALTER TABLE rbac_resource_fields DROP CONSTRAINT IF EXISTS check_field_or_group_assignment;
ALTER TABLE rbac_resource_fields ADD CONSTRAINT check_field_or_group_assignment
  CHECK (
    (field_id IS NOT NULL AND field_group_id IS NULL AND is_group_assignment = false) OR
    (field_id IS NULL AND field_group_id IS NOT NULL AND is_group_assignment = true)
  );

CREATE INDEX IF NOT EXISTS idx_rbac_resource_fields_group ON rbac_resource_fields(field_group_id);

-- ============================================================================
-- PHASE 3: USER NETWORK SYSTEM (MLM)
-- ============================================================================

-- User Network: Sponsor/Upline relationships
CREATE TABLE IF NOT EXISTS user_network (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sponsor_id UUID REFERENCES users(id) ON DELETE SET NULL, -- Direct upline/sponsor
  placement_id UUID REFERENCES users(id) ON DELETE SET NULL, -- Binary tree placement (optional)
  level INT NOT NULL DEFAULT 1,        -- Depth in network (1 = root)
  network_position VARCHAR(20),        -- left, right, center (for binary/unilevel)
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  is_active BOOLEAN DEFAULT true,
  metadata JSONB,                      -- Custom network data (rank, sales, etc)
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tenant_id, user_id)
);

CREATE INDEX idx_user_network_tenant ON user_network(tenant_id);
CREATE INDEX idx_user_network_user ON user_network(user_id);
CREATE INDEX idx_user_network_sponsor ON user_network(sponsor_id);
CREATE INDEX idx_user_network_placement ON user_network(placement_id);
CREATE INDEX idx_user_network_level ON user_network(level);

-- User Network Closure: Transitive closure for fast upline/downline queries
CREATE TABLE IF NOT EXISTS user_network_closure (
  tenant_id UUID NOT NULL,
  ancestor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  descendant_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  depth INT NOT NULL CHECK (depth >= 0),
  path_type VARCHAR(20) DEFAULT 'sponsor', -- sponsor, placement, or custom
  PRIMARY KEY (tenant_id, ancestor_id, descendant_id, path_type)
);

CREATE INDEX idx_user_network_closure_ancestor ON user_network_closure(ancestor_id);
CREATE INDEX idx_user_network_closure_descendant ON user_network_closure(descendant_id);
CREATE INDEX idx_user_network_closure_depth ON user_network_closure(depth);

-- User Connections: Non-hierarchical relationships (like LinkedIn)
CREATE TABLE IF NOT EXISTS user_connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  connected_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  connection_type VARCHAR(50) DEFAULT 'friend', -- friend, colleague, client, etc
  status VARCHAR(20) DEFAULT 'pending',        -- pending, accepted, blocked
  initiated_by UUID NOT NULL,                  -- Who sent the request
  connected_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CHECK (user_id != connected_user_id),
  UNIQUE(tenant_id, user_id, connected_user_id)
);

CREATE INDEX idx_user_connections_user ON user_connections(user_id);
CREATE INDEX idx_user_connections_connected_user ON user_connections(connected_user_id);
CREATE INDEX idx_user_connections_status ON user_connections(status);

-- ============================================================================
-- SEED DATA: System Field Types & Groups
-- ============================================================================

-- Note: System fields should ideally be loaded from YAML, but we provide
-- basic seed data here for initial setup

-- Address Fields
INSERT INTO field_types (tenant_id, key, display_name, data_type, category, is_system_field, validation_rules) VALUES
  ('00000000-0000-0000-0000-000000000000', 'street', 'Straße', 'string', 'address', true, '{"required": true, "minLength": 3}'),
  ('00000000-0000-0000-0000-000000000000', 'street_number', 'Hausnummer', 'string', 'address', true, '{"required": false}'),
  ('00000000-0000-0000-0000-000000000000', 'city', 'Stadt', 'string', 'address', true, '{"required": true}'),
  ('00000000-0000-0000-0000-000000000000', 'postal_code', 'PLZ', 'string', 'address', true, '{"required": true, "pattern": "^[0-9]{5}$"}'),
  ('00000000-0000-0000-0000-000000000000', 'country', 'Land', 'string', 'address', true, '{"required": true}'),
  ('00000000-0000-0000-0000-000000000000', 'state', 'Bundesland', 'string', 'address', true, '{"required": false}')
ON CONFLICT (tenant_id, key) DO NOTHING;

-- Financial Fields
INSERT INTO field_types (tenant_id, key, display_name, data_type, category, is_system_field, is_sensitive, validation_rules) VALUES
  ('00000000-0000-0000-0000-000000000000', 'iban', 'IBAN', 'string', 'financial', true, true, '{"required": true, "pattern": "^[A-Z]{2}[0-9]{2}[A-Z0-9]+$"}'),
  ('00000000-0000-0000-0000-000000000000', 'bic', 'BIC/SWIFT', 'string', 'financial', true, true, '{"required": false, "pattern": "^[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?$"}'),
  ('00000000-0000-0000-0000-000000000000', 'account_holder', 'Kontoinhaber', 'string', 'financial', true, true, '{"required": true}'),
  ('00000000-0000-0000-0000-000000000000', 'bank_name', 'Bank Name', 'string', 'financial', true, false, '{"required": false}')
ON CONFLICT (tenant_id, key) DO NOTHING;

-- Personal Fields
INSERT INTO field_types (tenant_id, key, display_name, data_type, category, is_system_field, validation_rules) VALUES
  ('00000000-0000-0000-0000-000000000000', 'first_name', 'Vorname', 'string', 'personal', true, '{"required": true}'),
  ('00000000-0000-0000-0000-000000000000', 'last_name', 'Nachname', 'string', 'personal', true, '{"required": true}'),
  ('00000000-0000-0000-0000-000000000000', 'birth_date', 'Geburtsdatum', 'date', 'personal', true, '{"required": false}'),
  ('00000000-0000-0000-0000-000000000000', 'phone', 'Telefon', 'string', 'contact', true, '{"required": false}'),
  ('00000000-0000-0000-0000-000000000000', 'mobile', 'Mobil', 'string', 'contact', true, '{"required": false}')
ON CONFLICT (tenant_id, key) DO NOTHING;

-- Field Groups
INSERT INTO field_groups (tenant_id, key, display_name, description, icon, is_system_group) VALUES
  ('00000000-0000-0000-0000-000000000000', 'address', 'Adresse', 'Vollständige Postadresse', 'map-pin', true),
  ('00000000-0000-0000-0000-000000000000', 'bank_account', 'Bankverbindung', 'Bankkonto-Informationen', 'landmark', true),
  ('00000000-0000-0000-0000-000000000000', 'contact_info', 'Kontaktinformationen', 'Telefon, E-Mail, etc.', 'phone', true),
  ('00000000-0000-0000-0000-000000000000', 'persona', 'Persona', 'Vollständiges Personenprofil', 'user', true)
ON CONFLICT (tenant_id, key) DO NOTHING;

-- Address Group Members
INSERT INTO field_group_members (field_group_id, field_type_id, display_order, is_required)
SELECT g.id, f.id,
  CASE f.key
    WHEN 'street' THEN 1
    WHEN 'street_number' THEN 2
    WHEN 'postal_code' THEN 3
    WHEN 'city' THEN 4
    WHEN 'state' THEN 5
    WHEN 'country' THEN 6
  END,
  CASE f.key
    WHEN 'street' THEN true
    WHEN 'city' THEN true
    WHEN 'postal_code' THEN true
    WHEN 'country' THEN true
    ELSE false
  END
FROM field_groups g, field_types f
WHERE g.tenant_id = '00000000-0000-0000-0000-000000000000'
  AND g.key = 'address'
  AND f.key IN ('street', 'street_number', 'city', 'postal_code', 'state', 'country')
ON CONFLICT (field_group_id, field_type_id) DO NOTHING;

-- Bank Account Group Members
INSERT INTO field_group_members (field_group_id, field_type_id, display_order, is_required)
SELECT g.id, f.id,
  CASE f.key
    WHEN 'account_holder' THEN 1
    WHEN 'iban' THEN 2
    WHEN 'bic' THEN 3
    WHEN 'bank_name' THEN 4
  END,
  CASE f.key
    WHEN 'account_holder' THEN true
    WHEN 'iban' THEN true
    ELSE false
  END
FROM field_groups g, field_types f
WHERE g.tenant_id = '00000000-0000-0000-0000-000000000000'
  AND g.key = 'bank_account'
  AND f.key IN ('account_holder', 'iban', 'bic', 'bank_name')
ON CONFLICT (field_group_id, field_type_id) DO NOTHING;

-- Contact Info Group Members
INSERT INTO field_group_members (field_group_id, field_type_id, display_order, is_required)
SELECT g.id, f.id,
  CASE f.key
    WHEN 'phone' THEN 1
    WHEN 'mobile' THEN 2
  END,
  false
FROM field_groups g, field_types f
WHERE g.tenant_id = '00000000-0000-0000-0000-000000000000'
  AND g.key = 'contact_info'
  AND f.key IN ('phone', 'mobile')
ON CONFLICT (field_group_id, field_type_id) DO NOTHING;

-- Persona Group: Nested group containing address + contact_info + personal fields
INSERT INTO field_group_members (field_group_id, field_type_id, display_order, is_required)
SELECT g.id, f.id,
  CASE f.key
    WHEN 'first_name' THEN 1
    WHEN 'last_name' THEN 2
    WHEN 'birth_date' THEN 3
  END,
  CASE f.key
    WHEN 'first_name' THEN true
    WHEN 'last_name' THEN true
    ELSE false
  END
FROM field_groups g, field_types f
WHERE g.tenant_id = '00000000-0000-0000-0000-000000000000'
  AND g.key = 'persona'
  AND f.key IN ('first_name', 'last_name', 'birth_date')
ON CONFLICT (field_group_id, field_type_id) DO NOTHING;

-- Add nested groups to persona (address + contact_info)
INSERT INTO field_group_members (field_group_id, child_group_id, display_order, is_required)
SELECT parent.id, child.id,
  CASE child.key
    WHEN 'address' THEN 10
    WHEN 'contact_info' THEN 20
  END,
  false
FROM field_groups parent, field_groups child
WHERE parent.tenant_id = '00000000-0000-0000-0000-000000000000'
  AND parent.key = 'persona'
  AND child.key IN ('address', 'contact_info')
ON CONFLICT (field_group_id, child_group_id) DO NOTHING;

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function: Rebuild User Network Closure Table
CREATE OR REPLACE FUNCTION rebuild_user_network_closure()
RETURNS void AS $$
BEGIN
  DELETE FROM user_network_closure;

  -- Self-relations (depth 0)
  INSERT INTO user_network_closure (tenant_id, ancestor_id, descendant_id, depth, path_type)
  SELECT tenant_id, user_id, user_id, 0, 'sponsor'
  FROM user_network;

  -- Sponsor path closure
  WITH RECURSIVE sponsor_paths AS (
    SELECT tenant_id, sponsor_id AS ancestor_id, user_id AS descendant_id, 1 AS depth
    FROM user_network
    WHERE sponsor_id IS NOT NULL

    UNION ALL

    SELECT sp.tenant_id, un.sponsor_id, sp.descendant_id, sp.depth + 1
    FROM sponsor_paths sp
    JOIN user_network un ON un.user_id = sp.ancestor_id AND un.tenant_id = sp.tenant_id
    WHERE un.sponsor_id IS NOT NULL AND sp.depth < 100
  )
  INSERT INTO user_network_closure (tenant_id, ancestor_id, descendant_id, depth, path_type)
  SELECT tenant_id, ancestor_id, descendant_id, depth, 'sponsor'
  FROM sponsor_paths
  ON CONFLICT (tenant_id, ancestor_id, descendant_id, path_type) DO NOTHING;

END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- AUDIT LOG ENTRIES
-- ============================================================================

INSERT INTO rbac_audit_log (tenant_id, action, entity_type, entity_id, details)
VALUES (
  '00000000-0000-0000-0000-000000000000',
  'MIGRATION_APPLIED',
  'database',
  gen_random_uuid(),
  jsonb_build_object(
    'migration', '007_field_management_and_user_network',
    'applied_at', NOW(),
    'description', 'Field Management System + User Network (MLM)'
  )
);
