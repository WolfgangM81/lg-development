# Docker Compose Multi-File Best Practices

## 🔍 Research: Best Practices für Multi-Compose Orchestration

### Option 1: Multiple -f Flags (Docker Native) ⭐ RECOMMENDED

**Ansatz:**
```bash
docker-compose \
  -f infrastructure/lg-traefik/docker-compose.yml \
  -f infrastructure/lg-postgres/docker-compose.yml \
  -f infrastructure/lg-redis/docker-compose.yml \
  -f services/lg-user-service/docker-compose.yml \
  up -d
```

**Vorteile:**
- ✅ Native Docker Compose Feature
- ✅ Kein Merging/Parsing nötig
- ✅ Files werden von Docker intelligent gemerged
- ✅ Later files override earlier ones
- ✅ Robust und wartbar
- ✅ Keine externe Dependencies (kein yq, jq, etc.)

**Nachteile:**
- ❌ Lange Command-Lines
- ❌ Makefile wird komplexer

**Docker Compose Merge-Regeln:**
1. Services werden gemerged (by name)
2. Später definierte Werte überschreiben frühere
3. Arrays werden concatenated (ports, volumes, etc.)
4. Networks/Volumes werden dedupliziert

### Option 2: Extends (Docker Compose Feature)

**Ansatz:**
```yaml
# services/lg-user-service/docker-compose.yml
services:
  user-service:
    extends:
      file: ../../infrastructure/lg-postgres/docker-compose.yml
      service: postgres
```

**Vorteile:**
- ✅ Explizite Dependencies
- ✅ Wiederverwendung von Definitionen

**Nachteile:**
- ❌ Komplexe Pfade
- ❌ Schwer zu durchschauen
- ❌ Deprecated in Compose v3 (wieder eingeführt in v3.4)

### Option 3: YAML Merge/Anchors

**Ansatz:**
```yaml
x-common-service: &common
  networks:
    - lg-internal
  restart: unless-stopped

services:
  user-service:
    <<: *common
    image: lg-user-service
```

**Vorteile:**
- ✅ Innerhalb einer Datei nützlich
- ✅ Native YAML Feature

**Nachteile:**
- ❌ Funktioniert nicht über Dateien hinweg
- ❌ Nicht geeignet für Multi-Repo

### Option 4: Generated File (Merging Script)

**Ansatz:**
```bash
# Script merged alle YAMLs zu einer
./scripts/merge-compose.sh > docker-compose.generated.yml
docker-compose -f docker-compose.generated.yml up -d
```

**Vorteile:**
- ✅ Eine finale Datei
- ✅ Einfacher docker-compose command

**Nachteile:**
- ❌ Fehleranfällig (YAML parsing)
- ❌ Extra Tooling (yq, jq)
- ❌ Debugging schwieriger
- ❌ Generated File muss ignoriert werden

## 🏆 Empfehlung: Hybrid Approach

**Kombination aus Option 1 (Multiple -f) + Makefile:**

```makefile
# Makefile

# Define all compose files in order
COMPOSE_FILES := \
	-f infrastructure/lg-traefik/docker-compose.yml \
	-f infrastructure/lg-postgres/docker-compose.yml \
	-f infrastructure/lg-redis/docker-compose.yml \
	-f infrastructure/lg-dynamodb/docker-compose.yml \
	-f infrastructure/lg-verdaccio/docker-compose.yml \
	-f services/lg-user-service/docker-compose.yml \
	-f services/lg-permissions-service/docker-compose.yml \
	-f services/lg-api-keys-service/docker-compose.yml \
	-f services/lg-tour-service/docker-compose.yml \
	-f services/lg-menu-service/docker-compose.yml \
	-f services/lg-secrets-service/docker-compose.yml \
	-f services/lg-admin/docker-compose.yml

# Use single variable for all commands
COMPOSE := docker-compose $(COMPOSE_FILES)

start:
	$(COMPOSE) up -d

stop:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f $(SERVICE)
```

**Warum dieser Ansatz?**
1. **Robust**: Native Docker Feature, keine Custom Parsing
2. **Wartbar**: Files in Liste, leicht erweiterbar
3. **Transparent**: Jeder sieht welche Files geladen werden
4. **Debuggable**: `$(COMPOSE) config` zeigt finales Compose File
5. **Flexibel**: Einzelne Files können temporär auskommentiert werden

## 📐 Structure Pattern: Base + Service Pattern

### Pattern 1: Self-Contained Services

**Jeder Service ist standalone lauffähig:**

```yaml
# services/lg-user-service/docker-compose.yml
services:
  user-service:
    image: lg-user-service:latest
    build: .
    environment:
      DATABASE_URL: ${DATABASE_URL}
    networks:
      - lg-internal
      - lg-public
    depends_on:
      postgres:
        condition: service_healthy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.user.rule=PathPrefix(`/api/user`)"
```

**Keine postgres Definition im Service!**
- Service erwartet dass `postgres` service existiert
- `depends_on: postgres` funktioniert wenn postgres in anderem compose file

