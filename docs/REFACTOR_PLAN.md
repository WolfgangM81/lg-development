# Admin Consolidation Refactor Plan

**Status:** Option A (Quick Fix) abgeschlossen - Build erfolgreich, teilweise funktionsfähig
**Datum:** 2026-01-15
**Zweck:** Plan für zukünftigen Clean Refactor (Option C+)

---

## 📊 Aktueller Zustand (nach Option A)

### ✅ Was funktioniert
- **Build**: Erfolgreich (984KB Bundle, 5.5s Build-Zeit)
- **Module Federation**: Entfernt - kein Runtime Overhead mehr
- **User Admin**: Alle Pages laden korrekt
- **Docker**: Ein Container statt 5
- **HMR**: Funktioniert für neue Änderungen

### ⚠️ Was "nervig" ist (Technische Schuld)

**1. Verschachtelte Struktur**
```
lg-admin-shell/src/
├── pages/
│   ├── ProfilePage.tsx           # Alt (Shell, root-level)
│   ├── ChangePasswordPage.tsx    # Alt (Shell, root-level)
│   ├── MenuSettingsPage.tsx      # Alt (Shell, root-level)
│   ├── user/                     # Neu (kopiert, verschachtelt)
│   │   ├── DashboardPage.tsx
│   │   ├── UsersPage.tsx
│   │   └── ...
│   ├── permissions/              # Neu (kopiert, verschachtelt)
│   ├── api-keys/                 # Neu (kopiert, verschachtelt)
│   └── cms/                      # Neu (kopiert, verschachtelt)
└── api/
    ├── user-api/client.ts        # Verschachtelt
    ├── permissions-api/client.ts # Verschachtelt
    ├── api-keys-api/client.ts    # Verschachtelt
    └── cms-api/client.ts         # Verschachtelt
```
**Problem:** Mix aus alter Shell-Struktur und kopierten Remote-Strukturen

**2. Doppelte Component Definitions**
- `lg-admin-shell/src/components/{Button,Card,Input,Modal,Select}.tsx` (kopiert)
- Sollten in `lg-admin-ui` sein (shared library)
- Import-Pfade: Mix aus `@apikeys/admin-ui` und `../../components/ui`

**3. API Client Struktur**
- Jeder Client in eigenem Unterordner (`user-api/`, `permissions-api/`)
- Alle heißen `client.ts` (nicht selbstbeschreibend)
- Import: `from '../../api/permissions-api/client'` (verbose)

**4. Bekannte Runtime-Fehler**
- CMS Pages: React Error (weiße Seite)
- Permissions Pages: React Error (weiße Seite)
- Vermutlich fehlende Exports oder falsche Imports in kopierten Pages

---

## 🎯 Ziel: Saubere Struktur (Option C+)

### Ideale Projektstruktur

```
lg-admin/  (NEU - Consolidated Clean Project)
├── src/
│   ├── pages/
│   │   ├── shell/              # Profile, Password, MenuSettings
│   │   ├── user/               # User Admin (6 pages)
│   │   ├── permissions/        # Permissions Admin (15 pages)
│   │   ├── api-keys/           # API Keys Admin (5 pages)
│   │   └── cms/                # CMS Admin (5 pages)
│   ├── api/
│   │   ├── userApi.ts          # Flat, selbstbeschreibend
│   │   ├── permissionsApi.ts
│   │   ├── apiKeysApi.ts
│   │   └── cmsApi.ts
│   ├── components/
│   │   ├── Layout.tsx          # Admin-spezifische Components
│   │   ├── LoadingSpinner.tsx
│   │   └── menu/               # Menu-spezifisch (MenuItem, etc.)
│   ├── App.tsx                 # Clean Router, keine Federation
│   └── main.tsx
├── vite.config.ts              # Simpel (nur React Plugin)
├── tailwind.config.js          # Ein Config für alles
├── package.json                # Alle Dependencies zentral
└── Dockerfile

lg-admin-ui/  (SHARED - Bleibt)
├── src/
│   ├── components/
│   │   ├── Button.tsx          # Hierhin verschieben!
│   │   ├── Card.tsx            # Hierhin verschieben!
│   │   ├── Input.tsx
│   │   ├── Modal.tsx
│   │   └── Select.tsx
│   └── index.ts                # Exports zentral

lg-menu-registry/  (SHARED - Bleibt)
```

