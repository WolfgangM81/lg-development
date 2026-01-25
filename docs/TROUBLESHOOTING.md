# Troubleshooting Guide - LicenseGuard Platform

Konsolidierte Fehlerbehebung für Docker, Testing, Module Federation und Development.

---

## Docker Issues

### "Cannot find module" in Container

**Symptome**: Module aus shared libraries werden nicht gefunden
**Ursache**: Volume Mount fehlt oder falsch konfiguriert

**Fix:**
```bash
# 1. Volume Mounts prüfen
docker-compose exec admin-shell ls -la /workspace/

# 2. Symlinks prüfen
docker-compose exec admin-shell ls -la /app/node_modules/@apikeys/

# 3. Container neu bauen
docker-compose down && docker-compose up --build
```

---

### "Error: listen EADDRINUSE"

**Symptome**: Service kann nicht starten, Port bereits belegt
**Ursache**: Alter Container läuft noch

**Fix:**
```bash
# 1. Port-Nutzung prüfen
lsof -i :3000

# 2. Alle Container stoppen
docker-compose down

# 3. Falls nötig: Alle Docker-Container stoppen
docker stop $(docker ps -q)
```

---

### Build Context zu groß (>100MB)

**Symptome**: `docker build` dauert >60s, zeigt "Sending build context 500MB+"
**Ursache**: `.dockerignore` fehlt

**Fix:**
```bash
# 1. Prüfen
docker build --no-cache lg-admin-shell 2>&1 | grep "Sending build context"
# Erwartung: ~50MB, nicht ~500MB

# 2. .dockerignore erstellen
cat > .dockerignore <<EOF
node_modules
dist
.git
.vscode
coverage
EOF
```

---

### Layer Caching funktioniert nicht

**Symptome**: `npm ci` wird bei jedem Build ausgeführt (nicht CACHED)
**Ursache**: Falsche Dockerfile-Reihenfolge

**Fix:**
```dockerfile
# ❌ FALSCH: Source vor Dependencies
COPY . .
RUN npm ci

# ✅ RICHTIG: Dependencies zuerst (cached)
COPY package*.json ./
RUN npm ci
COPY . .
```

---

### HMR funktioniert nicht

**Symptome**: Code-Änderungen werden nicht automatisch übernommen
**Ursache**: Dev Stack läuft nicht oder Volumes falsch

**Diagnose:**
```bash
docker-compose ps                       # Services running?
docker-compose exec admin-shell ls /app/src  # Source mounted?
docker-compose logs -f admin-shell      # Errors?
```

**Fix:**
1. Prüfe `docker-compose.dev.yml` Volumes
2. Config-Dateien (vite.config.ts, tailwind.config.js) als Volumes?
3. `docker-compose restart admin-shell`

---

## Module Federation Issues

### 404: remoteEntry.js not found

**Symptome**: Browser zeigt 404 für `/admin/user/assets/remoteEntry.js`
**Ursache**: Dev/Prod Pfad-Unterschied in vite.config.ts

**Fix:**
```typescript
// vite.config.ts muss Dev/Prod unterscheiden
remotes: isProd
  ? { userAdmin: 'http://localhost:81/admin/user/assets/remoteEntry.js' }
  : { userAdmin: 'http://localhost:81/admin/user/remoteEntry.js' };
```

**Prüfen:**
```bash
# Production (mit /assets/)
curl http://localhost:81/admin/user/assets/remoteEntry.js

# Development (ohne /assets/)
curl http://localhost:81/admin/user/remoteEntry.js
```

---

### Dynamic Remotes nicht geladen (E2E)

**Symptome**: E2E Tests schlagen fehl mit "Failed to fetch dynamically imported module"
**Ursache**: `__REMOTE_BASE_URL__` nicht injected

