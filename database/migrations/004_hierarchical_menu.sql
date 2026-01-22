-- Migration: Restructure menu to hierarchical format
-- Description: Add parent/child relationships and proper sort orders for improved menu navigation
-- Date: 2026-01-14

BEGIN;

-- Delete old menu preferences first (they reference menu_items)
DELETE FROM user_menu_preferences;

-- Delete old flat menu structure
DELETE FROM menu_items;

-- =============================================================================
-- Create Parent Menu Items and Their Children Using CTEs
-- =============================================================================

-- Insert parent items and capture their IDs
WITH parent_inserts AS (
  INSERT INTO menu_items (module_key, label_key, label_default, href, icon, sort_order, is_active) VALUES
    ('user', 'menu.user.title', 'User Admin', NULL, 'users', 10, true),
    ('permissions', 'menu.permissions.title', 'Permissions Admin', NULL, 'shield', 20, true),
    ('apikeys', 'menu.apikeys.title', 'API Keys', NULL, 'key', 30, true),
    ('activities', 'menu.activities.title', 'Activities', NULL, 'activity', 40, true)
  RETURNING id, module_key
),

-- Insert User Admin children
user_children AS (
  INSERT INTO menu_items (parent_id, module_key, label_key, label_default, href, icon, sort_order, is_active)
  SELECT p.id, 'user', 'menu.user.dashboard', 'Dashboard', '/admin/user/dashboard', 'layout-dashboard', 10, true
  FROM parent_inserts p WHERE p.module_key = 'user'
  UNION ALL
  SELECT p.id, 'user', 'menu.user.users', 'Benutzer', '/admin/user/users', 'users', 20, true
  FROM parent_inserts p WHERE p.module_key = 'user'
  RETURNING id
),

-- Insert Permissions Admin children
permissions_children AS (
  INSERT INTO menu_items (parent_id, module_key, label_key, label_default, href, icon, sort_order, is_active)
  SELECT p.id, 'permissions', 'menu.permissions.dashboard', 'Dashboard', '/admin/permissions/dashboard', 'layout-dashboard', 10, true
  FROM parent_inserts p WHERE p.module_key = 'permissions'
  UNION ALL
  SELECT p.id, 'permissions', 'menu.permissions.permissions', 'Berechtigungen', '/admin/permissions/permissions', 'shield-check', 20, true
  FROM parent_inserts p WHERE p.module_key = 'permissions'
  UNION ALL
  SELECT p.id, 'permissions', 'menu.permissions.modules', 'Module', '/admin/permissions/modules', 'package', 30, true
  FROM parent_inserts p WHERE p.module_key = 'permissions'
  UNION ALL
  SELECT p.id, 'permissions', 'menu.permissions.variants', 'Varianten', '/admin/permissions/variants', 'layers', 40, true
  FROM parent_inserts p WHERE p.module_key = 'permissions'
  UNION ALL
  SELECT p.id, 'permissions', 'menu.permissions.groups', 'Gruppen', '/admin/permissions/groups', 'users-round', 50, true
  FROM parent_inserts p WHERE p.module_key = 'permissions'
  UNION ALL
  SELECT p.id, 'permissions', 'menu.permissions.matrix', 'Matrix', '/admin/permissions/matrix', 'grid-2x2', 60, true
  FROM parent_inserts p WHERE p.module_key = 'permissions'
  RETURNING id
),

-- Insert API Keys children
apikeys_children AS (
  INSERT INTO menu_items (parent_id, module_key, label_key, label_default, href, icon, sort_order, is_active)
  SELECT p.id, 'apikeys', 'menu.apikeys.dashboard', 'Dashboard', '/admin/api-keys/dashboard', 'layout-dashboard', 10, true
  FROM parent_inserts p WHERE p.module_key = 'apikeys'
  UNION ALL
  SELECT p.id, 'apikeys', 'menu.apikeys.keys', 'API-Schlüssel', '/admin/api-keys/api-keys', 'key', 20, true
  FROM parent_inserts p WHERE p.module_key = 'apikeys'
  RETURNING id
),

-- Insert Activities children (NEW MODULE)
-- Note: This requires the lg-activities-admin module to be deployed
activities_children AS (
  INSERT INTO menu_items (parent_id, module_key, label_key, label_default, href, icon, sort_order, is_active)
  SELECT p.id, 'activities', 'menu.activities.dashboard', 'Dashboard', '/admin/activities/dashboard', 'layout-dashboard', 10, true
  FROM parent_inserts p WHERE p.module_key = 'activities'
  UNION ALL
  SELECT p.id, 'activities', 'menu.activities.user', 'Benutzer-Aktivitäten', '/admin/activities/user', 'user-check', 20, true
  FROM parent_inserts p WHERE p.module_key = 'activities'
  UNION ALL
  SELECT p.id, 'activities', 'menu.activities.apikeys', 'API-Schlüssel-Aktivitäten', '/admin/activities/api-keys', 'key-round', 30, true
  FROM parent_inserts p WHERE p.module_key = 'activities'
  RETURNING id
)

-- Select count to confirm inserts
SELECT
  (SELECT COUNT(*) FROM parent_inserts) as parents,
  (SELECT COUNT(*) FROM user_children) as user_items,
  (SELECT COUNT(*) FROM permissions_children) as permission_items,
  (SELECT COUNT(*) FROM apikeys_children) as apikey_items,
  (SELECT COUNT(*) FROM activities_children) as activity_items;

COMMIT;

-- =============================================================================
-- Verification Queries (Run these to verify the migration)
-- =============================================================================
-- SELECT id, parent_id, module_key, label_default, href, sort_order
-- FROM menu_items
-- ORDER BY COALESCE(parent_id, id), sort_order;
--
-- Expected output:
-- - 4 parent items (user-parent, permissions-parent, apikeys-parent, activities-parent) with NULL href
-- - 2 children under user-parent
-- - 6 children under permissions-parent
-- - 2 children under apikeys-parent
-- - 3 children under activities-parent
