-- API Keys Platform Database Schema
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'user' CHECK (role IN ('admin', 'user')),
    permission_mode VARCHAR(20) NOT NULL DEFAULT 'union'
        CHECK (permission_mode IN ('union', 'overrides_only')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- API Keys table
CREATE TABLE IF NOT EXISTS api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    key_hash VARCHAR(255) NOT NULL,
    key_prefix VARCHAR(12) NOT NULL,
    name VARCHAR(255),
    description TEXT,
    tier VARCHAR(50) DEFAULT 'basic' CHECK (tier IN ('basic', 'pro', 'enterprise', 'ultimate')),
    rate_limit INTEGER DEFAULT 1000,
    expires_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT true,
    granted_modules TEXT[] DEFAULT '{}',
    granted_module_groups TEXT[] DEFAULT '{}',
    allowed_ips INET[],
    allowed_domains TEXT[],
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_used_at TIMESTAMP WITH TIME ZONE,

    CONSTRAINT unique_key_hash UNIQUE (key_hash)
);

-- Audit logs table
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50),
    resource_id UUID,
    ip_address INET,
    user_agent TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Validation logs table (for analytics)
CREATE TABLE IF NOT EXISTS validations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    api_key_id UUID REFERENCES api_keys(id) ON DELETE SET NULL,
    is_valid BOOLEAN NOT NULL,
    reason VARCHAR(100),
    ip_address INET,
    user_agent TEXT,
    response_time_ms INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Refresh tokens table
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    revoked_at TIMESTAMP WITH TIME ZONE
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_api_keys_user_id ON api_keys(user_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_key_hash ON api_keys(key_hash);
CREATE INDEX IF NOT EXISTS idx_api_keys_is_active ON api_keys(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_validations_api_key_id ON validations(api_key_id);
CREATE INDEX IF NOT EXISTS idx_validations_created_at ON validations(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_granted_modules ON api_keys USING GIN(granted_modules);
CREATE INDEX IF NOT EXISTS idx_api_keys_granted_module_groups ON api_keys USING GIN(granted_module_groups);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for users table
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE IF NOT EXISTS modules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) UNIQUE NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS module_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) UNIQUE NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS module_group_modules (
    module_group_id UUID NOT NULL REFERENCES module_groups(id) ON DELETE CASCADE,
    module_id UUID NOT NULL REFERENCES modules(id) ON DELETE CASCADE,
    PRIMARY KEY (module_group_id, module_id)
);

CREATE TABLE IF NOT EXISTS perm_modules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(100) UNIQUE NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS perm_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(20) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

INSERT INTO perm_actions (key) VALUES
    ('create'),
    ('read'),
    ('update'),
    ('delete')
ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS perm_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_id UUID NOT NULL REFERENCES perm_modules(id) ON DELETE CASCADE,
    action_id UUID NOT NULL REFERENCES perm_actions(id) ON DELETE RESTRICT,
    perm_key VARCHAR(150) UNIQUE NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT unique_perm_module_action UNIQUE (module_id, action_id)
);

CREATE INDEX IF NOT EXISTS idx_perm_permissions_module_id ON perm_permissions(module_id);
CREATE INDEX IF NOT EXISTS idx_perm_permissions_action_id ON perm_permissions(action_id);