**Fix:**
```typescript
// tests/helpers/auth.ts - VOR page.goto() aufrufen!
await page.addInitScript(() => {
  const baseURL = new URL(window.location.href);
  (window as any).__REMOTE_BASE_URL__ = `${baseURL.protocol}//${baseURL.host}`;
});
```

---

### Shared Dependencies Konflikt

**Symptome**: React-Fehler, "Cannot read properties of null"
**Ursache**: `@tanstack/react-query` nicht in shared array

**Fix:**
```typescript
// ALLE Module müssen identische shared haben
shared: ['react', 'react-dom', 'react-router-dom', '@tanstack/react-query', 'lucide-react']
```

**Prüfen:**
```bash
# In package.json: react-query muss in dependencies sein
grep "react-query" lg-admin-shell/package.json
```

---

## Tailwind CSS Issues

### Klassen werden nicht generiert

**Symptome**:
- `lg:hidden` funktioniert nicht, Burger-Menü auf Desktop sichtbar
- CSS Bundle abnormal klein (~31KB statt ~38KB)
- Responsive Breakpoints fehlen

**Ursache**: `tailwind.config.js` scannt shared libraries nicht

**Diagnose:**
```bash
# 1. CSS Bundle Größe prüfen
ls -lh lg-admin-shell/dist/assets/*.css
# Sollte ~38KB sein

# 2. Responsive classes prüfen
grep "@media (min-width: 1024px)" dist/assets/*.css
```

**Fix:**
```javascript
// tailwind.config.js MUSS beide Pfade enthalten
module.exports = {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
    "/workspace/lg-admin-ui/src/**/*.{js,ts,jsx,tsx}",  // Docker
    "../lg-admin-ui/src/**/*.{js,ts,jsx,tsx}",          // Lokal
  ],
};
```

**Nach Fix:**
```bash
docker exec lg-platform-admin-shell-1 npm run build
# Browser: Hard Reload (Cmd+Shift+R)
```

---

## Testing Issues

### Vitest: "React is not defined"

**Symptome**: Tests schlagen fehl mit `ReferenceError: React is not defined`
**Ursache**: Component nutzt JSX ohne expliziten React Import

**Fix:**
```typescript
// ❌ FALSCH
import { useState } from 'react';

// ✅ RICHTIG
import React, { useState } from 'react';
```

---

### Vitest: Test Timeout mit Fake Timers

**Symptome**: Test timeout nach 5000ms bei Timer-Tests
**Ursache**: `await waitFor()` mit `vi.useFakeTimers()` inkompatibel

**Fix:**
```typescript
// ❌ FALSCH
it('test', async () => {
  vi.useFakeTimers();
  vi.advanceTimersByTime(4000);
  await waitFor(() => expect(...));
});

// ✅ RICHTIG (ohne async/await)
it('test', () => {
  vi.useFakeTimers();
  vi.advanceTimersByTime(4000);
  expect(...);
});
```

---

### Playwright: Network request failed

**Symptome**: E2E Test kann Services nicht erreichen
**Ursache**: Base URL falsch oder Service nicht im Network

**Diagnose:**
```bash
# 1. Services erreichbar?
docker network inspect lg-internal

# 2. Base URL korrekt?
echo $PLAYWRIGHT_BASE_URL  # Sollte http://traefik sein
```

**Fix:**
```bash
# ❌ FALSCH: localhost zeigt auf E2E Container selbst
PLAYWRIGHT_BASE_URL=http://localhost:81

# ✅ RICHTIG: traefik service name im Docker Network
PLAYWRIGHT_BASE_URL=http://traefik
```

---

### "Cannot find module @apikeys/admin-ui" (Tests)

**Symptome**: Vitest kann shared libraries nicht finden
**Ursache**: Alias nicht in vitest.config.ts

**Fix:**
```typescript
// vitest.config.ts
export default defineConfig({
  resolve: {
    alias: {
      '@apikeys/admin-ui': '/workspace/lg-admin-ui/src',
      '@apikeys/menu-registry': '/workspace/lg-menu-registry/src',
    },
  },
});
```

---

## NPM/Dependencies Issues

### "npm ERR! code ENOENT" nach Docker Build

**Symptome**: Production Build schlägt fehl, package-lock.json fehlt
**Ursache**: npm install auf Host ausgeführt (ARM64), Container braucht AMD64

**Prevention:**
```bash
# NPM Safety Guard aktivieren
source ~/Projects/.project.zshrc

# Effekt: npm auf Host wird blockiert
```

**Fix:**
```bash
# 1. Host node_modules löschen
rm -rf node_modules package-lock.json

# 2. Dependencies im Docker neu installieren
./dev.sh npm-in lg-admin-shell install
```

---

## Database Issues

### Migration schlägt fehl

**Symptome**: `psql: ERROR: relation "..." does not exist`
**Ursache**: Migrations nicht in korrekter Reihenfolge

**Diagnose:**
```bash
# Welche Migrations wurden angewandt?
docker exec lg-platform-postgres-1 psql -U admin licenseguard -c \
  "SELECT version, name FROM migrations ORDER BY version;"
