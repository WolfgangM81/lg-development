# Docker Best Practices - LicenseGuard Platform

## Production Dockerfile Patterns

### Frontend (Vite + Nginx)

```dockerfile
# Stage 1: Builder
FROM node:20-bookworm-slim AS builder
WORKDIR /app

# Layer 1: Dependencies (cached wenn package.json unverändert)
COPY package*.json ./
RUN npm ci

# Layer 2: Build-Configs (cached wenn configs unverändert)
COPY tsconfig*.json vite.config.ts postcss.config.js tailwind.config.js index.html ./

# Layer 3: Source-Code (ändert sich häufig, aber vorherige Layer cached)
COPY src ./src
RUN npm run build

# Stage 2: Nginx Runtime
FROM nginx:alpine

# Security: Non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S -D -H -u 1001 -h /var/cache/nginx -s /sbin/nologin -G nodejs nodejs && \
    chown -R nodejs:nodejs /var/cache/nginx /var/run && \
    touch /var/run/nginx.pid && \
    chown nodejs:nodejs /var/run/nginx.pid && \
    mkdir -p /usr/share/nginx/html && \
    chown -R nodejs:nodejs /usr/share/nginx/html

# Copy build artifacts
COPY --from=builder --chown=nodejs:nodejs /app/dist /usr/share/nginx/html

# Copy nginx config
COPY --chown=nodejs:nodejs nginx.conf /etc/nginx/conf.d/default.conf

USER nodejs
EXPOSE 3000

# Healthcheck (use curl, not wget on Alpine)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -sf http://localhost:3000/ > /dev/null || exit 1

CMD ["nginx", "-g", "daemon off;"]
```

**Wichtige Punkte:**
- ✅ Multi-stage build (Builder + Runtime trennen)
- ✅ Layer Caching (package.json vor src/ kopieren)
- ✅ Non-root user (nodejs:1001)
- ✅ Healthcheck mit `curl` (nicht `wget` auf Alpine!)
- ✅ `.dockerignore` nutzen (-90% Build Context)

---

### Backend (Node.js Service)

```dockerfile
# Stage 1: Builder
FROM node:20-bookworm-slim AS builder
WORKDIR /app

# Dependencies
COPY package*.json ./
RUN npm ci

# Build TypeScript
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# Stage 2: Runtime
FROM node:20-bookworm-slim
WORKDIR /app

# Production dependencies only
COPY package*.json ./
RUN npm ci --omit=dev

# Copy compiled code
COPY --from=builder /app/dist ./dist

# Security: Use node user (default uid 1000)
USER node

EXPOSE 3002

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3002/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

CMD ["node", "dist/index.js"]
```

**Wichtige Punkte:**
- ✅ `--omit=dev` für kleinere Images
- ✅ `USER node` (Standard-User in node Image)
- ✅ Healthcheck mit node inline-script
- ✅ Kein unnecessary `apt-get` install

---

### Development Dockerfile

```dockerfile
FROM node:20-alpine
WORKDIR /app

# Dependencies installieren (nur bei package.json Änderung neu gebaut)
COPY package*.json tsconfig*.json vite.config.ts postcss.config.js tailwind.config.js index.html ./
RUN npm ci

# Shared dependencies Ordner vorbereiten (als Volume gemountet)
RUN mkdir -p /workspace/lg-admin-ui /workspace/lg-menu-registry

# Source wird als Volume gemountet (kein COPY)
EXPOSE 3000
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
```

**Wichtige Punkte:**
- ✅ Alpine für kleineres Image
- ✅ npm ci nur bei package.json Änderung
- ✅ Source als Volume (kein COPY → HMR funktioniert)
- ✅ `--host 0.0.0.0` für Docker Networking

---

### Frontend HMR (Vite - lg-admin)

**Tool:** Vite (React)
**Speed:** Instant (<100ms)
**Scope:** Frontend components, React code

**docker-compose.dev.yml Pattern:**

```yaml
services:
  admin:
    build:
      context: ./repos
      dockerfile: lg-admin/Dockerfile
      target: development  # Vite dev server
    volumes:
      - ./repos/lg-admin/src:/app/src:ro         # Source code
      - ./repos/lg-admin/index.html:/app/index.html:ro
      - ./repos/lg-admin/vite.config.ts:/app/vite.config.ts:ro
    environment:
      NODE_ENV: development
      VITE_HMR_HOST: localhost  # Important for Docker!
      VITE_HMR_PORT: 3000
    command: npm run dev  # Vite dev server with HMR
    ports:
      - "3000:3000"  # Expose for HMR WebSocket
```

**Dockerfile (Multi-Stage):**