CREATE TABLE IF NOT EXISTS perm_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(100) UNIQUE NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS perm_variant_rules (
    variant_id UUID NOT NULL REFERENCES perm_variants(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES perm_permissions(id) ON DELETE CASCADE,
    effect VARCHAR(10) NOT NULL CHECK (effect IN ('allow', 'deny')),
    PRIMARY KEY (variant_id, permission_id)
);

CREATE INDEX IF NOT EXISTS idx_perm_variant_rules_permission_id ON perm_variant_rules(permission_id);

CREATE TABLE IF NOT EXISTS perm_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(100) UNIQUE NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS perm_group_variants (
    group_id UUID NOT NULL REFERENCES perm_groups(id) ON DELETE CASCADE,
    variant_id UUID NOT NULL REFERENCES perm_variants(id) ON DELETE CASCADE,
    PRIMARY KEY (group_id, variant_id)
);

CREATE INDEX IF NOT EXISTS idx_perm_group_variants_variant_id ON perm_group_variants(variant_id);

-- Direct group-permission assignments (simplified matrix)
CREATE TABLE IF NOT EXISTS perm_group_permissions (
    group_id UUID NOT NULL REFERENCES perm_groups(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES perm_permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (group_id, permission_id)
);

CREATE INDEX IF NOT EXISTS idx_perm_group_permissions_permission_id ON perm_group_permissions(permission_id);

CREATE TABLE IF NOT EXISTS perm_group_edges (
    parent_group_id UUID NOT NULL REFERENCES perm_groups(id) ON DELETE CASCADE,
    child_group_id UUID NOT NULL REFERENCES perm_groups(id) ON DELETE CASCADE,
    PRIMARY KEY (parent_group_id, child_group_id),
    CONSTRAINT perm_group_edges_no_self CHECK (parent_group_id <> child_group_id)
);

CREATE INDEX IF NOT EXISTS idx_perm_group_edges_child ON perm_group_edges(child_group_id);

CREATE TABLE IF NOT EXISTS perm_group_closure (
    ancestor_group_id UUID NOT NULL REFERENCES perm_groups(id) ON DELETE CASCADE,
    descendant_group_id UUID NOT NULL REFERENCES perm_groups(id) ON DELETE CASCADE,
    depth INTEGER NOT NULL,
    PRIMARY KEY (ancestor_group_id, descendant_group_id),
    CONSTRAINT perm_group_closure_depth_nonneg CHECK (depth >= 0)
);

CREATE INDEX IF NOT EXISTS idx_perm_group_closure_descendant ON perm_group_closure(descendant_group_id);

CREATE TABLE IF NOT EXISTS perm_user_groups (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES perm_groups(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, group_id)
);

CREATE INDEX IF NOT EXISTS idx_perm_user_groups_group_id ON perm_user_groups(group_id);

CREATE TABLE IF NOT EXISTS perm_user_overrides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES perm_permissions(id) ON DELETE CASCADE,
    effect VARCHAR(10) NOT NULL CHECK (effect IN ('allow', 'deny')),
    reason TEXT,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_perm_user_overrides_user_id ON perm_user_overrides(user_id);
CREATE INDEX IF NOT EXISTS idx_perm_user_overrides_permission_id ON perm_user_overrides(permission_id);
CREATE INDEX IF NOT EXISTS idx_perm_user_overrides_expires_at ON perm_user_overrides(expires_at);

CREATE UNIQUE INDEX IF NOT EXISTS uniq_perm_user_overrides_no_expiry
  ON perm_user_overrides(user_id, permission_id)
  WHERE expires_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uniq_perm_user_overrides_with_expiry
  ON perm_user_overrides(user_id, permission_id, expires_at)
  WHERE expires_at IS NOT NULL;

-- Seed default admin user (password: admin123 - CHANGE IN PRODUCTION!)
-- Password hash for 'admin123' using bcrypt
INSERT INTO users (email, name, password_hash, role)
VALUES (
    'admin@licenseguard.local',
    'Administrator',
    '$2b$12$ZYdwbsHsIOtl5KIlrZxIuOyDKwqBOEMnOWQozMGN.Vs0qPoExZ0Ka',
    'admin'
) ON CONFLICT (email) DO NOTHING;

-- Menu items table for dynamic menu management
CREATE TABLE IF NOT EXISTS menu_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID REFERENCES menu_items(id) ON DELETE CASCADE,
    module_key VARCHAR(100) NOT NULL,
    label_key VARCHAR(100) NOT NULL,
    label_default VARCHAR(255) NOT NULL,
    href VARCHAR(500),  -- NULL for group headers
    icon VARCHAR(50),
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    required_permission JSONB,  -- e.g. {"moduleKey": "admin.users", "action": "read"}
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for menu_items
CREATE INDEX IF NOT EXISTS idx_menu_items_parent ON menu_items(parent_id);
CREATE INDEX IF NOT EXISTS idx_menu_items_active ON menu_items(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_menu_items_module_key ON menu_items(module_key);

-- Unique constraint on module_key + href (except NULL hrefs)
CREATE UNIQUE INDEX IF NOT EXISTS idx_menu_items_unique_href
    ON menu_items(module_key, href)
    WHERE href IS NOT NULL;

-- Trigger for menu_items updated_at
CREATE OR REPLACE FUNCTION update_menu_items_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS menu_items_updated_at ON menu_items;
CREATE TRIGGER menu_items_updated_at
    BEFORE UPDATE ON menu_items
    FOR EACH ROW
    EXECUTE FUNCTION update_menu_items_updated_at();

-- Table for user-specific menu sorting and aliases
CREATE TABLE IF NOT EXISTS user_menu_preferences (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    custom_sort_order INTEGER NOT NULL,
    custom_label VARCHAR(255),
    PRIMARY KEY (user_id, menu_item_id)
);

CREATE INDEX IF NOT EXISTS idx_user_menu_preferences_user ON user_menu_preferences(user_id);

-- Seed default menu items
-- User Admin Menu
-- Hierarchical Menu Structure
-- Parent items (group headers with no href, collapsible sections)
INSERT INTO menu_items (id, parent_id, module_key, label_key, label_default, href, icon, sort_order, is_active) VALUES
  ('user-parent', NULL, 'user', 'menu.user.title', 'User Admin', NULL, 'users', 10, true),
  ('permissions-parent', NULL, 'permissions', 'menu.permissions.title', 'Permissions Admin', NULL, 'shield', 20, true),
  ('apikeys-parent', NULL, 'apikeys', 'menu.apikeys.title', 'API Keys', NULL, 'key', 30, true),
  ('activities-parent', NULL, 'activities', 'menu.activities.title', 'Activities', NULL, 'activity', 40, true)
ON CONFLICT (id) DO UPDATE SET
    label_default = EXCLUDED.label_default,
    href = EXCLUDED.href,
    icon = EXCLUDED.icon,
    sort_order = EXCLUDED.sort_order,
    parent_id = EXCLUDED.parent_id;

-- User Admin children
INSERT INTO menu_items (id, parent_id, module_key, label_key, label_default, href, icon, sort_order, is_active) VALUES
  ('user-dashboard', 'user-parent', 'user', 'menu.user.dashboard', 'Dashboard', '/admin/user/dashboard', 'layout-dashboard', 10, true),
  ('user-users', 'user-parent', 'user', 'menu.user.users', 'Benutzer', '/admin/user/users', 'users', 20, true)
ON CONFLICT (id) DO UPDATE SET
    label_default = EXCLUDED.label_default,
    href = EXCLUDED.href,
    icon = EXCLUDED.icon,
    sort_order = EXCLUDED.sort_order,
    parent_id = EXCLUDED.parent_id;

-- Permissions Admin children
INSERT INTO menu_items (id, parent_id, module_key, label_key, label_default, href, icon, sort_order, is_active) VALUES
  ('permissions-dashboard', 'permissions-parent', 'permissions', 'menu.permissions.dashboard', 'Dashboard', '/admin/permissions/dashboard', 'layout-dashboard', 10, true),
  ('permissions-permissions', 'permissions-parent', 'permissions', 'menu.permissions.permissions', 'Berechtigungen', '/admin/permissions/permissions', 'shield-check', 20, true),
  ('permissions-modules', 'permissions-parent', 'permissions', 'menu.permissions.modules', 'Module', '/admin/permissions/modules', 'package', 30, true),
  ('permissions-variants', 'permissions-parent', 'permissions', 'menu.permissions.variants', 'Varianten', '/admin/permissions/variants', 'layers', 40, true),
  ('permissions-groups', 'permissions-parent', 'permissions', 'menu.permissions.groups', 'Gruppen', '/admin/permissions/groups', 'users-round', 50, true),
  ('permissions-matrix', 'permissions-parent', 'permissions', 'menu.permissions.matrix', 'Matrix', '/admin/permissions/matrix', 'grid-2x2', 60, true)
ON CONFLICT (id) DO UPDATE SET
    label_default = EXCLUDED.label_default,
    href = EXCLUDED.href,
    icon = EXCLUDED.icon,
    sort_order = EXCLUDED.sort_order,
    parent_id = EXCLUDED.parent_id;

-- API Keys children
INSERT INTO menu_items (id, parent_id, module_key, label_key, label_default, href, icon, sort_order, is_active) VALUES
  ('apikeys-dashboard', 'apikeys-parent', 'apikeys', 'menu.apikeys.dashboard', 'Dashboard', '/admin/api-keys/dashboard', 'layout-dashboard', 10, true),
  ('apikeys-keys', 'apikeys-parent', 'apikeys', 'menu.apikeys.keys', 'API-Schlüssel', '/admin/api-keys/api-keys', 'key', 20, true)
ON CONFLICT (id) DO UPDATE SET
    label_default = EXCLUDED.label_default,
    href = EXCLUDED.href,
    icon = EXCLUDED.icon,
    sort_order = EXCLUDED.sort_order,
    parent_id = EXCLUDED.parent_id;

-- Activities children (requires lg-activities-admin module to be deployed)
INSERT INTO menu_items (id, parent_id, module_key, label_key, label_default, href, icon, sort_order, is_active) VALUES
  ('activities-dashboard', 'activities-parent', 'activities', 'menu.activities.dashboard', 'Dashboard', '/admin/activities/dashboard', 'layout-dashboard', 10, true),
  ('activities-user', 'activities-parent', 'activities', 'menu.activities.user', 'Benutzer-Aktivitäten', '/admin/activities/user', 'user-check', 20, true),
  ('activities-apikeys', 'activities-parent', 'activities', 'menu.activities.apikeys', 'API-Schlüssel-Aktivitäten', '/admin/activities/api-keys', 'key-round', 30, true)
ON CONFLICT (id) DO UPDATE SET
    label_default = EXCLUDED.label_default,
    href = EXCLUDED.href,
    icon = EXCLUDED.icon,
    sort_order = EXCLUDED.sort_order,
    parent_id = EXCLUDED.parent_id;
