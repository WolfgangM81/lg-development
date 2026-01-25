# 🔥 GOTCHAS & CRITICAL BUGS

**Datum:** 2026-01-22

---

## 🚨 useState mit Props Initializer = BUG

### Problem

```typescript
// ❌ FALSCH - Initializer läuft nur EINMAL!
const [menuStack, setMenuStack] = useState([{ items, title: '', depth: 0 }]);
// Wenn items anfangs [] ist, bleibt menuStack bei [] auch wenn items später gefüllt wird!
```

**Symptom:** Menu zeigt permanent "Loading menu..." obwohl Console "menu items: 3 items" zeigt.

**Root Cause:** useState Initializer läuft NUR beim ersten Render! Props Änderungen werden ignoriert!

### Lösung

```typescript
// ✅ RICHTIG - State startet leer, currentPanel wird von items ABGELEITET
const [navigationStack, setNavigationStack] = useState([]);
const currentPanel = navigationStack.length === 0
  ? { items, title: '', depth: 0 }  // ← items prop direkt nutzen!
  : navigationStack[navigationStack.length - 1];
```

**Warum:** currentPanel wird bei jedem Render NEU berechnet → items Änderungen werden sofort reflektiert!

---

## 🎯 Rationales Vorgehen

### ❌ Trial & Error (2+ Stunden verschwendet)
- useLocation() entfernen ❌
- NavLink durch Link ersetzen ❌
- pathname als prop durchreichen ❌
- useEffect zum Synchen ❌
- → **KEINES davon hat geholfen!**

### ✅ Root Cause Analysis (10 Minuten)
1. **Symptom:** Sidebar zeigt "Loading menu...", Console zeigt "3 items"
2. **Code lesen:** `useState([{ items, ... }])` gefunden
3. **Root Cause:** Initializer mit prop, läuft nur einmal!
4. **Fix:** navigationStack startet leer, currentPanel von items ableiten
5. **Test:** Menu rendert!

**Unterschied:** **12x schneller!**

---

## 📋 Debug Checklist

Bei jedem Bug:
1. **Symptom:** Was ist kaputt?
2. **Daten:** Console Logs, Network Tab prüfen
3. **Code lesen:** Nicht raten!
4. **Root Cause:** WARUM (nicht nur WAS)?
5. **Minimal Fix:** Kleinste Änderung!
6. **Browser Test:** Hard refresh + Screenshot!

---

## 🐛 Weitere Gotchas

### Docker Container Cache
```bash
# ❌ FALSCH
docker-compose restart admin  # Nutzt altes Image!

# ✅ RICHTIG
docker-compose up -d --force-recreate admin  # Nutzt neues Image!
```

### Browser Cache
```bash
# Hard Refresh: Cmd+Shift+R (Mac) / Ctrl+Shift+R (Win)
# Oder: localStorage.clear(); sessionStorage.clear(); location.reload(true);
```

---

## Package Hot-Reload Gotchas

### 1. "Hot-Reload funktioniert nicht" - Builder läuft nicht

**Symptome:**
- Änderungen in `repos/lg-menu-registry/src/` werden nicht übernommen
- Services laden alte Package-Versionen
- `make dev-sync-status` zeigt keine Builder

**Root Cause:**
Builder Container nicht gestartet oder gestoppt.

**Fix:**
```bash
make dev-sync          # Aktiviert Hot-Reload
make dev-sync-status   # Prüft Builder Status
```

---

### 2. Builder Health Check fehlgeschlagen

**Symptome:**
- `make dev-sync-status` zeigt "unhealthy"
- Compilation funktioniert, aber Health Check fails
- Logs zeigen "health check failed"

**Mögliche Ursachen:**
1. `.d.ts` Dateien fehlen (TypeScript declarations)
2. JavaScript Syntax-Fehler
3. Build-Artefakte korrupt

**Fix:**
```bash
make dev-sync-check    # Zeigt detaillierte Fehler
make dev-sync-logs PACKAGE=backend-common  # Volle Logs
make dev-sync-rebuild  # Rebuild aller Builder
```

---

### 3. Smart Restart funktioniert nicht - jq fehlt

**Symptome:**
- Alle 6 Services restarten bei jeder Änderung (langsam!)
- Kein intelligenter Restart (nur betroffene Services)

**Root Cause:**
`jq` nicht installiert - Fallback auf "restart all services"

**Fix:**
```bash
# macOS
brew install jq

# Linux
apt-get install jq

# Verify
which jq  # Sollte Pfad anzeigen
```

**Fallback:** Funktioniert auch ohne jq, nur langsamer (alle Services werden restarted)

---

### 4. Volume Mount Issues - Permissions

**Symptome:**
- Builder kann nicht in `/dist` schreiben
- Errors: "EACCES: permission denied"
- Build succeeds, aber Dateien fehlen

**Root Cause:**
Docker Volume Permissions (Linux)

**Fix:**
```bash
# Check Volume Ownership
docker run --rm -v lg-package-builds:/data alpine ls -la /data

# Fix permissions (falls nötig)
docker run --rm -v lg-package-builds:/data alpine chown -R 1000:1000 /data

# Rebuild
make dev-sync-rebuild
```

