# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

# Claude Code Projekt-Konfiguration

## 📖 Dokumentationsstruktur

Für detaillierte Informationen siehe dedizierte Dokumentationen:
- **[TESTING.md](./TESTING.md)** - E2E Tests (Playwright), Unit Tests (Vitest), Coverage Best Practices
- **[DOCKER.md](./DOCKER.md)** - Dockerfile Patterns, Docker Compose, Nginx Config, Performance
- **[RBAC.md](./RBAC.md)** - Organizational Units, Closure Tables, Permission Resolution, Matrix UI
- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** - Fehlerbehebung, Debug Commands, Häufige Probleme
- **[GOTCHAS.md](./GOTCHAS.md)** - Kritische Bugs & Learnings (useState mit Props, Trial & Error)

**Diese Datei (CLAUDE.md):** Kritische Regeln, Architektur-Überblick, häufige Workflows

## 🗂️ Projekt-Kontext: Multi-Projekt Workspace

Dieses Workspace enthält **mehrere LicenseGuard-Projekte**:

### Hauptprojekt: lg-admin (Konsolidierte Admin Platform)
- **Status:** ✅ Production Ready
- **Port:** 81 (via Traefik: `http://localhost:81/admin/`)
- **Tech:** Vite, React 19, React Router 7, TailwindCSS
- **Kontext:** [Siehe unten - Projekt-Kontext](#projekt-kontext)

### lg-management (Next.js Migration)
- **Status:** ⚠️ ~10% Complete (Early Migration Phase)
- **Port:** 82 (via Traefik: `http://localhost:82`)
- **Tech:** Next.js 16, Turborepo, pnpm, Tailwind v4
- **Kontext:** Siehe [lg-management/CLAUDE.md](./lg-management/CLAUDE.md)

### lg-development (Repository Manager)
- **Status:** ✅ Migration Tool (Einmalige Nutzung)
- **Zweck:** Automation für Monorepo → Multi-Repo Migration
- **Kontext:** Siehe [lg-development/CLAUDE.md](./lg-development/CLAUDE.md)

### Weitere Services
- `lg-secrets-service`: Secrets & Config Management (Port 3004)
- `lg-menu-service`: Dynamic Menu Configuration (Port 3005)
- `lg-tour-service`: Guided Tours & Onboarding (Port 3006)

**Wichtig:** Jedes Projekt hat eigene CLAUDE.md mit projekt-spezifischen Regeln!

### Welches Projekt für welche Task?

| Task | Projekt | Kontext |
|------|---------|---------|
| Admin UI entwickeln (Production) | `lg-admin` | Konsolidierte Vite/React App |
| Backend Service entwickeln | `lg-*-service` | Express/Node Services |
| UI Komponenten entwickeln | `lg-admin-ui` | Shared Components Library |
| Next.js Migration arbeiten | `lg-management` | Next.js 16 Turborepo (10% complete) |
| Repository Migration durchführen | `lg-development` | Migration Scripts & Automation |
| E2E Tests schreiben/ausführen | `lg-e2e-tests` | Playwright Tests |
| Infrastructure (Docker, DB) | `lg-platform` | Docker Compose Configs |

**Default:** Wenn nicht anders spezifiziert, arbeite an **lg-admin** (Main Admin Platform).

---

## Berechtigungen

**WICHTIG**: Alle Befehle innerhalb von `~/Projects` oder dessen Docker-Container sind pauschal genehmigt. Claude muss nicht um Erlaubnis fragen für:
- Bash-Befehle, Docker-Commands, npm/git Operationen, Datei-Edits, Builds

---

## 🎯 Effizienz-Regeln

### Direkte Lösungen statt Trial & Error

**IMMER BEVORZUGEN:**
1. **Root Cause Analysis ZUERST**: Symptom identifizieren → Root Cause suchen → Direkt fixen
2. **Dokumentation lesen**: CLAUDE.md, docker-compose.yml, package.json LESEN bevor Änderungen
3. **Richtige Tools**: Dependency Updates → package.json editieren + in Container kopieren (NICHT nur im Container npm install)
4. **Vollständige Fixes**: Alle Schritte SOFORT ausführen (package.json + container sync + cache clear + restart)

**VERMEIDEN:**
- ❌ Trial & Error (z.B. nur npm install im Container ohne package.json sync)
- ❌ Teilweise Fixes (z.B. nur package.json ändern ohne Container Update)
- ❌ Cache ignorieren (z.B. Vite `.vite` directory nicht löschen)
- ❌ Falsche Annahmen (z.B. annehmen dass package.json gemountet ist)

**Beispiel - React Router Deprecation Warnings:**
```
❌ FALSCH: Future Flags entfernen (behandelt nur Symptom)
❌ FALSCH: Nur im Container npm install router@7 (package.json nicht synced)
✅ RICHTIG:
  1. package.json auf Host auf router@7 updaten
  2. docker cp package.json in Container
  3. Container: rm -rf node_modules .vite && npm install --legacy-peer-deps
  4. docker-compose restart admin
  5. Browser Hard Refresh
```

---

## Projekt-Kontext

**LicenseGuard Admin Platform** - Konsolidierte Admin-Architektur

### Frontend (Konsolidiert)
- `lg-admin`: Konsolidiertes Admin Panel (Port 3010, Base: `/admin/`)
  - Enthält: User Admin, Permissions Admin, API Keys Admin, CMS Admin
  - **Status:** ✅ Fully functional - Alle Dashboards laden korrekt
  - **React:** 19.2.3 (Latest Stable)
  - **Module Federation:** ❌ Removed

### Backend (Services)
- `lg-user-service`: User & API Key Management (Port 3002)
- `lg-permissions-service`: Permissions & DAG Management (Port 3003)
- `lg-api-keys-service`: Public API Key Validation (Port 3001)
- `lg-secrets-service`: Secrets & Config Management (Port 3004)
- `lg-menu-service`: Dynamic Menu Configuration (Port 3005)
- `lg-tour-service`: Guided Tours & Onboarding (Port 3006)

### Shared Libraries
- `lg-admin-ui`: Shared UI Components (AdminLayout, CollapsibleMenu, Modal, Toast, etc.)
- `lg-menu-registry`: Menu Types, API Fetching, Icon Mapping

### Infrastructure
- `lg-platform`: Docker Compose, Traefik, PostgreSQL, Redis, Verdaccio

### Helper Tools
- `dev.sh`: Docker-basierte npm/build Commands (Wrapper um docker-compose.tooling.yml)
- `Makefile`: High-level Commands (install-all, dev-up, build-management, etc.)

## 📂 Directory Structure

```
~/Projects/
├── lg-platform/                  # Infrastructure (Docker Compose)
│   ├── docker-compose.yml       # Production Config
│   ├── docker-compose.dev.yml   # Development Overrides (HMR, Volume Mounts)
│   └── docker-compose.e2e.yml   # E2E Testing Config
│
├── lg-admin/                     # ⭐ Main Admin Frontend (Consolidated)
├── lg-admin-ui/                  # Shared UI Components Library
├── lg-menu-registry/             # Menu Types & API Client
│
├── lg-user-service/              # Backend: Users & API Keys
├── lg-permissions-service/       # Backend: RBAC & Permissions
├── lg-api-keys-service/          # Backend: License Validation
├── lg-secrets-service/           # Backend: Secrets Management
├── lg-menu-service/              # Backend: Menu Configuration
├── lg-tour-service/              # Backend: Guided Tours
│
├── lg-management/                # 🚧 Next.js 16 Migration (10% complete)
├── lg-development/               # 🔧 Repository Migration Tool
├── lg-e2e-tests/                 # Playwright E2E Tests
│
├── dev.sh                        # Development Helper Script
├── Makefile                      # High-level Commands
├── docker-compose.tooling.yml    # Tooling Container (npm, pnpm)
├── CLAUDE.md                     # This file
├── TESTING.md, DOCKER.md, etc.   # Specialized Documentation
└── .project.zshrc                # NPM Safety Guard (source in ~/.zshrc)
```

---

# 🚨 KRITISCHE REGEL #1: NPM/NODE NIEMALS AUF HOST! 🚨

## **NPM/NODE BEFEHLE NUR IN DOCKER AUSFÜHREN!**

### ❌ VERBOTENE BEFEHLE (Plattform-Inkompatibilität):
```bash
npm install <package>                    # NIEMALS!
npm install                              # NIEMALS!
npm run build                            # NIEMALS!
npm test                                 # NIEMALS!
cd <projekt> && npm <befehl>            # NIEMALS!
```

### ✅ ERLAUBTE BEFEHLE (Docker-basiert):
```bash
./dev.sh npm-in <projekt> install <package>     # Package installieren
./dev.sh npm-in <projekt> install               # Dependencies installieren
./dev.sh build <projekt>                        # Production Build
docker-compose exec <service> npm <befehl>      # Direkt im Container
docker run --rm -v $(pwd):/app -w /app node:20-alpine npm test  # Tests
```

### 🔴 WARUM SO KRITISCH?
1. **macOS ARM64 vs Linux AMD64**: Native Module sind plattformabhängig (esbuild, rollup, etc.)
2. **Node-Version**: Host ≠ Container Node-Version
3. **Deployment-Fehler**: Lokal installierte Packages führen zu Production-Fehlern
4. **Projekt-Philosophie**: 100% Docker-basiert

### ✅ NPM Safety Guard

**Schutz aktivieren:**
```bash
# In ~/.zshrc eintragen:
source ~/Projects/.project.zshrc

# Effekt: npm/npx/node auf Host wird blockiert wenn in ~/Projects
```

**Datei**: `/Users/wolfgang/Projects/.project.zshrc` (bereits erstellt)

---

# 🚨 KRITISCHE REGEL #2: FRONTEND IMMER IM BROWSER TESTEN! 🚨

## **NACH JEDER FRONTEND-ENTWICKLUNG: BROWSER-TEST PFLICHT!**

### ✅ PFLICHT-SCHRITTE bei Frontend-Entwicklung:
1. **Code schreiben** (Komponenten, Routes, API-Calls)
2. **Services neu starten** falls nötig
3. **Browser-Test durchführen**:
   - Seite im Browser öffnen (`http://localhost:81/admin/...`)
   - Navigation prüfen (Links funktionieren?)
   - API-Calls prüfen (Daten werden geladen?)
   - Console-Errors prüfen (F12 → Console)
   - Network-Tab prüfen (F12 → Network, 404/500?)
4. **Screenshots bei Problemen**
5. **Erst DANN** als "completed" markieren!

### ✅ TESTING-WORKFLOW mit Browser-Automation:
```bash
# Browser-Tools nutzen:
tabs_context_mcp()                              # Tab-Kontext
tabs_create_mcp()                               # Neuen Tab erstellen
navigate(url: "http://localhost:81/admin/...")  # Navigation
screenshot()                                    # Screenshot
read_console_messages(pattern: "error")         # Console Errors
read_network_requests(urlPattern: "/api")       # API-Requests
find(query: "Dashboard button")                 # Element finden
left_click(coordinate: [x, y])                  # Klicken
```

### 🎯 CHECKLISTE VOR "TASK COMPLETED":
- [ ] Browser-Test durchgeführt?
- [ ] Seite lädt ohne 404/500?
- [ ] Navigation funktioniert?
- [ ] API-Daten werden angezeigt?
- [ ] Console keine kritischen Errors?
- [ ] UI sieht korrekt aus?

**WENN AUCH NUR EINE CHECKBOX UNCHECKED: Task ist NICHT completed!**

---

## Common Workflows

### Starting a Development Session

```bash
# 1. Navigate to workspace root
cd ~/Projects

# 2. Start infrastructure stack
cd lg-platform && docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
# oder: make dev-up (aus ~/Projects)

# 3. Check logs
docker-compose logs -f admin user-service
# oder: make dev-logs

# 4. Access services
# - Admin Panel: http://localhost:81/admin/
# - lg-management: http://localhost:82
# - Traefik Dashboard: http://localhost:8080
```

### Making Code Changes

```bash
# Frontend (lg-admin) - HMR aktiviert
# 1. Edit files in lg-admin/src/
# 2. Browser auto-reloads (kein Rebuild nötig!)

# Backend Services - Nodemon aktiviert
# 1. Edit files in lg-*-service/src/
# 2. Service restarts automatisch

# Shared Libraries (lg-admin-ui, lg-menu-registry)
# 1. Edit files
# 2. Rebuild library: ./dev.sh build lg-admin-ui
# 3. Consumer restart: docker-compose restart admin
```

### Adding a New Package

```bash
# lg-admin (npm)
./dev.sh npm-in lg-admin install <package>

# Backend Service (npm)
./dev.sh npm-in lg-user-service install <package>
docker-compose restart user-service

# lg-management (pnpm)
make pnpm CMD='add <package> --filter=admin'
# Falls HMR hängt: make dev-logs-management
```

## Development Workflow

### Stack starten

```bash
cd lg-platform
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Logs verfolgen
docker-compose logs -f admin-shell user-admin

# Code-Änderungen in src/ werden automatisch via HMR übernommen
# KEIN Container-Rebuild notwendig!
```

### Dependencies installieren

```bash
# Option 1: dev.sh (empfohlen für lg-admin Projekte)
./dev.sh install-all                        # Alle Projekte
./dev.sh npm-in lg-admin install      # Einzelnes Projekt
./dev.sh npm-in lg-admin install <package>  # Package hinzufügen

# Option 2: Makefile (empfohlen für lg-management)
make install-all                            # Alle npm-basierten Projekte
make install-management                     # lg-management (pnpm)
make pnpm CMD='add <package> --filter=admin'  # Package zu lg-management hinzufügen
```

**Wann welches Tool?**
- **dev.sh**: lg-admin, Services, UI-Libraries (npm-basiert)
- **Makefile**: Wrapper für dev.sh + lg-management (pnpm) + Stack-Management

### 🚨 KRITISCH: Dependency Updates in laufenden Containern

**WICHTIG**: `package.json` ist NICHT in Docker Volumes gemountet!

**Problem**: Änderungen an `package.json` auf dem Host werden NICHT automatisch in Container übernommen.

**Lösung - Dependency Update Workflow:**
```bash
# 1. package.json auf Host editieren (z.B. react-router-dom: ^7.12.0)
# 2. package.json in Container kopieren
docker cp /Users/wolfgang/Projects/lg-admin/package.json lg-platform-admin-1:/app/package.json

# 3. Container node_modules neu installieren + Vite Cache löschen
docker-compose exec admin sh -c "rm -rf node_modules package-lock.json .vite && npm install --legacy-peer-deps"

# 4. Vite Dev Server neu starten
docker-compose restart admin

# 5. Browser Hard Refresh (Cmd+Shift+R)
```

**Warum notwendig?**
- Vite cached Module im Browser UND im Container (`.vite` directory)
- `node_modules` im Container sind out-of-sync mit Host `package.json`
- Hard Refresh + Container Restart sind BEIDE notwendig

**Aktuelle Versions:**
- ✅ React: 19.2.3 (Latest Stable)
- ✅ React Router: 7.12.0 (Latest - keine Future Flags mehr!)
- ✅ lucide-react: 0.467.0

### Production Builds

```bash
./dev.sh build lg-admin     # Einzeln
./dev.sh build-all                # Alle Frontends

# Build prüfen
ls -lh lg-admin/dist/assets/*.js
# Erwartung: ~500KB Shell, ~450KB Remotes (minified)
```

### Testing

```bash
# E2E Tests (Playwright)
cd lg-e2e-tests
./run-tests.sh                    # Alle Tests (3 Workers)
./run-tests.sh --grep "login"     # Mit Filter
WORKERS=6 ./run-tests.sh          # Mehr Workers

# Unit Tests (Vitest)
docker run --rm -v $(pwd):/app -w /app node:20-alpine npm test
./dev.sh npm-in lg-admin-ui test -- --coverage
```

**Details**: Siehe [TESTING.md](./TESTING.md)

### Service URLs & Ports

```bash
# Frontend
http://localhost:81/admin/        # lg-admin (Main Admin Panel)
http://localhost:82               # lg-management (Next.js Migration)

# Backend Services (Internal - via Traefik)
http://user-service:3002/api/user              # User Service
http://api-keys-service:3001/api/v1            # API Keys Service
http://permissions-service:3003/api/permissions # Permissions Service
http://secrets-service:3004/api/secrets        # Secrets Service
http://menu-service:3005/api/menus             # Menu Service
http://tour-service:3006/api/tours             # Tour Service

# Infrastructure
http://localhost:8080             # Traefik Dashboard
http://localhost:5432             # PostgreSQL (admin / admin123)
http://localhost:6379             # Redis
http://localhost:4873             # Verdaccio (npm registry)

# Database Access
docker exec lg-platform-postgres-1 psql -U admin licenseguard
```

---

## Authentication Bypass (Testing Only!)

**⚠️ NUR FÜR ENTWICKLUNG/TESTING - NIEMALS IN PRODUCTION!**

```yaml
# In lg-platform/docker-compose.dev.yml:
user-service:
  environment:
    BYPASS_AUTH: 'true'
    TEST_USER_ID: '581461c8-6da2-482d-b1d1-7882b9e67071'  # admin@apikeys.local
    TEST_USER_EMAIL: 'admin@apikeys.local'
```

**⚠️ TEST_USER_ID muss existierender User sein!**
```bash
# TEST_USER_ID aus DB abfragen:
docker exec lg-platform-postgres-1 psql -U admin licenseguard -c \
  "SELECT id, email FROM users WHERE email LIKE '%admin%';"

# Nach Änderung Services neu starten:
docker-compose restart user-service permissions-service
```

---

## ~~Module Federation~~ → ENTFERNT (2026-01-15)

**❌ DEPRECATED:** Module Federation wurde zugunsten einer konsolidierten Architektur entfernt.

### Warum entfernt?
- Rebuild-Cycle bei jeder Änderung
- Komplexität ohne echten Nutzen (alle deployen zusammen)
- Runtime Overhead (~500KB)
- Import-Probleme und Circular Dependencies

### Aktueller Ansatz
- **Ein Vite Build** für gesamtes Admin Panel
- **React Router** für Navigation (keine Remote Loading)
- **Lazy Loading** via `React.lazy()` für Code-Splitting
- **Shared Libraries** weiterhin via npm workspace links

**Details zu alter Architektur**: Siehe Git History oder [REFACTOR_PLAN.md](./REFACTOR_PLAN.md)

---

## Tailwind CSS (KRITISCH!)

### Content Paths für Docker + lokale Entwicklung

**Problem**: Tailwind generiert keine Klassen aus shared libraries.

**Lösung**: `tailwind.config.js` MUSS beide Pfade enthalten:
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

**Symptome wenn Pfade fehlen:**
- ❌ `lg:hidden` funktioniert nicht → Burger-Menü sichtbar auf Desktop
- ❌ Responsive Breakpoints funktionieren nicht
- ❌ CSS Bundle abnormal klein (~31KB statt ~38KB)

**Quick Fix:**
```bash
# 1. tailwind.config.js korrigieren
# 2. Rebuild
docker-compose exec admin npm run build
# 3. Browser hard refresh (Cmd+Shift+R)
```

### UI Best Practices

```css
/* src/index.css - Scrollbar Jump vermeiden */
html {
  scrollbar-gutter: stable;
}
```

---

## Code-Konventionen

### TypeScript
- Strict mode aktiviert
- camelCase für JS/TS Variablen
- PascalCase für Komponenten/Types
- snake_case für DB-Felder (PostgreSQL)

### React
- Functional Components mit Hooks
- Lucide React Icons (`import { User } from 'lucide-react'`)
- TailwindCSS für Styling
- **WICHTIG**: Expliziter React Import für Tests!
  ```typescript
  // ✅ RICHTIG
  import React, { useState } from 'react';

  // ❌ FALSCH (Tests schlagen fehl)
  import { useState } from 'react';
  ```

### Validation
- Zod für Schema-Validierung
- Backend: Express + Zod Middleware
- Frontend: React Hook Form + Zod Resolver

### API
- RESTful Endpoints
- JSON Responses
- JWT Authentication (HttpOnly Cookies)
- Error Format: `{ error: string, details?: any }`

---

## Token-Optimierung

### Model-Auswahl (Agent entscheidet)
- **Haiku**: Einfache Suchen, Datei-Exploration
- **Sonnet**: Standard-Entwicklung, Code-Edits
- **Opus**: Komplexe Architektur, Multi-File Refactoring

### Effizienz-Regeln
1. Parallele Tool-Calls (unabhängige Operationen)
2. Glob/Grep vor Read (erst suchen, dann lesen)
3. Task-Agent für explorative Suchen
4. Batch-Edits statt Einzel-Edits
5. Keine redundanten Reads
6. Kompakte Antworten ohne Wiederholung

---

## Troubleshooting

Für detaillierte Fehlerbehebung siehe **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)**