```

**Fix:**
```bash
# 1. Backup erstellen
docker exec lg-platform-postgres-1 pg_dump -U admin licenseguard > backup.sql

# 2. Migration erneut ausführen
docker exec lg-platform-postgres-1 psql -U admin licenseguard -f /docker-entrypoint-initdb.d/migrations/00X_name.sql
```

---

## Performance Issues

### Frontend Build dauert >60s

**Symptome**: `vite build` sehr langsam
**Ursache**: Zu viele Dateien im Build Context

**Fix:**
1. `.dockerignore` vollständig? (node_modules, dist, coverage)
2. Layer Caching aktiv? (package.json vor src kopieren)
3. Dependencies clean? (`rm -rf node_modules && npm ci`)

---

### E2E Tests laufen > 5 Minuten

**Symptome**: Playwright Tests sehr langsam
**Ursache**: Workers nicht optimal konfiguriert

**Fix:**
```bash
# Mehr Workers (Standard: 3)
WORKERS=6 ./run-tests.sh

# Debugging: Sequentiell (1 Worker)
./run-tests.sh --workers=1

# Spezifischen Test isolieren
./run-tests.sh tests/auth/login.spec.ts
```

---

## Quick Reference: Häufigste Probleme

| Problem | Schnell-Check | Fix |
|---------|---------------|-----|
| **npm auf Host** | `which npm` zeigt `/usr/local/bin` | `source ~/Projects/.project.zshrc` |
| **Tailwind fehlt** | CSS < 35KB | tailwind.config.js Pfade prüfen |
| **Module 404** | curl remoteEntry.js | vite.config.ts Dev/Prod Pfade |
| **HMR tot** | Code-Änderung ignoriert | docker-compose restart |
| **React undefined** | Test fail "React is not defined" | `import React` hinzufügen |
| **Port EADDRINUSE** | Service startet nicht | `docker-compose down` |

---

## Debug Commands

### Docker
```bash
# Container Shell
docker-compose exec admin-shell sh

# Logs (live)
docker-compose logs -f admin-shell

# Network inspect
docker network inspect lg-internal

# Volume Mounts prüfen
docker-compose exec admin-shell ls -la /workspace/
```

### Testing
```bash
# Vitest verbose
docker run --rm -v $(pwd):/app -w /app node:20-alpine npm test -- --reporter=verbose

# Playwright debug
./run-tests.sh --headed --workers=1

