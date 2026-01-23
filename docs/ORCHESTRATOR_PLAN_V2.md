# LG-Development Orchestrator Plan v2.0

**Based on: Docker Compose Best Practices + User Requirements**

---

## 🎯 Ziele (Confirmed)

1. ✅ Bessere Trennung, Übersichtlichkeit, Wartbarkeit, Erweiterbarkeit
2. ✅ Separate Git Repos für Infrastructure, Services, Packages
3. ✅ Best Practice: Multiple `-f` Flags (keine YAML Merging-Scripts)
4. ✅ Makefile + Scripts für komplexe Logik
5. ✅ Komfortable Setup-CLI mit `.env` Generator
6. ✅ Standalone Service Development möglich
7. ✅ Inkrementelle aber parallelisierte Migration

---

## 📂 Finale Struktur

```
lg-development/                      # Orchestrator (Git Repo)
├── Makefile                         # Main orchestration (schlank!)
├── .env                             # Global environment
├── .env.example
├── .gitignore
│
├── scripts/
│   ├── setup.sh                    # Interactive CLI setup
│   ├── help.sh                     # Help text
│   ├── status.sh                   # Service status
│   ├── wait-for-health.sh          # Wait for services
│   ├── clean.sh                    # Cleanup
│   └── lib/
│       ├── clone-repos.sh          # Clone from GitHub
│       ├── list-compose-files.sh   # Generate -f flags
│       ├── init-networks.sh        # Docker networks
│       └── common.sh               # Shared functions
│
├── infrastructure/                  # Infrastructure (Git Clones)
│   ├── lg-traefik/
│   │   ├── .git/
│   │   ├── docker-compose.yml
│   │   ├── traefik.yml
│   │   ├── dynamic.yml
│   │   └── README.md
│   │
│   ├── lg-postgres/
│   │   ├── .git/
│   │   ├── docker-compose.yml
│   │   ├── init.sql
│   │   └── README.md
│   │
│   ├── lg-redis/
│   │   ├── .git/
│   │   ├── docker-compose.yml
│   │   └── README.md
│   │
│   ├── lg-dynamodb/
│   │   ├── .git/
│   │   ├── docker-compose.yml
│   │   └── README.md
│   │
│   └── lg-verdaccio/
│       ├── .git/
│       ├── docker-compose.yml
│       ├── config.yaml
│       └── README.md
│
├── services/                        # Application Services (Git Clones)
│   ├── lg-user-service/
│   ├── lg-permissions-service/
│   ├── lg-api-keys-service/
│   ├── lg-tour-service/
│   ├── lg-menu-service/
│   ├── lg-secrets-service/
│   └── lg-admin/
│
└── packages/                        # Shared Libraries (Git Clones)
    ├── lg-admin-ui/
    ├── lg-menu-registry/
    ├── lg-backend-common/
    └── lg-types/
```

---

## 🎮 Makefile (Schlank & Wartbar)

```makefile
# Makefile

.PHONY: help setup start stop restart logs status build rebuild clean

# Load environment
include .env
export

# Generate compose file list dynamically
COMPOSE_FILES := $(shell ./scripts/lib/list-compose-files.sh)
COMPOSE := docker-compose $(COMPOSE_FILES)

# Default target
help:
	@./scripts/help.sh

# Setup
setup:
	@./scripts/setup.sh

# Development
start:
	@echo "🚀 Starting services..."
	@$(COMPOSE) up -d
	@./scripts/wait-for-health.sh

stop:
	@echo "🛑 Stopping services..."
	@$(COMPOSE) down

restart: stop start

# Logs
logs:
ifdef SERVICE
	@$(COMPOSE) logs -f $(SERVICE)
else
	@$(COMPOSE) logs -f
endif

# Status
status:
	@./scripts/status.sh

# Build
build:
ifdef SERVICE
	@$(COMPOSE) build $(SERVICE)
else
	@$(COMPOSE) build
endif

rebuild:
	@$(COMPOSE) build --no-cache
	@make restart

# Show final compose config (for debugging)
config:
	@$(COMPOSE) config

# Cleanup
clean:
	@./scripts/clean.sh

# Start single service (if possible)
start-%:
	@echo "🚀 Starting $*..."
	@./scripts/lib/start-service.sh $*
```

