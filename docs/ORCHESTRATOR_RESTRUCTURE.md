# Orchestrator Restructure Plan

## 🎯 Ziel

Klare Strukturierung des lg-development Orchestrators mit:
- Trennung nach Verantwortlichkeiten (infrastructure, services, packages)
- Jedes Projekt als eigenes Git Repository
- Docker Compose Files in jeweiligen Projekten
- Makefile für einfaches Setup und Management

---

## 📂 Neue Struktur

```
lg-development/                      # Orchestrator (Git Repo)
├── Makefile                         # Main orchestration
├── .env                             # Global environment config
├── .gitignore                       # repos/ ist gitignored
├── scripts/
│   ├── setup/
│   │   ├── clone-repos.sh          # Clone all repos from GitHub
│   │   ├── merge-compose.sh        # Merge docker-compose files
│   │   └── init-networks.sh        # Create Docker networks
│   └── dev/
│       ├── start.sh                # Start stack
│       ├── stop.sh                 # Stop stack
│       ├── logs.sh                 # View logs
│       └── status.sh               # Check health
│
├── infrastructure/                  # Infrastructure projects (Git Clones)
│   ├── lg-traefik/
│   │   ├── .git/
│   │   ├── docker-compose.yml      # Traefik service definition
│   │   ├── traefik.yml             # Traefik config
│   │   ├── dynamic.yml             # Routing rules
│   │   └── README.md
│   │
│   ├── lg-database/
│   │   ├── .git/
│   │   ├── docker-compose.yml      # Postgres + Redis
│   │   ├── init.sql                # Database initialization
│   │   └── README.md
│   │
│   └── lg-verdaccio/
│       ├── .git/
│       ├── docker-compose.yml      # NPM registry
│       ├── config.yaml
│       └── README.md
│
├── services/                        # Backend services (Git Clones)
│   ├── lg-user-service/
│   │   ├── .git/
│   │   ├── docker-compose.yml      # Service definition
│   │   ├── Dockerfile
│   │   ├── src/
│   │   └── package.json
│   │
│   ├── lg-permissions-service/
│   ├── lg-api-keys-service/
│   ├── lg-tour-service/
│   ├── lg-menu-service/
│   ├── lg-secrets-service/
│   └── lg-admin/                   # Frontend service
│
├── packages/                        # Shared libraries (Git Clones)
│   ├── lg-admin-ui/
│   │   ├── .git/
│   │   ├── package.json
│   │   ├── src/
│   │   └── README.md
│   │
│   ├── lg-menu-registry/
│   ├── lg-backend-common/
│   └── lg-types/
│
└── docker-compose.generated.yml     # Auto-generated merged compose file

```

---

## 🎮 Makefile Commands

### Main Commands

```makefile
# Makefile

.PHONY: help setup start stop restart logs status clean rebuild

# Default target
help:
	@echo "LG-Development Orchestrator"
	@echo ""
	@echo "Setup Commands:"
	@echo "  make setup          - Clone all repos and setup environment"
	@echo "  make setup-infra    - Clone only infrastructure repos"
	@echo "  make setup-services - Clone only service repos"
	@echo "  make setup-packages - Clone only package repos"
	@echo ""
	@echo "Development Commands:"
	@echo "  make start          - Start all services"
	@echo "  make stop           - Stop all services"
	@echo "  make restart        - Restart all services"
	@echo "  make logs           - View logs (SERVICE=name for specific)"
	@echo "  make status         - Show service status"
	@echo ""
	@echo "Build Commands:"
	@echo "  make build          - Build all services"
	@echo "  make rebuild        - Rebuild from scratch"
	@echo ""
	@echo "Cleanup Commands:"
	@echo "  make clean          - Remove generated files"
	@echo "  make clean-all      - Remove everything including repos"

# Setup
setup: setup-env setup-networks setup-repos merge-compose
	@echo "✅ Setup complete!"
	@echo "Run 'make start' to start the stack"

setup-env:
	@echo "🔧 Checking environment..."
	@test -f .env || (echo "❌ .env not found! Copy .env.example" && exit 1)
	@echo "✅ Environment OK"

setup-networks:
	@echo "🌐 Creating Docker networks..."
	@./scripts/setup/init-networks.sh

setup-repos:
	@echo "📦 Cloning repositories..."
	@./scripts/setup/clone-repos.sh

merge-compose:
	@echo "🔨 Merging docker-compose files..."
	@./scripts/setup/merge-compose.sh

# Development
start:
	@echo "🚀 Starting services..."
	@docker-compose -f docker-compose.generated.yml up -d
	@echo "✅ Services started!"
	@make status

stop:
	@echo "🛑 Stopping services..."
	@docker-compose -f docker-compose.generated.yml down
	@echo "✅ Services stopped!"

restart:
	@make stop
	@make start

logs:
ifdef SERVICE
	@docker-compose -f docker-compose.generated.yml logs -f $(SERVICE)
else
	@docker-compose -f docker-compose.generated.yml logs -f
endif

status:
	@echo "📊 Service Status:"
	@docker-compose -f docker-compose.generated.yml ps

# Build
build:
	@echo "🔨 Building services..."
	@docker-compose -f docker-compose.generated.yml build

rebuild:
	@echo "🔨 Rebuilding from scratch..."
	@docker-compose -f docker-compose.generated.yml build --no-cache
	@make restart

# Cleanup
clean:
	@echo "🧹 Cleaning generated files..."
	@rm -f docker-compose.generated.yml
	@echo "✅ Clean complete!"

clean-all: clean
	@echo "🧹 Removing all repositories..."
	@rm -rf infrastructure/ services/ packages/
	@echo "✅ Clean all complete!"
```