---

### 5. Änderungen werden nicht erkannt - Watch nicht aktiv

**Symptome:**
- Datei editiert, aber kein Rebuild
- Logs zeigen keine Aktivität
- Builder läuft, aber tut nichts

**Root Cause:**
TypeScript Compiler Watch Mode nicht aktiv oder gecrasht

**Debug:**
```bash
make dev-sync-logs PACKAGE=menu-registry
# Should show: "Starting compilation in watch mode..."
# If not: Builder crashed or misconfigured
```

**Fix:**
```bash
make dev-sync-rebuild  # Rebuild Builder
```

---

### 6. False Positives - Build erfolgreich, aber Fehler in Service

**Symptome:**
- `make dev-sync-check` zeigt ✅ (grün)
- Service crashed oder lädt Package nicht
- Runtime Error im Service

**Root Cause:**
- TypeScript compiled erfolgreich, aber Runtime Fehler
- Package Versionskonflikt
- Service cached alte Version

**Fix:**
```bash
# Service neu starten (lädt Package fresh)
docker-compose restart menu-service

# Check Service Logs
docker-compose logs -f menu-service

# Check welche Package Version geladen
docker-compose exec menu-service npm list @wolfgangm81/lg-menu-registry
```

---

### 7. Dashboard nicht verfügbar - watch fehlt

**Symptome:**
- `make dev-sync-dashboard` zeigt Fehlermeldung
- "watch: command not found"
- Dashboard fällt auf manuelle Refresh zurück

**Root Cause:**
`watch` Utility nicht installiert (optional)

**Fix:**
```bash
# macOS
brew install watch

# Linux (meist pre-installed)
apt-get install procps

# Fallback: Manuelle Refresh
make dev-sync-status  # Einmalig, ohne Auto-Refresh
```

---

### 8. Cache Issues - alte Artefakte

**Symptome:**
- Änderungen überschreiben sich nicht
- Alte Versionen bleiben bestehen
- Rebuild zeigt keine Wirkung

**Root Cause:**
Docker Volume cached alte Builds

**Fix:**
```bash
make dev-sync-clean    # Löscht Build-Artefakte
make dev-sync-rebuild  # Rebuild von Scratch

# Nuclear Option (löscht ALLES):
docker volume rm lg-package-builds
make dev-sync          # Neu aufsetzen
```

---

## 🐳 Docker Compose: `version:` Attribut ist obsolet

### Problem

```yaml
# ❌ WARNING: the attribute `version` is obsolete
version: '3.8'

services:
  traefik:
    image: traefik:v3.0
```

**Symptom:** Docker Compose zeigt Warning beim Starten:
```
time="2026-01-25T13:49:42+01:00" level=warning msg="/path/to/docker-compose.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion"
```

**Root Cause:** Seit **Docker Compose v2** (2020) ist das `version:` Attribut nicht mehr notwendig und wird ignoriert. Die Compose Spec ist jetzt unabhängig von der Version.

### Lösung

```yaml
# ✅ RICHTIG - Kein version: Attribut
services:
  traefik:
    image: traefik:v3.0
    ports:
      - "80:80"
```

**Warum entfernen?**
- Docker Compose erkennt automatisch die Spec-Features
- Vermeidet verwirrende Warnings
- Moderne Best Practice (seit 2020)

### Fix in allen docker-compose Dateien

**Betroffene Dateien:**
```bash
# Alle docker-compose.yml Dateien prüfen
find . -name "docker-compose*.yml" -exec grep -l "^version:" {} \;

# In jedem File:
# 1. Erste Zeile "version: '3.8'" entfernen
# 2. Datei speichern
# 3. Docker Compose neu starten
```

**Beispiel:**
```diff
- version: '3.8'
-
  services:
    traefik:
      image: traefik:v3.0
```

### Warum taucht das Problem auf?

**Historisch:**
- Docker Compose v1: `version: '3'` war **mandatory**
- Docker Compose v2 (2020): `version:` wurde **optional**
- Docker Compose v2 (2023): `version:` wurde **deprecated**

**Aktuell (2026):**
- `version:` wird komplett ignoriert
- Führt zu Warnings aber NICHT zu Fehlern
- Best Practice: Komplett weglassen

### Nachhaltige Lösung

**1. Template aktualisieren:**
```bash
# In templates/docker-compose.template.yml (falls vorhanden)
# version: Zeile entfernen
```

**2. Service-Repos aktualisieren:**
```bash
# In jedem Service-Repo (lg-*-service, lg-infrastructure/*)
# docker-compose.yml editieren
# version: Zeile entfernen
# Committen
```

**3. Dokumentation:**
- In [DOCKER.md](./DOCKER.md) Best Practices dokumentieren
- In [GOTCHAS.md](./GOTCHAS.md) erklären (✅ DONE)

---

**Siehe auch:**
- **[HOT_RELOAD_QUICK_REF.md](../HOT_RELOAD_QUICK_REF.md)** - Quick Reference
- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** - General Troubleshooting
- **[CLAUDE.md](../CLAUDE.md#package-hot-reload-system)** - Complete Hot-Reload Docs

---

**Key Takeaway:** Root Cause Analysis > Trial & Error!
