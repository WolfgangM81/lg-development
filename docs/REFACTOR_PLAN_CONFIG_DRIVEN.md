# Config-Driven Architecture Refactor Plan

**Status:** DRAFT
**Erstellt:** 2026-01-15
**Ziel:** Große React-Komponenten durch Config-gesteuerte, generische Komponenten ersetzen

---

## Problem-Analyse

### Aktuelle Situation

**Größte Dateien (Lines of Code):**
```
617 lines: RBACGuidePage.tsx        (statischer Content)
496 lines: ApiKeysPage.tsx (x3!)    (CRUD Forms + Tables, DUPLIZIERT!)
463 lines: ResourcesPage.tsx        (CRUD)
440 lines: VariantsPage.tsx         (CRUD)
349 lines: MatrixPage.tsx           (Komplexe UI-Logik)
310 lines: FieldTypesPage.tsx       (CRUD)
308 lines: UsersPage.tsx (x3!)      (CRUD, DUPLIZIERT!)
```

**Bundle Sizes (Production Build):**
```
273 KB: OrgUnitsPage (91 KB gzip)   ← KRITISCH!
883 KB: index.js (184 KB gzip)      ← Hauptbundle
```

**Hauptprobleme:**
1. ❌ **Code-Duplikation**: ApiKeysPage existiert 3x identisch (user/api-keys/permissions)
2. ❌ **Große Bundles**: OrgUnitsPage allein 273KB
3. ❌ **Wartbarkeit**: Jede Änderung muss in vielen Files gemacht werden
4. ❌ **Boilerplate**: 80% jeder CRUD-Page ist identisch
5. ❌ **Statische Daten**: Viele Pages enthalten nur Content/Config

---

## Lösungsansatz: Config-Driven Components

### Prinzip

**VORHER (Status Quo):**
```tsx
// pages/user/UsersPage.tsx (308 Zeilen)
export default function UsersPage() {
  const [formData, setFormData] = useState({ email: '', name: '', role: 'user' });
  const createMutation = useMutation({ ... });

  return (
    <div>
      <Modal>
        <form>
          <Input label="E-Mail" name="email" type="email" required />
          <Input label="Name" name="name" required />
          <Select label="Role" name="role" options={...} />
          <Button type="submit">Create</Button>
        </form>
      </Modal>
      <DataTable columns={...} data={users} />
    </div>
  );
}
```

**NACHHER (Config-Driven):**
```yaml
# configs/pages/users.yaml
entity: users
title: Users
description: Manage users in the system

fields:
  - key: email
    label: E-Mail
    type: email
    required: true
    validation:
      pattern: "^[^@]+@[^@]+\\.[^@]+$"

  - key: name
    label: Name
    type: text
    required: true

  - key: role
    label: Role
    type: select
    options:
      - value: user
        label: User
      - value: admin
        label: Admin

table:
  columns:
    - key: email
      label: E-Mail
      sortable: true
    - key: name
      label: Name
      sortable: true
    - key: role
      label: Role
      badge: true

api:
  list: /api/user/users
  create: /api/user/users
  update: /api/user/users/:id
  delete: /api/user/users/:id
```

```tsx
// pages/user/UsersPage.tsx (5 Zeilen!)
import { CRUDPage } from '@apikeys/admin-ui';
import usersConfig from '../../configs/pages/users.yaml';

export default function UsersPage() {
  return <CRUDPage config={usersConfig} />;
}
```

**Reduktion: 308 → 5 Zeilen (98% weniger Code!)**

---

## Phase 1: Generic CRUD Component

**Ziel:** Generische `<CRUDPage>` Komponente für Standard-CRUD Operationen

### Betroffene Pages (Immediate Impact)
- `UsersPage.tsx` (3x dupliziert) → 924 LOC gespart
- `ApiKeysPage.tsx` (3x dupliziert) → 1,488 LOC gespart
- `ResourcesPage.tsx` → 463 LOC gespart
- `VariantsPage.tsx` → 440 LOC gespart
- `RolesPage.tsx` → 295 LOC gespart
- `PermissionsPage.tsx` → 291 LOC gespart
- `ModulesPage.tsx` → 301 LOC gespart
- `GroupsPage.tsx` → 287 LOC gespart

**Total Savings:** ~4,500 Lines of Code → ~40 Lines

### Implementation

**1. Config Schema (TypeScript)**