**Eigenschaften:**
- ✅ Schlank (< 60 Zeilen)
- ✅ Komplexe Logik delegiert an Scripts
- ✅ `make start-lg-user-service` für einzelne Services
- ✅ `make config` zeigt finales Compose (Debug)

---

## 🔧 Script: list-compose-files.sh

```bash
#!/bin/bash
# scripts/lib/list-compose-files.sh
#
# Generiert Liste von -f flags für docker-compose

set -e

COMPOSE_FILES=""

# Helper function
add_compose_file() {
    local file=$1
    if [ -f "$file" ]; then
        COMPOSE_FILES="$COMPOSE_FILES -f $file"
    fi
}

# Infrastructure (Reihenfolge wichtig!)
add_compose_file "infrastructure/lg-traefik/docker-compose.yml"
add_compose_file "infrastructure/lg-postgres/docker-compose.yml"
add_compose_file "infrastructure/lg-redis/docker-compose.yml"
add_compose_file "infrastructure/lg-dynamodb/docker-compose.yml"
add_compose_file "infrastructure/lg-verdaccio/docker-compose.yml"

# Services (alphabetisch)
for service_dir in services/*/; do
    add_compose_file "${service_dir}docker-compose.yml"
done

echo "$COMPOSE_FILES"
```

**Vorteil:**
- Automatische Discovery von Services
- Neue Services werden auto-detected
- Reihenfolge kontrollierbar (Infrastructure zuerst)

---

## 🎨 Script: setup.sh (Interactive CLI)

```bash
#!/bin/bash
# scripts/setup.sh
#
# Interactive setup wizard

set -e

source scripts/lib/common.sh

print_header "LG-Development Setup Wizard"

# Step 1: Check prerequisites
print_step "Checking prerequisites..."
command -v docker >/dev/null || die "Docker not installed"
command -v docker-compose >/dev/null || die "docker-compose not installed"
command -v gh >/dev/null || die "GitHub CLI not installed"
success "Prerequisites OK"

# Step 2: Environment configuration
print_step "Environment Configuration"

if [ -f .env ]; then
    echo "⚠️  .env already exists"
    read -p "Overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Using existing .env"
    else
        generate_env_file
    fi
else
    generate_env_file
fi

# Step 3: Select components to clone
print_step "Select Components"
echo ""
echo "Which components do you want to clone?"
echo ""

declare -A COMPONENTS=(
    ["Infrastructure"]="lg-traefik lg-postgres lg-redis lg-dynamodb lg-verdaccio"
    ["Services"]="lg-user-service lg-permissions-service lg-api-keys-service lg-tour-service lg-menu-service lg-secrets-service lg-admin"
    ["Packages"]="lg-admin-ui lg-menu-registry lg-backend-common lg-types"
)

SELECTED_REPOS=()

for category in "${!COMPONENTS[@]}"; do
    echo "━━━ $category ━━━"
    for repo in ${COMPONENTS[$category]}; do
        read -p "  Clone $repo? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            SELECTED_REPOS+=("$repo")
        fi
    done
    echo
done

# Step 4: Clone repositories
print_step "Cloning repositories..."
for repo in "${SELECTED_REPOS[@]}"; do
    clone_repo "$repo"
done

# Step 5: Setup Docker networks
print_step "Setting up Docker networks..."
./scripts/lib/init-networks.sh

# Step 6: Verify setup
print_step "Verifying setup..."
./scripts/lib/verify-setup.sh

# Done
print_header "✅ Setup Complete!"
echo ""
echo "Next steps:"
echo "  make start      # Start all services"
echo "  make status     # Check service status"
echo "  make logs       # View logs"
echo ""
```

**Features:**
- ✅ Interactive (mit Defaults)
- ✅ Generiert `.env` File
- ✅ Selektive Component-Auswahl
- ✅ Prerequisite Checks
- ✅ Verifizierung am Ende

---

## 🔧 Script: generate_env_file (in common.sh)