```dockerfile
# Stage 1: Development (Vite HMR)
FROM node:20-alpine AS development
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]

# Stage 2: Production (Static Build)
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:alpine AS production
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

**vite.config.ts (wichtig für Docker HMR):**

```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',  // Listen on all interfaces (Docker)
    port: 3000,
    hmr: {
      host: 'localhost',  // Browser connects to localhost
      port: 3000,
    },
    watch: {
      usePolling: true,  // Für manche Docker Setups nötig
      interval: 1000,
    },
  },
})
```

**Troubleshooting Vite HMR:**

**Problem:** HMR verbindet nicht (Browser: "disconnected from server")

**Ursachen:**
1. Port nicht exposed: `ports: - "3000:3000"`
2. `hmr.host` falsch konfiguriert (sollte `localhost` sein)
3. Firewall blockiert WebSocket Connection

**Fix:**
```bash
# Check port is exposed
docker port lg-platform-admin-1

# Check logs for HMR errors
docker logs lg-platform-admin-1 | grep HMR

# Restart with build
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build admin
```

**Performance:**
- Vite HMR: <100ms (instant updates)
- Full Reload (wenn HMR fails): ~1-2s

---

### Unterschied: Frontend HMR vs Package Hot-Reload

| Feature | Frontend HMR (Vite) | Package Hot-Reload |
|---------|---------------------|---------------------|
| **Tool** | Vite Dev Server | TypeScript Compiler + Docker Volume |
| **Target** | React Components (lg-admin) | npm Packages (lg-menu-registry, etc.) |
| **Speed** | <100ms (instant) | 2-3s (compile + restart) |
| **Scope** | Single app | Multiple services |
| **Reload** | In-browser (no page refresh) | Service restart required |
| **Setup** | Standard Vite config | Custom builder containers |

**Zusammenfassung:**
- **Frontend HMR:** Für UI Development (lg-admin, lg-management)
- **Package Hot-Reload:** Für Shared Package Development (lg-menu-registry, lg-backend-common, lg-types)

Beide können **gleichzeitig aktiv** sein!

```bash
# Enable both:
docker-compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.dev-sync.yml up -d

# Result:
# - Frontend: Vite HMR (<100ms)
# - Packages: Builder compiles + Service restart (2-3s)
```

---

## Docker Compose Best Practices

### Volume Mounts (KRITISCH!)

**❌ FALSCH (nur src/ - fehlt package.json, tsconfig.json):**
```yaml
volumes:
  - ../lg-admin-ui/src:/workspace/lg-admin-ui/src
```

**✅ RICHTIG (komplettes Verzeichnis):**
```yaml
volumes:
  - ../lg-admin-ui:/workspace/lg-admin-ui
```

**Warum?** TypeScript braucht `package.json` + `tsconfig.json` für korrekte Compilation!

### Shared Libraries richtig mounten

```yaml
# docker-compose.dev.yml
services:
  admin-shell:
    volumes:
      # Own source
      - ../lg-admin-shell/src:/app/src
      - ../lg-admin-shell/vite.config.ts:/app/vite.config.ts
      - ../lg-admin-shell/tailwind.config.js:/app/tailwind.config.js

      # Shared libraries (komplette Verzeichnisse!)
      - ../lg-admin-ui:/workspace/lg-admin-ui
      - ../lg-menu-registry:/workspace/lg-menu-registry
```

**Config-Dateien auch mounten:**
- `vite.config.ts` - für HMR Config Änderungen
- `tailwind.config.js` - für CSS Regeneration
- `postcss.config.js` - falls Tailwind Plugins
- `index.html` - für HTML Änderungen

**Vorteil**: Änderungen in Configs werden automatisch übernommen, **kein** Container-Rebuild nötig!

---

## .dockerignore (KRITISCH!)

```
node_modules
dist
.git
.vscode
.env
*.log
coverage
test-results
playwright-report
README.md
*.test.ts
*.spec.ts
```

**Effekt**:
- ❌ Ohne: Build Context ~500 MB
- ✅ Mit: Build Context ~50 MB (-90%)

**Immer prüfen:**
```bash
docker build --no-cache lg-admin-shell 2>&1 | grep "Sending build context"
# Erwartung: ~50 MB
```

---

## Performance Optimierung

### Build-Zeiten minimieren

```bash
# Schnellste Methode: Nur Build im Container
docker exec lg-platform-admin-shell-1 npm run build  # ~2-3s

# Langsamer: Container restart
docker-compose restart admin-shell  # ~10-15s