---

## 📋 Refactor-Plan (Schritt-für-Schritt)

### Phase 1: Setup (30 min)

**1.1 Neues Projekt erstellen**
```bash
cd /Users/wolfgang/Projects
mkdir lg-admin
cd lg-admin
npm init -y
```

**1.2 Package.json**
```json
{
  "name": "@licenseguard/admin",
  "dependencies": {
    "@apikeys/admin-ui": "file:../lg-admin-ui",
    "@apikeys/menu-registry": "file:../lg-menu-registry",
    "@dnd-kit/core": "^6.1.0",
    "@dnd-kit/sortable": "^8.0.0",
    "@dnd-kit/utilities": "^3.2.2",
    "@monaco-editor/react": "^4.6.0",
    "@tanstack/react-query": "^5.17.0",
    "@xyflow/react": "^12.3.5",
    "dagre": "^0.8.5",
    "js-yaml": "^4.1.0",
    "lucide-react": "^0.303.0",
    "react": "^18.2.0",
    "react-complex-tree": "^2.6.1",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.21.1",
    "zod": "^3.22.4"
  }
}
```

**1.3 Vite Config (simpel!)**
```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  base: '/admin/',
  plugins: [react()],
  // Kein Federation Plugin!
});
```

**1.4 Docker Setup**
```dockerfile
# lg-admin/Dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
# ... Nginx serving
```

**1.5 Tailwind Config**
```javascript
module.exports = {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
    "/workspace/lg-admin-ui/src/**/*.{js,ts,jsx,tsx}",  // Docker
    "../lg-admin-ui/src/**/*.{js,ts,jsx,tsx}",          // Lokal
  ],
};
```

---

### Phase 2: UI Components bereinigen (30 min)

**2.1 Components zu lg-admin-ui verschieben**

Folgende Components aus `lg-admin-shell/src/components/` → `lg-admin-ui/src/components/`:
- `Button.tsx`
- `Card.tsx`
- `Input.tsx`
- `Modal.tsx` (falls anders als existing)
- `Select.tsx`

**2.2 lg-admin-ui/src/index.ts erweitern**
```typescript
// Basis UI Components
export { Button } from './components/Button';
export { Card, CardHeader, CardContent } from './components/Card';
export { Input } from './components/Input';
export { Select } from './components/Select';
// ... rest bleibt
```

**2.3 Alle Pages umschreiben**
```typescript
// Alt
import { Card } from '../../components/ui';

// Neu
import { Card } from '@apikeys/admin-ui';
```

---

### Phase 3: API Clients konsolidieren (45 min)

**3.1 User API**
```typescript
// lg-admin/src/api/userApi.ts
const BASE_URL = '/api/user';

export const userApi = {
  getUsers: async () => { /* ... */ },
  createUser: async (data) => { /* ... */ },
  // ... alle User-bezogenen Calls
};
```

**3.2 Permissions API**
```typescript
// lg-admin/src/api/permissionsApi.ts
const BASE_URL = '/api/rbac';

export const permissionsApi = {
  getModules: async () => { /* ... */ },
  createRole: async (data) => { /* ... */ },
  // ... alle Permissions-bezogenen Calls
};
```

**3.3 API Keys API**
```typescript
// lg-admin/src/api/apiKeysApi.ts
```

**3.4 CMS API**
```typescript
// lg-admin/src/api/cmsApi.ts
```