### Pattern 2: External Networks

**Networks werden zentral erstellt:**

```bash
# Vor docker-compose up
docker network create lg-public
docker network create lg-internal
```

**Alle compose files nutzen external:**

```yaml
# In JEDEM compose file
networks:
  lg-public:
    external: true
  lg-internal:
    external: true
```

**Vorteil:**
- Services können standalone starten
- Keine Network-Konflikte
- Services finden sich automatisch (Docker DNS)

### Pattern 3: Shared Volumes

**Volumes zentral in infrastructure definiert:**

```yaml
# infrastructure/lg-postgres/docker-compose.yml
volumes:
  postgres_data:
    driver: local
```

**Services nutzen external:**

```yaml
# services/lg-backup-service/docker-compose.yml (hypothetisch)
volumes:
  postgres_data:
    external: true

services:
  backup:
    volumes:
      - postgres_data:/backup-source:ro
```

## 🎯 Recommended File Structure

### Infrastructure Services (Self-Contained)

```yaml
# infrastructure/lg-postgres/docker-compose.yml
version: '3.8'

services:
  postgres:
    container_name: lg-infra-postgres
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    networks:
      - lg-internal
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
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

### Application Services (Depends on Infrastructure)

```yaml
# services/lg-user-service/docker-compose.yml
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
      - "traefik.http.routers.user.rule=PathPrefix(`/api/user`)"
      - "traefik.http.routers.user.entrypoints=web"
      - "traefik.http.services.user.loadbalancer.server.port=3002"
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

**Key Points:**
- ✅ `depends_on: postgres` funktioniert über File-Grenzen
- ✅ Service ist lauffähig wenn infra gestartet ist
- ✅ Healthchecks garantieren Bereitschaft

## 🔧 Makefile Organization

### Clean Makefile mit Script Delegation

```makefile
# Makefile

.PHONY: help setup start stop restart logs status build clean

# Include environment variables
include .env
export

# Compose file list
COMPOSE_FILES := $(shell ./scripts/lib/list-compose-files.sh)
COMPOSE := docker-compose $(COMPOSE_FILES)

help:
	@./scripts/help.sh

setup:
	@./scripts/setup.sh

start:
	@echo "🚀 Starting services..."
	@$(COMPOSE) up -d
	@./scripts/wait-for-health.sh

stop:
	@echo "🛑 Stopping services..."
	@$(COMPOSE) down

restart: stop start

logs:
ifdef SERVICE
	@$(COMPOSE) logs -f $(SERVICE)
else
	@$(COMPOSE) logs -f
endif

status:
	@./scripts/status.sh $(COMPOSE_FILES)

build:
	@$(COMPOSE) build $(SERVICE)

clean:
	@./scripts/clean.sh
```

**Vorteile:**
- Makefile bleibt schlank
- Komplexe Logik in Scripts
- Scripts sind testbar
- Bessere Fehlerbehandlung in Scripts

## 🚀 Standalone Service Development

### Pattern: Dev Override Files

```yaml
# services/lg-user-service/docker-compose.yml (Production)
services:
  user-service:
    depends_on:
      postgres:
        condition: service_healthy
```

```yaml
# services/lg-user-service/docker-compose.dev.yml (Development)
services:
  user-service:
    build:
      context: .
      dockerfile: Dockerfile.dev
      target: development
    volumes:
      - ./src:/app/src:ro  # Hot reload
    environment:
      NODE_ENV: development
      LOG_LEVEL: debug

  # Optional: Lokale Postgres für isolated development
  postgres-dev:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev
      POSTGRES_DB: dev
    ports:
      - "5433:5432"
```

**Entwickler startet standalone:**

```bash
cd services/lg-user-service

# Option 1: Mit echter Infrastruktur (aus Orchestrator)
docker-compose up -d
# → Nutzt lg-internal network, findet shared postgres

# Option 2: Komplett isolated mit dev DB
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
# → Startet eigene postgres-dev
```

## 📊 Comparison Table

| Ansatz | Robustheit | Wartbarkeit | Komplexität | Empfehlung |
|--------|------------|-------------|-------------|------------|
| **Multiple -f** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ✅ **Best** |
| **Extends** | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ | ❌ Zu komplex |
| **Generated File** | ⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ❌ Fehleranfällig |
| **YAML Anchors** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⚠️ Nur innerhalb File |

## 🎯 Final Recommendation

**Use: Multiple `-f` Flags + Makefile + External Networks**

1. **Infrastructure** definiert Base Services (Postgres, Redis, Traefik)
2. **Services** definieren App Services + depends_on
3. **Networks** sind external (vorher mit `docker network create`)
4. **Makefile** orchestriert mit Liste von compose files
5. **Scripts** handhaben komplexe Logik (setup, health checks)

**This is industry standard for multi-service orchestration!**

Examples:
- Gitlab development environment
- HashiCorp development setups
- Many enterprise Docker Compose stacks
