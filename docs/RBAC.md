# RBAC Architecture - LicenseGuard Platform

## Organizational Units (Multi-Parent Hierarchie)

### Matrix-Organisation

Das System implementiert **Matrix-Organisation** mit Multi-Parent Support:

```
Acme Corporation (Company)
├── Acme Germany (Subsidiary)
│   ├── Berlin Branch
│   │   ├── Sales Department ← Multi-Parent!
│   │   └── IT Department
│   └── Hamburg Branch
│       └── Sales Department ← Selbes Department, anderer Parent!
└── Acme Austria (Subsidiary)
    └── Vienna Branch
```

**Wichtige Tabellen:**
- `org_units`: Organizational Units (Company, Subsidiary, Branch, Department, Team)
- `org_unit_edges`: Parent-Child Beziehungen (Multi-Parent möglich)
- `org_unit_closure`: Transitive Closure für effiziente Hierarchie-Queries
- `org_unit_role_assignments`: Role-Zuweisung an OUs (mit Inheritance-Flag)

---

## Closure Table Pattern

### Warum Closure Tables?

- **O(1)** Ancestor/Descendant Queries (ohne rekursive CTEs)
- **Multi-Parent** Hierarchien unterstützt
- Effiziente "Find all descendants" / "Find all ancestors"

### Struktur

```sql
CREATE TABLE org_unit_closure (
  ancestor_unit_id UUID,
  descendant_unit_id UUID,
  depth INT,  -- Distanz zwischen ancestor und descendant
  PRIMARY KEY (ancestor_unit_id, descendant_unit_id)
);

-- Selbst-Referenzen (depth=0)
INSERT INTO org_unit_closure (ancestor, descendant, depth)
SELECT id, id, 0 FROM org_units;

-- Transitive Closure (depth>0)
WITH RECURSIVE paths AS (
  SELECT parent_unit_id, child_unit_id, 1 as depth
  FROM org_unit_edges
  UNION ALL
  SELECT p.ancestor_unit_id, e.child_unit_id, p.depth + 1
  FROM paths p
  JOIN org_unit_edges e ON e.parent_unit_id = p.descendant_unit_id
)
INSERT INTO org_unit_closure (ancestor, descendant, depth)
SELECT ancestor_unit_id, descendant_unit_id, MIN(depth)
FROM paths
GROUP BY ancestor_unit_id, descendant_unit_id;
```

### Rebuild nach Struktur-Änderungen

```typescript
// Nach org_unit_edges INSERT/UPDATE/DELETE:
await db.query('INSERT INTO org_unit_edges (parent, child) VALUES ($1, $2)', [parent, child]);
await rebuildOrgUnitClosure(db);  // KRITISCH!
```

**Datei**: `/lg-permissions-service/src/services/closure.ts`

### Effiziente Queries

```sql
-- Alle Descendants einer OU (z.B. für Inheritance)
SELECT DISTINCT ouc.descendant_unit_id, ouc.depth
FROM org_unit_closure ouc
WHERE ouc.ancestor_unit_id = $1
ORDER BY ouc.depth ASC;

-- Alle Ancestors einer OU (z.B. für Upline)
SELECT DISTINCT ouc.ancestor_unit_id, ouc.depth
FROM org_unit_closure ouc
WHERE ouc.descendant_unit_id = $1
ORDER BY ouc.depth ASC;

-- User's effektive Rollen (via OU Membership + Inheritance)
SELECT p.permission_key, rp.effect, ouc.depth
FROM org_user_assignments oua
JOIN org_unit_closure ouc ON ouc.ancestor_unit_id = oua.org_unit_id
JOIN org_unit_role_assignments oura ON oura.org_unit_id = ouc.descendant_unit_id
JOIN rbac_role_permissions rp ON rp.role_id = oura.role_id
JOIN rbac_permissions p ON p.id = rp.permission_id
WHERE oua.user_id = $1
  AND oura.is_inherited = true;
```

