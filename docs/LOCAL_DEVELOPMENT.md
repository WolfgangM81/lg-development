# Local Package Development

Dieses Guide erklärt wie du Packages lokal entwickeln und testen kannst OHNE sie zu GitHub zu pushen.

**Zwei Methoden verfügbar:**
1. **🔥 Hot-Reload System (Empfohlen)** - Änderungen in ~2-3 Sekunden
2. **📦 Verdaccio Registry** - Traditioneller Ansatz mit npm publish/install

---

## 🔥 Hot-Reload System (Empfohlen)

**Optimale Developer Experience** mit instant package updates!

### Vorteile
- ⚡ **Super schnell**: 2-3 Sekunden statt 30-60 Sekunden
- 🔄 **Automatisch**: Kein manuelles publish/install
- 🎯 **Einfach**: Ein Befehl zum Enable/Disable
- 🐳 **Docker-nativ**: Funktioniert perfekt in Containern
- 🚀 **Produktiv**: 10-20x schneller als Verdaccio

### Quick Start

```bash
# 1. Enable hot-reload
make dev-sync

# 2. Edit any package (lg-menu-registry, lg-backend-common, lg-types)
vim repos/lg-menu-registry/src/index.ts

# 3. Changes appear in ~2-3 seconds automatically! ⚡
# Kein manuelles publish/install nötig!
```

### Wie es funktioniert

```
Developer editiert Package → TypeScript Watch Compiler (~1-2s) →
  → Shared Docker Volume → NODE_PATH Resolution →
    → Consumer Service Auto-Reload (~0.5s) → Browser sieht Änderung! ✨
```

**Architektur:**
- Builder containers kompilieren TypeScript on-the-fly (`tsc --watch`)
- Shared Docker volume (`lg-packages-dist`) für compiled .js files
- Consumer services nutzen `NODE_PATH=/workspace/packages` Resolution
- `tsx watch` sieht Änderungen und restartet automatisch

### Verfügbare Befehle

```bash
# Enable/Disable
make dev-sync                      # Hot-reload aktivieren
make dev-normal                    # Hot-reload deaktivieren
make dev-toggle                    # Toggle current mode

# Status & Debugging
make dev-sync-status               # Builder status anzeigen
make dev-sync-logs PACKAGE=menu-registry   # Compilation logs ansehen
make dev-sync-rebuild              # Alle Builder neu starten
make dev-sync-clean                # Build artifacts löschen
make dev-sync-watch                # Auto-restart services on package changes
```

### Development Workflow

```bash
# 1. Enable hot-reload
make dev-sync

# 2. Edit package source
cd repos/lg-menu-registry
vim src/api.ts
# → Builder kompiliert automatisch (~1-2s)

# 3. Check compilation logs (optional)
make dev-sync-logs PACKAGE=menu-registry
# → [tsc] File change detected. Starting incremental compilation...
# → [tsc] Found 0 errors. Watching for file changes.

# 4. Consumer service sieht Änderung
docker logs -f lg-backend-menu
# → [tsx] File change detected. Restarting...
# → Server started on port 3005

# 5. Test in browser
curl http://api.lg.local/menu/health
# → {"status": "healthy"}

# Fertig! 🎉
```

### 🔄 Auto-Restart Services (Fortgeschritten)

**Problem:** Consumer services mit `tsx watch` reloaden manchmal nicht automatisch.

**Lösung:** Watchdog-Script überwacht Package-Änderungen und restartet Services:

```bash
# Terminal 1: Hot-reload aktivieren
make dev-sync

# Terminal 2: Watchdog starten (überwacht Packages, restartet Services)
make dev-sync-watch

# Terminal 3: Development
cd repos/lg-menu-registry
vim src/index.ts
# → Builder kompiliert (~1-2s)
# → Watchdog erkennt Änderung
# → Services werden automatisch neu gestartet
# → Änderungen sichtbar in ~3-4s total!
```