---

## 🔧 Script: clone-repos.sh

```bash
#!/bin/bash
# scripts/setup/clone-repos.sh

set -e

source .env

GITHUB_USER="${GITHUB_USER:-WolfgangM81}"

echo "🔧 Cloning repositories from GitHub..."

# Function to clone repo
clone_repo() {
    local category=$1
    local repo_name=$2
    local target_dir="${category}/${repo_name}"

    if [ -d "${target_dir}/.git" ]; then
        echo "  ⊘ ${repo_name} (already exists, skipping)"
        return
    fi

    echo "  📦 Cloning ${repo_name}..."
    mkdir -p "${category}"
    gh repo clone "${GITHUB_USER}/${repo_name}" "${target_dir}" 2>/dev/null || {
        echo "  ❌ Failed to clone ${repo_name}"
        return 1
    }
    echo "  ✅ ${repo_name} cloned"
}

# Infrastructure
echo ""
echo "🏗️  Infrastructure Repositories:"
clone_repo "infrastructure" "lg-traefik"
clone_repo "infrastructure" "lg-database"
clone_repo "infrastructure" "lg-verdaccio"

# Services
echo ""
echo "🔧 Service Repositories:"
clone_repo "services" "lg-user-service"
clone_repo "services" "lg-permissions-service"
clone_repo "services" "lg-api-keys-service"
clone_repo "services" "lg-tour-service"
clone_repo "services" "lg-menu-service"
clone_repo "services" "lg-secrets-service"
clone_repo "services" "lg-admin"

# Packages
echo ""
echo "📦 Package Repositories:"
clone_repo "packages" "lg-admin-ui"
clone_repo "packages" "lg-menu-registry"
clone_repo "packages" "lg-backend-common"
clone_repo "packages" "lg-types"

echo ""
echo "✅ All repositories cloned!"
```

---

## 🔨 Script: merge-compose.sh

```bash
#!/bin/bash
# scripts/setup/merge-compose.sh

set -e

OUTPUT_FILE="docker-compose.generated.yml"

echo "🔨 Merging docker-compose files..."

# Start with base structure
cat > "${OUTPUT_FILE}" << 'EOF'
# Auto-generated by lg-development orchestrator
# DO NOT EDIT MANUALLY - Changes will be overwritten
# Generated: $(date)

version: '3.8'

services:
EOF

# Function to extract services from compose file
merge_compose_file() {
    local compose_file=$1
    local project_name=$2

    if [ ! -f "${compose_file}" ]; then
        echo "  ⚠️  ${compose_file} not found, skipping"
        return
    fi

    echo "  ✅ Merging ${project_name}"

    # Extract services section (skip version and networks)
    # Add proper indentation
    yq eval '.services' "${compose_file}" | sed 's/^/  /' >> "${OUTPUT_FILE}"
}

# Merge infrastructure
echo ""
echo "🏗️  Merging infrastructure:"
merge_compose_file "infrastructure/lg-traefik/docker-compose.yml" "lg-traefik"
merge_compose_file "infrastructure/lg-database/docker-compose.yml" "lg-database"
merge_compose_file "infrastructure/lg-verdaccio/docker-compose.yml" "lg-verdaccio"

# Merge services
echo ""
echo "🔧 Merging services:"
for service_dir in services/*/; do
    if [ -f "${service_dir}docker-compose.yml" ]; then
        service_name=$(basename "${service_dir}")
        merge_compose_file "${service_dir}docker-compose.yml" "${service_name}"
    fi
done

# Add networks section
cat >> "${OUTPUT_FILE}" << 'EOF'

networks:
  lg-public:
    external: true
    name: lg-public
  lg-internal:
    external: true
    name: lg-internal

volumes:
  postgres_data:
  redis_data:
  verdaccio_storage:
EOF

echo ""
echo "✅ Merged compose file generated: ${OUTPUT_FILE}"
```