# Langsamster: Rebuild from scratch
docker-compose up --build admin-shell  # ~60s+
```

### HMR maximieren

**Was braucht KEINEN Rebuild:**
- Code-Änderungen in `src/` → automatisch via HMR
- Config-Änderungen (vite, tailwind) → automatisch (wenn als Volume gemountet)

**Was braucht Container Restart:**
- `package.json` Änderungen (neue Dependencies)
- `Dockerfile.dev` Änderungen
- Environment Variables

**Was braucht Full Rebuild:**
- `Dockerfile` Änderungen (Production)
- Base Image Updates

### Layer Caching prüfen

```bash
docker build lg-admin-shell

# Output sollte zeigen:
# => [2/8] COPY package*.json ./                                    CACHED
# => [3/8] RUN npm ci                                               CACHED
# => [4/8] COPY tsconfig*.json vite.config.ts ...                   CACHED
# => [5/8] COPY src ./src                                           0.3s
```

Wenn "CACHED" fehlt → Dockerfile-Reihenfolge prüfen!

---

## Package Hot-Reload Architecture

**Status:** ✅ Fully Implemented (2026-01-24)

### Overview

Das Package Hot-Reload System ermöglicht **~2-3 Sekunden Updates** für shared npm Packages (`lg-menu-registry`, `lg-backend-common`, `lg-types`) ohne npm publish Cycle.

**Traditioneller Workflow:**
1. Package Code ändern
2. `npm run build` (30s)
3. `npm version patch` (5s)
4. `npm publish` (60s)
5. Service: `npm install @wolfgangm81/lg-menu-registry@latest` (30s)
6. Service restart (10s)
**Total: ~2-3 Minuten**

**Mit Hot-Reload:**
1. Package Code ändern
2. Auto-Compile (2-3s)
3. Auto-Restart (1-2s)
**Total: ~3-5 Sekunden** ⚡ (50x schneller!)

---

### Architecture: Builder Containers + Shared Volume

#### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  HOST: repos/lg-menu-registry/src/                         │
│  (Developer edits TypeScript files)                        │
└────────────────────┬────────────────────────────────────────┘
                     │ Volume Mount (Read-Only)
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  BUILDER CONTAINER: lg-builder-menu-registry               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ TypeScript Compiler (Watch Mode)                     │  │
│  │ tsc --watch                                          │  │
│  │ Detects changes → Compiles to .js + .d.ts          │  │
│  └──────────────┬───────────────────────────────────────┘  │
│                 │ Writes to                                 │
│                 ▼                                           │
│  /dist/menu-registry/   (.js + .d.ts files)              │
└────────────────────┬────────────────────────────────────────┘
                     │ Shared Docker Volume
                     │ lg-package-builds:/dist
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  SERVICE CONTAINERS: menu-service, user-service, etc.      │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ NODE_PATH=/shared-packages/node_modules             │  │
│  │ require('@wolfgangm81/lg-menu-registry')            │  │
│  │ → Loads from /shared-packages/node_modules/...      │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

### Docker Compose Configuration

**File:** `docker-compose.dev-sync.yml`

```yaml
volumes:
  lg-package-builds:
    # Shared volume for compiled packages

services:
  # Builder Container (one per package)
  lg-builder-menu-registry:
    build:
      context: ./repos
      dockerfile: lg-menu-registry/Dockerfile
      target: builder  # Multi-stage: builder stage
    volumes:
      - ./repos/lg-menu-registry:/app:ro  # Source code (Read-Only)
      - lg-package-builds:/dist           # Output (Write)
    command: npm run build:watch  # tsc --watch
    healthcheck:
      test: |
        test -f /dist/menu-registry/index.js &&
        test -f /dist/menu-registry/index.d.ts &&
        node -c /dist/menu-registry/index.js
      interval: 5s
      timeout: 3s
      retries: 3

  # Service Container (consuming package)
  menu-service:
    volumes:
      - lg-package-builds:/shared-packages:ro  # Read compiled packages
    environment:
      NODE_PATH: /shared-packages/node_modules:/app/node_modules
    # Service now loads packages from /shared-packages/node_modules
```

---

### How It Works

**Step 1: Developer edits package source**
```bash
vi repos/lg-menu-registry/src/index.ts
# Save file
```

**Step 2: Builder detects change**
```
lg-builder-menu-registry: File change detected: src/index.ts
lg-builder-menu-registry: Starting incremental compilation...
lg-builder-menu-registry: [2:14:23 PM] Found 0 errors. Watching for file changes.
```

**Step 3: Builder compiles to shared volume**
```
/dist/
└── menu-registry/
    ├── index.js        ← Compiled JavaScript
    ├── index.d.ts      ← TypeScript declarations
    └── package.json    ← Auto-generated package metadata