**Wie es funktioniert:**
- Überwacht `/dist/menu-registry/index.js` Modification Time
- Erkennt Änderungen alle 2 Sekunden
- Führt `docker restart` auf Consumer Services aus
- Funktioniert parallel zu `tsx watch` (Double-Safety)

**Anpassen:**
```bash
# Nur bestimmte Services überwachen
./scripts/dev/watch-packages.sh "menu-service user-service"

# Nur bestimmte Packages überwachen
./scripts/dev/watch-packages.sh "menu-service user-service" "menu-registry backend-common"
```

**Wann nutzen?**
- ✅ `tsx watch` reagiert nicht auf Package-Änderungen
- ✅ Multiple Consumer Services gleichzeitig entwickeln
- ✅ Garantierte Restarts nach Package Updates
- ❌ NICHT nötig wenn `tsx watch` funktioniert (normaler Fall)

### Consumer Services konfigurieren

**Für neue Services:**

1. Erstelle `docker-compose.dev.yml`:
```yaml
version: '3.8'

services:
  your-service:
    volumes:
      - ./src:/app/src
      - lg-packages-dist:/workspace/packages:ro
    environment:
      NODE_PATH: /workspace/packages:/app/node_modules
      NODE_ENV: development
    command: npm run dev

volumes:
  lg-packages-dist:
    external: true
```

2. Service mit dev override starten:
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

### Troubleshooting

**"Changes not appearing"**
```bash
# Check builder status
make dev-sync-status

# View compilation logs
make dev-sync-logs PACKAGE=menu-registry

# Restart builders
make dev-sync-rebuild
```

**"Builder crashed"**
```bash
# Check logs
docker logs lg-builder-menu-registry

# Restart all builders
make dev-sync-rebuild
```

**"Consumer service not restarting"**
```bash
# Check NODE_PATH
docker exec lg-backend-menu env | grep NODE_PATH
# → Should show: /workspace/packages:/app/node_modules

# Check if volume is mounted
docker exec lg-backend-menu ls -la /workspace/packages
# → Should show: menu-registry/, backend-common/, types/
```

### Wann Normal Mode nutzen?

```bash
make dev-normal

# Use cases:
# - Testing production-like builds
# - Debugging npm dependency issues
# - When not actively developing packages
# - CI/CD testing
```

---

## 📦 Verdaccio Registry (Alternative)

Traditioneller Ansatz mit lokalem npm registry.

## 🎯 Use Case

**Problem:** Bei jeder Änderung an einem shared Package (`lg-admin-ui`, `lg-menu-registry`, etc.) musst du:
1. Code ändern
2. Tests schreiben/fixen
3. Committen
4. Pushen
5. GitHub Actions wartet ab
6. Package wird published
7. In anderem Package testen

Das dauert 5-10 Minuten pro Iteration! 😰

**Lösung:** Verdaccio local registry - Package lokal publishen und installieren in Sekunden! ⚡

## 🚀 Setup (einmalig)

### 1. Verdaccio läuft bereits im Docker Stack

```bash
docker ps | grep verdaccio
# → lg-development-infra-verdaccio-1
```

Verdaccio UI: http://localhost:4873/

### 2. Login (einmalig)

```bash
./scripts/dev/verdaccio-login.sh
```

Das erstellt einen User und speichert das Auth-Token in `scripts/dev/.verdaccio-token`.

**Hinweis:** Das Token bleibt gültig bis du Verdaccio neu startest oder htpasswd löschst.

## 📦 Lokaler Development Workflow

### 1. Package entwickeln & lokal publishen

```bash
# In lg-menu-registry arbeiten
cd repos/lg-menu-registry
vim src/index.ts

# LOKAL publishen (läuft tests, typecheck, und published zu Verdaccio)
./scripts/dev/publish-local.sh lg-menu-registry
```

**Was passiert:**
- ✅ Tests laufen in Docker
- ✅ Typecheck läuft
- ✅ Package wird zu lokalem Verdaccio published
- ⚡ **Dauert ~10 Sekunden statt 5-10 Minuten!**

### 2. Package in anderem Projekt installieren

```bash
# Install from local Verdaccio
./scripts/dev/install-local.sh lg-user-service @wolfgangm81/menu-registry
```