```bash
#!/bin/bash
# scripts/lib/common.sh

generate_env_file() {
    echo "Generating .env file..."
    echo ""

    # GitHub
    read -p "GitHub Username [WolfgangM81]: " GITHUB_USER
    GITHUB_USER=${GITHUB_USER:-WolfgangM81}

    # Database
    read -sp "Postgres Password [changeme]: " POSTGRES_PASSWORD
    echo
    POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-changeme}

    read -p "Database Name [licenseguard]: " POSTGRES_DB
    POSTGRES_DB=${POSTGRES_DB:-licenseguard}

    # Redis
    read -sp "Redis Password [changeme]: " REDIS_PASSWORD
    echo
    REDIS_PASSWORD=${REDIS_PASSWORD:-changeme}

    # JWT
    echo "Generating JWT Secret..."
    JWT_SECRET=$(openssl rand -base64 32)

    # Master Encryption Key
    echo "Generating Master Encryption Key..."
    MASTER_ENCRYPTION_KEY=$(openssl rand -base64 32)

    # Write .env
    cat > .env << EOF
# Generated by lg-development setup
# $(date)

# GitHub
GITHUB_USER=${GITHUB_USER}

# Database
POSTGRES_USER=licenseguard
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}
DATABASE_URL=postgres://licenseguard:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}

# Redis
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379

# Security
JWT_SECRET=${JWT_SECRET}
INTERNAL_API_KEY=$(openssl rand -hex 16)
MASTER_ENCRYPTION_KEY=${MASTER_ENCRYPTION_KEY}

# Environment
NODE_ENV=development
LOG_LEVEL=debug
EOF

    success ".env file created!"
}
```

---

## 📦 Repository Struktur: lg-postgres

```
lg-postgres/
├── .git/
├── .github/
│   └── workflows/
│       └── test.yml                # Test postgres init scripts
├── docker-compose.yml
├── init.sql                        # Database initialization
├── scripts/
│   ├── backup.sh
│   └── restore.sh
├── README.md
└── .env.example
```

### docker-compose.yml

```yaml
version: '3.8'

services:
  postgres:
    container_name: lg-infra-postgres
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-licenseguard}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-changeme}
      POSTGRES_DB: ${POSTGRES_DB:-licenseguard}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    networks:
      - lg-internal
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-licenseguard}"]
      interval: 10s
      timeout: 5s
      retries: 5

networks:
  lg-internal:
    external: true

volumes:
  postgres_data:
    driver: local
```

**Key Points:**
- ✅ Standalone lauffähig
- ✅ External network (wird vom Orchestrator erstellt)
- ✅ Healthcheck für depends_on
- ✅ Init script für Schema

---

## 📦 Repository Struktur: lg-user-service

```
lg-user-service/
├── .git/
├── .github/
│   └── workflows/
│       ├── test.yml
│       └── docker-publish.yml
├── docker-compose.yml
├── docker-compose.dev.yml          # Development overrides
├── Dockerfile
├── Dockerfile.dev
├── src/
├── tests/
├── package.json
├── README.md
└── .env.example
```

### docker-compose.yml (Production)

```yaml
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
      traefik:
        condition: service_started
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

networks:
  lg-public:
    external: true
  lg-internal:
    external: true
```

### docker-compose.dev.yml (Development Override)

```yaml
version: '3.8'

services:
  user-service:
    build:
      dockerfile: Dockerfile.dev
      target: development
    environment:
      NODE_ENV: development
      LOG_LEVEL: debug
    volumes:
      - ./src:/app/src:ro              # Hot reload
      - ./tests:/app/tests:ro
```

**Standalone Development:**

```bash
cd services/lg-user-service

# Mit Orchestrator Infrastructure
docker-compose up -d
# → Nutzt externe postgres, redis, traefik

# Mit Dev Overrides
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
# → Hot reload, debug logging
```

---

## 🔄 Makefile: Einzelservice starten

```makefile
# Pattern rule für einzelne Services
start-%:
	@./scripts/lib/start-service.sh $*
```

### Script: start-service.sh

```bash
#!/bin/bash
# scripts/lib/start-service.sh

SERVICE_NAME=$1

# Map service name to directory
case $SERVICE_NAME in
    lg-traefik)
        DIR="infrastructure/lg-traefik"
        ;;
    lg-user-service)
        DIR="services/lg-user-service"
        ;;
    *)
        # Auto-detect
        if [ -d "infrastructure/$SERVICE_NAME" ]; then
            DIR="infrastructure/$SERVICE_NAME"
        elif [ -d "services/$SERVICE_NAME" ]; then
            DIR="services/$SERVICE_NAME"
        else
            echo "❌ Service $SERVICE_NAME not found"
            exit 1
        fi
        ;;
esac

if [ ! -f "$DIR/docker-compose.yml" ]; then
    echo "❌ $DIR/docker-compose.yml not found"
    exit 1
fi

echo "🚀 Starting $SERVICE_NAME..."

# Check dependencies
DEPS=$(grep "depends_on:" "$DIR/docker-compose.yml" | sed 's/.*depends_on://;s/://g' | tr -d ' ')

if [ -n "$DEPS" ]; then
    echo "ℹ️  Service has dependencies: $DEPS"
    echo "Make sure they are running (make status)"
fi

# Start service
cd "$DIR"
docker-compose up -d
cd - > /dev/null

echo "✅ $SERVICE_NAME started"
```