```

**Step 4: Health check validates build**
```bash
✅ index.js exists
✅ index.d.ts exists
✅ JavaScript syntax valid (node -c)
```

**Step 5: Watch script restarts affected services**
```bash
# Smart restart: Only menu-service (depends on menu-registry)
docker-compose restart menu-service
```

**Step 6: Service loads new package version**
```
menu-service: Loading @wolfgangm81/lg-menu-registry from /shared-packages/node_modules
menu-service: ✅ Package loaded successfully
```

**Total time:** ~2-3s (compile) + ~1-2s (restart) = **3-5s** ⚡

---

### Builder Container Pattern

**Multi-Stage Dockerfile:**

```dockerfile
# Stage 1: Builder (for hot-reload)
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
CMD ["npm", "run", "build:watch"]
# Outputs to /dist (mounted volume)

# Stage 2: Production (for deployment)
FROM node:20-alpine AS production
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY package*.json ./
RUN npm install --production
CMD ["npm", "start"]
```

**package.json scripts:**

```json
{
  "scripts": {
    "build": "tsc",
    "build:watch": "tsc --watch --preserveWatchOutput",
    "dev": "npm run build:watch"
  }
}
```

---

### Health Checks (Enhanced - Phase 1)

Builder health checks verify **3 critical conditions:**

1. ✅ **JavaScript file exists** (`index.js`)
2. ✅ **TypeScript declarations exist** (`index.d.ts`)
3. ✅ **JavaScript syntax valid** (`node -c index.js`)

**Why this matters:**
- Prevents broken packages from being loaded
- Detects compilation failures instantly
- Catches syntax errors before service restart

**Check health:**
```bash
make dev-sync-status
# Shows: Up (healthy) or Up (unhealthy)

make dev-sync-check
# Shows detailed error messages
```

---

### Smart Service Restarts (Phase 3)

**Dependency Mapping:** `scripts/dev/package-dependencies.json`

```json
{
  "menu-registry": ["menu-service"],
  "backend-common": ["user-service", "permissions-service", "api-keys-service",
                     "secrets-service", "tour-service"],
  "types": ["menu-service", "user-service", "permissions-service",
            "api-keys-service", "secrets-service", "tour-service"]
}
```

**Before optimization:**
- Edit ANY package → Restart ALL 6 services (~10s)

**After optimization:**
- Edit `menu-registry` → Restart **1** service (~2s) - **6x faster!**
- Edit `backend-common` → Restart **5** services (~6s)
- Edit `types` → Restart **6** services (~10s - all depend on it)

**Implementation:**
```bash
# Watch script automatically restarts only affected services
./scripts/dev/watch-packages.sh
# Uses jq to parse dependencies, fallback to restart all if jq missing
```

---

### Volume Performance

**Best Practices:**

```yaml
volumes:
  # Source code: Read-Only (prevents accidental writes from container)
  - ./repos/lg-menu-registry:/app:ro

  # Build output: Read-Write (builder writes, services read)
  - lg-package-builds:/dist

  # macOS: Use :cached for better performance
  - ./repos/lg-menu-registry:/app:ro,cached

  # Linux: Usually not needed (native performance)
```

**Avoid:**
- ❌ Mounting entire workspace (slow!)
- ❌ Read-Write for source code (security risk)
- ❌ Syncing node_modules (conflicts, huge size)

---

### Commands

```bash
# Enable hot-reload
make dev-sync

# Check status
make dev-sync-status

# View compilation logs
make dev-sync-logs PACKAGE=menu-registry

# Check for build errors
make dev-sync-check

# Live dashboard
make dev-sync-dashboard

# Performance metrics
make dev-sync-metrics

# Disable hot-reload
make dev-normal
```

---

### Troubleshooting

See detailed troubleshooting in:
- **[HOT_RELOAD_QUICK_REF.md](../HOT_RELOAD_QUICK_REF.md)** - Quick fixes
- **[GOTCHAS.md](./GOTCHAS.md#package-hot-reload-gotchas)** - Common pitfalls
- **[CLAUDE.md](../CLAUDE.md#package-hot-reload-system)** - Complete documentation

**Quick Checks:**

```bash
# Builders running?
docker-compose -f docker-compose.dev-sync.yml ps

# Volume contents?
docker run --rm -v lg-package-builds:/data alpine ls -la /data

