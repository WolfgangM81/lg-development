# Verdaccio als GitHub Packages Proxy

Lokale Entwicklung mit Verdaccio als Proxy für GitHub Packages.

## Konzept

```
┌─────────────┐
│   Service   │
│  (Docker)   │
└──────┬──────┘
       │ npm install @wolfgangm81/menu-registry
       ▼
┌─────────────┐
│  Verdaccio  │ ← Lokaler NPM Registry Proxy
│ (localhost: │    - Cache für schnellere Installs
│    4873)    │    - Proxy zu GitHub Packages
└──────┬──────┘    - Proxy zu npmjs.org
       │
       ├─────────► npmjs.org (public packages)
       │
       └─────────► npm.pkg.github.com (@wolfgangm81/*)
```

## Vorteile

1. **🚀 Schneller** - Cached packages lokal
2. **🔄 Offline** - Arbeite ohne Internet (mit Cache)
3. **🔒 Sicher** - GitHub Token nur in Verdaccio, nicht in jedem Projekt
4. **🎯 Einfach** - Eine .npmrc für alle Projekte

## Setup

### 1. Verdaccio konfigurieren

Verdaccio ist bereits konfiguriert in `repos/lg-verdaccio/config.yaml`:

```yaml
uplinks:
  npmjs:
    url: https://registry.npmjs.org/

  github:
    url: https://npm.pkg.github.com/
    auth:
      type: bearer
      token_env: GITHUB_TOKEN

packages:
  "@wolfgangm81/*":
    access: $all
    publish: $authenticated
    proxy: github  # ← GitHub Packages

  "**":
    access: $all
    proxy: npmjs  # ← npm Registry
```

### 2. GitHub Token setzen

In `.env` (bereits konfiguriert):

```bash
GITHUB_TOKEN=gho_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 3. Verdaccio starten

```bash
make start  # Startet alle Services inkl. Verdaccio
```

Oder nur Verdaccio:

```bash
docker-compose -f repos/lg-verdaccio/docker-compose.yml up -d
```

### 4. Services konfigurieren

Jedes Service braucht `.npmrc`:

```
registry=http://verdaccio:4873
```

**Lokal (außerhalb Docker):**

```
registry=http://localhost:4873
```

## Verwendung

### Packages installieren

```bash
# In einem Service (z.B. lg-menu-service)
npm install @wolfgangm81/menu-registry
```

**Was passiert:**
1. npm fragt Verdaccio (localhost:4873)
2. Verdaccio prüft Cache
3. Wenn nicht im Cache → GitHub Packages
4. Package wird gecacht für nächstes Mal

### Packages publishen

**Lokal zu Verdaccio:**

```bash
cd repos/lg-menu-registry
npm publish --registry http://localhost:4873
```

**Zu GitHub Packages:**

```bash
# Mit make
make publish-package PACKAGE=lg-menu-registry

# Oder manuell
cd repos/lg-menu-registry
npm publish --registry https://npm.pkg.github.com
```

## Auto-Publish bei Push

### Workflows installieren

```bash
make install-publish-workflows
```

Das installiert `.github/workflows/publish.yml` in:
- lg-menu-registry
- lg-admin-ui

### Was passiert bei Push

```
Push to main
    ↓
GitHub Actions
    ├─ npm test
    ├─ npm build (falls vorhanden)
    ├─ npm publish → GitHub Packages
    └─ git tag v1.2.3
```

### Workflow anpassen

`.github/workflows/publish.yml`:

```yaml
on:
  push:
    branches:
      - main  # ← Auf main pushen triggert publish
    paths:
      - 'package.json'  # ← Nur bei Version-Änderung
      - 'src/**'        # ← Oder Code-Änderungen
```

## Troubleshooting

### "403 Forbidden" bei GitHub Packages

**Problem:** Token hat keine Rechte

**Lösung:**
```bash
# Neuen Token erstellen mit write:packages scope
# Siehe: docs/GITHUB_PACKAGES.md

# Token in .env eintragen
GITHUB_TOKEN=ghp_xxxxxxxxxxxx

# Verdaccio neu starten
docker-compose -f repos/lg-verdaccio/docker-compose.yml restart
```

### "ENOTFOUND verdaccio"

**Problem:** Service findet Verdaccio nicht

**Lösung:**
```bash
# 1. Verdaccio läuft?
docker ps | grep verdaccio

# 2. Im gleichen Network?
docker network inspect lg-internal

# 3. DNS resolve test
docker exec lg-backend-menu ping verdaccio
```

### Cache löschen

**Vollständig:**
```bash
docker-compose -f repos/lg-verdaccio/docker-compose.yml down -v
docker-compose -f repos/lg-verdaccio/docker-compose.yml up -d
```

**Einzelnes Package:**
```bash
docker exec lg-infra-verdaccio rm -rf /verdaccio/storage/@wolfgangm81/menu-registry
```

### Verdaccio zeigt Packages nicht

**Web UI öffnen:**
```
http://localhost:4873
```

**Packages prüfen:**
```bash
# Liste aller Packages
curl http://localhost:4873/-/verdaccio/packages

# Spezifisches Package
curl http://localhost:4873/@wolfgangm81/menu-registry
```

## Best Practices

### Development Workflow

1. **Lokale Änderungen testen:**
   ```bash
   cd repos/lg-menu-registry
   npm version patch  # 1.0.0 → 1.0.1
   npm publish --registry http://localhost:4873
   ```

2. **In Service testen:**
   ```bash
   cd repos/lg-menu-service
   npm install @wolfgangm81/menu-registry@latest
   npm test
   ```

3. **Wenn OK → GitHub pushen:**
   ```bash
   cd repos/lg-menu-registry
   git add .
   git commit -m "feat: neue Funktion"
   git push  # ← Triggert auto-publish
   ```

### Version Bumping

```bash
# Patch (1.0.0 → 1.0.1) - Bug fixes
npm version patch

# Minor (1.0.0 → 1.1.0) - New features
npm version minor

# Major (1.0.0 → 2.0.0) - Breaking changes
npm version major
```

## Monitoring

### Verdaccio Logs

```bash
docker logs -f lg-infra-verdaccio
```

### Package Downloads

```bash
# Welche Packages wurden heruntergeladen?
docker exec lg-infra-verdaccio ls /verdaccio/storage
```

### Disk Usage

```bash
docker exec lg-infra-verdaccio du -sh /verdaccio/storage
```

## Migration zu Production

Wenn du in Production gehst:

1. **Verdaccio entfernen** - Nicht für Production gedacht
2. **Direkt GitHub Packages** - Services direkt mit npm.pkg.github.com
3. **.npmrc anpassen:**
   ```
   @wolfgangm81:registry=https://npm.pkg.github.com
   //npm.pkg.github.com/:_authToken=${GITHUB_TOKEN}
   ```

## Weitere Infos

- Verdaccio Docs: https://verdaccio.org/docs/configuration
- GitHub Packages: https://docs.github.com/en/packages
- npm Registry: https://docs.npmjs.com/cli/v8/using-npm/registry