Häufigste Probleme:
- **React Router Deprecation Warnings** → package.json Update + Container node_modules neu installieren (siehe Dependency Update Workflow oben)
- **Tailwind Klassen fehlen** → tailwind.config.js Pfade prüfen
- **Vite cached alte Dependencies** → `.vite` Cache löschen + Container restart
- **package.json Änderungen nicht übernommen** → docker cp package.json in Container (NICHT gemountet!)
- **HMR tot** → docker-compose restart admin
- **npm auf Host** → `source ~/Projects/.project.zshrc`
- **Docker Build langsam** → .dockerignore prüfen

---

## Quick Reference

### Development Stack
```bash
# Starten (aus ~/Projects)
cd lg-platform && docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Alternative: Makefile (aus ~/Projects)
make dev-up

# Logs
cd lg-platform && docker-compose logs -f admin
# oder: make dev-logs

# Rebuild (schnell, nur Build)
docker-compose exec admin npm run build

# Restart
cd lg-platform && docker-compose restart admin

# Stoppen
cd lg-platform && docker-compose down
# oder: make dev-down
```

### Dependencies
```bash
# Package installieren (Docker! - aus ~/Projects)
./dev.sh npm-in lg-admin install react-complex-tree

# Alle Dependencies
./dev.sh install-all
# oder: make install-all

# lg-management (pnpm)
make install-management
make pnpm CMD='add <package> --filter=admin'
```