**Usage:**
```bash
make start-lg-user-service
# → Startet nur user-service (erwartet postgres, redis laufen)
```

---

## 🔀 Migration Plan: Inkrementell & Parallelisiert

### Phase 1: Infrastructure (Parallel - 2-3h)

**Team-Mitglieder können parallel arbeiten:**

**Person A: Traefik**
```bash
# 1. Create repo
gh repo create WolfgangM81/lg-traefik --public

# 2. Extract & Commit
mkdir temp-lg-traefik
cd temp-lg-traefik
git init
# Copy traefik files
# Create docker-compose.yml
git add .
git commit -m "Initial: Extract from lg-development"
git remote add origin git@github.com:WolfgangM81/lg-traefik.git
git push -u origin main

# 3. Test standalone
docker network create lg-internal
docker network create lg-public
docker-compose up -d
curl http://localhost:8080  # Dashboard
```

**Person B: Databases** (parallel!)
```bash
# lg-postgres
gh repo create WolfgangM81/lg-postgres --public
# ... extract & test

# lg-redis
gh repo create WolfgangM81/lg-redis --public
# ... extract & test

# lg-dynamodb
gh repo create WolfgangM81/lg-dynamodb --public
# ... extract & test
```

**Person C: Verdaccio** (parallel!)
```bash
gh repo create WolfgangM81/lg-verdaccio --public
# ... extract & test
```

**Integration Test:**
```bash
# In lg-development
./scripts/lib/clone-repos.sh infrastructure
./scripts/lib/list-compose-files.sh
docker-compose $(./scripts/lib/list-compose-files.sh) up -d
# → Alle Infra-Services laufen
```

### Phase 2: Services Batch 1 (Parallel - 2h)

**3 Personen / 3 Services parallel:**
- lg-user-service
- lg-permissions-service
- lg-api-keys-service

**Pro Service:**
1. Create GitHub Repo
2. Extract Code + Create docker-compose.yml
3. Test standalone (mit Infrastructure aus Phase 1)
4. Commit & Push

### Phase 3: Services Batch 2 (Parallel - 2h)

- lg-tour-service
- lg-menu-service
- lg-secrets-service
- lg-admin

### Phase 4: Packages (Parallel - 1h)

- lg-admin-ui
- lg-menu-registry
- lg-backend-common
- lg-types

### Phase 5: Orchestrator Finalisierung (1h)

1. Alle Scripts schreiben
2. Makefile finalisieren
3. Setup wizard testen
4. Dokumentation

### Phase 6: Cleanup (30min)

1. Alte Struktur entfernen
2. CLAUDE.md updaten

**Total: 8-9h mit 3 Personen parallel = ~3h Wallclock-Time**

---

## 🎯 Entwickler Workflows

### Workflow 1: Full Stack Development

```bash
# Initial setup
git clone git@github.com:WolfgangM81/lg-development.git
cd lg-development
make setup
# → Interactive wizard, clones all repos

# Start everything
make start
# → All services up

# Develop
cd services/lg-user-service
vi src/routes/auth.ts
cd ../..
make restart SERVICE=user-service

# View logs
make logs SERVICE=user-service
```

### Workflow 2: Single Service Focus

```bash
# Clone orchestrator
git clone lg-development
cd lg-development

# Setup nur Infrastructure
./scripts/lib/clone-repos.sh infrastructure
./scripts/lib/init-networks.sh

# Start Infrastructure
make start-lg-traefik
make start-lg-postgres
make start-lg-redis

# Clone und entwickle EINEN Service
gh repo clone WolfgangM81/lg-user-service services/lg-user-service
cd services/lg-user-service

# Develop standalone
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up
# → Hot reload, nutzt zentrale infrastructure
```

### Workflow 3: Package Development

