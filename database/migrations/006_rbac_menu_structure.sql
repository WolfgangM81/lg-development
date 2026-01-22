-- Migration: RBAC Menu Structure Refactoring
-- COMPLETELY REPLACES legacy permission system menu items with new RBAC structure

BEGIN;

DO $$
DECLARE
    permissions_parent_id UUID;
BEGIN
    -- Get the Permissions module parent ID
    SELECT id INTO permissions_parent_id
    FROM menu_items
    WHERE module_key = 'permissions' AND parent_id IS NULL;

    IF permissions_parent_id IS NULL THEN
        RAISE EXCEPTION 'Permissions module not found - cannot proceed with migration';
    END IF;

    RAISE NOTICE 'Found permissions module: %', permissions_parent_id;

    -- DELETE legacy menu items COMPLETELY (no deactivation - full cleanup)
    DELETE FROM menu_items
    WHERE parent_id = permissions_parent_id
      AND label_default IN ('Module', 'Varianten', 'Gruppen', 'Berechtigungen');

    RAISE NOTICE 'DELETED legacy menu items: Module, Varianten, Gruppen, Berechtigungen';

    -- Delete existing RBAC menu items if they exist (for clean re-insert)
    DELETE FROM menu_items
    WHERE parent_id = permissions_parent_id
      AND href IN (
        '/admin/permissions/rbac-guide',
        '/admin/permissions/org-units',
        '/admin/permissions/roles',
        '/admin/permissions/resources',
        '/admin/permissions/effective',
        '/admin/permissions/matrix'
      );

    RAISE NOTICE 'Cleaned up existing RBAC menu items';

    -- Insert NEW RBAC menu structure
    INSERT INTO menu_items (module_key, parent_id, label_key, label_default, href, icon, sort_order, is_active)
    VALUES
        ('permissions', permissions_parent_id, 'menu.permissions.rbac_guide', 'RBAC Dokumentation', '/admin/permissions/rbac-guide', 'book-open', 10, true),
        ('permissions', permissions_parent_id, 'menu.permissions.org_units', 'Organizational Units', '/admin/permissions/org-units', 'building', 20, true),
        ('permissions', permissions_parent_id, 'menu.permissions.roles', 'Rollen', '/admin/permissions/roles', 'shield', 30, true),
        ('permissions', permissions_parent_id, 'menu.permissions.resources', 'Ressourcen', '/admin/permissions/resources', 'database', 40, true),
        ('permissions', permissions_parent_id, 'menu.permissions.effective', 'Permission Calculator', '/admin/permissions/effective', 'calculator', 50, true),
        ('permissions', permissions_parent_id, 'menu.permissions.matrix', 'Matrix (OUs × Rollen)', '/admin/permissions/matrix', 'grid-3x3', 60, true);

    RAISE NOTICE 'Inserted new RBAC menu items';
END$$;

COMMIT;

-- Verification
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== Migration Complete ===';
    RAISE NOTICE 'Verify with: SELECT label_default, href, sort_order, is_active FROM menu_items WHERE parent_id = (SELECT id FROM menu_items WHERE module_key = ''permissions'' AND parent_id IS NULL) ORDER BY sort_order;';
END$$;