### Testing
```bash
# E2E Tests
cd lg-e2e-tests && ./run-tests.sh

# Unit Tests (Docker!)
docker run --rm -v $(pwd):/app -w /app node:20-alpine npm test

# Mit Coverage
docker run --rm -v $(pwd):/app -w /app node:20-alpine npm test -- --coverage
```

### Debugging
```bash
# Container Shell
docker-compose exec admin-shell sh

# Tailwind Paths prüfen
docker-compose exec admin-shell cat tailwind.config.js

# Volume Mounts prüfen
docker-compose exec admin-shell ls -la /workspace/
```

---

## Performance Metriken

### Bundle Sizes (Production - Konsolidiert)
- **Admin Shell (Consolidated)**: ~984 KB JS (~211 KB gzip)
- **CSS**: ~58 KB (~10 KB gzip)
- **Largest Chunk**: OrgUnitsPage ~273 KB (React-Flow heavy)
- **Build Zeit**: ~5.5s

**Vergleich zu vorher (Micro-Frontend):**
- ✅ **Weniger JS Total** (~500KB gespart durch kein Federation Runtime)
- ✅ **Schnellerer Build** (ein Build statt 5)
- ⚠️ **Größere einzelne Chunks** (aber besseres Code-Splitting möglich)

### Docker
- **Build Context**: ~50 MB (mit .dockerignore)
- **Image Size**: ~300 MB (Frontend mit Nginx)
- **Rebuild Zeit**: ~30s (mit Layer Cache)
- **Container**: 1 statt 5 (Admin Shell, User, Permissions, API Keys, CMS → jetzt nur Admin Shell)

