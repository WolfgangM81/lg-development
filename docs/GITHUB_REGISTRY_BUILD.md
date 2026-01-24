# GitHub Registry Build Setup

Automatischer Build und Publish über GitHub Actions zu GitHub Packages Registry.

## 🎯 Konzept

**Alles läuft in GitHub Actions - NICHT lokal!**

```
Local Development
    ↓
git push to main
    ↓
GitHub Actions
    ├─ Install dependencies (from GitHub Packages)
    ├─ Run type check
    ├─ Run tests
    ├─ Build package/Docker image
    └─ Publish to GitHub Packages Registry
    ↓
GitHub Packages
    ├─ npm packages (@wolfgangm81/*)
    └─ Docker images (ghcr.io/wolfgangm81/*)
```

## 📦 Zwei Build-Typen

### 1. Package Build (npm packages)

**Repos:** lg-menu-registry, lg-admin-ui

**Workflow:** `package-build.yml`

**Was passiert:**
1. ✅ npm install (mit GitHub Packages Registry)
2. ✅ npm run typecheck
3. ✅ npm test (falls vorhanden)
4. ✅ npm run build (falls vorhanden)
5. ✅ npm publish → GitHub Packages
6. ✅ Git Tag v1.2.3
7. ✅ GitHub Release erstellen

### 2. Service Build (Docker images)

**Repos:** lg-*-service, lg-admin

**Workflow:** `service-build.yml`

**Was passiert:**
1. ✅ npm install (mit GitHub Packages Registry)
2. ✅ npm run typecheck
3. ✅ npm run lint
4. ✅ npm test
5. ✅ Docker build (multi-arch: amd64, arm64)
6. ✅ Docker push → GitHub Container Registry
7. ✅ GitHub Release erstellen

## 🚀 Einmaliges Setup

### Schritt 1: GitHub Registry konfigurieren

```bash
make setup-github-registry
```

**Was macht das:**
- Erstellt `.npmrc` in allen repos
- Konfiguriert `@wolfgangm81:registry=https://npm.pkg.github.com`
- Verwendet `gh auth token` für Authentication
- Erstellt `.npmrc.example` (safe to commit)

### Schritt 2: publishConfig hinzufügen

```bash
make setup-publish-config
```

**Was macht das:**
- Fügt `publishConfig` zu package.json hinzu
- Setzt registry auf GitHub Packages
- Macht packages public

**Ergebnis in package.json:**
```json
{
  "publishConfig": {
    "registry": "https://npm.pkg.github.com",
    "access": "public"
  }
}
```

### Schritt 3: Build Workflows installieren

```bash
make install-build-workflows
```

**Was macht das:**
- Installiert `package-build.yml` für Packages
- Installiert `service-build.yml` für Services
- Erstellt `.github/workflows/` Verzeichnisse

### Schritt 4: Workflows pushen

```bash
# Für Packages
cd repos/lg-menu-registry
git add .github/workflows/build.yml .npmrc.example package.json
git commit -m "ci: add GitHub Actions build workflow"
git push

cd ../lg-admin-ui
git add .github/workflows/build.yml .npmrc.example package.json
git commit -m "ci: add GitHub Actions build workflow"
git push

# Für Services (Beispiel)
cd ../lg-user-service
git add .github/workflows/build.yml .npmrc.example
git commit -m "ci: add GitHub Actions build workflow"
git push
```

## 📝 Daily Workflow

### Development (lokal)

```bash
# 1. Code ändern
vi repos/lg-menu-registry/src/index.ts

# 2. Lokal testen (optional)
cd repos/lg-menu-registry
GITHUB_TOKEN=$(gh auth token) npm install
npm test

# 3. Version bumpen
npm version patch  # 1.0.0 → 1.0.1

# 4. Commit & Push
git add .
git commit -m "feat: neue funktion"
git push
```

### Was passiert dann automatisch:

```
Push to main
    ↓
GitHub Actions startet
    ↓
Build Job
    ├─ Checkout code
    ├─ Setup Node.js 20
    ├─ npm ci (mit GitHub Packages Registry)
    ├─ npm run typecheck
    ├─ npm test
    └─ npm run build
    ↓
Publish Job (nur bei main branch)
    ├─ Check if version exists
    ├─ npm publish (wenn neue Version)
    ├─ Create git tag v1.0.1
    └─ Create GitHub Release
    ↓
GitHub Packages
    ├─ Package verfügbar: @wolfgangm81/menu-registry@1.0.1
    └─ Install mit: npm install @wolfgangm81/menu-registry@1.0.1
```

## 🐳 Docker Images (Services)

### Build Prozess

```bash
# Lokal entwickeln
cd repos/lg-user-service
vi src/index.ts

# Version bumpen
npm version patch

# Push
git push
```

### Was passiert:

```
Push to main
    ↓
GitHub Actions
    ├─ Test Job
    │   ├─ npm ci
    │   ├─ npm run typecheck
    │   ├─ npm run lint
    │   └─ npm test
    └─ Build & Push Job
        ├─ Docker build (amd64 + arm64)
        ├─ Push to ghcr.io/wolfgangm81/lg-user-service
        └─ Tags: latest, v1.0.1, main-abc1234
```