# E2E Screenshots
open test-results/*/test-failed-*.png
```

### Performance
```bash
# Build Context Size
docker build --no-cache . 2>&1 | grep "Sending build context"

# Bundle Size
ls -lh dist/assets/*.{js,css}

# Layer Caching
docker build . | grep CACHED
```

---

## Weiterführende Dokumentation

- **[DOCKER.md](./DOCKER.md)** - Docker Best Practices, Dockerfile Patterns
- **[TESTING.md](./TESTING.md)** - Test Setup, Coverage, E2E Tests
- **[CLAUDE.md](./CLAUDE.md)** - Projekt-Konfiguration, Workflows

---

## 🐛 Hot-Reload Debugging Checklist

Systematische Fehlersuche für Package Hot-Reload Probleme.

---

### Level 1: Quick Checks (30 seconds)

**Run these first:**

```bash
# 1. Builders running?
make dev-sync-status
# Expected: All builders "Up (healthy)"

# 2. Any build errors?
make dev-sync-check
# Expected: ✅ for all packages

# 3. Recent logs (last 20 lines)
make dev-sync-logs PACKAGE=menu-registry
# Expected: "Watching for file changes" or "Found 0 errors"
```

**If all green → Problem is NOT with hot-reload system!**

---

### Level 2: Service-Specific Checks (1 minute)

**If a specific service isn't loading new packages:**

```bash
# 1. Which package version is service using?
docker-compose exec menu-service npm list @wolfgangm81/lg-menu-registry
# Expected: Symlink to /shared-packages/node_modules/...

# 2. Is volume mounted correctly?
docker inspect menu-service | grep -A 10 Mounts | grep lg-package-builds
# Expected: lg-package-builds:/shared-packages (read-only)

# 3. Is NODE_PATH set correctly?
docker-compose exec menu-service printenv NODE_PATH
# Expected: /shared-packages/node_modules:/app/node_modules

# 4. Restart service manually
docker-compose restart menu-service
```

---

### Level 3: Volume Checks (2 minutes)

**If builds succeed but services don't see changes:**

```bash
# 1. Volume contents exist?
docker run --rm -v lg-package-builds:/data alpine ls -la /data
# Expected: menu-registry/, backend-common/, types/ directories

# 2. Compiled files exist?
docker run --rm -v lg-package-builds:/data alpine ls -la /data/menu-registry
# Expected: index.js, index.d.ts, package.json

# 3. File permissions OK?
docker run --rm -v lg-package-builds:/data alpine stat /data/menu-registry/index.js
# Expected: Access: (0644/-rw-r--r--)

# 4. File contents look correct?
docker run --rm -v lg-package-builds:/data alpine head -20 /data/menu-registry/index.js
# Expected: Valid JavaScript code
```

---

### Level 4: Builder Checks (3 minutes)

**If health checks fail:**

```bash
# 1. Builder logs (full)
docker-compose -f docker-compose.dev-sync.yml logs lg-builder-menu-registry | tail -100

# 2. Builder process running?
docker-compose -f docker-compose.dev-sync.yml exec lg-builder-menu-registry ps aux
# Expected: npm run build:watch or tsc --watch

# 3. Health check command manually
docker-compose -f docker-compose.dev-sync.yml exec lg-builder-menu-registry sh -c '
  test -f /dist/menu-registry/index.js &&
  test -f /dist/menu-registry/index.d.ts &&
  node -c /dist/menu-registry/index.js &&
  echo "✅ Health check passed"
'

# 4. Rebuild builder from scratch
docker-compose -f docker-compose.dev-sync.yml stop lg-builder-menu-registry
docker-compose -f docker-compose.dev-sync.yml rm -f lg-builder-menu-registry
docker-compose -f docker-compose.dev-sync.yml up -d --build lg-builder-menu-registry
```

---

### Level 5: Source Code Checks (2 minutes)

**If watch isn't detecting changes:**

```bash
# 1. Source files mounted correctly?
docker-compose -f docker-compose.dev-sync.yml exec lg-builder-menu-registry ls -la /app/src
# Expected: TypeScript source files

# 2. Test file write (from host)
echo "// test" >> repos/lg-menu-registry/src/index.ts
# Check builder logs for activity:
make dev-sync-logs PACKAGE=menu-registry
# Expected: "File change detected" within 1-2 seconds

# 3. Revert test change
git checkout repos/lg-menu-registry/src/index.ts

# 4. Check .dockerignore (shouldn't ignore src/)
cat repos/lg-menu-registry/.dockerignore | grep src
# Expected: src/ NOT in ignore list
```

---

### Level 6: Configuration Checks (3 minutes)

**If setup seems broken:**

```bash
# 1. docker-compose.dev-sync.yml valid?
docker-compose -f docker-compose.dev-sync.yml config | grep -A 20 lg-builder-menu-registry
# Expected: Valid YAML, no errors

# 2. package.json has build:watch script?
cat repos/lg-menu-registry/package.json | jq '.scripts["build:watch"]'
# Expected: "tsc --watch" or similar

# 3. tsconfig.json valid?
cd repos/lg-menu-registry && npx tsc --showConfig
# Expected: Valid config, no errors

# 4. Dependency mapping exists?
cat scripts/dev/package-dependencies.json | jq '.["menu-registry"]'
# Expected: ["menu-service"]
```

---

### Level 7: Network & Communication (2 minutes)

**If services can't communicate:**

```bash
# 1. Services on same network?
docker network inspect lg-development_default | jq '.[0].Containers'
# Expected: All services + builders listed

# 2. Service can reach builder volume?
docker-compose exec menu-service ls -la /shared-packages/node_modules/@wolfgangm81
# Expected: Symlinks to package directories

# 3. Test package import in service
docker-compose exec menu-service node -e "
  const pkg = require('@wolfgangm81/lg-menu-registry');
  console.log('✅ Package loaded:', Object.keys(pkg));
"
# Expected: Package exports listed
```

---

### Level 8: Clean Slate (5 minutes)

**Nuclear option: Rebuild everything**

```bash
# 1. Stop all
docker-compose down
docker-compose -f docker-compose.dev-sync.yml down

# 2. Remove volume
docker volume rm lg-package-builds

# 3. Remove builder images
docker rmi lg-development-lg-builder-menu-registry
docker rmi lg-development-lg-builder-backend-common
docker rmi lg-development-lg-builder-types

# 4. Clean build artifacts
rm -rf repos/lg-menu-registry/dist
rm -rf repos/lg-backend-common/dist
rm -rf repos/lg-types/dist

# 5. Rebuild from scratch
make dev-sync
# Wait for all builders healthy (~30s)

# 6. Verify
make dev-sync-check
make dev-sync-dashboard
```

---

### Common Error Messages & Solutions

#### "health check failed"

**Error:**
```
lg-builder-menu-registry health_status=unhealthy
```

**Debug:**
```bash
make dev-sync-logs PACKAGE=menu-registry
# Look for TypeScript errors, missing files
```

**Fix:**
1. Fix TypeScript errors in source
2. If no errors, rebuild: `make dev-sync-rebuild`

---

#### "EACCES: permission denied"

**Error:**
```
Error: EACCES: permission denied, open '/dist/menu-registry/index.js'
```

**Debug:**
```bash
# Check volume ownership
docker run --rm -v lg-package-builds:/data alpine ls -la /data
```

**Fix:**
```bash
# Fix permissions (Linux)
docker run --rm -v lg-package-builds:/data alpine chown -R 1000:1000 /data
make dev-sync-rebuild
```

---

#### "Cannot find module '@wolfgangm81/lg-menu-registry'"

**Error:**
```
Error: Cannot find module '@wolfgangm81/lg-menu-registry'
```

**Debug:**
```bash
# Check NODE_PATH
docker-compose exec menu-service printenv NODE_PATH

# Check volume mount
docker inspect menu-service | grep lg-package-builds

# Check package exists
docker run --rm -v lg-package-builds:/data alpine ls /data/menu-registry
```

**Fix:**
```bash
# Ensure NODE_PATH includes /shared-packages/node_modules
# Check docker-compose.dev-sync.yml:
#   environment:
#     NODE_PATH: /shared-packages/node_modules:/app/node_modules

# Restart service
docker-compose restart menu-service
```

---

#### "File change detected" but no rebuild

**Error:**
```
File change detected: src/index.ts
(nothing happens after this)
```

**Debug:**
```bash
# Builder process crashed?
docker-compose -f docker-compose.dev-sync.yml exec lg-builder-menu-registry ps aux
```

**Fix:**
```bash
# Restart builder
make dev-sync-rebuild
```

---

### Debugging Tools Summary

| Tool | Command | Use Case |
|------|---------|----------|
| **Status** | `make dev-sync-status` | Quick health check |
| **Errors** | `make dev-sync-check` | Detailed build errors |
| **Logs** | `make dev-sync-logs PACKAGE=name` | Full compilation logs |
| **Dashboard** | `make dev-sync-dashboard` | Real-time monitoring |
| **Metrics** | `make dev-sync-metrics` | Performance trends |
| **Volume** | `docker volume inspect lg-package-builds` | Volume details |
| **Inspect** | `docker inspect <container>` | Container config |
| **Config** | `docker-compose config` | Merged compose config |

---

### When to Ask for Help

If after Level 8 (Clean Slate) it still doesn't work:

1. **Gather debug info:**
   ```bash
   # Create debug report
   {
     echo "=== Status ==="
     make dev-sync-status
     echo ""
     echo "=== Check ==="
     make dev-sync-check
     echo ""
     echo "=== Builder Logs (last 50 lines) ==="
     make dev-sync-logs PACKAGE=menu-registry | tail -50
     echo ""
     echo "=== Service Logs (last 50 lines) ==="
     docker-compose logs --tail=50 menu-service
     echo ""
     echo "=== Volume Contents ==="
     docker run --rm -v lg-package-builds:/data alpine ls -laR /data
   } > hot-reload-debug.txt
   ```

2. **Share debug report** in issue or chat

3. **Check documentation:**
   - [GOTCHAS.md#package-hot-reload-gotchas](./GOTCHAS.md#package-hot-reload-gotchas)
   - [HOT_RELOAD_QUICK_REF.md](../HOT_RELOAD_QUICK_REF.md)
   - [CLAUDE.md#package-hot-reload-system](../CLAUDE.md#package-hot-reload-system)

---

### See Also

- **[GOTCHAS.md](./GOTCHAS.md)** - Common pitfalls
- **[HOT_RELOAD_QUICK_REF.md](../HOT_RELOAD_QUICK_REF.md)** - Quick reference
- **[DOCKER.md#package-hot-reload-architecture](./DOCKER.md#package-hot-reload-architecture)** - Architecture details