**Alternative (manuell):**
```bash
cd repos/lg-user-service
docker run --rm -v $(pwd):/app -w /app --network host node:20-alpine sh -c "
  echo 'registry=http://host.docker.internal:4873/' > .npmrc
  npm install @wolfgangm81/menu-registry
"
```

### 3. Iterieren

```bash
# 1. Code in menu-registry ändern
cd repos/lg-menu-registry
vim src/api.ts

# 2. Version bumpen (optional, oder gleiche Version überschreiben)
npm version patch  # 1.1.0 → 1.1.1

# 3. Lokal publishen
./scripts/dev/publish-local.sh lg-menu-registry

# 4. In user-service updaten
./scripts/dev/install-local.sh lg-user-service @wolfgangm81/menu-registry

# 5. Testen
cd repos/lg-user-service
docker-compose up -d --build user-service
docker logs -f lg-backend-user
```

## 🔄 Von lokal → GitHub Packages

Wenn du fertig bist mit lokalen Tests:

```bash
cd repos/lg-menu-registry

# 1. Finale Version setzen
docker run --rm -v $(pwd):/app -w /app node:20-alpine npm version minor
# → 1.1.0 → 1.2.0

# 2. Committen & Pushen
git add .
git commit -m "feat: add new API method"
git push

# 3. GitHub Actions published automatisch zu GitHub Packages
# 4. Andere Services können dann von GitHub Packages installieren
```

## 🧹 Cleanup

### Verdaccio reset (alle lokalen Packages löschen)

```bash
docker exec lg-development-infra-verdaccio-1 rm -rf /verdaccio/storage
docker restart lg-development-infra-verdaccio-1
```

### Re-login (falls Token expired)

```bash
./scripts/dev/verdaccio-login.sh
```

## 📝 Verfügbare Scripts

| Script | Beschreibung |
|--------|--------------|
| `./scripts/dev/verdaccio-login.sh` | Login zu Verdaccio, Token speichern |
| `./scripts/dev/publish-local.sh <package>` | Package lokal publishen |
| `./scripts/dev/install-local.sh <target> <dep>` | Dependency lokal installieren |

## 🎯 Best Practices

1. **Versionierung:**
   - Lokal: Kannst gleiche Version mehrmals publishen (überschreibt)
   - Produktion: Immer neue Version für GitHub Packages

2. **Testing:**
   - Lokal vollständig testen BEVOR du zu GitHub pushst
   - Spart CI/CD Zeit und Kosten

3. **Cleanup:**
   - Verdaccio storage wächst nicht - ist nur temporär
   - Bei Problemen einfach `rm -rf /verdaccio/storage` und neu starten

4. **Parallel Development:**
   - Mehrere Leute können gleichzeitig lokal entwickeln
   - Jeder hat eigenen Verdaccio Token

## ⚠️ Troubleshooting

### "Not logged in to Verdaccio"

```bash
./scripts/dev/verdaccio-login.sh
```

### "403 Forbidden"

Verdaccio config falsch. Prüfe:
```bash
docker exec lg-development-infra-verdaccio-1 cat /verdaccio/conf/config.yaml | grep -A 3 "@wolfgangm81"
```

Sollte sein:
```yaml
"@wolfgangm81/*":
  access: $all
  publish: $all
  unpublish: $authenticated
```

### "500 Internal Server Error"

Meist Problem mit GitHub proxy. Prüfe dass `proxy: github` auskommentiert ist für `@wolfgangm81/*`.

### "Cannot connect to Verdaccio"

```bash
# Check if running
docker ps | grep verdaccio

# Restart
docker restart lg-development-infra-verdaccio-1

# Check logs
docker logs lg-development-infra-verdaccio-1 --tail 50
```

## 🔗 Weiterführende Links

- Verdaccio Docs: https://verdaccio.org/docs/what-is-verdaccio
- npm registry: https://docs.npmjs.com/cli/v9/using-npm/registry
- Docker host networking: https://docs.docker.com/network/drivers/host/