---

## 🌐 Script: init-networks.sh

```bash
#!/bin/bash
# scripts/setup/init-networks.sh

set -e

echo "🌐 Initializing Docker networks..."

# Check if networks exist, create if not
for network in lg-public lg-internal; do
    if docker network inspect "${network}" >/dev/null 2>&1; then
        echo "  ⊘ ${network} (already exists)"
    else
        echo "  ✅ Creating ${network}"
        docker network create "${network}"
    fi
done

echo "✅ Networks ready!"
```

---

## 📦 Beispiel: lg-traefik Repository

### Struktur
```
lg-traefik/
├── .git/
├── .github/
│   └── workflows/
│       └── docker-build.yml
├── docker-compose.yml
├── traefik.yml
├── dynamic.yml
├── certs/
├── README.md
└── .env.example
```

### docker-compose.yml
```yaml
# lg-traefik/docker-compose.yml
version: '3.8'

services:
  traefik:
    container_name: lg-infra-traefik
    image: traefik:v3.0
    restart: unless-stopped
    user: "0:0"
    ports:
      - "${TRAEFIK_HTTP_PORT:-80}:80"
      - "${TRAEFIK_HTTPS_PORT:-443}:443"
      - "${TRAEFIK_DASHBOARD_PORT:-8080}:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/etc/traefik/traefik.yml:ro
      - ./dynamic.yml:/etc/traefik/dynamic.yml:ro
      - ./certs:/etc/traefik/certs:ro
    networks:
      - lg-public
      - lg-internal
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(`traefik.lg.local`)"
      - "traefik.http.routers.dashboard.service=api@internal"
```

### README.md
```markdown
# lg-traefik

Traefik reverse proxy for LicenseGuard development environment.

## Features
- HTTP/HTTPS routing
- Proxy domains (*.lg.local)
- Dashboard (traefik.lg.local)
- Auto-discovery via Docker labels

## Configuration
See `traefik.yml` and `dynamic.yml`

## Environment Variables
- `TRAEFIK_HTTP_PORT` (default: 80)
- `TRAEFIK_HTTPS_PORT` (default: 443)
- `TRAEFIK_DASHBOARD_PORT` (default: 8080)
```

---

## 📦 Beispiel: lg-user-service Repository

### Struktur
```
lg-user-service/
├── .git/
├── .github/
│   └── workflows/
│       ├── build.yml
│       └── docker-publish.yml
├── docker-compose.yml
├── Dockerfile
├── src/
├── tests/
├── package.json
├── README.md
└── .env.example
```