```typescript
// lg-admin-ui/src/types/CRUDConfig.ts
export interface FieldConfig {
  key: string;
  label: string;
  type: 'text' | 'email' | 'password' | 'number' | 'select' | 'checkbox' | 'date' | 'textarea';
  required?: boolean;
  placeholder?: string;
  defaultValue?: any;
  validation?: {
    pattern?: string;
    min?: number;
    max?: number;
    minLength?: number;
    maxLength?: number;
  };
  options?: Array<{ value: string; label: string }>;
  disabled?: boolean;
  hidden?: boolean;
  helpText?: string;
}

export interface ColumnConfig {
  key: string;
  label: string;
  sortable?: boolean;
  filterable?: boolean;
  type?: 'text' | 'badge' | 'date' | 'boolean' | 'actions';
  format?: (value: any) => string;
  badge?: {
    colorMap?: Record<string, string>;
  };
}

export interface CRUDConfig {
  entity: string;
  title: string;
  description?: string;

  fields: FieldConfig[];

  table: {
    columns: ColumnConfig[];
    searchable?: boolean;
    paginated?: boolean;
    defaultSort?: { key: string; direction: 'asc' | 'desc' };
  };

  api: {
    list: string;
    create: string;
    update: string;
    delete: string;
  };

  permissions?: {
    create?: string;
    update?: string;
    delete?: string;
  };
}
```

**2. Generic CRUD Component**

```tsx
// lg-admin-ui/src/components/CRUDPage.tsx
import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { CRUDConfig } from '../types/CRUDConfig';
import { Modal, Button, Card } from './index';
import { DynamicForm } from './DynamicForm';
import { DataTable } from './DataTable';

interface CRUDPageProps {
  config: CRUDConfig;
  apiClient: any; // Generic API client
}

export function CRUDPage({ config, apiClient }: CRUDPageProps) {
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [editingItem, setEditingItem] = useState<any>(null);
  const queryClient = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: [config.entity],
    queryFn: () => apiClient.request('GET', config.api.list),
  });

  const createMutation = useMutation({
    mutationFn: (data: any) => apiClient.request('POST', config.api.create, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [config.entity] });
      setIsCreateOpen(false);
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: any) =>
      apiClient.request('PUT', config.api.update.replace(':id', id), data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [config.entity] });
      setEditingItem(null);
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => apiClient.request('DELETE', config.api.delete.replace(':id', id)),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [config.entity] });
    },
  });

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold">{config.title}</h1>
          {config.description && <p className="text-gray-500">{config.description}</p>}
        </div>
        <Button onClick={() => setIsCreateOpen(true)}>Create {config.entity}</Button>
      </div>

      <Card>
        <DataTable
          columns={config.table.columns}
          data={data?.data || []}
          isLoading={isLoading}
          onEdit={setEditingItem}
          onDelete={(item) => {
            if (confirm(`Delete ${config.entity}?`)) deleteMutation.mutate(item.id);
          }}
        />
      </Card>

      <Modal isOpen={isCreateOpen} onClose={() => setIsCreateOpen(false)}>
        <DynamicForm
          fields={config.fields}
          onSubmit={(data) => createMutation.mutate(data)}
          isLoading={createMutation.isPending}
        />
      </Modal>

      <Modal isOpen={!!editingItem} onClose={() => setEditingItem(null)}>
        <DynamicForm
          fields={config.fields}
          initialValues={editingItem}
          onSubmit={(data) => updateMutation.mutate({ id: editingItem.id, data })}
          isLoading={updateMutation.isPending}
        />
      </Modal>
    </div>
  );
}
```

**3. Dynamic Form Component**

```tsx
// lg-admin-ui/src/components/DynamicForm.tsx
import { useState } from 'react';
import { FieldConfig } from '../types/CRUDConfig';
import { Input, Select, Button } from './index';

interface DynamicFormProps {
  fields: FieldConfig[];
  initialValues?: Record<string, any>;
  onSubmit: (data: Record<string, any>) => void;
  isLoading?: boolean;
}

export function DynamicForm({ fields, initialValues = {}, onSubmit, isLoading }: DynamicFormProps) {
  const [formData, setFormData] = useState(initialValues);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {fields.map((field) => {
        if (field.hidden) return null;

        const commonProps = {
          key: field.key,
          label: field.label,
          value: formData[field.key] || field.defaultValue || '',
          onChange: (e: any) => setFormData({ ...formData, [field.key]: e.target.value }),
          required: field.required,
          disabled: field.disabled || isLoading,
        };

        switch (field.type) {
          case 'select':
            return <Select {...commonProps} options={field.options || []} />;
          case 'textarea':
            return <textarea {...commonProps} className="w-full border rounded p-2" />;
          default:
            return <Input {...commonProps} type={field.type} />;
        }
      })}

      <Button type="submit" disabled={isLoading}>
        {isLoading ? 'Saving...' : 'Save'}
      </Button>
    </form>
  );
}
```