**Import in Pages:**
```typescript
// Alt
import { apiClient } from '../../api/user-api/client';

// Neu
import { userApi } from '../../api/userApi';
```

---

### Phase 4: Pages Modul-für-Modul migrieren

**Reihenfolge (einfach → komplex):**

#### 4.1 User Admin (6 pages) - 30 min
1. `DashboardPage.tsx`
2. `UsersPage.tsx`
3. `ApiKeysPage.tsx`
4. `AuditLogPage.tsx`
5. `LoginPage.tsx`
6. `ProfilePage.tsx`

**Pro Page:**
- Kopieren nach `lg-admin/src/pages/user/`
- API Import anpassen (`userApi`)
- UI Component Imports prüfen (`@apikeys/admin-ui`)
- **Browser Test!** (sofort testen)

#### 4.2 API Keys Admin (5 pages) - 30 min
Gleicher Prozess wie User Admin

#### 4.3 CMS Admin (5 pages) - 45 min
Gleicher Prozess, plus:
- YAML handling testen
- Monaco Editor prüfen

#### 4.4 Permissions Admin (15 pages) - 1h
Komplexeste Sektion:
- ReactFlow Dependencies
- DAG Visualisierung
- Matrix UI
- OrgUnits Tree

**Wichtig:** Nach JEDER Page sofort Browser-Test!

---

### Phase 5: Shell Pages (30 min)

**5.1 Shell-spezifische Pages**
Verschieben nach `lg-admin/src/pages/shell/`:
- `ProfilePage.tsx`
- `ChangePasswordPage.tsx`
- `MenuSettingsPage.tsx`

**5.2 Menu Components**
Behalten in `lg-admin/src/components/menu/`:
- `MenuItem.tsx`
- `RootDropZone.tsx`
- `MenuButtonControls.tsx`
- etc.

---

### Phase 6: Router & Layout (15 min)

**6.1 App.tsx (Clean!)**
```typescript
import { Routes, Route, Navigate } from 'react-router-dom';
import { AdminLayout } from '@apikeys/admin-ui';
import { lazy, Suspense } from 'react';

// User Admin
const UserDashboard = lazy(() => import('./pages/user/DashboardPage'));
const UsersPage = lazy(() => import('./pages/user/UsersPage'));
// ... mehr

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<AdminLayout />}>
        <Route index element={<Navigate to="/user/dashboard" />} />
        <Route path="user">
          <Route path="dashboard" element={<UserDashboard />} />
          <Route path="users" element={<UsersPage />} />
          {/* ... */}
        </Route>
        {/* ... mehr */}
      </Route>
    </Routes>
  );
}
```

---

### Phase 7: Docker Integration (15 min)

**7.1 docker-compose.yml anpassen**
```yaml
services:
  admin:  # Umbenennen von admin-shell
    build:
      context: ..
      dockerfile: lg-admin/Dockerfile
    restart: unless-stopped
    depends_on:
      - user-service
      - permissions-service
      - api-keys-service
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.admin.rule=PathPrefix(`/admin`)"
      - "traefik.http.services.admin.loadbalancer.server.port=3000"
```

**7.2 Alte Services entfernen**
```bash
docker-compose down admin-shell user-admin permissions-admin api-keys-admin cms-admin
```

---

## ⏱️ Zeitaufwand Gesamt

| Phase | Aufwand | Kumulativ |
|-------|---------|-----------|
| 1. Setup | 30 min | 30 min |
| 2. UI Components | 30 min | 1h |
| 3. API Clients | 45 min | 1h 45m |
| 4. User Admin | 30 min | 2h 15m |
| 4. API Keys | 30 min | 2h 45m |
| 4. CMS Admin | 45 min | 3h 30m |
| 4. Permissions | 1h | 4h 30m |
| 5. Shell Pages | 30 min | 5h |
| 6. Router | 15 min | 5h 15m |
| 7. Docker | 15 min | 5h 30m |
| **Buffer & Tests** | 30 min | **6h total** |

