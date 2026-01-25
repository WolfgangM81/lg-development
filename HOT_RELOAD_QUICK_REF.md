# Hot-Reload System - Quick Reference Card

**Status:** ✅ Fully Optimized (2026-01-24)

---

## 🚀 Quick Start

```bash
# Start hot-reload mode
make dev-sync

# Open live dashboard (recommended)
make dev-sync-dashboard

# Edit a package and watch it compile in ~2-3 seconds
vi repos/packages/lg-menu-registry/src/index.ts
```

---

## 📋 Essential Commands

### Daily Workflow
| Command | Description |
|---------|-------------|
| `make dev-sync` | Enable hot-reload (~2-3s updates) |
| `make dev-sync-dashboard` | Live dashboard (real-time status) ⭐ |
| `make dev-sync-check` | Verify all builds are healthy |
| `make dev-normal` | Disable hot-reload (npm versions) |

### Debugging
| Command | Description |
|---------|-------------|
| `make dev-sync-status` | Check builder container status |
| `make dev-sync-logs PACKAGE=name` | View compilation logs |
| `make dev-sync-rebuild` | Restart all builders |
| `make dev-sync-clean` | Clean build artifacts |

### Performance
| Command | Description |
|---------|-------------|
| `make dev-sync-metrics` | Show build performance stats |
| `make dev-sync-metrics-watch` | Watch builds in real-time |
| `make dev-sync-metrics-reset` | Clear metrics |

### Advanced
| Command | Description |
|---------|-------------|
| `make dev-sync-watch` | Auto-restart services (smart) |
| `make dev-sync-test` | Test package loading |
| `make dev-sync-toggle` | Toggle hot-reload on/off |

---

## 🎯 Package Names

Use these names with `PACKAGE=` parameter:

- `menu-registry` - Menu types and registry
- `backend-common` - Shared backend utilities
- `types` - Shared TypeScript types

**Example:**
```bash
make dev-sync-logs PACKAGE=menu-registry
```

---

## 🎨 Dashboard Features

The live dashboard shows:
- ✅ Builder status (Up/Down)
- 📦 Last compilation output
- ❌ Error count from TypeScript
- 📊 Volume size and contents
- ⏱️ Auto-refresh every 2s

```bash
make dev-sync-dashboard
```

---

## 🔍 Health Check Details

Enhanced health checks verify:
1. ✅ `.js` file exists
2. ✅ `.d.ts` file exists (TypeScript declarations)
3. ✅ JavaScript syntax is valid
4. ✅ No compilation errors

---

## 🎯 Smart Service Restarts

When you edit a package, only affected services restart:

| Package Changed | Services Restarted |
|----------------|-------------------|
| `menu-registry` | menu-service only |
| `backend-common` | 5 backend services |
| `types` | All 6 services (all depend) |

**Before:** Edit any package → 6 services restart
**After:** Edit menu-registry → 1 service restarts ⚡

---

## 📊 Performance Metrics

Track build times over time:

```bash
# View aggregated stats
make dev-sync-metrics

# Sample output:
# menu-registry: 2.3s avg (15 builds, 2.0s-3.1s range)
# backend-common: 2.5s avg (12 builds, 2.1s-3.0s range)
# types: 1.8s avg (18 builds, 1.5s-2.2s range)
```

---

## 🐛 Troubleshooting

### "No such file or directory: repos/"
**Fix:** Scripts were using wrong directory
```bash
# Already fixed! Update.sh and status.sh now use repos/
./scripts/dev/update.sh  # Now works
```

### "Health check failed but build succeeded"
**Possible causes:**
- Missing `.d.ts` files
- Invalid JavaScript syntax
- Permission issues

**Debug:**
```bash
make dev-sync-check  # Shows detailed errors
```

### "Service not restarting after package change"
**Check:**
1. Is hot-reload enabled? → `make dev-sync-status`
2. Is builder running? → Look for "Up" status
3. Check logs → `make dev-sync-logs PACKAGE=name`

### "Dashboard not refreshing"
**Note:** `watch` command not installed (optional)
- Dashboard uses manual refresh fallback
- Install `watch`: `brew install watch` (macOS)
- Or use: `make dev-sync-status` for one-time check

---

## 💡 Pro Tips

### 1. Keep Dashboard Open
```bash
# Terminal 1: Dashboard
make dev-sync-dashboard

# Terminal 2: Development
vi repos/packages/lg-menu-registry/src/index.ts
```

### 2. Check Builds Before Commit
```bash
# Ensure no TypeScript errors
make dev-sync-check
```

### 3. Monitor Performance
```bash
# Track if builds are slowing down
make dev-sync-metrics
```

### 4. Smart Restart Saves Time
- Edit single package → Only relevant services restart
- 5-6x faster than restarting everything
- Less noise in logs

---

## 🔗 Related Files

- `docker-compose.dev-sync.yml` - Builder configuration
- `scripts/dev/package-dependencies.json` - Service dependency map
- `OPTIMIZATION_SUMMARY.md` - Full implementation details
- `CLAUDE.md` - Complete development guide

---

## 📦 What Gets Hot-Reloaded?

**Packages (3):**
- `lg-menu-registry` → Menu types, client
- `lg-backend-common` → Shared backend utilities
- `lg-types` → Core TypeScript types

**Services (6):**
- `menu-service`
- `user-service`
- `permissions-service`
- `api-keys-service`
- `secrets-service`
- `tour-service`

**Not included:**
- Frontend apps (admin-ui) - use their own dev servers
- Infrastructure (postgres, redis, traefik)

---

## ⚡ Performance Stats

| Metric | Value |
|--------|-------|
| Typical build time | 2-3 seconds |
| Health check interval | 5 seconds |
| Dashboard refresh | 2 seconds |
| Service restart (targeted) | 1-2 seconds |
| Full volume size | ~2-3 MB |

---

## 🎯 Workflow Example

```bash
# 1. Start your day
make dev-sync
make dev-sync-dashboard  # Keep this open

# 2. Make changes
vi repos/packages/lg-menu-registry/src/menu-types.ts

# 3. Watch dashboard show:
#    ✅ menu-registry: Found 0 errors. Watching...
#    🔄 menu-service restarting...
#    ✅ Done in 2.3s

# 4. Test your changes
curl http://api.lg.local/menu/health

# 5. Before commit
make dev-sync-check  # Ensure no errors

# 6. End of day
make dev-normal      # Or leave running
```

---

## 🚨 Common Mistakes

❌ **Don't do this:**
```bash
# Editing outside of repos/
vi ~/Projects/lg-menu-registry/src/index.ts  # Wrong!
```

✅ **Do this:**
```bash
# Edit inside lg-development/repos/
vi repos/packages/lg-menu-registry/src/index.ts  # Correct!
```

---

❌ **Don't do this:**
```bash
# Committing repos/ to lg-development
git add repos/  # Wrong! (gitignored)
```

✅ **Do this:**
```bash
# Commit inside each package repo
cd repos/packages/lg-menu-registry
git add .
git commit -m "feat: new feature"
git push
```

---

## 📞 Need Help?

1. Check dashboard: `make dev-sync-dashboard`
2. Check for errors: `make dev-sync-check`
3. View logs: `make dev-sync-logs PACKAGE=name`
4. Read full docs: `OPTIMIZATION_SUMMARY.md`
5. Ask in chat! 💬

---

**Happy Hot-Reloading! 🚀**
