# Testing Strategy - LicenseGuard Platform

---

## ⚠️ Test Watch vs. Code Hot-Reload - Unterschied

**WICHTIG:** Dieses Dokument behandelt **Test Watch Mode** (Vitest), NICHT Code Hot-Reload!

### Was ist der Unterschied?

| Feature | Test Watch Mode | Code Hot-Reload |
|---------|----------------|----------------|
| **Zweck** | Tests neu laufen lassen bei Code-Änderungen | Package Code neu kompilieren und Services neu starten |
| **Tool** | Vitest (`vitest --watch`) | TypeScript Compiler + Docker Volume |
| **Scope** | Nur Tests | Production Code + Services |
| **Speed** | Instant (in-memory) | ~2-3s (compile + restart) |
| **Use Case** | TDD Workflow | Package Development |
| **Docs** | Dieses Dokument | [HOT_RELOAD_QUICK_REF.md](../HOT_RELOAD_QUICK_REF.md) |

### Test Watch Mode (Dieses Dokument)

```bash
# Startet Vitest im Watch Mode
make test-watch SERVICE=lg-user-service

# Was passiert:
# 1. Edit: src/routes/user.ts
# 2. Vitest detects change
# 3. Re-runs related tests
# 4. Shows results instantly (in-memory)
```

**Use Case:** Test-Driven Development (TDD)
- Schreibe Test → Test fails → Implementiere Code → Test passes
- Instant Feedback Loop für Unit Tests

### Code Hot-Reload (Andere Docs)

```bash
# Startet Package Hot-Reload System
make dev-sync

# Was passiert:
# 1. Edit: repos/lg-menu-registry/src/index.ts
# 2. Builder compiles package (~2-3s)
# 3. Services restart automatically (~1-2s)
# 4. Production code updated (not tests!)
```

**Use Case:** Package Development
- Develop shared packages (lg-menu-registry, lg-backend-common, lg-types)
- Test changes across multiple services
- Avoid npm publish cycle

