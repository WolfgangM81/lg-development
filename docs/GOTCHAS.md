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

**Key Takeaway:** Root Cause Analysis > Trial & Error!
