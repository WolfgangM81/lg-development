# CLAUDE.md - LG-Development Repository Manager

AI Assistant Instructions für dieses Projekt.

---

## 🎯 Projekt-Kontext

**LG-Development** ist ein **Repository Manager** für die Migration von einem Monorepo zu Multi-Repo.

**Rolle:** Automation Tool (einmalige Nutzung), NICHT ein Service im LicenseGuard Stack!

**Status:** ✅ Production Ready (Scripts komplett)

---

## 🚨 KRITISCHE REGEL #1: NON-DESTRUCTIVE!

**NIEMALS** das Original-Monorepo anfassen!

### ❌ VERBOTEN:
- Dateien in `../lg-*` löschen/ändern
- Git History in Originalen manipulieren
- Dependencies in Originalen updaten

### ✅ ERLAUBT:
- Lesen aus `../lg-*`
- Kopieren nach `repos/`
- Änderungen NUR in `repos/`

**Warum?** Original muss jederzeit als Fallback funktionieren!

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
├── scripts/                         # 8 Automation Scripts
├── templates/                       # .npmrc, Workflows, etc.
├── repos/                           # ⚠️ GITIGNORED! Kopierte Projekte
│   ├── lg-admin-ui/.git            # Separates Git Repo
│   ├── lg-management/.git          # Separates Git Repo
│   └── ...
├── .dependency-graph.json          # Auto-generiert
└── .migration-order.txt            # Auto-generiert

~/Projects/                          # ✅ ORIGINAL MONOREPO (bleibt!)
├── lg-admin/
├── lg-management/
└── ...
```

---

## 🛠️ Scripts Übersicht

| Script | Zweck | Safe? |
|--------|-------|-------|
| **migrate.sh** | Master Wizard (7 Schritte) | ✅ Ja |
| **analyze-dependencies.sh** | Dependency Graph erstellen | ✅ Ja (read-only) |
| **copy-project.sh** | Ein Projekt kopieren | ✅ Ja (kopiert nur) |
| **copy-all.sh** | Alle 10 Projekte kopieren | ✅ Ja |
| **prepare-repo.sh** | Templates anwenden | ✅ Ja (nur in repos/) |
| **create-github-repos.sh** | GitHub Repos erstellen | ⚠️ Vorsicht (GitHub API) |
| **setup-secrets.sh** | GitHub Secrets setzen | ⚠️ Vorsicht (Secrets!) |
| **health-check.sh** | Pre-flight Validation | ✅ Ja (read-only) |

---

## 🎯 Typische Tasks

### Task 1: "Führe Migration durch"

```bash
cd /Users/wolfgang/Projects/lg-development

# Option A: Interactive
./scripts/migrate.sh

# Option B: Automated
./scripts/migrate.sh --auto
```

**Was passiert:**
1. Dependency Analysis
2. Copy 10 projects from ../lg-*
3. Apply templates (.npmrc, workflows)
4. Create GitHub repos
5. Setup secrets
6. Health check
7. Summary

### Task 2: "Nur ein Projekt vorbereiten"

```bash
# Kopieren
./scripts/copy-project.sh --source ../lg-admin-ui --dest repos/lg-admin-ui

# Vorbereiten
./scripts/prepare-repo.sh repos/lg-admin-ui --type library

# Health Check
./scripts/health-check.sh
```

### Task 3: "GitHub Repo erstellen (dry-run)"

```bash
# Test first
./scripts/create-github-repos.sh --dry-run

# Then real
./scripts/create-github-repos.sh
```

### Task 4: "Secrets updaten"

```bash
# Erst .env.secrets editieren
vi .env.secrets

# Dann setzen
./scripts/setup-secrets.sh
# Oder nur ein Repo:
./scripts/setup-secrets.sh --repo lg-user-service
```

### Task 5: "Script fixen/verbessern"

```bash
# Scripts sind in scripts/
vi scripts/prepare-repo.sh

# Test:
./scripts/prepare-repo.sh repos/test-project --type library

# Commit in lg-development (nicht in repos/!)
git add scripts/prepare-repo.sh
git commit -m "fix: improve prepare-repo error handling"
```

---

## 🔍 Debugging

### "Migration schlägt fehl"

**Schritt 1:** Check logs
```bash
# Scripts schreiben nach /tmp/
cat /tmp/copy-lg-admin-ui.log
cat /tmp/prepare-lg-admin-ui.log
```

**Schritt 2:** Health Check
```bash
./scripts/health-check.sh
# Zeigt was fehlt
```

**Schritt 3:** Einzeln fixen
```bash
# Re-run nur failing step
./scripts/prepare-repo.sh repos/lg-admin-ui --type library
```

### "Dependency Graph fehlerhaft"

```bash
# Re-run analysis
rm .dependency-graph.json .migration-order.txt
./scripts/analyze-dependencies.sh
```

### "GitHub Repo existiert schon"

```bash
# Script überspringt automatisch
./scripts/create-github-repos.sh
# Output: "⊘ lg-platform (already exists, skipping)"
```

---

## 🚨 Häufige Fehler

### Fehler 1: "Git add repos/"

❌ **FALSCH:**
```bash
git add repos/lg-admin-ui
# → Error: repos/ ist gitignored!
```

✅ **RICHTIG:**
```bash
cd repos/lg-admin-ui
git add .
git push origin main  # ← Zu GitHub Repo
```

### Fehler 2: "Original anfassen"

❌ **FALSCH:**
```bash
rm ../lg-admin/package-lock.json  # ← Original ändern!
```

✅ **RICHTIG:**
```bash
rm repos/lg-admin/package-lock.json  # ← Kopie ändern
```

### Fehler 3: "Scripts ohne chmod +x"

❌ **FALSCH:**
```bash
bash scripts/migrate.sh  # Funktioniert, aber...
```

✅ **RICHTIG:**
```bash
chmod +x scripts/*.sh
./scripts/migrate.sh
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

## ✅ Success Criteria

Migration erfolgreich wenn:

1. ✅ `./scripts/health-check.sh` → All checks pass
2. ✅ Alle 10 Repos auf GitHub existieren
3. ✅ GitHub Actions Workflows vorhanden
4. ✅ Secrets konfiguriert (secrets.sh gelaufen)
5. ✅ Original Monorepo unverändert

---

## 📚 Weiterführende Docs

- **README.md** - Quick Start Guide
- **MIGRATION_PLAN.md** - Strategie (70KB)
- **SAFE_MIGRATION_STRATEGY.md** - Non-Destructive Approach
- **PARALLELIZATION_TIMELINE.md** - Time Estimates

---

## 🆘 Troubleshooting

Siehe README.md → Troubleshooting Section

**Noch Fragen?** Frag den User! 🙂