**Siehe:**
- **[HOT_RELOAD_QUICK_REF.md](../HOT_RELOAD_QUICK_REF.md)** - Quick Reference
- **[CLAUDE.md#package-hot-reload-system](../CLAUDE.md#package-hot-reload-system)** - Complete Docs
- **[DOCKER.md#package-hot-reload-architecture](./DOCKER.md#package-hot-reload-architecture)** - Architecture

---

**Zusammenfassung:**
- **Test Watch:** Tests re-run (Vitest)
- **Code Hot-Reload:** Code re-compiles + Services restart (TypeScript + Docker)

Beide sind nützlich, aber für unterschiedliche Zwecke!

---

## Test Coverage Philosophie

### Realistische Coverage Targets (Recherchiert 2025)

**Unsere Thresholds:**
- ✅ **Statements**: 85%
- ✅ **Functions**: 85%
- ✅ **Lines**: 85%
- ✅ **Branches**: 75%

**Begründung** ([Industry Standards](https://testing.googleblog.com/2020/08/code-coverage-best-practices.html)):
- Google's Approach: 60% acceptable, 75% commendable, 90% exemplary
- Empirische Studien: 74-76% Durchschnitt über 47 Projekte
- Microsoft: 70-80% optimal, "overly ambitious goals can be counterproductive"
- Pragmatischer Konsens: **75-80% ist der Sweet Spot**

**Branch Coverage niedriger weil:**
- UI Components haben defensive Type Guards (typeof checks)
- Error Handling Paths werden nie getriggert
- 80-90% Coverage erfordert Tests für Code, der nie feilt
- **Diminishing Returns**: 70-80% findet meiste Bugs, 90%+ ist zeitaufwändig mit minimalem Zusatznutzen

**Quellen:**
- [Google Testing Blog](https://testing.googleblog.com/2020/08/code-coverage-best-practices.html)
- [Bullseye: Minimum Acceptable Code Coverage](https://www.bullseye.com/minimum.html)
- [Microsoft: Unit Testing Best Practices](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-code-coverage)
- [Codecov: Line vs Branch Coverage](https://about.codecov.io/blog/line-or-branch-coverage-which-type-is-right-for-you/)

---

## Unit Tests (Vitest)

### Framework Setup
- **Framework**: Vitest v4.0.17
- **Test Library**: @testing-library/react
- **Coverage**: @vitest/coverage-v8
- **Environment**: jsdom

### Tests ausführen

```bash
# ✅ RICHTIG: Im Docker ausführen
docker run --rm -v $(pwd):/app -w /app node:20-alpine npm test

# ✅ RICHTIG: Mit dev.sh Helper
./dev.sh npm-in lg-admin-ui test

# ✅ RICHTIG: Mit Coverage
./dev.sh npm-in lg-admin-ui test -- --coverage

# ❌ FALSCH: Auf Host (siehe NPM-Regel in CLAUDE.md!)
npm test  # NIEMALS!
```

### Vitest Config Pattern

```typescript
// vitest.config.ts (Template für alle Projekte)
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: [],
    include: ['src/**/*.{test,spec}.{ts,tsx}'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      include: ['src/**/*.{ts,tsx}'],
      exclude: ['src/**/*.d.ts', 'src/index.ts', 'src/**/*.test.{ts,tsx}'],
      thresholds: {
        branches: 75,      // UI Components: Defensive Code
        functions: 85,     // Alle Functions getestet
        lines: 85,         // Hohe Line Coverage
        statements: 85,    // Hohe Statement Coverage
      },
    },
  },
});
```

### Test-Struktur

```typescript
// Component Test Pattern
import { render, screen, fireEvent } from '@testing-library/react';
import { describe, it, expect, beforeEach, vi } from 'vitest';

describe('MyComponent', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders correctly', () => {
    render(<MyComponent />);
    expect(screen.getByText('Expected Text')).toBeInTheDocument();
  });

  it('handles user interactions', () => {
    const mockHandler = vi.fn();
    render(<MyComponent onClick={mockHandler} />);

    fireEvent.click(screen.getByRole('button'));
    expect(mockHandler).toHaveBeenCalled();
  });
});
```

### React Import Requirements

**KRITISCH**: Alle React Components brauchen expliziten React Import für Tests!

```typescript
// ❌ FALSCH: Tests schlagen fehl mit "React is not defined"
import { useState } from 'react';

// ✅ RICHTIG: Tests funktionieren
import React, { useState } from 'react';
```

---

## E2E Tests (Playwright)

### Setup
- **Framework**: Playwright v1.57.0
- **Execution**: 100% Docker-basiert
- **Network**: `lg-internal` (Docker Network)
- **Base URL**: `http://traefik` (nicht localhost!)

### Tests ausführen

**✅ Empfohlen (Shell-Script):**
```bash
cd lg-e2e-tests

# Build E2E Image (einmalig)
docker build -t lg-e2e-tests:latest .

# Alle Tests (3 Workers)
./run-tests.sh

# Spezifische Test-Datei
./run-tests.sh tests/auth/login.spec.ts

# Mit Grep-Filter
./run-tests.sh tests/admin/menu-administration.spec.ts --grep "reset"

# Mit mehr Workers
WORKERS=6 ./run-tests.sh

# Debugging (1 Worker, sequentiell)
./run-tests.sh tests/ --workers=1
```

**Manuell (für Custom-Optionen):**
```bash
docker run --rm --network lg-internal \
  -v $(pwd)/tests:/app/tests \
  -v $(pwd)/playwright.config.ts:/app/playwright.config.ts \
  -v $(pwd)/test-results:/app/test-results \
  -e PLAYWRIGHT_BASE_URL=http://traefik \
  lg-e2e-tests:latest npm test -- tests/auth/login.spec.ts --workers=3
```

### Test-Ergebnisse
- **43/46 passing (93.5%)**
- **3 skipped** (RBAC Features noch nicht implementiert)
- Screenshots: `test-results/*/test-failed-*.png`
- Videos: `test-results/*/video.webm`

### Module Federation für E2E Tests

**Problem**: Statische Remote URLs funktionieren nicht in Docker.

**❌ Falsch:**
```typescript
remotes: {
  userAdmin: 'http://localhost:81/admin/user/assets/remoteEntry.js',
}
```

**✅ Richtig (Promise-based Dynamic Remotes):**
```typescript
// lg-admin-shell/vite.config.ts
remotes: {
  userAdmin: {
    external: `Promise.resolve((window.__REMOTE_BASE_URL__ || 'http://localhost:81') + '/admin/user/assets/remoteEntry.js')`,
    externalType: 'promise'
  },
}
```

**Playwright Helper:**
```typescript
// tests/helpers/auth.ts
export async function injectRemoteBaseURL(page: Page): Promise<void> {
  await page.addInitScript(() => {
    const baseURL = new URL(window.location.href);
    (window as any).__REMOTE_BASE_URL__ = `${baseURL.protocol}//${baseURL.host}`;
  });
}

// Im Test: VOR page.goto() aufrufen!
test.beforeEach(async ({ page }) => {
  await injectRemoteBaseURL(page);
});
```

**Vite Config Requirements:**
```typescript
preview: {
  allowedHosts: ['traefik', 'localhost', 'host.docker.internal'],
  port: 3000,
  host: true,
  cors: true,
}
```

### UI Testing Best Practices

**Vollständiger Test-Flow:**
1. ✅ Screenshot vorher (Initial State)
2. ✅ Aktion ausführen (Click, Drag, Type)
3. ✅ Network Request prüfen (200 OK?)
4. ✅ Screenshot nachher (Updated State)
5. ✅ Console Errors prüfen
6. ✅ Datenbank verifizieren (optional)

**Network Tracking ist kritisch:**
```typescript
// Nach jeder Änderung: Network prüfen!
await click(saveButton);

const requests = await read_network_requests(tabId, urlPattern: '/api/rbac');
const saveRequest = requests.find(r => r.method === 'POST' && r.statusCode === 200);

if (!saveRequest) {
  throw new Error('Save request failed!');
}
```

---

## Test Coverage Metriken

### lg-admin-ui (Aktuelle Coverage)
```
Statements:   90.11% (Ziel: 85%) ✅
Branches:     77.50% (Ziel: 75%) ✅
Functions:    91.04% (Ziel: 85%) ✅
Lines:        93.28% (Ziel: 85%) ✅
```

**Breakdown:**
- Components: 83% (CollapsibleMenu, UserDropdown, Toast, Modal, ConfirmDialog)
- Layouts: 90% (BaseLayout, AdminLayout)
- Hooks: 100% (useToast)

**Fehlende Branches (ca. 7.5%):**
- Type Guards (`typeof icon === 'function'`)
- Null Checks (`if (!Icon) return null`)
- Keyboard Event Handlers (Escape Key)
- Error Handling Paths

**Warum nicht 85% Branches?**
- Edge Cases testen, die nie feilen (Type Guards)
- Diminishing Returns (viel Aufwand, wenig Nutzen)
- 77.5% ist **über** Industrie-Durchschnitt (74-76%)

---

## Troubleshooting

Für detaillierte Fehlerbehebung siehe **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)**:
- Vitest Errors (React not defined, Test timeout, Module not found)
- Playwright Issues (Network failed, remoteEntry 404)
- Debug Commands (verbose mode, screenshots)

---

## Test-Patterns & Conventions

### Component Tests
- Gruppierung nach Feature/Component
- `describe()` für Component, `it()` für spezifischen Test
- `beforeEach()` für Setup (mock cleanup)
- Mock Functions: `vi.fn()`, nicht `jest.fn()`

### E2E Tests
- Gruppierung nach Feature/Page
- `test.beforeEach()` für Navigation & Auth
- Screenshots bei jeder Assertion (für Debugging)
- Network Requests prüfen bei API-Interaktionen

### Coverage Goals
- Components: 85%+ (Critical UI Logic)
- Utils: 90%+ (Pure Functions)
- Hooks: 90%+ (Reusable Logic)
- Layouts: 80%+ (Less critical, mehr UI-focused)

---

## Best Practices Quellen

**Test Coverage:**
- [Google Testing Blog: Code Coverage Best Practices](https://testing.googleblog.com/2020/08/code-coverage-best-practices.html)
- [The Coder Cafe: Using Judgment Over Rigid Goals](https://read.thecoder.cafe/p/code-coverage)
- [LaunchDarkly: What Code Coverage Is and Why It Matters](https://launchdarkly.com/blog/code-coverage-what-it-is-and-why-it-matters/)

**Module Federation:**
- [Dynamic Module Federation with Vite](https://medium.com/@lester.sconyers/dynamic-module-federation-with-vite-0bce2bfcc517)
- [vite-plugin-federation Discussions #193](https://github.com/originjs/vite-plugin-federation/discussions/193)