# Service loading correct package?
docker-compose exec menu-service npm list @wolfgangm81/lg-menu-registry
```

---

### Performance Stats

| Metric | Traditional | Hot-Reload | Improvement |
|--------|-------------|------------|-------------|
| **Package update cycle** | 2-3 min | 3-5s | **50x faster** |
| **Build time** | 30s | 2-3s | **10x faster** |
| **Service restart (targeted)** | N/A | 1-2s | **6x fewer restarts** |
| **Developer feedback loop** | Minutes | Seconds | **Instant iteration** |

---

### See Also

- **[OPTIMIZATION_SUMMARY.md](../OPTIMIZATION_SUMMARY.md)** - All 5 optimization phases
- **[LOCAL_DEVELOPMENT.md](./LOCAL_DEVELOPMENT.md)** - Development workflow
- **[docker-compose.dev-sync.yml](../docker-compose.dev-sync.yml)** - Full configuration

---

## Nginx Configuration

### Frontend Routing (SPA)

```nginx
# Strip /admin/user prefix (Traefik routes /admin/user → user-admin:3000)
location ^~ /admin/user/ {
    alias /usr/share/nginx/html/;
    add_header Access-Control-Allow-Origin *;
    try_files $uri $uri/ /index.html;

    # Cache static assets with CORS
    location ~ \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        add_header Access-Control-Allow-Origin *;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Don't cache HTML
    location ~ \.html$ {
        expires -1;
        add_header Cache-Control "no-store, no-cache, must-revalidate";
    }
}

# SPA routing for root
location / {
    add_header Access-Control-Allow-Origin *;
    try_files $uri $uri/ /index.html;
}
```

**Wichtige Punkte:**
- `^~` Prefix Match hat höchste Priorität (wichtig!)
- `alias` ersetzt Prefix, `rewrite` nicht
- CORS Headers für Module Federation
- Cache-Control für Assets vs HTML

### Nginx Location Priority

1. **Exact match** (`=`)
2. **Prefix match with `^~`** (highest priority for prefixes)
3. **Regex match** (`~`, `~*`)
4. **Regular prefix match**

Beispiel:
```nginx
location = /admin { }           # Priority 1 (exact)
location ^~ /admin/ { }         # Priority 2 (prefix with ^~)
location ~* \.(js|css)$ { }    # Priority 3 (regex)
location /admin { }             # Priority 4 (regular prefix)
```

---

## Docker Networks

### Traefik Routing

```yaml
# docker-compose.yml
services:
  traefik:
    networks:
      - lg-internal

  admin-shell:
    networks:
      - lg-internal
```

**Wichtig:**
- Alle Services im gleichen Network (`lg-internal`)
- Services können sich mit Servicename ansprechen (`http://admin-shell:3000`)
- Traefik routet von außen: `localhost:81/admin/` → `admin-shell:3000/`

### E2E Tests mit Docker Network

```bash
# E2E Container im gleichen Network starten
docker run --rm --network lg-internal \
  -e PLAYWRIGHT_BASE_URL=http://traefik \
  lg-e2e-tests:latest npm test
```

**Nicht** `http://localhost:81` verwenden - das zeigt auf Container selbst!

---

## Healthchecks

### Best Practices

```dockerfile
# Frontend (Nginx)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -sf http://localhost:3000/ > /dev/null || exit 1

# Backend (Node.js)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3002/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"
```

**Wichtige Parameter:**
- `--interval`: Wie oft prüfen (30s)
- `--timeout`: Max Wartezeit (3s)
- `--start-period`: Grace Period nach Start (5-10s)
- `--retries`: Fehlversuche vor "unhealthy" (3)

**Häufige Fehler:**
- ❌ `wget` auf Alpine (nicht vorhanden) → `curl` verwenden
- ❌ Zu kurze start-period → Container wird zu früh als unhealthy markiert
- ❌ Keine Healthcheck → Docker weiß nicht ob Service läuft

---

## Troubleshooting

Für detaillierte Fehlerbehebung siehe **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)**:
- Docker Errors (Cannot find module, EADDRINUSE, Build Context, Layer Caching)
- Module Federation 404
- Tailwind CSS Issues
- Testing Problems
- Performance Debugging

### Quick Debug Commands

```bash
# Container Shell
docker-compose exec admin-shell sh

# Live Logs
docker-compose logs -f admin-shell

# Volume Mounts prüfen
docker-compose exec admin-shell ls -la /workspace/

# Network inspect
docker network inspect lg-internal
```

---

## Docker Compose Commands

```bash
# Stack starten
docker-compose up -d

# Stack stoppen
docker-compose down

# Einzelnen Service neu starten
docker-compose restart admin-shell

# Logs anzeigen
docker-compose logs -f admin-shell

# Container Status
docker-compose ps

# Rebuild + Start
docker-compose up --build -d

# Container Shell
docker-compose exec admin-shell sh
```
