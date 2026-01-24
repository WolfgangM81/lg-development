# GitHub Packages Setup

## Token mit Package-Rechten erstellen

1. **Gehe zu GitHub Settings:**
   ```
   https://github.com/settings/tokens/new
   ```

2. **Token konfigurieren:**
   - Name: `LG-Development Package Publishing`
   - Expiration: `No expiration` oder `1 year`
   - Scopes:
     - ✅ `write:packages` - Upload packages to GitHub Package Registry
     - ✅ `read:packages` - Download packages from GitHub Package Registry
     - ✅ `delete:packages` - Delete packages from GitHub Package Registry
     - ✅ `repo` - Full control of private repositories (für private packages)

3. **Token kopieren und in .env eintragen:**
   ```bash
   GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

## Packages publishen

```bash
# Alle Packages publishen
make publish-packages

# Einzelnes Package publishen
make publish-package PACKAGE=lg-menu-registry

# Dry-run (ohne tatsächlich zu publishen)
make publish-packages-dry
```

## .npmrc Setup

Jedes Repo benötigt `.npmrc` mit:

```
@wolfgangm81:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=${GITHUB_TOKEN}
```

## Packages installieren

Nach dem Publish können andere Repos die Packages installieren:

```bash
npm install @wolfgangm81/menu-registry
npm install @wolfgangm81/admin-ui
```

## Troubleshooting

### 403 Permission Denied

- Token hat keine `write:packages` Rechte
- Token ist abgelaufen
- Repo ist nicht zugänglich

### 404 Not Found beim Install

- Package wurde noch nicht gepublisht
- .npmrc fehlt oder ist falsch konfiguriert
- Token hat keine `read:packages` Rechte

### Package Version existiert bereits

- Version in package.json erhöhen
- Oder bestehende Version mit `npm unpublish` löschen (nicht empfohlen)
