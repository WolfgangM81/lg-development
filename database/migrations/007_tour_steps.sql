-- Migration: Tour Steps für NextStepjs Integration
-- Description: Stores interactive tour steps for forms/modals (CMS-editable)
-- Version: 007
-- Date: 2026-01-15

BEGIN;

-- Tour Steps Table
CREATE TABLE IF NOT EXISTS tour_steps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,

  -- Form/Modal Identifier (e.g., 'rbac.create_role')
  form_key VARCHAR(255) NOT NULL,

  -- Step Configuration
  step_order INTEGER NOT NULL DEFAULT 0,
  selector VARCHAR(500), -- CSS selector for target element (e.g., 'input[name="key"]', '.help-button')
  title VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  icon VARCHAR(100), -- Emoji or icon identifier (e.g., '🎯', 'rocket')

  -- Position & Behavior
  side VARCHAR(20) DEFAULT 'bottom', -- top, bottom, left, right, top-left, top-right, etc.
  show_controls BOOLEAN DEFAULT true,
  show_skip BOOLEAN DEFAULT true,

  -- Metadata
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID,
  updated_by UUID,

  -- Unique step order per form
  UNIQUE(tenant_id, form_key, step_order)
);

-- Indexes
CREATE INDEX idx_tour_steps_tenant ON tour_steps(tenant_id);
CREATE INDEX idx_tour_steps_form_key ON tour_steps(form_key);
CREATE INDEX idx_tour_steps_active ON tour_steps(is_active) WHERE is_active = true;
CREATE INDEX idx_tour_steps_order ON tour_steps(form_key, step_order);

-- Updated At Trigger
CREATE TRIGGER tour_steps_updated_at
  BEFORE UPDATE ON tour_steps
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Seed Initial Tour Steps (for default tenant)
INSERT INTO tour_steps (tenant_id, form_key, step_order, selector, title, content, icon, side, show_controls, show_skip, is_active)
SELECT
  t.id as tenant_id,
  step_data.form_key,
  step_data.step_order,
  step_data.selector,
  step_data.title,
  step_data.content,
  step_data.icon,
  step_data.side,
  true as show_controls,
  true as show_skip,
  true as is_active
FROM tenants t
CROSS JOIN (VALUES
  -- RBAC Create Role Tour
  ('rbac.create_role', 1, 'input[name="key"]', 'Schlüssel eingeben', 'Der Schlüssel ist ein eindeutiger technischer Identifier. Verwenden Sie nur Kleinbuchstaben, Zahlen und Unterstriche.', '🔑', 'bottom'),
  ('rbac.create_role', 2, 'input[name="displayName"]', 'Anzeigename definieren', 'Der Anzeigename wird in der Benutzeroberfläche angezeigt. Wählen Sie einen klaren, beschreibenden Namen.', '✏️', 'bottom'),
  ('rbac.create_role', 3, 'input[name="description"]', 'Beschreibung hinzufügen', 'Eine hilfreiche Beschreibung erleichtert anderen Administratoren das Verständnis dieser Rolle.', '📝', 'bottom'),

  -- RBAC Create OrgUnit Tour
  ('rbac.create_org_unit', 1, 'select[name="orgUnitTypeId"]', 'Typ auswählen', 'Wählen Sie die Hierarchieebene: Unternehmen → Zweigstelle → Abteilung → Team. Dies bestimmt die Position in der MLM-Struktur.', '🏢', 'bottom'),
  ('rbac.create_org_unit', 2, 'input[name="key"]', 'Eindeutigen Schlüssel vergeben', 'Der Schlüssel identifiziert diese Organisationseinheit eindeutig im System.', '🔑', 'bottom'),
  ('rbac.create_org_unit', 3, 'input[name="displayName"]', 'Namen festlegen', 'Geben Sie einen aussagekräftigen Namen ein, z.B. "Hauptsitz München" oder "Vertrieb Nord".', '🏷️', 'bottom'),

  -- RBAC Create Resource Tour
  ('rbac.create_resource', 1, 'input[name="key"]', 'Resource Key definieren', 'Verwenden Sie Plural-Form und snake_case, z.B. "api_keys", "user_profiles", "sales_reports".', '📦', 'bottom'),
  ('rbac.create_resource', 2, 'input[name="displayName"]', 'Benutzerfreundlichen Namen wählen', 'Dies ist der Name, den Benutzer in der Berechtigungsverwaltung sehen.', '🏷️', 'bottom'),

  -- API Keys Create Tour
  ('api_keys.create', 1, 'select[name="userId"]', 'Benutzer auswählen', 'Wählen Sie den Benutzer, für den dieser API-Key generiert werden soll.', '👤', 'bottom'),
  ('api_keys.create', 2, 'input[name="name"]', 'Key benennen', 'Ein optionaler Name hilft bei der Identifikation (z.B. "Produktiv-Key", "Test-Integration").', '🏷️', 'bottom'),
  ('api_keys.create', 3, 'select[name="tier"]', 'Tier festlegen', 'Der Tier bestimmt die Nutzungslimits: Basic (begrenzt), Pro (erweitert), Enterprise (unbegrenzt).', '⭐', 'bottom')
) AS step_data(form_key, step_order, selector, title, content, icon, side)
WHERE t.key = 'default'
ON CONFLICT (tenant_id, form_key, step_order) DO NOTHING;

-- Comments
COMMENT ON TABLE tour_steps IS 'Interactive tour steps for NextStepjs onboarding (CMS-editable)';
COMMENT ON COLUMN tour_steps.form_key IS 'Identifier for the form/modal (e.g., rbac.create_role)';
COMMENT ON COLUMN tour_steps.step_order IS 'Order of steps in the tour (1, 2, 3, ...)';
COMMENT ON COLUMN tour_steps.selector IS 'CSS selector to target element (optional for general info steps)';
COMMENT ON COLUMN tour_steps.side IS 'Position of the card relative to target: top, bottom, left, right, top-left, etc.';
COMMENT ON COLUMN tour_steps.show_controls IS 'Show next/prev buttons';
COMMENT ON COLUMN tour_steps.show_skip IS 'Show skip button';

COMMIT;