### docker-compose.yml
```yaml
# lg-user-service/docker-compose.yml
version: '3.8'

services:
  user-service:
    container_name: lg-backend-user
    build:
      context: .
      dockerfile: Dockerfile
    restart: unless-stopped
    environment:
      NODE_ENV: ${NODE_ENV:-production}
      PORT: 3002
      DATABASE_URL: ${DATABASE_URL}
      REDIS_URL: ${REDIS_URL}
      JWT_SECRET: ${JWT_SECRET}
      INTERNAL_API_KEY: ${INTERNAL_API_KEY}
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - lg-internal
      - lg-public
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.user-service.rule=PathPrefix(`/api/user`)"
      - "traefik.http.routers.user-service.entrypoints=web"
      - "traefik.http.services.user-service.loadbalancer.server.port=3002"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3002/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

---

## 🔄 Migration Plan

### Phase 1: Vorbereitung (1-2h)

1. **Neue Repository-Struktur erstellen:**
   ```bash
   # Auf GitHub (via gh CLI)
   gh repo create WolfgangM81/lg-traefik --public
   gh repo create WolfgangM81/lg-database --public
   gh repo create WolfgangM81/lg-verdaccio --public
   ```

2. **Bestehende Projekte aufteilen:**
   ```bash
   # lg-traefik aus aktueller Struktur extrahieren
   mkdir temp-lg-traefik
   cp -r traefik/* temp-lg-traefik/
   cd temp-lg-traefik
   git init
   # Create docker-compose.yml for traefik only
   git add .
   git commit -m "Initial commit: Extract Traefik from monorepo"
   git remote add origin git@github.com:WolfgangM81/lg-traefik.git
   git push -u origin main
   ```

3. **lg-database Repository erstellen:**
   ```bash
   # Postgres + Redis zusammenfassen
   mkdir temp-lg-database
   cp -r database/* temp-lg-database/
   # Create docker-compose.yml with both postgres and redis
   ```

### Phase 2: Orchestrator Setup (2-3h)

1. **Makefile erstellen**
2. **Scripts schreiben** (clone-repos.sh, merge-compose.sh, init-networks.sh)
3. **Testen** mit `make setup`

### Phase 3: Service Migration (3-4h)

1. **Für jeden Service:**
   - docker-compose.yml im Service Repository erstellen
   - Nur Service-spezifische Config
   - Testen mit standalone `docker-compose up`
   - Pushen zu GitHub

2. **Services in Orchestrator integrieren**
   - Clone via `make setup`
   - Merge via `merge-compose.sh`
   - Testen

### Phase 4: Cleanup (1h)

1. **Alte Struktur entfernen**
2. **Dokumentation aktualisieren**
3. **CLAUDE.md anpassen**

**Total: 7-10 Stunden**

---

## ✅ Vorteile

### 1. Klare Verantwortlichkeiten
- **Infrastructure**: Platform-Tools (Traefik, DB, Registry)
- **Services**: Business Logic (User, Permissions, etc.)
- **Packages**: Shared Code (UI Components, Types)

### 2. Unabhängige Repositories
- Jedes Projekt hat eigene Git History
- Separate CI/CD Pipelines
- Unabhängige Versioning
- Klare Ownership

### 3. Einfaches Setup
```bash
git clone lg-development
cd lg-development
cp .env.example .env
make setup
make start
```

### 4. Flexible Entwicklung
```bash
# Nur Infrastructure
make setup-infra
make start

# Nur ein Service
cd services/lg-user-service
docker-compose up -d

# Full Stack
make setup
make start
```

### 5. Bessere Wartbarkeit
- docker-compose.yml nah am Code
- Keine zentrale monolithische compose file
- Changes isoliert im jeweiligen Repo

---

## 🎯 Beispiel Workflow

### Entwickler startet Environment

```bash
# Clone Orchestrator
git clone git@github.com:WolfgangM81/lg-development.git
cd lg-development

# Configure
cp .env.example .env
vi .env  # Fill in secrets

# Setup (one-time)
make setup
# → Clones all repos
# → Creates networks
# → Merges compose files

# Start
make start
# → docker-compose -f docker-compose.generated.yml up -d

# Develop
cd services/lg-user-service
vi src/routes/auth.ts
cd ../..
make restart SERVICE=user-service

# View logs
make logs SERVICE=user-service

# Stop
make stop
```

### Entwickler arbeitet an einem Service

```bash
cd services/lg-user-service

# Standalone development
docker-compose up -d
# → Startet nur user-service (mit Traefik, DB als external)

# Make changes
vi src/routes/auth.ts

# Test
curl http://localhost:3002/health

# Commit & Push
git add .
git commit -m "feat: improve auth"
git push origin main
```

---

## 📋 Nächste Schritte

1. **Review dieses Plans**
2. **GitHub Repositories erstellen** (via gh CLI)
3. **Erste Migration**: lg-traefik als Proof-of-Concept
4. **Makefile & Scripts implementieren**
5. **Services migrieren** (batch-weise)
6. **Testen & Dokumentieren**
7. **Alte Struktur entfernen**

---

## ❓ Offene Fragen

1. **Shared Dependencies?**
   - Soll postgres/redis in lg-database sein?
   - Oder separate lg-postgres, lg-redis Repos?

2. **Environment Variables?**
   - Zentral in lg-development/.env?
   - Oder per Service .env Files?
   - **Empfehlung**: Zentral + service-specific overrides

3. **Verdaccio Packages?**
   - Bleiben in packages/ oder separate npm registry?
   - **Empfehlung**: Packages bleiben in packages/, Verdaccio ist infra

4. **Testing?**
   - lg-e2e-tests als eigenes Repo?
   - In services/ oder separate tests/ category?
   - **Empfehlung**: services/lg-e2e-tests

---

**Status**: 📋 Plan Ready for Review