---

## Permission Resolution Priority System

### Resolution-Reihenfolge (höhere Priority gewinnt)

1. **User Override** (Priority 10000) - Höchste Priorität
2. **Direct User Role** (Priority 9000) - User → Role direkt
3. **OU Role** (Priority 7000 - depth*10) - User → OU → Role (näher = höher)

**Bei gleicher Priority: DENY schlägt ALLOW**

### Beispiel

```
User Max Mustermann:
- Assigned to: Sales Department (depth=4)
- OU Role: Sales Department → Editor Role (Priority 7000 - 40 = 6960)
- Inherited: Company → Super Admin (Priority 7000 - 0 = 7000)
→ Super Admin gewinnt (7000 > 6960)

- Direct User Role: Max → Viewer (Priority 9000)
→ Viewer gewinnt (9000 > 7000)

- User Override: Max → orders:delete DENY (Priority 10000)
→ DENY gewinnt (10000 > 9000)
```

### Implementation

```typescript
// /lg-permissions-service/src/services/permissionResolver.ts
export async function resolveEffectivePermissions(
  db: DbLike,
  userId: string,
  tenantId: string
): Promise<EffectivePermission[]> {
  const winners = new Map<string, EffectivePermission>();

  // 1. OU Role Permissions (via closure table)
  const ouRoles = await db.query(`
    SELECT p.permission_key, rp.effect, ouc.depth
    FROM org_user_assignments oua
    JOIN org_unit_closure ouc ON ouc.ancestor_unit_id = oua.org_unit_id
    JOIN org_unit_role_assignments oura ON oura.org_unit_id = ouc.descendant_unit_id
    JOIN rbac_role_permissions rp ON rp.role_id = oura.role_id
    JOIN rbac_permissions p ON p.id = rp.permission_id
    WHERE oua.user_id = $1 AND oura.is_inherited = true
  `, [userId]);

  for (const row of ouRoles.rows) {
    const priority = 7000 - (row.depth * 10); // Closer OUs win
    winners.set(row.permission_key, pickWinner(
      winners.get(row.permission_key),
      { permissionKey: row.permission_key, effect: row.effect, priority, source: 'ou_role' }
    ));
  }

  // 2. Direct User Role Assignments (Priority 9000)
  // 3. User Overrides (Priority 10000)
  // ...

  return Array.from(winners.values());
}

function pickWinner(current, candidate) {
  if (!current) return candidate;
  if (candidate.priority > current.priority) return candidate;
  if (candidate.priority < current.priority) return current;
  // Same priority: deny wins
  return candidate.effect === 'deny' ? candidate : current;
}
```

---

## Matrix Visualization (OUs × Rollen)

### Drei visuelle Zustände

- ✓ **Grün (Check)**: Direkt zugewiesen (klickbar zum Entziehen)
- ↓ **Grün Border (Arrow Down)**: Geerbt von Parent OU (disabled, nicht klickbar)
- − **Grau (Minus)**: Nicht zugewiesen (klickbar zum Zuweisen)

### API Endpoints

```bash
# Matrix-Daten laden
GET /api/rbac/org-units              # Alle OUs
GET /api/rbac/roles                  # Alle Rollen
GET /api/rbac/org-units/{id}/roles   # Direkte Assignments (pro OU)
GET /api/rbac/org-units/matrix/effective-roles  # Inherited Roles (alle OUs)

# Role Assignment togglen
POST /api/rbac/org-units/{unitId}/roles
Body: { roleId, isInherited: true }
```

### Frontend Implementation

**Datei**: `/lg-permissions-admin/src/pages/MatrixPage.tsx`

**Features:**
- React Query für parallele Fetches
- Tooltip zeigt Vererbungs-Quelle (`inherited_from`)
- Inherited roles sind disabled (`cursor-help`)