**4. Config Files Structure**

```
lg-admin/
├── src/
│   ├── configs/
│   │   ├── pages/
│   │   │   ├── users.yaml
│   │   │   ├── api-keys.yaml
│   │   │   ├── resources.yaml
│   │   │   ├── roles.yaml
│   │   │   └── permissions.yaml
│   │   └── index.ts (exports all configs)
│   └── pages/
│       ├── user/
│       │   └── UsersPage.tsx (5 lines!)
│       └── permissions/
│           └── UsersPage.tsx (5 lines!)
```

**5. YAML Loader (Vite Plugin)**

```typescript
// vite.config.ts
import yaml from '@rollup/plugin-yaml';

export default defineConfig({
  plugins: [
    react(),
    yaml() // Erlaubt import von .yaml Files
  ],
});
```

### Migration Steps

1. ✅ **Generic Components erstellen** (CRUDPage, DynamicForm, DataTable)
2. ✅ **Config Schema definieren** (TypeScript Types)
3. ✅ **YAML Plugin installieren** (@rollup/plugin-yaml)
4. ✅ **Eine Page migrieren** (z.B. UsersPage) als Proof of Concept
5. ✅ **Testen** (Unit + E2E Tests)
6. ✅ **Restliche Pages migrieren** (batch migration)
7. ✅ **Alte Pages löschen**

---

## Phase 2: Static Content Pages

**Ziel:** Markdown/YAML für Content-Pages (RBACGuidePage: 617 Zeilen!)

### Betroffene Pages
- `RBACGuidePage.tsx` (617 LOC) → Markdown Guide
- Dashboard Statistics (repetitive stat cards)

### Implementation

**1. Markdown Content**

```markdown
<!-- configs/content/rbac-guide.md -->
# RBAC Architecture Guide

## Overview
LicenseGuard uses a hierarchical RBAC system with...

## Key Concepts

### Roles
Roles define sets of permissions...

### Resources
Resources are the entities being protected...

### Permissions
Permissions grant access to specific actions...
```

**2. Generic Content Page**

```tsx
// lg-admin-ui/src/components/ContentPage.tsx
import ReactMarkdown from 'react-markdown';
import { Card } from './Card';

interface ContentPageProps {
  markdown: string;
}

export function ContentPage({ markdown }: ContentPageProps) {
  return (
    <Card>
      <div className="prose max-w-none">
        <ReactMarkdown>{markdown}</ReactMarkdown>
      </div>
    </Card>
  );
}
```

**3. Usage**

```tsx
// pages/permissions/RBACGuidePage.tsx (3 Zeilen!)
import { ContentPage } from '@apikeys/admin-ui';
import guideContent from '../../configs/content/rbac-guide.md';

export default function RBACGuidePage() {
  return <ContentPage markdown={guideContent} />;
}
```

**Reduktion: 617 → 3 Zeilen (99% weniger Code!)**

---

## Phase 3: Dashboard Widgets

**Ziel:** Dashboard-Konfiguration via YAML

### Config Example

```yaml
# configs/dashboards/permissions-dashboard.yaml
title: Permissions Dashboard
widgets:
  - type: stat-card
    title: Total Roles
    icon: shield
    color: primary
    query:
      endpoint: /api/permissions/stats
      path: totalRoles

  - type: stat-card
    title: Active Permissions
    icon: key
    color: green
    query:
      endpoint: /api/permissions/stats
      path: activePermissions

  - type: chart
    title: Permission Usage
    type: line
    query:
      endpoint: /api/permissions/usage
      x: date
      y: count
```

---

## Phase 4: Complex UI (OrgUnitsPage)

**Problem:** OrgUnitsPage ist 273KB! Wahrscheinlich Tree-Komponente mit viel Daten.

**Analyse nötig:**
- Ist es react-complex-tree Library?
- Sind es inline Daten?
- Ist es komplexe Logic?

**Mögliche Lösungen:**
1. **Tree Config**: Tree-Struktur aus Backend laden
2. **Code Splitting**: Lazy-load Tree Component
3. **Virtualization**: Nur sichtbare Nodes rendern

**TODO:** OrgUnitsPage analysieren für spezifische Lösung

---

## ROI-Kalkulation

### Code-Reduktion (Phase 1 nur)