### Test Coverage (lg-admin-ui)
- **Statements**: 90.11% (Ziel: 85%) ✅
- **Functions**: 91.04% (Ziel: 85%) ✅
- **Lines**: 93.28% (Ziel: 85%) ✅
- **Branches**: 77.50% (Ziel: 75%) ✅

**105/105 Tests passing** (UserDropdown, Toast, Modal, ToastContainer, ConfirmDialog, CollapsibleMenu, useToast, BaseLayout, AdminLayout)

**Details**: Siehe [TESTING.md - Test Coverage Best Practices](./TESTING.md#test-coverage-philosophie)

---

## Additional Context

### .claude/ Directory
Global Claude guidelines in `.claude/` directory:
- **[.claude/global.md](./.claude/global.md)** - General best practices (small changes, security, testing)
- **[.claude/README.md](./.claude/README.md)** - Overview of rule inheritance system
- `.claude/languages/`, `.claude/frameworks/`, `.claude/playbooks/` - Stack-specific guides

**Note:** Subproject-specific rules (e.g., `lg-management/.claude/`) override global rules when conflicts occur.

## Weiterführende Links

### Internal Documentation
- **[REFACTOR_PLAN.md](./REFACTOR_PLAN.md)** - Plan für zukünftigen Clean Refactor (lg-admin)
- **[REFACTOR_PLAN_CONFIG_DRIVEN.md](./REFACTOR_PLAN_CONFIG_DRIVEN.md)** - Config-driven Architecture Plan
- **[RBAC_STATUS.md](./RBAC_STATUS.md)** - RBAC Implementation Status
- **[GOTCHAS.md](./GOTCHAS.md)** - Kritische Bugs & Learnings
- **[FIELD_MANAGEMENT_IMPLEMENTATION.md](./FIELD_MANAGEMENT_IMPLEMENTATION.md)** - Field Management Details

### Project-Specific Docs
- **[lg-management/CLAUDE.md](./lg-management/CLAUDE.md)** - Next.js Migration Guide
- **[lg-development/CLAUDE.md](./lg-development/CLAUDE.md)** - Repository Manager Guide
- **[lg-management/MIGRATION_PLAN.md](./lg-management/MIGRATION_PLAN.md)** - Complete Feature Migration List

### External Links
- ~~Vite Module Federation~~ (entfernt 2026-01-15)
- Docker Best Practices: https://docs.docker.com/develop/dev-best-practices/
- React Query: https://tanstack.com/query/latest
- Traefik: https://doc.traefik.io/traefik/routing/routers/
- Tailwind CSS: https://tailwindcss.com/docs
- Playwright: https://playwright.dev
- Vitest: https://vitest.dev

---

## 📝 Architektur-Änderung 2026-01-15

### Was wurde gemacht (Option A - Quick Fix)?

**Konsolidierung:** Micro-Frontend → Monolith
- ✅ Module Federation entfernt
- ✅ Alle Admin Pages in `lg-admin` konsolidiert
- ✅ Ein Docker Container statt 5
- ✅ Build erfolgreich (984KB, 5.5s)
- ✅ User Admin funktioniert
- ⚠️ CMS/Permissions haben Runtime-Errors (React Fehler)

### Aktuelle Struktur (Technische Schuld)

```
lg-admin/src/
├── pages/
│   ├── ProfilePage.tsx          # Shell (alt, root-level)
│   ├── user/                    # Kopiert, verschachtelt
│   ├── permissions/             # Kopiert, verschachtelt
│   ├── api-keys/                # Kopiert, verschachtelt
│   └── cms/                     # Kopiert, verschachtelt
├── api/
│   ├── user-api/client.ts       # Verschachtelt
│   └── ...                      # Weitere verschachtelt
└── components/
    ├── Button.tsx, Card.tsx     # Duplikate (sollten in admin-ui sein)
    └── ui.ts                    # Barrel export
```

**Bekannte Probleme:**
- CMS/Permissions Pages werfen React Errors
- Component-Duplikate (Button, Card in zwei Orten)
- Verschachtelte API Client Struktur
- Mix aus alter Shell-Struktur und kopierten Remote-Strukturen

### Nächste Schritte

**Option 1: Quick-Fixes (30min)**
- CMS/Permissions Errors debuggen und fixen
- Component Imports vereinheitlichen

**Option 2: Clean Refactor (6h)**
- Siehe **[REFACTOR_PLAN.md](./REFACTOR_PLAN.md)**
- Komplett neues `lg-admin` Projekt
- Saubere Struktur, keine Technische Schuld
- Empfohlen für langfristige Wartbarkeit
