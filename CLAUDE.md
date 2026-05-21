# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## ⚡ QUICK RULES - LIES DAS ZUERST!

**NIEMALS:**
- ❌ npm/node auf dem Host ausführen → IMMER in Docker!
- ❌ repos/ commiten → ist gitignored!
- ❌ Aus ~/Projects/lg-* kopieren → nur via `make prepare`!

**IMMER:**
- ✅ npm in Docker: `docker run --rm -v $(pwd):/app -w /app node:20-alpine npm ...`
- ✅ Oder make targets: `make test`, `make test-parallel`
- ✅ Build/Publish in GitHub Actions (automatisch bei push)
- ✅ repos/ sind git clones mit eigenem .git

---

## 🎯 Projekt-Kontext

**LG-Development** ist ein **Development Orchestrator** für das LicenseGuard Multi-Repo System.

**Rolle:** Development Environment Manager mit Docker Stack Orchestration

**Status:** ✅ Production Ready - Migration Complete (2026-01-23)

---

## 🚨 KRITISCHE REGEL #1: REPOS/ SIND GIT CLONES!

**repos/** enthält **Git Clones von GitHub**, NICHT Kopien aus `/Users/wolfgang/Projects`!

### ✅ SO FUNKTIONIERT ES:

**Option A - Automated Setup (Empfohlen):**
```bash
# 1. Konfiguriere .env (welche Repos clonen?)
vi .env  # CLONE_LG_PLATFORM=true, etc.

# 2. Run setup script
./scripts/dev/setup.sh  # Clont von GitHub nach repos/

# 3. Jedes Projekt in repos/ hat eigenes .git
cd repos/lg-menu-service
git pull  # Updates von GitHub
git push  # Pusht zu GitHub
```

**Option B - Manual Clone:**
```bash
cd /Users/wolfgang/Projects/lg-development/repos
gh repo clone WolfgangM81/lg-menu-service
gh repo clone WolfgangM81/lg-secrets-service
```

### ❌ NIEMALS:
- Aus `/Users/wolfgang/Projects/lg-*` kopieren (das ist für Migration, nicht Development!)
- repos/ in lg-development commiten (ist gitignored!)

**Warum?** lg-development ist ein Development Orchestrator, kein Code-Repo!

---

## 🚨 KRITISCHE REGEL #2: NPM NIEMALS AUF DEM HOST!

**ALLE npm/node Befehle MÜSSEN in Docker laufen, NIEMALS auf dem Host!**

### ❌ NIEMALS AUF DEM HOST:
```bash
npm install    # FALSCH!
npm test       # FALSCH!
npm run build  # FALSCH!
npm publish    # FALSCH!
npm version    # FALSCH!
```

### ✅ IMMER IN DOCKER:
```bash
# Tests
docker run --rm -v $(pwd):/app -w /app node:20-alpine npm test

# Install
docker run --rm -v $(pwd):/app -w /app node:20-alpine npm install

# Version bump
docker run --rm -v $(pwd):/app -w /app node:20-alpine npm version patch

# Build (falls nötig lokal)
docker run --rm -v $(pwd):/app -w /app node:20-alpine npm run build
```

### ✅ ODER ÜBER MAKE:
```bash
make test              # Nutzt Docker
make test-parallel     # Nutzt Docker
make test-watch SERVICE=lg-user-service  # Nutzt Docker
```

### ✅ ODER GITHUB ACTIONS (Production):
```bash
# Code ändern, committen, pushen
git add .
git commit -m "feat: neue funktion"
git push  # ← GitHub Actions macht Build/Test/Publish in der Cloud!
```

**Warum?**
- Konsistente Umgebung (keine "works on my machine")
- Keine Node.js Installation auf dem Host nötig
- Gleiche Umgebung wie Production (Docker)
- Kein Konflikt mit anderen Projekten

**Ausnahme:** `npm version` kann auf dem Host laufen wenn Node.js installiert ist, ABER besser in Docker!

---

## 🚨 KRITISCHE REGEL #3: REPOS/ IST GITIGNORED!

**repos/** Verzeichnis ist in `.gitignore`!

### ❌ NICHT:
```bash
cd /Users/wolfgang/Projects/lg-development
git add repos/  # ← FALSCH! Ist gitignored
```

### ✅ RICHTIG:
```bash
# repos/ wird NICHT committed
# Jedes Projekt in repos/ hat eigenes .git
cd repos/lg-admin-ui
git add .
git commit -m "..."
git push origin main  # ← Zu WolfgangM81/lg-admin-ui
```

---

## 📂 Verzeichnis-Struktur

```
~/Projects/lg-development/           # Dieses Repo (Manager)
├── scripts/
│   ├── migration/                   # 🔧 Migration Scripts (einmalig)
│   │   ├── migrate.sh              # Master Wizard
│   │   ├── copy-all.sh             # Kopiert von ~/Projects/lg-*
│   │   └── ...
│   └── dev/                         # 🚀 Development Scripts (täglich)
│       ├── setup.sh                # Clont von GitHub → repos/
│       ├── start.sh                # Docker Stack starten
│       └── ...
├── templates/                       # .npmrc, Workflows, etc.
├── repos/                           # ⚠️ GITIGNORED! Git Clones (nested!)
│   ├── infrastructure/
│   │   ├── lg-traefik/.git
│   │   ├── lg-postgres/.git
│   │   ├── lg-redis/.git
│   │   ├── lg-dynamodb/.git
│   │   ├── lg-verdaccio/.git
│   │   └── lg-monitoring/.git
│   ├── services/
│   │   ├── lg-user-service/.git
│   │   ├── lg-permissions-service/.git
│   │   ├── lg-api-keys-service/.git
│   │   ├── lg-tour-service/.git
│   │   ├── lg-menu-service/.git
│   │   └── lg-secrets-service/.git
│   └── ui/
│       └── lg-admin/.git
├── .dependency-graph.json          # Auto-generiert
├── .env                             # Setup Config (CLONE_LG_*)
└── docker-compose.dev-sync.yml     # Hot-Reload Builders Stack
```

### repos/ Contents (Git Clones — nested seit 2026-02)

```
repos/
├── infrastructure/        # Layer 0 — Infrastructure
│   ├── lg-traefik/        # Reverse Proxy
│   ├── lg-postgres/       # PostgreSQL 16
│   ├── lg-redis/          # Redis 7
│   ├── lg-dynamodb/       # DynamoDB Local
│   ├── lg-verdaccio/      # Local NPM Registry
│   └── lg-monitoring/     # Prometheus + Grafana
├── services/              # Layer 1 — Backend Services
│   ├── lg-user-service/        # User & Auth
│   ├── lg-permissions-service/ # RBAC & DAG
│   ├── lg-api-keys-service/    # API Key Validation
│   ├── lg-tour-service/        # NextStepjs Integration
│   ├── lg-menu-service/        # Menu Management
│   └── lg-secrets-service/     # Secrets Management
└── ui/                    # Layer 2 — Frontend
    └── lg-admin/          # Admin UI (Vite)
```

**Each repo has its own `.git` directory!**

**`scripts/lib/list-compose-files.sh`** auto-discovers via `find_repo_compose()` —
versteht sowohl die nested-Struktur als auch (für Legacy-Kompatibilität) die alte
flache Struktur (`repos/<name>/`).
```

---

## 🔄 Workflows

### Development Workflow (Primary)
Daily development with Docker Stack orchestration.

```bash
# Setup once (clone repos from GitHub)
./scripts/dev/setup.sh

# Daily workflow
./scripts/dev/start.sh   # Start Docker Stack
./scripts/dev/status.sh  # Check service health
./scripts/dev/logs.sh    # View logs (all or specific service)
./scripts/dev/stop.sh    # Stop all services
./scripts/dev/update.sh  # Pull latest changes from GitHub

# Access services via proxy domains (no ports!)
open http://admin.lg.local              # Admin UI
open http://api.lg.local/user/health    # User Service
open http://traefik.lg.local            # Traefik Dashboard
```

### Migration Workflow (Historical - Completed)
One-time migration from monorepo to multi-repo (already done).

```bash
# Migration completed 2026-01-23
./scripts/migration/migrate.sh  # Historical reference only
```

---

## 🛠️ Scripts Übersicht

### Development Scripts (scripts/dev/)

| Script | Zweck | Verwendung |
|--------|-------|------------|
| **setup.sh** | Clone repos from GitHub | First-time setup |
| **start.sh** | Start Docker Stack | Daily: Start services |
| **stop.sh** | Stop Docker Stack | Stop all containers |
| **status.sh** | Check service health | View running services |
| **logs.sh** | View container logs | Debug issues |
| **update.sh** | Pull latest from GitHub | Update all repos |

### Migration Scripts (scripts/migration/) - Historical

| Script | Zweck | Safe? |
|--------|-------|-------|
| **migrate.sh** | Master Wizard (7 Schritte) | ✅ Ja (completed) |
| **analyze-dependencies.sh** | Dependency Graph erstellen | ✅ Ja (read-only) |
| **copy-project.sh** | Ein Projekt kopieren | ✅ Ja (kopiert nur) |
| **copy-all.sh** | Alle 10 Projekte kopieren | ✅ Ja |
| **prepare-repo.sh** | Templates anwenden | ✅ Ja (nur in repos/) |
| **create-github-repos.sh** | GitHub Repos erstellen | ⚠️ Vorsicht (GitHub API) |
| **setup-secrets.sh** | GitHub Secrets setzen | ⚠️ Vorsicht (Secrets!) |
| **health-check.sh** | Pre-flight Validation | ✅ Ja (read-only) |

---

## 🐋 Docker Stack Architecture

### Services in docker-compose.yml

**Infrastructure:**
- `verdaccio` (Port 4873) - Local NPM Registry
- `traefik` (Ports 80, 443, 8080) - Reverse Proxy & Load Balancer
- `postgres` (Internal) - PostgreSQL 16 Database
- `redis` (Internal) - Redis Cache

**Backend Services:**
- `user-service` (Port 3002) - User & Authentication Management
- `permissions-service` (Port 3003) - RBAC & DAG Permissions
- `api-keys-service` (Port 3001) - Public API Key Validation
- `tour-service` (Port 3004) - NextStepjs Integration
- `menu-service` (Port 3005) - Hierarchical Menu Management
- `secrets-service` (Port 3007) - Encrypted Secrets Management

**Frontend:**
- `admin` (Port 3000) - Consolidated Admin UI (Vite)
- `lg-management` (DISABLED) - Next.js 16 Admin UI (commented out)

### Networks

- `lg-public` - External network for Traefik routing
- `lg-internal` - Internal network for service-to-service communication

### Proxy Domains

**Setup:** Run `make proxy-domains` to configure and test.

**Required /etc/hosts entries:**
```bash
127.0.0.1 admin.lg.local
127.0.0.1 api.lg.local
127.0.0.1 traefik.lg.local
```

**With OrbStack (Port 80 - no port needed):**
- `http://admin.lg.local/` - Admin UI
- `http://api.lg.local/user/health` - User Service
- `http://api.lg.local/keys/health` - API Keys Service
- `http://traefik.lg.local/` - Traefik Dashboard

**Universal (Port 8180 - works everywhere):**
- `http://admin.lg.local:8180/`
- `http://api.lg.local:8180/user/health`
- `http://traefik.lg.local:8180/`

**API Endpoints (via api.lg.local):**

| Path | Service |
|------|---------|
| `/user/*` | User Service |
| `/permissions/*` | Permissions Service |
| `/rbac/*` | Permissions Service (RBAC) |
| `/keys/*` | API Keys Service |
| `/tour/*` | Tour Service |
| `/menu/*` | Menu Service |
| `/secrets/*` | Secrets Service |

**OrbStack vs Docker Desktop:**

| Feature | OrbStack | Docker Desktop |
|---------|----------|----------------|
| Port 80 auto-routing | ✅ `dev.orbstack.domains` | ❌ Manual (TRAEFIK_HTTP_PORT=80) |
| Port 8180 fallback | ✅ Works | ✅ Works |

**See:** [PROXY_DOMAINS.md](./PROXY_DOMAINS.md) for complete setup guide.

### Demo Credentials

| Field | Value |
|-------|-------|
| **E-Mail** | `admin@licenseguard.local` |
| **Password** | `admin123` |

These credentials are seeded via `repos/lg-postgres/init.sql` and displayed in the Admin UI login pages.

### Environment Variables

**Required in `.env`:**
- `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`
- `REDIS_PASSWORD`
- `JWT_SECRET` (min 32 chars)
- `INTERNAL_API_KEY`
- `MASTER_ENCRYPTION_KEY` (for secrets-service)

**Clone Configuration:**
- `CLONE_LG_PLATFORM=true` - Clone platform repo
- `CLONE_LG_USER_SERVICE=true` - Clone user service
- etc. (see `.env.example`)

### Build Context

All services build from `./repos/`:
```yaml
build:
  context: ./repos
  dockerfile: lg-user-service/Dockerfile
```

**Important:** Services must exist in `repos/` directory before building!

---

## ⚡ Package Hot-Reload System

**Status:** ✅ Fully Optimized (2026-01-24)

### Overview

The hot-reload system enables **fast iterative development** of npm packages with ~2-3 second update times, compared to minutes with traditional npm publish/install workflows.

**What it does:**
- Watches package source files (`lg-menu-registry`, `lg-backend-common`, `lg-types`)
- Auto-compiles on file changes (~2-3s build time)
- Syncs built packages to consuming services via Docker volume
- Intelligently restarts only affected services (6x faster!)
- Provides real-time monitoring and error detection

**When to use:**
- ✅ Developing shared packages (menu-registry, backend-common, types)
- ✅ Testing package changes across multiple services
- ✅ Rapid iteration without npm publish cycle

**When NOT to use:**
- ❌ Only working on service code (use normal mode)
- ❌ Production deployments (always uses npm-installed versions)

---

### Quick Start

```bash
# 1. Enable hot-reload
make dev-sync

# 2. Open live dashboard (recommended!)
make dev-sync-dashboard

# 3. Edit a package - watch it compile and services restart
vi repos/lg-menu-registry/src/index.ts
# ✅ Compiles in ~2-3s
# ✅ Only menu-service restarts (6x faster than restarting all!)

# 4. Check for build errors
make dev-sync-check

# 5. When done, disable hot-reload
make dev-normal
```

---

### All Commands

| Command | Description |
|---------|-------------|
| **Core Commands** ||
| `make dev-sync` | Enable hot-reload (~2-3s updates) |
| `make dev-normal` | Disable hot-reload (npm versions) |
| `make dev-toggle` | Toggle hot-reload on/off |
| **Monitoring** ||
| `make dev-sync-dashboard` | Live dashboard (real-time status) ⭐ |
| `make dev-sync-status` | Check builder container status |
| `make dev-sync-check` | Verify build integrity & detect errors |
| `make dev-sync-logs PACKAGE=name` | View compilation logs |
| **Performance** ||
| `make dev-sync-metrics` | Show build performance stats |
| `make dev-sync-metrics-watch` | Watch builds in real-time |
| `make dev-sync-metrics-reset` | Clear metrics |
| **Advanced** ||
| `make dev-sync-watch` | Auto-restart services (smart) |
| `make dev-sync-rebuild` | Restart all builders |
| `make dev-sync-clean` | Clean build artifacts |
| `make dev-sync-test` | Test package loading |

**Package names:**
- `menu-registry` - Menu types and registry
- `backend-common` - Shared backend utilities
- `types` - Shared TypeScript types

**Example:**
```bash
make dev-sync-logs PACKAGE=menu-registry
```

---

### Smart Service Restarts (Phase 3)

**Before optimization:**
- Edit ANY package → ALL 6 services restart
- Slow, noisy logs, wasted time

**After optimization:**
- Edit `menu-registry` → Only `menu-service` restarts (6x faster!)
- Edit `backend-common` → Only 5 backend services restart
- Edit `types` → All 6 services restart (all depend on it)

**How it works:**
1. Dependency mapping in `scripts/dev/package-dependencies.json`
2. Watch script detects which package changed
3. Only restarts services that depend on that package
4. Automatic fallback if `jq` not available (restarts all)

**Dependencies:**
```json
{
  "menu-registry": ["menu-service"],
  "backend-common": ["user-service", "permissions-service", "api-keys-service",
                     "secrets-service", "tour-service"],
  "types": ["menu-service", "user-service", "permissions-service",
            "api-keys-service", "secrets-service", "tour-service"]
}
```

**Performance improvement:**
- ~5x faster restarts for targeted changes
- Less disruption during development
- Cleaner logs (only relevant service output)

---

### Enhanced Health Checks (Phase 1)

All package builders have robust health checks that verify:

1. ✅ `.js` file exists (compiled JavaScript)
2. ✅ `.d.ts` file exists (TypeScript declarations)
3. ✅ JavaScript syntax is valid (`node -c`)
4. ✅ No compilation errors

**Health check interval:** 5 seconds

**Container status:**
```bash
make dev-sync-status
# Shows: Up (healthy) or Up (unhealthy)
```

If a builder becomes unhealthy:
```bash
make dev-sync-check  # Shows detailed errors
make dev-sync-logs PACKAGE=backend-common  # View full logs
```

---

### Error Detection (Phase 2)

**Automatic error detection:**
- TypeScript compilation errors detected instantly
- Syntax errors caught by health checks
- Missing files detected (`.js` or `.d.ts`)

**Check for errors:**
```bash
make dev-sync-check

# Sample output:
# ✅ menu-registry: All checks passed
# ✅ backend-common: All checks passed
# ❌ types: Build errors detected!
#    Missing: dist/index.d.ts
#    Last 30 log lines:
#    [error messages...]
```

**Error response workflow:**
1. `make dev-sync-check` detects error
2. Shows last 30 log lines with context
3. Fix the issue in source code
4. Builder auto-compiles on save
5. Health check turns green

---

### Live Dashboard (Phase 5)

**Real-time monitoring:**
```bash
make dev-sync-dashboard
```

**Shows:**
- 📦 Builder status (Up/Down/Healthy/Unhealthy)
- 📁 Last compilation output
- ❌ Error counts from TypeScript
- 📊 Volume size and contents
- ⏱️ Auto-refresh every 2s

**Sample output:**
```
╔══════════════════════════════════════════════════════════════╗
║     🔧 HOT-RELOAD DASHBOARD                                   ║
╚══════════════════════════════════════════════════════════════╝

📦 Builders:
NAME                      STATUS    PORTS
lg-builder-menu-registry  Up (healthy)
lg-builder-backend-common Up (healthy)
lg-builder-types          Up (healthy)

📁 Last Build Activity:
  ✅ menu-registry: Found 0 errors. Watching for file changes.
  ✅ backend-common: Found 0 errors. Watching for file changes.
  ✅ types: Found 0 errors. Watching for file changes.

📊 Volume Status:
  Size: 2.1M

════════════════════════════════════════════════════════════════
Press Ctrl+C to exit | Refreshes every 2s
```

**Tip:** Keep dashboard open in one terminal while developing!

---

### Performance Metrics (Phase 4)

**Track build performance:**
```bash
# Show aggregated metrics
make dev-sync-metrics

# Sample output:
# 📈 Build Performance Metrics
#
# Average Build Times:
#   menu-registry: 2.3s avg (15 builds, 2.0s-3.1s range)
#   backend-common: 2.5s avg (12 builds, 2.1s-3.0s range)
#   types: 1.8s avg (18 builds, 1.5s-2.2s range)
#
# Recent Builds (last 10):
#   types: 2s at 14:23:45
#   menu-registry: 2s at 14:22:10
#   backend-common: 3s at 14:20:55
```

**Watch builds in real-time:**
```bash
make dev-sync-metrics-watch
# Tracks every build as it happens
# Press Ctrl+C to stop
```

**Reset metrics:**
```bash
make dev-sync-metrics-reset
# Clears all historical data
```

**Metrics storage:** Persistent in Docker volumes (survives container restarts)

---

### Typical Workflow

**Daily development:**
```bash
# Terminal 1: Start hot-reload + dashboard
cd /Users/wolfgang/Projects/lg-development
make dev-sync
make dev-sync-dashboard  # Keep this open

# Terminal 2: Development
vi repos/lg-menu-registry/src/menu-types.ts

# Watch dashboard show:
#   ✅ menu-registry: Found 0 errors. Watching...
#   🔄 menu-service restarting...
#   ✅ Done in 2.3s

# Test your changes
curl http://api.lg.local/menu/health

# Before commit
make dev-sync-check  # Ensure no errors

# End of day
make dev-normal      # Or leave running
```

**Debugging build issues:**
```bash
# Check overall status
make dev-sync-status

# Check for errors with details
make dev-sync-check

# View specific package logs
make dev-sync-logs PACKAGE=backend-common

# Or open live dashboard
make dev-sync-dashboard
```

---

### Troubleshooting Hot-Reload

#### "Builders won't start"

**Check:**
```bash
docker-compose -f docker-compose.dev-sync.yml ps
docker-compose -f docker-compose.dev-sync.yml logs
```

**Fix:**
```bash
make dev-sync-rebuild  # Restart all builders
```

#### "Changes not reflected in services"

**Possible causes:**
1. Wrong package name in command
2. Builder crashed (check status)
3. Service didn't restart

**Debug:**
```bash
make dev-sync-status  # Check builders are healthy
make dev-sync-check   # Check for compilation errors
make dev-sync-logs PACKAGE=types  # View logs

# Force service restart
docker-compose restart user-service
```

#### "Health check failed but build succeeded"

**Possible causes:**
- Missing `.d.ts` files → Check TypeScript config
- Invalid JavaScript syntax → Check TypeScript errors
- File permissions → Check Docker volume permissions

**Debug:**
```bash
make dev-sync-check  # Shows detailed error info

# Check volume contents
docker run --rm -v lg-package-builds:/data alpine ls -la /data
```

#### "Smart restart not working"

**Check:**
1. Is `jq` installed? → `which jq`
2. Does `package-dependencies.json` exist?
3. Are service names correct in JSON?

**Install jq (optional):**
```bash
# macOS
brew install jq

# Linux
apt-get install jq
```

**Fallback:** If `jq` not available, automatically falls back to restart all services.

#### "Dashboard not refreshing"

**Check:**
1. Is `watch` installed? → `which watch`

**Install watch (optional):**
```bash
# macOS
brew install watch

# Linux (usually pre-installed)
apt-get install procps
```

**Fallback:** Dashboard automatically falls back to manual refresh mode.

#### "Scripts reference wrong directory (projects/ instead of repos/)"

**Fix:** Already fixed in Phase 1! Scripts now correctly use `repos/`:
- `scripts/dev/update.sh:18` - Fixed ✅
- `scripts/dev/status.sh:19` - Fixed ✅

If you see this error, pull latest changes:
```bash
git pull origin main
```

---

### Performance Stats

| Metric | Value |
|--------|-------|
| **Typical build time** | 2-3 seconds |
| **Health check interval** | 5 seconds |
| **Dashboard refresh** | 2 seconds |
| **Service restart (targeted)** | 1-2 seconds |
| **Full volume size** | ~2-3 MB |
| **Improvement vs npm publish** | ~50x faster (3s vs 150s) |
| **Smart restart improvement** | ~6x faster (1 service vs 6 services) |

---

### Dependencies

**Required:**
- Docker & Docker Compose
- Bash 4.0+

**Optional (Enhanced Features):**
- `jq` - For smart restarts and advanced metrics
  - Install: `brew install jq` (macOS) or `apt-get install jq` (Linux)
  - Fallback: Works without jq, just less smart

- `watch` - For live dashboard
  - Install: `brew install watch` (macOS) or `apt-get install procps` (Linux)
  - Fallback: Manual refresh mode if not available

---

### Documentation

- **[HOT_RELOAD_QUICK_REF.md](./HOT_RELOAD_QUICK_REF.md)** - Quick reference card
- **[OPTIMIZATION_SUMMARY.md](./OPTIMIZATION_SUMMARY.md)** - Complete implementation details
- **[README.md](./README.md)** - Overview and quick start

---

## 📚 Documentation Maintenance Responsibilities

**CRITICAL:** Claude MUST update documentation when making code changes!

### Documentation Structure

```
lg-development/
├── docs/
│   ├── ARCHITECTURE.md          # System-wide architecture
│   ├── DEPENDENCIES.md          # Package dependency graph
│   ├── DOCKER.md                # Docker patterns
│   ├── TESTING.md               # Testing strategy
│   └── ...
├── repos/
│   ├── services/<service-name>/
│   │   ├── ARCHITECTURE.md      # Service architecture
│   │   ├── CLAUDE.md           # AI guidelines (includes doc maintenance)
│   │   └── README.md           # User documentation
│   ├── packages/<package-name>/
│   │   ├── CLAUDE.md           # Package guidelines
│   │   └── README.md
│   └── ui/<app-name>/
│       ├── CLAUDE.md
│       └── README.md
├── CLAUDE.md                   # Root guidelines (this file)
├── HOT_RELOAD_QUICK_REF.md    # Quick reference
└── README.md                   # Project overview
```

---

### When to Update Documentation

#### 1. Code Changes Require Doc Updates

**Trigger:** Any code modification that affects:
- API endpoints (add/modify/remove)
- Database schema (tables, columns, relationships)
- Service dependencies (new imports, external calls)
- Configuration (environment variables, settings)
- Architecture (new services, packages, components)

**Action:** Update corresponding documentation in the SAME commit.

---

#### 2. API Endpoint Changes

**If you add/modify/remove an endpoint:**

1. **Update `repos/services/<service>/ARCHITECTURE.md`:**
   - API Endpoints table
   - Communication diagram (if changes communication flow)
   - Example requests/responses

2. **Commit message:**
   ```
   feat(menu-service): Add bulk menu creation endpoint

   - Add POST /menu/bulk endpoint
   - Update ARCHITECTURE.md: API Endpoints table
   - Update ARCHITECTURE.md: Bulk creation sequence diagram
   ```

---

#### 3. Database Schema Changes

**If you modify database schema:**

1. **Update `repos/services/<service>/ARCHITECTURE.md`:**
   - Database Schema diagram (Mermaid ERD)
   - Data models section

2. **Also update:**
   - Migration files (code)
   - Model definitions (code)
   - ARCHITECTURE.md (documentation)

---

#### 4. Service Dependencies Changes

**If you add a new service-to-service call:**

1. **Update `repos/services/<service>/ARCHITECTURE.md`:**
   - Communication Plan → Outbound Communication table
   - Service Dependencies diagram

2. **Update sequence diagram** showing new communication flow

---

#### 5. Shared Package Changes

**If you modify `lg-backend-common`, `lg-types`, `lg-menu-registry`:**

1. **Update `docs/DEPENDENCIES.md`:**
   - Package Dependency Graph (if new dependencies)

2. **Update ALL consuming services' `CLAUDE.md`:**
   - Shared Packages section (usage examples)

---

#### 6. Architecture Changes

**If you add a new service, package, or major component:**

1. **Update `docs/ARCHITECTURE.md`:**
   - System Architecture Overview diagram

2. **Create service documentation:**
   - `repos/services/<new-service>/ARCHITECTURE.md`
   - `repos/services/<new-service>/CLAUDE.md`
   - `repos/services/<new-service>/README.md`

3. **Update `docs/DEPENDENCIES.md`:**
   - Package Dependency Graph

---

### Documentation Update Workflow

**Step-by-Step Process:**

1. **Make Code Changes**
   ```bash
   vi repos/services/lg-menu-service/src/routes/menu.ts
   # Add new endpoint
   ```

2. **Update Documentation (BEFORE committing)**
   ```bash
   vi repos/services/lg-menu-service/ARCHITECTURE.md
   # Add endpoint to API Endpoints table
   # Add/update sequence diagram if needed
   ```

3. **Commit Code + Docs Together**
   ```bash
   git add repos/services/lg-menu-service/src/routes/menu.ts
   git add repos/services/lg-menu-service/ARCHITECTURE.md
   git commit -m "feat(menu-service): Add bulk menu creation

   - Add POST /menu/bulk endpoint
   - Update ARCHITECTURE.md: API Endpoints table
   - Update ARCHITECTURE.md: Bulk creation sequence diagram
   - Add unit tests for bulk creation
   "
   ```

---

### Documentation Quality Standards

**Mermaid Diagrams:**
- ✅ Use consistent styling (colors for layers)
- ✅ Keep diagrams simple (max 10-15 nodes)
- ✅ Add legends if needed
- ✅ Test rendering before commit (use https://mermaid.live/)

**API Documentation:**
- ✅ Include request/response examples
- ✅ Document all parameters
- ✅ Show authentication requirements
- ✅ Add error codes

**Architecture Diagrams:**
- ✅ Show clear boundaries (frontend/backend/data)
- ✅ Use standard notation (arrows for data flow)
- ✅ Include all dependencies
- ✅ Keep up-to-date with code

---

### Common Documentation Mistakes

❌ **Don't:**
- Commit code without updating docs
- Update docs in separate commit (should be together)
- Leave outdated examples in CLAUDE.md
- Break Mermaid diagrams (test before commit)
- Forget to update Communication Plan when adding service calls

✅ **Do:**
- Commit code + docs together
- Test Mermaid diagrams render correctly
- Update ALL affected documentation files
- Keep examples in sync with code
- Use clear commit messages explaining doc changes

---

## 🎯 Typische Tasks

### Task 1: "Start Development Environment"

```bash
cd /Users/wolfgang/Projects/lg-development

# First time setup
./scripts/dev/setup.sh   # Clones repos from GitHub

# Start all services
./scripts/dev/start.sh

# Verify services are running
./scripts/dev/status.sh

# View logs
./scripts/dev/logs.sh            # All services
./scripts/dev/logs.sh user-service   # Specific service
```

### Task 2: "Work on a specific service"

```bash
# Navigate to service
cd repos/lg-user-service

# Make changes
vi src/routes/auth.ts

# Rebuild and restart (in lg-development root)
cd /Users/wolfgang/Projects/lg-development
docker-compose up -d --build user-service

# View logs
docker logs -f lg-backend-user

# Test changes
curl http://api.lg.local/user/health

# Commit to service repo (NOT lg-development!)
cd repos/lg-user-service
git add .
git commit -m "feat: improve auth flow"
git push origin main
```

### Task 3: "Debug a failing service"

```bash
# Check service status
docker ps | grep lg-

# View logs
./scripts/dev/logs.sh permissions-service

# Check Traefik routing
open http://traefik.lg.local

# Restart specific service
docker-compose restart permissions-service

# Rebuild from scratch
docker-compose up -d --build --force-recreate permissions-service

# Check database connection
docker exec -it lg-infra-postgres psql -U licenseguard -d licenseguard
```

### Task 4: "Update repos from GitHub"

```bash
# Update all repos
./scripts/dev/update.sh

# Or update specific repo
cd repos/lg-menu-service
git pull origin main

# Rebuild if dependencies changed
cd ../..
docker-compose up -d --build menu-service
```

### Task 5: "Fix infrastructure issue"

```bash
# Check infrastructure services
docker ps | grep lg-infra

# Restart infrastructure
docker-compose restart postgres redis traefik verdaccio

# View infrastructure logs
docker logs lg-infra-postgres
docker logs lg-infra-traefik

# Reset database (CAUTION!)
docker-compose down -v  # Removes volumes
docker-compose up -d postgres
```

### Task 6: "Script fixen/verbessern"

```bash
# Scripts sind in scripts/dev/ oder scripts/migration/
vi scripts/dev/start.sh

# Test:
./scripts/dev/start.sh

# Commit in lg-development (nicht in repos/!)
git add scripts/dev/start.sh
git commit -m "fix: improve start.sh error handling"
git push origin main
```

---

## 🐳 Common Docker Commands

### Service Management

```bash
# View all running services
docker-compose ps

# Start all services
docker-compose up -d

# Start specific service
docker-compose up -d user-service

# Stop all services
docker-compose down

# Stop but keep volumes (data preserved)
docker-compose stop

# Rebuild and restart service
docker-compose up -d --build user-service

# Force recreate (ignores cache)
docker-compose up -d --build --force-recreate user-service

# View logs
docker-compose logs -f                    # All services
docker-compose logs -f user-service       # Specific service
docker-compose logs --tail=100 user-service  # Last 100 lines
```

### Network & Connectivity

```bash
# List networks
docker network ls

# Inspect network
docker network inspect lg-internal

# Test connectivity between services
docker exec lg-backend-user ping postgres
docker exec lg-backend-user curl http://postgres:5432
```

### Database Operations

```bash
# Connect to Postgres
docker exec -it lg-infra-postgres psql -U licenseguard -d licenseguard

# Run SQL query
docker exec lg-infra-postgres psql -U licenseguard -d licenseguard -c "SELECT * FROM users LIMIT 5;"

# Backup database
docker exec lg-infra-postgres pg_dump -U licenseguard licenseguard > backup.sql

# Restore database
cat backup.sql | docker exec -i lg-infra-postgres psql -U licenseguard -d licenseguard

# Reset database (DANGEROUS!)
docker-compose down -v  # Removes volumes!
docker-compose up -d postgres
```

### Redis Operations

```bash
# Connect to Redis
docker exec -it lg-infra-redis redis-cli -a changeme

# Common Redis commands (in redis-cli)
AUTH changeme
PING
KEYS *
GET some_key
FLUSHALL  # DANGEROUS: Clears all data!
```

### Container Inspection

```bash
# View container details
docker inspect lg-backend-user

# View environment variables
docker exec lg-backend-user env

# View processes
docker top lg-backend-user

# Execute command in container
docker exec lg-backend-user ls -la /app
docker exec -it lg-backend-user sh  # Interactive shell
```

### Cleanup

```bash
# Remove stopped containers
docker-compose down

# Remove with volumes (data loss!)
docker-compose down -v

# Remove images
docker-compose down --rmi all

# Clean up unused Docker resources
docker system prune -a  # CAUTION: Removes all unused images!
```

---

## 🔍 Debugging

### "Service won't start" / Container crashes

**Schritt 1:** Check logs
```bash
docker logs lg-backend-user
docker logs --tail=100 -f lg-backend-user  # Follow logs
```

**Schritt 2:** Check environment variables
```bash
docker exec lg-backend-user env | grep DATABASE_URL
docker exec lg-backend-user env | grep JWT_SECRET
```

**Schritt 3:** Check dependencies
```bash
# Is postgres healthy?
docker ps | grep postgres
docker exec lg-infra-postgres pg_isready -U licenseguard

# Is redis healthy?
docker exec lg-infra-redis redis-cli -a changeme PING
```

**Schritt 4:** Rebuild from scratch
```bash
docker-compose stop user-service
docker-compose rm -f user-service
docker-compose up -d --build user-service
```

### "Proxy domains not working"

**Problem:** `http://admin.lg.local` returns connection refused

**Schritt 1:** Check /etc/hosts
```bash
cat /etc/hosts | grep lg.local
# Should show: 127.0.0.1 admin.lg.local api.lg.local traefik.lg.local
```

**Schritt 2:** Check Traefik
```bash
docker ps | grep traefik
docker logs lg-infra-traefik --tail=50
```

**Schritt 3:** Check Traefik routing
```bash
open http://traefik.lg.local
# Or: http://localhost:8080
```

**Schritt 4:** Restart Traefik
```bash
docker-compose restart traefik
```

### "Database connection failed"

**Problem:** Services can't connect to postgres

**Check connection string:**
```bash
docker exec lg-backend-user env | grep DATABASE_URL
# Should be: postgres://licenseguard:changeme@postgres:5432/licenseguard
```

**Check postgres is running:**
```bash
docker ps | grep postgres
docker logs lg-infra-postgres --tail=20
```

**Test connection from service:**
```bash
docker exec lg-backend-user sh -c "apk add postgresql-client && psql postgres://licenseguard:changeme@postgres:5432/licenseguard -c 'SELECT 1;'"
```

### "Port already in use"

**Problem:** `Error: bind: address already in use`

**Find process using port:**
```bash
# macOS/Linux
lsof -i :80
lsof -i :3002

# Kill process
kill -9 <PID>
```

**Or change port in docker-compose.yml:**
```yaml
ports:
  - "8080:80"  # Use 8080 instead of 80
```

### "npm package not found" (Verdaccio)

**Problem:** `npm install @wolfgangm81/lg-menu-registry` fails

**Check Verdaccio:**
```bash
docker ps | grep verdaccio
curl http://localhost:4873/@wolfgangm81/lg-menu-registry
```

**Check .npmrc in service:**
```bash
cat repos/lg-user-service/.npmrc
# Should have: @wolfgangm81:registry=http://verdaccio:4873/
```

**Publish package to Verdaccio:**
```bash
cd repos/lg-menu-registry

# In Docker (recommended)
docker run --rm -it -v $(pwd):/app -w /app node:20-alpine sh -c "
  npm login --registry http://host.docker.internal:4873
  npm publish --registry http://host.docker.internal:4873
"

# Oder über make (publisht zu GitHub Packages)
make publish-package PACKAGE=lg-menu-registry
```

---

## 🚨 Häufige Fehler

### Fehler 1: "Git add repos/"

❌ **FALSCH:**
```bash
cd /Users/wolfgang/Projects/lg-development
git add repos/lg-admin-ui
# → Error: repos/ ist gitignored!
```

✅ **RICHTIG:**
```bash
# repos/ wird NICHT in lg-development committed!
# Jedes Projekt in repos/ hat eigenes .git Repo
cd repos/lg-admin-ui
git add .
git commit -m "fix: ..."
git push origin main  # ← Pusht zu WolfgangM81/lg-admin-ui auf GitHub
```

### Fehler 2: "Service changes not reflected"

❌ **FALSCH:**
```bash
# Code in repos/lg-user-service ändern
# docker-compose up -d  # ← Nutzt altes Image!
```

✅ **RICHTIG:**
```bash
# Nach Code-Änderungen IMMER rebuilden
docker-compose up -d --build user-service
# Oder rebuild ohne cache:
docker-compose build --no-cache user-service
docker-compose up -d user-service
```

### Fehler 3: "Wrong working directory"

❌ **FALSCH:**
```bash
cd repos/lg-user-service
./scripts/dev/start.sh  # ← Script nicht gefunden!
```

✅ **RICHTIG:**
```bash
# Dev scripts müssen aus lg-development/ root ausgeführt werden
cd /Users/wolfgang/Projects/lg-development
./scripts/dev/start.sh
```

### Fehler 4: "Missing environment variables"

❌ **FALSCH:**
```bash
# .env nicht konfiguriert
docker-compose up -d
# → Services starten, aber DB connection fails
```

✅ **RICHTIG:**
```bash
# .env immer zuerst konfigurieren
cp .env.example .env
vi .env  # Fill in POSTGRES_PASSWORD, JWT_SECRET, etc.
docker-compose up -d
```

### Fehler 5: "Forgot to run setup.sh"

❌ **FALSCH:**
```bash
# repos/ ist leer
docker-compose up -d
# → Build fails: Dockerfile not found
```

✅ **RICHTIG:**
```bash
# Erst repos clonen
./scripts/dev/setup.sh
# Dann services starten
docker-compose up -d
```

---

## 📝 Template-System

### Templates in `templates/`

- `.npmrc.template` - GitHub Packages Auth
- `library-workflow.yml.template` - npm publish Pipeline
- `backend-workflow.yml.template` - Docker Build Pipeline
- `nextjs-workflow.yml.template` - Next.js Build Pipeline
- `README.md.template` - Projekt README

### Wie Templates angewendet werden

```bash
./scripts/prepare-repo.sh repos/lg-admin-ui --type library
```

**Was passiert:**
1. Kopiert `templates/.npmrc.template` → `repos/lg-admin-ui/.npmrc`
2. Kopiert `templates/library-workflow.yml.template` → `.github/workflows/build.yml`
3. Ersetzt Platzhalter: `{{PROJECT_NAME}}` → `lg-admin-ui`
4. Fixt package.json Dependencies

### Template editieren

```bash
vi templates/library-workflow.yml.template

# Dann re-run prepare:
./scripts/prepare-repo.sh repos/lg-admin-ui --type library
```

---

## 🎓 Best Practices

### 1. Immer Dry-Run zuerst

```bash
./scripts/create-github-repos.sh --dry-run
# Prüfen was passieren würde
./scripts/create-github-repos.sh
```

### 2. Health Check vor Push

```bash
./scripts/health-check.sh
# Sicherstellen alles OK
cd repos/lg-admin-ui && git push
```

### 3. Secrets niemals ausgeben

```bash
# ❌ FALSCH:
cat .env.secrets

# ✅ RICHTIG:
grep -q "GITHUB_TOKEN" .env.secrets && echo "✓ Found"
```

### 4. Original als Referenz

```bash
# Unsicher bei Config?
diff ../lg-admin-ui/package.json repos/lg-admin-ui/package.json
```

---

## 🚀 Performance

**Migration Dauer:**
- Sequentiell: 15-20min
- Parallel (mit Scripts): 10-12min

**Bottlenecks:**
- GitHub API (Rate-Limited)
- rsync (bei großen Projekten)
- npm install (bei prepare-repo)

**Optimierung:**
```bash
# Parallel copy (wenn genug RAM):
for p in lg-admin-ui lg-menu-registry lg-user-service; do
  ./scripts/copy-project.sh --source ../$p --dest repos/$p &
done
wait
```

---

## ✅ Development Environment Health Check

Environment is healthy when:

1. ✅ All services running: `docker-compose ps` → all "Up"
2. ✅ Proxy domains working: `curl http://admin.lg.local` → HTTP 200
3. ✅ Database healthy: `docker exec lg-infra-postgres pg_isready` → "accepting connections"
4. ✅ Redis healthy: `docker exec lg-infra-redis redis-cli -a changeme PING` → "PONG"
5. ✅ Traefik dashboard: `open http://traefik.lg.local` → Shows all services
6. ✅ API endpoints: `curl http://api.lg.local/user/health` → {"status": "healthy"}

**Quick health check:**
```bash
./scripts/dev/status.sh  # Shows all service states
```

---

## ⚡ Quick Reference

### Daily Commands

```bash
# Start development
cd /Users/wolfgang/Projects/lg-development
./scripts/dev/start.sh

# Check status
./scripts/dev/status.sh

# View logs
./scripts/dev/logs.sh user-service

# Stop all
./scripts/dev/stop.sh

# Update from GitHub
./scripts/dev/update.sh
```

### Service URLs

| Service | URL | Alternative |
|---------|-----|-------------|
| Admin UI | http://admin.lg.local | http://localhost |
| User Service | http://api.lg.local/user | http://localhost/api/user |
| Permissions | http://api.lg.local/permissions | http://localhost/api/permissions |
| API Keys | http://api.lg.local/v1 | http://localhost/api/v1 |
| Tour Service | http://api.lg.local/tour | http://localhost/api/tour |
| Menu Service | http://api.lg.local/menu | http://localhost/api/menu |
| Secrets | http://api.lg.local/secrets | http://localhost/api/secrets |
| Traefik Dashboard | http://traefik.lg.local | http://localhost:8080 |
| Verdaccio | http://localhost:4873 | - |

### Docker Quick Commands

```bash
# View all services
docker-compose ps

# Rebuild service
docker-compose up -d --build user-service

# View logs
docker-compose logs -f user-service

# Restart service
docker-compose restart user-service

# Database access
docker exec -it lg-infra-postgres psql -U licenseguard -d licenseguard

# Redis access
docker exec -it lg-infra-redis redis-cli -a changeme
```

### Hot-Reload Quick Commands

```bash
# Enable hot-reload for package development
make dev-sync

# Open live dashboard (recommended!)
make dev-sync-dashboard

# Check for build errors
make dev-sync-check

# View package logs
make dev-sync-logs PACKAGE=menu-registry

# Show build performance
make dev-sync-metrics

# Disable hot-reload
make dev-normal
```

### Git Workflow (in repos/)

```bash
cd repos/lg-user-service
git checkout -b feature/new-endpoint
# Make changes
git add .
git commit -m "feat: add new endpoint"
git push origin feature/new-endpoint
# Create PR on GitHub
```

---

## 🚀 Hot-Reload Performance Tuning

### Build Performance

#### TypeScript Compiler Options

**tsconfig.json Optimizations:**

```json
{
  "compilerOptions": {
    // Incremental compilation (faster rebuilds)
    "incremental": true,
    "tsBuildInfoFile": ".tsbuildinfo",

    // Skip lib check (faster, but less safe)
    "skipLibCheck": true,

    // Parallel type checking (faster on multi-core)
    // Note: Only available in ts-node/tsx, not tsc
    "transpileOnly": true,  // For tsx watch

    // Don't emit on error (prevents broken builds)
    "noEmitOnError": false  // Set false for watch mode
  }
}
```

**Trade-offs:**
- `skipLibCheck: true` → Faster, but misses type errors in node_modules
- `noEmitOnError: false` → Emits even with errors (useful for iterative development)

---

#### Watch Mode Delays

**Problem:** Too frequent rebuilds → High CPU usage

**Solution:** Increase watch delay

**.env.dev:**
```bash
# Delay before triggering rebuild (milliseconds)
TS_WATCH_DELAY_MS=500  # Default
TS_WATCH_DELAY_MS=1000  # Conservative (less CPU, slower feedback)
TS_WATCH_DELAY_MS=100   # Aggressive (more CPU, faster feedback)
```

**package.json:**
```json
{
  "scripts": {
    "build:watch": "tsc --watch --preserveWatchOutput"
  }
}
```

**Note:** TypeScript's --watch doesn't support custom delays natively. Use tools like `chokidar-cli` for fine-grained control.

---

### Volume Mount Performance

#### macOS: Use :cached or :delegated

**Problem:** Docker volumes on macOS are slow (OSXFS overhead)

**Solution:** Use consistency modes

```yaml
services:
  lg-builder-menu-registry:
    volumes:
      # :cached = Host writes, container reads (faster)
      - ./repos/lg-menu-registry:/app:ro,cached

      # :delegated = Container writes, host reads (fastest for build output)
      - lg-package-builds:/dist:delegated
```

**Performance Impact:**
- No flag: ~200ms overhead per file operation
- `:cached`: ~50ms overhead
- `:delegated`: ~10ms overhead

**Trade-off:** Less consistency (changes may take 100-500ms to propagate)

---

#### Linux: Native Performance (No Tuning Needed)

Linux uses native bind mounts → No performance overhead.

**Skip volume flags:**
```yaml
volumes:
  - ./repos/lg-menu-registry:/app:ro  # No :cached needed
```

---

### Service Restart Performance

#### Smart Restart: Only Affected Services

**Automatic (with jq):**

Install `jq`:
```bash
# macOS
brew install jq

# Linux
apt-get install jq
```

**Manual (fallback):**

Edit `scripts/dev/package-dependencies.json`:

```json
{
  "menu-registry": ["menu-service"],
  "backend-common": ["user-service", "permissions-service", "api-keys-service", "secrets-service", "tour-service"],
  "types": ["all"]  # "all" = restart everything
}
```

**Performance:**
- Edit `menu-registry` → Restart 1 service (~2s) vs 6 services (~10s) = **5x faster**

---

#### Restart Delay Tuning

**Problem:** Multiple rapid changes → Multiple restarts

**Solution:** Add delay to batch changes

**.env.dev:**
```bash
# Wait N seconds after build before restarting
RESTART_DELAY_SECONDS=2  # Default
RESTART_DELAY_SECONDS=5  # Conservative (fewer restarts)
RESTART_DELAY_SECONDS=0  # Aggressive (instant restarts)
```

**Use Case:**
- Rapid edits (refactoring) → Set higher delay (5s)
- Single targeted changes → Set lower delay (0-1s)

---

### Metrics & Monitoring Overhead

#### Disable Metrics in Production

**.env.dev:**
```bash
# Development: Enabled (useful for debugging)
METRICS_ENABLED=true

# Production: Disabled (no overhead)
METRICS_ENABLED=false
```

**Overhead:** ~5-10ms per build (negligible for dev, avoid in prod)

---

#### Tune Metrics Retention

**.env.dev:**
```bash
# Keep last N builds in metrics
METRICS_MAX_BUILDS=100  # Default (uses ~50KB storage)
METRICS_MAX_BUILDS=1000  # High retention (~500KB storage)
METRICS_MAX_BUILDS=20   # Low retention (~10KB storage)
```

---

### Dashboard Performance

#### Auto-Refresh Interval

**Problem:** Dashboard refresh too frequent → High CPU

**Solution:** Increase refresh interval

**.env.dev:**
```bash
# Dashboard refresh every N seconds
DASHBOARD_REFRESH_INTERVAL=2  # Default (responsive)
DASHBOARD_REFRESH_INTERVAL=5  # Conservative (less CPU)
DASHBOARD_REFRESH_INTERVAL=1  # Aggressive (more responsive, more CPU)
```

**Use watch alternatives:**

```bash
# Built-in watch (if available)
make dev-sync-dashboard  # Uses 'watch' command

# Manual polling (fallback)
while true; do clear; make dev-sync-status; sleep 2; done
```

---

### Build Cache Optimization

#### Docker Layer Caching

**Best Practice:** Copy package.json first

```dockerfile
# ✅ GOOD: Layers are cached if dependencies don't change
COPY package*.json ./
RUN npm install
COPY . .

# ❌ BAD: npm install runs every time source changes
COPY . .
RUN npm install
```

**Performance Impact:**
- Cached: ~1s rebuild
- Not cached: ~30s rebuild (full npm install)

---

#### TypeScript Incremental Builds

**tsconfig.json:**
```json
{
  "compilerOptions": {
    "incremental": true,
    "tsBuildInfoFile": ".tsbuildinfo"
  }
}
```

**What it does:**
- Stores compilation info in `.tsbuildinfo`
- Only recompiles changed files + dependencies
- **5-10x faster** rebuilds

**Trade-off:** Requires ~1-5MB storage for .tsbuildinfo file

---

### Network Performance

#### Use Host Network Mode (Linux Only)

**For services that don't need isolation:**

```yaml
services:
  menu-service:
    network_mode: host  # Use host network stack
```

**Performance:**
- Bridge network: ~0.1-0.5ms overhead
- Host network: No overhead

**Trade-off:** Services must use unique ports (can't have multiple on same port)

**Note:** Not supported on macOS/Windows Docker Desktop

---

### Benchmark: Performance Impact

| Optimization | Before | After | Improvement |
|--------------|--------|-------|-------------|
| **Incremental TypeScript** | 10s | 2s | 5x faster |
| **macOS :cached volumes** | 5s | 2s | 2.5x faster |
| **Smart restart (1 vs 6 services)** | 10s | 2s | 5x faster |
| **Restart delay (batch 3 changes)** | 6s (3×2s) | 2s (1×2s) | 3x faster |
| **Docker layer caching** | 30s | 1s | 30x faster |
| **Combined** | ~60s | ~2-3s | **20-30x faster** |

---

### Recommended Settings

**Development (.env.dev):**
```bash
# Fast feedback
NODE_ENV=development
TS_WATCH_DELAY_MS=500
RESTART_DELAY_SECONDS=2
METRICS_ENABLED=true
DASHBOARD_REFRESH_INTERVAL=2
SMART_RESTART_ENABLED=true
```

**Heavy workload (refactoring, mass edits):**
```bash
# Batch changes, reduce overhead
TS_WATCH_DELAY_MS=1000
RESTART_DELAY_SECONDS=5
DASHBOARD_REFRESH_INTERVAL=5
```

**Testing / CI:**
```bash
# No overhead
METRICS_ENABLED=false
SMART_RESTART_ENABLED=false  # Restart all (safer)
```

---

### Troubleshooting Performance Issues

**Slow builds (>10s):**
1. Check TypeScript config: `incremental: true`?
2. Check Docker layer caching: `package.json` copied first?
3. Check volume mode (macOS): Using `:cached`?

**High CPU usage:**
1. Increase watch delay: `TS_WATCH_DELAY_MS=1000`
2. Increase restart delay: `RESTART_DELAY_SECONDS=5`
3. Reduce dashboard refresh: `DASHBOARD_REFRESH_INTERVAL=5`

**Frequent restarts:**
1. Increase restart delay to batch changes
2. Check watch isn't triggering on build output (exclude `/dist` in .dockerignore)

**Out of sync (changes not reflected):**
1. Reduce delays: `TS_WATCH_DELAY_MS=100`, `RESTART_DELAY_SECONDS=0`
2. Check volume mounts: `docker inspect <container> | grep Mounts`
3. Force rebuild: `make dev-sync-rebuild`

---

### See Also

- **[.env.dev.example](../.env.dev.example)** - All tuning variables
- **[DOCKER.md#package-hot-reload-architecture](./docs/DOCKER.md#package-hot-reload-architecture)** - Architecture
- **[OPTIMIZATION_SUMMARY.md](./OPTIMIZATION_SUMMARY.md)** - Implementation details

---

## 📚 Weiterführende Docs

### General Documentation
- **[README.md](./README.md)** - Quick Start & Overview
- **[PROXY_DOMAINS.md](./PROXY_DOMAINS.md)** - Proxy Domains Setup & Troubleshooting
- **[MIGRATION_COMPLETE.md](./MIGRATION_COMPLETE.md)** - Migration Status & History

### Hot-Reload Documentation
- **[HOT_RELOAD_QUICK_REF.md](./HOT_RELOAD_QUICK_REF.md)** - Hot-Reload Quick Reference Card
- **[OPTIMIZATION_SUMMARY.md](./OPTIMIZATION_SUMMARY.md)** - Complete Implementation Details (All 5 Phases)

### Platform Documentation
- **[docs/CLAUDE.md](./docs/CLAUDE.md)** - LicenseGuard Platform Architecture (50% complete)
- **[docs/DOCKER.md](./docs/DOCKER.md)** - Docker Best Practices
- **[docs/TESTING.md](./docs/TESTING.md)** - Testing Strategy
- **[docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md)** - Common Issues & Solutions
- **[docs/RBAC.md](./docs/RBAC.md)** - RBAC Implementation (100% complete)

---

## 🆘 Support

### Common Issues

See sections above:
- **⚡ Package Hot-Reload System** - Hot-reload troubleshooting and error detection
- **🔍 Debugging** - Service, network, database issues
- **🚨 Häufige Fehler** - Git, Docker, environment variable mistakes
- **[PROXY_DOMAINS.md](./PROXY_DOMAINS.md)** - Proxy domain setup issues
- **[docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md)** - Platform-specific issues

### Getting Help

1. Check service logs: `./scripts/dev/logs.sh <service-name>`
2. Check Traefik dashboard: `http://traefik.lg.local`
3. Check service health: `./scripts/dev/status.sh`
4. Review relevant documentation in `docs/`

**Noch Fragen?** Frag den User! 🙂