| Kategorie | Vorher (LOC) | Nachher (LOC) | Ersparnis |
|-----------|--------------|---------------|-----------|
| CRUD Pages (11 Pages) | ~4,500 | ~55 | 98.8% |
| Content Pages (1 Page) | 617 | 3 | 99.5% |
| **Total Phase 1+2** | **5,117** | **58** | **98.9%** |

### Bundle-Size Reduktion (geschätzt)

| File | Vorher | Nachher | Ersparnis |
|------|--------|---------|-----------|
| CRUD Pages | ~450 KB | ~50 KB | 88% |
| Content Pages | ~30 KB | ~3 KB | 90% |
| Generic Components | 0 KB | ~40 KB | +40 KB |
| **Net Savings** | | | **~390 KB** |

### Wartbarkeit

- ✅ **1 Stelle ändern** statt 3 (bei duplizierten Pages)
- ✅ **Config-Dateien** können von Non-Developers bearbeitet werden
- ✅ **Unit Tests** nur für Generic Components nötig
- ✅ **Konsistenz** automatisch durch Generic Components

---

## Risiken & Mitigation

### Risiko 1: Generic Component ist zu generisch
**Problem:** Deckt nicht alle Edge Cases ab
**Mitigation:**
- Escape Hatch: `customRenderer` Props
- Hybrid: Config + Custom Code

```tsx
<CRUDPage
  config={usersConfig}
  customColumns={{
    role: (value) => <CustomRoleBadge role={value} />
  }}
/>
```

### Risiko 2: Performance
**Problem:** Dynamisches Rendern langsamer als statischer Code
**Mitigation:**
- Memoization (React.memo, useMemo)
- Config Parsing zur Build-Time
- Benchmarks vor/nach Migration

### Risiko 3: TypeScript Type Safety
**Problem:** Config ist runtime, verlieren Type-Safety
**Mitigation:**
- Zod Schema Validation
- TypeScript für Config Types
- Build-Time Config Validation

```typescript
import { z } from 'zod';

const CRUDConfigSchema = z.object({
  entity: z.string(),
  title: z.string(),
  fields: z.array(FieldConfigSchema),
  // ...
});

// Validate at import time
export const usersConfig = CRUDConfigSchema.parse(rawUsersConfig);
```

---

## Timeline

### Phase 1: Generic CRUD (2-3 Tage)
- Tag 1: Generic Components + Config Schema
- Tag 2: Eine Page migrieren + Tests
- Tag 3: Restliche Pages migrieren

### Phase 2: Static Content (1 Tag)
- ContentPage Component + RBACGuidePage Migration

### Phase 3: Dashboards (1-2 Tage)
- Dashboard Config Schema + Generic Widgets

### Phase 4: OrgUnitsPage (TBD)
- Analyse + Spezifische Lösung

**Total: 5-7 Tage**

---

## Next Steps

1. **Decision:** Welche Phase zuerst? (Empfehlung: Phase 1)
2. **Proof of Concept:** Eine Page (UsersPage) als PoC migrieren
3. **Review:** PoC reviewen, Feedback einarbeiten
4. **Batch Migration:** Restliche Pages migrieren
5. **Testing:** E2E Tests für Generic Components
6. **Documentation:** Config Schema dokumentieren

---

## Appendix: Alternative Approaches

### JSON vs YAML
**YAML Vorteile:**
- Besser lesbar
- Weniger Boilerplate (keine Quotes)
- Kommentare möglich

**JSON Vorteile:**
- Native JavaScript Support
- Schnelleres Parsing
- Bessere IDE Support

**Empfehlung:** YAML für Configs, JSON für Runtime-Daten

### Code Generation vs Runtime
**Code Generation:**
```bash
# Generate React Components from Configs
npm run generate-pages
```
- ✅ Type-Safe
- ✅ Schneller (kein Runtime Parsing)
- ❌ Extra Build Step

**Runtime (Current Approach):**
- ✅ Hot Module Reload
- ✅ Dynamic Config Loading
- ❌ Runtime Overhead (minimal)

**Empfehlung:** Runtime first, Code Generation later if needed

---

## Fazit

**Config-Driven Architecture** ist die richtige Strategie für dieses Projekt weil:

1. ✅ **Massive Code-Reduktion** (~98% weniger LOC)
2. ✅ **DRY Principle** (keine Duplikation mehr)
3. ✅ **Wartbarkeit** (1 Generic Component statt 11 Pages)
4. ✅ **Konsistenz** (automatisch durch Generic Components)
5. ✅ **Non-Developer Friendly** (Configs statt Code)

**Start:** Phase 1 (Generic CRUD) → Immediate ROI, klarer Proof of Concept
