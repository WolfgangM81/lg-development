# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

## 🚨 KRITISCHE REGEL #2: REPOS/ IST GITIGNORED!

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
├── repos/                           # ⚠️ GITIGNORED! Git Clones
│   ├── lg-admin-ui/.git            # Von GitHub geclont
│   ├── lg-management/.git          # Von GitHub geclont
│   └── ...
├── .dependency-graph.json          # Auto-generiert
├── .env                             # Setup Config (CLONE_LG_*)
└── docker-compose.yml              # Infrastructure Stack

~/Projects/                          # ⚠️ OLD MONOREPO (removed after migration!)
└── backups/                         # Backup archives only
```

### repos/ Contents (Git Clones)

```
repos/
├── lg-platform/           # Infrastructure (Traefik, Postgres, Redis)
├── lg-admin/              # Admin UI (Vite) - ACTIVE
├── lg-management/         # Next.js 16 Admin UI - DISABLED
├── lg-user-service/       # Backend: User & Auth
├── lg-permissions-service/ # Backend: RBAC & DAG
├── lg-api-keys-service/   # Backend: API Key Validation
├── lg-tour-service/       # Backend: NextStepjs Integration
├── lg-menu-service/       # Backend: Menu Management
├── lg-secrets-service/    # Backend: Secrets Management
├── lg-admin-ui/           # Shared UI Components (npm package)
├── lg-menu-registry/      # Shared Types (npm package)
├── lg-backend-common/     # Shared Backend Utilities (npm package)
└── lg-e2e-tests/          # Playwright E2E Tests
```

**Each repo has its own `.git` directory!**
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

### Proxy Domains (No Ports!)

**Setup Required:** Add to `/etc/hosts`:
```bash
127.0.0.1 admin.lg.local
127.0.0.1 api.lg.local
127.0.0.1 traefik.lg.local
```

**Access Services:**
- `http://admin.lg.local` - Admin UI
- `http://api.lg.local/user` - User Service
- `http://api.lg.local/permissions` - Permissions Service
- `http://api.lg.local/rbac` - RBAC Endpoints
- `http://api.lg.local/v1` - API Keys Service
- `http://api.lg.local/tour` - Tour Service
- `http://api.lg.local/menu` - Menu Service
- `http://api.lg.local/secrets` - Secrets Service
- `http://traefik.lg.local` - Traefik Dashboard

**See:** [PROXY_DOMAINS.md](./PROXY_DOMAINS.md) for complete setup guide.

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
npm login --registry http://localhost:4873
npm publish --registry http://localhost:4873
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

## 📚 Weiterführende Docs

- **[README.md](./README.md)** - Quick Start & Overview
- **[PROXY_DOMAINS.md](./PROXY_DOMAINS.md)** - Proxy Domains Setup & Troubleshooting
- **[MIGRATION_COMPLETE.md](./MIGRATION_COMPLETE.md)** - Migration Status & History
- **[docs/CLAUDE.md](./docs/CLAUDE.md)** - LicenseGuard Platform Architecture (50% complete)
- **[docs/DOCKER.md](./docs/DOCKER.md)** - Docker Best Practices
- **[docs/TESTING.md](./docs/TESTING.md)** - Testing Strategy
- **[docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md)** - Common Issues & Solutions
- **[docs/RBAC.md](./docs/RBAC.md)** - RBAC Implementation (100% complete)

---

## 🆘 Support

### Common Issues

See sections above:
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