```tsx
<button
  onClick={() => toggle(orgUnit, role)}
  disabled={isInherited}  // Wichtig!
  className={isInherited ? 'cursor-help' : 'cursor-pointer'}
  title={isInherited ? `Inherited from ${inherited_from}` : undefined}
>
  {isDirectlyAssigned ? <Check /> : isInherited ? <ArrowDown /> : <Minus />}
</button>
```

---

## Häufige RBAC Bugs & Lösungen

### 1. Inherited Roles sind klickbar (FALSCH!)

```tsx
// ❌ FALSCH: Alle Rollen sind klickbar
<button onClick={() => toggle(orgUnit, role)}>
  {hasRole ? <Check /> : <Minus />}
</button>

// ✅ RICHTIG: Inherited roles disabled
<button
  onClick={() => toggle(orgUnit, role)}
  disabled={isInherited}  // Wichtig!
  className={isInherited ? 'cursor-help' : 'cursor-pointer'}
>
  {isDirectlyAssigned ? <Check /> : isInherited ? <ArrowDown /> : <Minus />}
</button>
```

### 2. checkForChanges() vergleicht nicht alle Felder

```typescript
// ❌ FALSCH: Nur parent_id vergleichen
const changed = JSON.stringify(items.map(i => ({ id: i.id, parent_id: i.parent_id })))
  !== JSON.stringify(original.map(i => ({ id: i.id, parent_id: i.parent_id })));

// ✅ RICHTIG: Alle relevanten Felder
const changed = JSON.stringify(items.map(i => ({
  id: i.id,
  parent_id: i.parent_id,
  sort_order: i.sort_order  // Wichtig!
}))) !== JSON.stringify(original.map(i => ({
  id: i.id,
  parent_id: i.parent_id,
  sort_order: i.sort_order
})));
```

### 3. Closure Table nicht rebuilt

```typescript
// ❌ FALSCH: Edge hinzufügen ohne Closure Update
await db.query('INSERT INTO org_unit_edges (parent, child) VALUES ($1, $2)', [parent, child]);

// ✅ RICHTIG: Edge hinzufügen + Closure rebuilden
await db.query('INSERT INTO org_unit_edges (parent, child) VALUES ($1, $2)', [parent, child]);
await rebuildOrgUnitClosure(db);  // Wichtig!
```

### 4. Permission Priority falsch berechnet

```typescript
// ❌ FALSCH: Depth ignoriert (alle OUs gleiche Priority)
const priority = 7000;

// ✅ RICHTIG: Nähere OUs haben höhere Priority
const priority = 7000 - (depth * 10);  // depth=0 → 7000, depth=4 → 6960
```

---

## Database Schema (Wichtigste Tabellen)