**Realistisch: 1 Arbeitstag**

---

## 🚀 Vorteile nach Refactor

### Entwicklung
- ✅ **HMR < 100ms** (statt Rebuild-Cycle)
- ✅ **Build ~5s** (unverändert, aber sauber)
- ✅ **TypeScript errors sofort** (keine Federation Types)
- ✅ **Einfaches Debugging** (ein Bundle, Source Maps klar)
- ✅ **Neue Features schneller** (keine Import-Pfad-Rätsel)

### Code-Qualität
- ✅ **Konsistente Struktur** (alles flach, klar organisiert)
- ✅ **Klare API Client Separation**
- ✅ **Keine Component-Duplikate**
- ✅ **Shared UI Library sauber**
- ✅ **Einfacher für neue Entwickler**

### Deployment
- ✅ **Ein Docker Image** statt 5
- ✅ **Kleineres Gesamt-Image** (~300MB)
- ✅ **Einfachere CI/CD Pipeline**
- ✅ **Weniger Docker Resources** (RAM, CPU)

---

## 🔄 Migration-Strategie

### Option 1: Big Bang (Empfohlen für Refactor)
1. Komplettes `lg-admin` Projekt neu aufsetzen
2. Modul für Modul migrieren mit Tests
3. Wenn komplett → `lg-admin-shell` löschen
4. **Downtime:** Minimal (Hot-Swap)

### Option 2: Inkrementell
1. `lg-admin` parallel zu `lg-admin-shell` entwickeln
2. Feature-Flag für Routing zwischen alt/neu
3. Modul für Modul umschalten
4. Wenn alles umgestellt → Altes löschen
5. **Downtime:** Keine

**Empfehlung:** Option 1 - sauberer, schneller fertig

---

## 📝 Checkliste vor Start

- [ ] CLAUDE.md backup erstellen
- [ ] Aktuelle docker-compose.yml backup
- [ ] Alle offenen Features committed
- [ ] Tests laufen durch
- [ ] User informiert über Refactor
- [ ] Zeit geblockt (1 Tag)

---

## 🐛 Bekannte Issues (aktueller Zustand)

### Zu fixen bei Refactor:
1. **CMS Pages**: React Errors beim Laden
2. **Permissions Pages**: React Errors beim Laden
3. **Component Imports**: Mix aus `@apikeys/admin-ui` und `../../components/ui`
4. **API Client Pfade**: Verschachtelt und verbose
5. **Duplicate Components**: Button, Card, etc. in zwei Orten

### Quick-Fixes (falls Refactor verschoben wird):
```bash
# CMS Errors debuggen
docker logs lg-platform-admin-shell-1 | grep -i error

# Component Imports vereinheitlichen
find src/pages -name "*.tsx" -exec sed -i '' 's|from "../../components/ui"|from "@apikeys/admin-ui"|g' {} \;
```

---

## 📚 Referenzen

- **Aktueller Code**: `/Users/wolfgang/Projects/lg-admin-shell`
- **CLAUDE.md**: Aktuelle Architektur-Dokumentation
- **docker-compose.yml**: Container-Setup
- **TESTING.md**: Test-Strategie

---

## ✅ Wann solltest du refactoren?

**Refactor JETZT wenn:**
- ✅ Du mehrere neue Features planst
- ✅ Die aktuellen Errors nerven
- ✅ Du 1 Tag Zeit investieren kannst
- ✅ Code-Qualität wichtig ist

**Warte mit Refactor wenn:**
- ⏳ Deadline ist nah
- ⏳ Nur kleine Bugfixes anstehen
- ⏳ Aktueller Zustand "gut genug" ist

---

**Erstellt:** 2026-01-15
**Status:** Option A funktioniert teilweise, Refactor-Plan bereit
**Nächster Schritt:** CLAUDE.md updaten mit aktuellem Zustand
