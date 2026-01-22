-- Migration: Form Help Links (Context-sensitive Help System)
-- Description: Stores help URLs for forms/modals with CMS editability
-- Version: 006
-- Date: 2026-01-15

BEGIN;

-- Form Help Links Table
CREATE TABLE IF NOT EXISTS form_help_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,

  -- Form Identifier (e.g., 'rbac.create_role', 'api_keys.create')
  form_key VARCHAR(255) NOT NULL,

  -- Help URL (can be external docs or internal wiki)
  help_url TEXT NOT NULL,

  -- Display Information
  title VARCHAR(255),
  description TEXT,

  -- Metadata
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID,
  updated_by UUID,

  -- Unique per tenant and form
  UNIQUE(tenant_id, form_key)
);

-- Indexes
CREATE INDEX idx_form_help_links_tenant ON form_help_links(tenant_id);
CREATE INDEX idx_form_help_links_form_key ON form_help_links(form_key);
CREATE INDEX idx_form_help_links_active ON form_help_links(is_active) WHERE is_active = true;

-- Updated At Trigger
CREATE TRIGGER form_help_links_updated_at
  BEFORE UPDATE ON form_help_links
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Seed Initial Help Links (for default tenant)
INSERT INTO form_help_links (tenant_id, form_key, help_url, title, description, is_active)
SELECT
  t.id as tenant_id,
  form_data.form_key,
  form_data.help_url,
  form_data.title,
  form_data.description,
  true as is_active
FROM tenants t
CROSS JOIN (VALUES
  -- RBAC Forms
  ('rbac.create_role', 'https://docs.licenseguard.io/rbac/roles', 'Rollen erstellen', 'Erfahren Sie, wie Sie Rollen erstellen und verwalten'),
  ('rbac.create_org_unit', 'https://docs.licenseguard.io/rbac/org-units', 'Organisationseinheiten', 'Lernen Sie die MLM-Hierarchie kennen'),
  ('rbac.create_resource', 'https://docs.licenseguard.io/rbac/resources', 'Resources verwalten', 'Was sind Resources und wie werden sie verwendet?'),

  -- API Keys
  ('api_keys.create', 'https://docs.licenseguard.io/api-keys/create', 'API-Keys generieren', 'Erstellen und verwalten Sie API-Schlüssel'),

  -- Users
  ('users.create', 'https://docs.licenseguard.io/users/create', 'Benutzer anlegen', 'Neue Benutzer zur Plattform hinzufügen'),
  ('users.assign_role', 'https://docs.licenseguard.io/users/roles', 'Rollen zuweisen', 'Weisen Sie Benutzern Rollen und Berechtigungen zu'),

  -- Settings
  ('settings.general', 'https://docs.licenseguard.io/settings', 'Systemeinstellungen', 'Konfigurieren Sie die Plattform-Einstellungen')
) AS form_data(form_key, help_url, title, description)
WHERE t.key = 'default'
ON CONFLICT (tenant_id, form_key) DO NOTHING;

-- Comments
COMMENT ON TABLE form_help_links IS 'Context-sensitive help links for forms and modals (CMS-editable)';
COMMENT ON COLUMN form_help_links.form_key IS 'Unique identifier for the form (e.g., rbac.create_role)';
COMMENT ON COLUMN form_help_links.help_url IS 'URL to help documentation (can be external or internal)';
COMMENT ON COLUMN form_help_links.title IS 'Display title for the help link';
COMMENT ON COLUMN form_help_links.description IS 'Short description of what the help covers';

COMMIT;