```sql
-- Organizational Unit Types
CREATE TABLE org_unit_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key VARCHAR(50) NOT NULL UNIQUE,
  display_name VARCHAR(100) NOT NULL,
  hierarchy_level INT NOT NULL,
  allows_multi_parent BOOLEAN DEFAULT false
);

-- Organizational Units
CREATE TABLE org_units (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_unit_type_id UUID NOT NULL REFERENCES org_unit_types(id),
  tenant_id UUID NOT NULL,
  key VARCHAR(100) NOT NULL,
  display_name VARCHAR(255) NOT NULL,
  UNIQUE(tenant_id, key)
);

-- OU Hierarchy (Multi-Parent)
CREATE TABLE org_unit_edges (
  parent_unit_id UUID REFERENCES org_units(id) ON DELETE CASCADE,
  child_unit_id UUID REFERENCES org_units(id) ON DELETE CASCADE,
  PRIMARY KEY (parent_unit_id, child_unit_id),
  CHECK (parent_unit_id != child_unit_id)
);

-- OU Closure Table
CREATE TABLE org_unit_closure (
  ancestor_unit_id UUID REFERENCES org_units(id) ON DELETE CASCADE,
  descendant_unit_id UUID REFERENCES org_units(id) ON DELETE CASCADE,
  depth INT NOT NULL CHECK (depth >= 0),
  PRIMARY KEY (ancestor_unit_id, descendant_unit_id)
);

-- Roles
CREATE TABLE rbac_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  key VARCHAR(100) NOT NULL,
  display_name VARCHAR(255) NOT NULL,
  UNIQUE(tenant_id, key)
);

-- Permissions
CREATE TABLE rbac_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  resource_id UUID REFERENCES rbac_resources(id),
  action_id UUID REFERENCES rbac_actions(id),
  permission_key VARCHAR(200) NOT NULL UNIQUE
);

-- Role → Permission
CREATE TABLE rbac_role_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  role_id UUID REFERENCES rbac_roles(id) ON DELETE CASCADE,
  permission_id UUID REFERENCES rbac_permissions(id) ON DELETE CASCADE,
  effect VARCHAR(10) NOT NULL CHECK (effect IN ('allow', 'deny')),
  UNIQUE(role_id, permission_id)
);

-- User → OU
CREATE TABLE org_user_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  org_unit_id UUID REFERENCES org_units(id) ON DELETE CASCADE,
  is_primary BOOLEAN DEFAULT false,
  UNIQUE(user_id, org_unit_id)
);

-- OU → Role (mit Inheritance)
CREATE TABLE org_unit_role_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_unit_id UUID REFERENCES org_units(id) ON DELETE CASCADE,
  role_id UUID REFERENCES rbac_roles(id) ON DELETE CASCADE,
  is_inherited BOOLEAN DEFAULT true,
  priority INT DEFAULT 1000,
  UNIQUE(org_unit_id, role_id)
);

-- User Permission Overrides (Highest Priority)
CREATE TABLE rbac_user_permission_overrides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  permission_id UUID REFERENCES rbac_permissions(id) ON DELETE CASCADE,
  effect VARCHAR(10) NOT NULL CHECK (effect IN ('allow', 'deny')),
  UNIQUE(user_id, permission_id)
);
```

---

## API Design Patterns

### GET /api/rbac/users/{userId}/effective

**Response:**
```json
{
  "permissions": [
    {
      "permissionKey": "users:read",
      "effect": "allow",
      "priority": 9000,
      "source": "direct_role"
    },
    {
      "permissionKey": "orders:delete",
      "effect": "deny",
      "priority": 10000,
      "source": "user_override"
    }
  ]
}
```

### POST /api/rbac/users/{userId}/check

**Request:**
```json
{
  "resource": "users",
  "action": "read",
  "fields": ["email", "name", "salary"]
}
```

**Response:**
```json
{
  "allowed": true,
  "allowedFields": ["email", "name"],
  "deniedFields": ["salary"]
}
```

---

## Performance Considerations

### Caching Strategy

```typescript
// Redis Cache für Effective Permissions (TTL: 5 min)
const CACHE_KEY = (userId: string) => `user:perms:${userId}`;

export async function getCachedPermissions(userId: string) {
  const cached = await redis.get(CACHE_KEY(userId));
  if (cached) return JSON.parse(cached);

  const perms = await resolveEffectivePermissions(db, userId, tenantId);
  await redis.setex(CACHE_KEY(userId), 300, JSON.stringify(perms));
  return perms;
}

// Invalidate on permission changes
export async function invalidateUserPermissions(userId: string) {
  await redis.del(CACHE_KEY(userId));
}
```

### Index Strategy

```sql
-- Closure table indexes
CREATE INDEX idx_org_unit_closure_descendant ON org_unit_closure(descendant_unit_id);
CREATE INDEX idx_org_unit_closure_depth ON org_unit_closure(depth);

-- User assignments
CREATE INDEX idx_org_user_assignments_user ON org_user_assignments(user_id);
CREATE INDEX idx_org_user_assignments_unit ON org_user_assignments(org_unit_id);

-- Performance: <10ms für effective permissions bei 10k Users, 100 OUs, 50 Roles
```