```bash
cd packages/lg-menu-registry

# Develop locally
npm install
npm run dev

# Test in service
cd ../../services/lg-user-service
npm link ../../packages/lg-menu-registry
npm run dev

# Publish to Verdaccio
cd ../../packages/lg-menu-registry
npm publish --registry http://localhost:4873
```

---

## ✅ Vorteile dieser Lösung

### 1. Industry Best Practice
- ✅ Multiple `-f` ist Docker Compose Standard
- ✅ External Networks ist etabliertes Pattern
- ✅ Makefile Orchestration ist common

### 2. Robust & Wartbar
- ✅ Kein fragiles YAML Parsing
- ✅ Native Docker Features
- ✅ `make config` für Debugging
- ✅ Scripts sind testbar

### 3. Developer Experience
- ✅ `make setup` - einfacher Einstieg
- ✅ `make start` - alles läuft
- ✅ `make logs SERVICE=x` - gezieltes Debugging
- ✅ Standalone Service Development möglich

### 4. Skalierbar
- ✅ Neue Services: Repo erstellen, fertig
- ✅ Auto-discovery via `list-compose-files.sh`
- ✅ Keine zentrale Datei pflegen

### 5. Flexibel
- ✅ Full Stack oder selective Components
- ✅ Production vs. Development Overrides
- ✅ Parallel Development möglich

---

## 📊 Aufwand vs. Nutzen

### Aufwand (einmalig)
- **Setup**: 8-9h (parallelisiert: ~3h Wallclock)
- **Testing**: 2h
- **Dokumentation**: 2h
- **Total**: ~12h (oder 5h mit 3 Personen)

### Laufende Kosten
- **Neue Services**: +30min (Repo erstellen, compose file)
- **Wartung**: Minimal (jeder Service unabhängig)
- **Onboarding**: Schneller (`make setup` statt manuelle Anleitung)

### Nutzen
- ✅ Klare Strukturen (Infrastructure vs. Services vs. Packages)
- ✅ Unabhängige Git Historie pro Service
- ✅ Separate CI/CD Pipelines
- ✅ Einfaches Setup für neue Entwickler
- ✅ Flexible Entwicklung (Full Stack oder einzeln)
- ✅ Bessere Wartbarkeit
- ✅ Zukunftssicher (einfach erweiterbar)

### Meine Meinung: ✅ **Aufwand ist gerechtfertigt!**

**Warum:**
1. **Einmalige Investition** mit langfristigem Nutzen
2. **Best Practices** statt Custom-Lösung
3. **Skalierbar** für weitere Services
4. **Developer Experience** deutlich besser
5. **Professioneller** für potenzielle Contributors

---

## 🚀 Nächste Schritte

1. **✅ Review dieses Plans** - Feedback einholen
2. **Entscheidungen finalisieren:**
   - lg-postgres + lg-redis + lg-dynamodb als separate Repos? ✓
   - Setup wizard mit .env generation? ✓
   - Makefile-basierte Orchestration? ✓

3. **Proof of Concept:**
   - lg-traefik als erstes Repo migrieren
   - Testen mit `docker-compose -f infrastructure/lg-traefik/docker-compose.yml up`
   - Makefile bauen und testen

4. **Parallel Migration:**
   - 3 Personen: Infrastructure, Services Batch 1, Services Batch 2
   - Wallclock-Time: 3-5h

5. **Finalisierung:**
   - Scripts polish
   - Dokumentation
   - CLAUDE.md update

---

## ❓ Offene Fragen zur Finalisierung

1. **Setup Wizard Scope:**
   - Soll er auch GitHub Token erfragen und gh auth durchführen?
   - Soll er Docker networks anlegen oder nur prüfen?
   - Soll er Traefik /etc/hosts Einträge vorschlagen?

2. **Service Dependencies:**
   - Wie handhaben wir if service X needs service Y?
   - Z.B. lg-tour-service braucht lg-user-service?
   - Auto-start dependencies? Oder nur Warning?

3. **DynamoDB:**
   - Welches Image? localstack? dynamodb-local?
   - Welche Tables pre-seed?
   - Benötigen wir init scripts?

4. **Package Publishing:**
   - Automatisches publish zu Verdaccio beim Build?
   - Oder manuell? (Empfehlung: manuell für Kontrolle)

5. **CI/CD:**
   - GitHub Actions in jedem Service-Repo?
   - Was sollen sie tun? (Test, Build, Publish zu Registry?)

---

**Status**: 📋 Ready for Implementation - Feedback erwünscht!