### Docker Image verwenden

```yaml
# docker-compose.yml
services:
  user-service:
    image: ghcr.io/wolfgangm81/lg-user-service:latest
    # oder spezifische Version:
    # image: ghcr.io/wolfgangm81/lg-user-service:v1.0.1
```

## 🔐 Secrets & Permissions

### GitHub Token (automatisch)

GitHub Actions hat automatisch Zugriff auf:
- `secrets.GITHUB_TOKEN` - Für Packages publish
- `packages: write` - Für GitHub Packages
- `contents: write` - Für Releases & Tags

**Keine manuellen Secrets nötig!**

### Package Visibility

**Public Packages:**
```json
{
  "publishConfig": {
    "access": "public"
  }
}
```

**Private Packages:**
```json
{
  "publishConfig": {
    "access": "restricted"
  }
}
```

## 📊 Workflow Status

### Badges in README

```markdown
[![Build](https://github.com/WolfgangM81/lg-menu-registry/actions/workflows/build.yml/badge.svg)](https://github.com/WolfgangM81/lg-menu-registry/actions/workflows/build.yml)
```

### GitHub Actions UI

- **Actions Tab** - Alle Workflow Runs
- **Packages** - Published packages
- **Releases** - Automatische Releases

## 🛠️ Troubleshooting

### "npm ERR! 404 Not Found - GET https://npm.pkg.github.com/@wolfgangm81/..."

**Problem:** Package wurde noch nie gepublisht

**Lösung:**
```bash
# Ersten Publish manuell triggern
cd repos/lg-menu-registry
git commit --allow-empty -m "ci: trigger first build"
git push
```

### "Error: Version 1.0.0 already exists"

**Problem:** Version wurde schon gepublisht

**Lösung:**
```bash
# Version bumpen
npm version patch
git push
```

### "Permission denied to write to package"

**Problem:** Workflow hat keine Package-Rechte

**Lösung:** In `.github/workflows/build.yml`:
```yaml
permissions:
  contents: write
  packages: write
```

### Docker build fails with "npm ERR! 404"

**Problem:** Dockerfile kann GitHub Packages nicht erreichen

**Lösung:** Build-Args im Dockerfile:
```dockerfile
ARG GITHUB_TOKEN
RUN echo "@wolfgangm81:registry=https://npm.pkg.github.com" > .npmrc && \
    echo "//npm.pkg.github.com/:_authToken=${GITHUB_TOKEN}" >> .npmrc && \
    npm ci && \
    rm .npmrc
```

Und in `service-build.yml`:
```yaml
build-args: |
  GITHUB_TOKEN=${{ secrets.GITHUB_TOKEN }}
```

## 🎨 Customization

### Nur auf Version-Änderung publishen

In `build.yml`:
```yaml
on:
  push:
    branches:
      - main
    paths:
      - 'package.json'  # ← Nur bei package.json Änderung
```

### Mehrere Branches publishen

```yaml
on:
  push:
    branches:
      - main
      - develop
      - release/*
```

### Pre-release Versionen

```bash
# Beta Version
npm version prerelease --preid=beta  # 1.0.0 → 1.0.1-beta.0

# Alpha Version
npm version prerelease --preid=alpha  # 1.0.0 → 1.0.1-alpha.0
```

## 📚 Best Practices

1. **Version Bumping**
   ```bash
   npm version patch  # Bug fixes
   npm version minor  # Features
   npm version major  # Breaking changes
   ```

2. **Semantic Commits**
   ```bash
   git commit -m "feat: add feature"    # → minor bump
   git commit -m "fix: bug fix"         # → patch bump
   git commit -m "BREAKING: change"     # → major bump
   ```

3. **Branch Protection**
   - main branch → require PR
   - require status checks (build) to pass
   - require review approval

4. **Versioning Strategy**
   - main branch → stable releases
   - develop branch → pre-releases
   - feature/* → no publish

## 🔄 Rollback

### Package Rollback

```bash
# Publish alte Version erneut (geht nicht bei GitHub Packages)
# Stattdessen: neue Version mit Fix

npm version patch
git commit -m "fix: revert breaking change"
git push
```

### Docker Rollback

```yaml
# Nutze alte Tag
services:
  user-service:
    image: ghcr.io/wolfgangm81/lg-user-service:v1.0.0
```

## 📦 Monorepo Support

Für Monorepos mit mehreren Packages:

```yaml
# .github/workflows/build.yml
strategy:
  matrix:
    package:
      - packages/menu-registry
      - packages/admin-ui

steps:
  - name: Publish
    working-directory: ${{ matrix.package }}
    run: npm publish
```

## ✅ Checkliste Setup

- [ ] `make setup-github-registry` ausgeführt
- [ ] `make setup-publish-config` ausgeführt
- [ ] `make install-build-workflows` ausgeführt
- [ ] Workflows zu GitHub gepusht
- [ ] Ersten Build getriggert
- [ ] Package im GitHub Packages sichtbar
- [ ] Badge in README eingefügt
- [ ] Branch Protection aktiviert

**Nach Setup: Alles läuft automatisch!** 🎉
