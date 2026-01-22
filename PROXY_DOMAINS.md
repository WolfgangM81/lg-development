# Proxy Domains - LG Development Environment

## 📋 Übersicht

Die lg-development Umgebung bietet **lokale Proxy-Domains ohne Ports** für alle Services.

**Vorteile:**
- ✅ Keine Ports in URLs (z.B. `http://admin.lg.local` statt `http://localhost:81`)
- ✅ Saubere URLs für Frontend/Backend Entwicklung
- ✅ Service-Isolation (eigene Domain pro Service möglich)
- ✅ Traefik Dashboard unter eigener Domain

---

## 🌐 Verfügbare Domains

### Frontend
| Domain | Service | Beschreibung |
|--------|---------|--------------|
| `http://admin.lg.local` | Admin UI | Konsolidierte Admin-Oberfläche |
| `http://traefik.lg.local` | Traefik Dashboard | Traefik Monitoring & Routing-Übersicht |

### Backend (API Gateway)
| Domain | Service | Beschreibung |
|--------|---------|--------------|
| `http://api.lg.local/user` | User Service | User & Authentication Management |
| `http://api.lg.local/permissions` | Permissions Service | RBAC & DAG Permissions |
| `http://api.lg.local/rbac` | Permissions Service | RBAC Endpoints |
| `http://api.lg.local/v1` | API Keys Service | Public API Key Validation |
| `http://api.lg.local/tour` | Tour Service | NextStepjs Integration |
| `http://api.lg.local/menu` | Menu Service | Hierarchical Menu Management |
| `http://api.lg.local/secrets` | Secrets Service | Encrypted Secrets Management |
| `http://api.lg.local/audit` | Secrets Service | Audit Log Endpoints |

**Hinweis:** Backend-Services sind auch unter `http://localhost/api/*` erreichbar (für Legacy-Kompatibilität).

---

## ⚙️ Setup

### 1. Hosts-Datei konfigurieren

**macOS/Linux:**
```bash
sudo sh -c 'echo "
# LG Development Environment
127.0.0.1 admin.lg.local
127.0.0.1 api.lg.local
127.0.0.1 traefik.lg.local
" >> /etc/hosts'
```

**Windows:**
```powershell
# Als Administrator ausführen
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "
# LG Development Environment
127.0.0.1 admin.lg.local
127.0.0.1 api.lg.local
127.0.0.1 traefik.lg.local
"
```

### 2. Stack starten

```bash
cd lg-development
docker-compose up -d
```

**Wichtig:** Traefik läuft jetzt auf Port **80** (nicht mehr 81!).

### 3. Verifizieren

```bash
# Admin UI
curl -I http://admin.lg.local

# API Gateway
curl http://api.lg.local/user/health

# Traefik Dashboard
open http://traefik.lg.local
```

---

## 🔧 Routing-Details

### Host-basiertes Routing (Proxy Domains)

Traefik verwendet `Host()` Regeln für Domains:

```yaml
# traefik/dynamic.yml
routers:
  admin-domain:
    rule: Host(`admin.lg.local`)
    service: admin-ui
    priority: 100

  api-gateway-domain:
    rule: Host(`api.lg.local`)
    service: admin-ui  # API Gateway unter api.lg.local
    priority: 100
```

**Priority 100** = Host-basierte Rules haben Vorrang vor Path-basierten Rules.

### Path-basiertes Routing (Legacy)

Weiterhin verfügbar unter `localhost`:

```yaml
routers:
  api-user:
    rule: PathPrefix(`/api/user`)
    service: user-service
```

Beide Routing-Arten funktionieren **parallel**:
- `http://admin.lg.local` → Admin UI
- `http://localhost/` → Admin UI
- `http://api.lg.local/user` → User Service
- `http://localhost/api/user` → User Service

---

## 🧪 Testing

### Health Checks

```bash
# Mit Proxy Domains
curl http://api.lg.local/user/health
curl http://api.lg.local/permissions/health
curl http://api.lg.local/v1/health
curl http://api.lg.local/tour/health

# Mit localhost (Legacy)
curl http://localhost/api/user/health
curl http://localhost/api/permissions/health
```

### Browser-Tests

1. **Admin UI:** http://admin.lg.local
   - Login-Seite sollte laden
   - Assets ohne 404-Fehler

2. **Traefik Dashboard:** http://traefik.lg.local
   - Übersicht aller Routers und Services
   - Health Checks der Services

3. **API Gateway:** http://api.lg.local/user/health
   - JSON Response: `{"status": "healthy", "service": "user-service"}`

---

## 🐛 Troubleshooting

### "Site not found" oder "Connection refused"

**Problem:** Domain wird nicht aufgelöst oder Traefik läuft nicht.

**Lösung:**
```bash
# 1. Hosts-Datei prüfen
cat /etc/hosts | grep lg.local

# 2. Traefik Status prüfen
docker ps | grep traefik

# 3. Traefik Port prüfen (sollte 80 sein)
docker port lg-infra-traefik

# 4. Traefik neu starten
docker-compose restart traefik
```

### Domain funktioniert, aber 404-Fehler

**Problem:** Routing-Regel fehlt in `traefik/dynamic.yml`.

**Lösung:**
```bash
# 1. Dynamic Config prüfen
cat traefik/dynamic.yml | grep -A5 "admin-domain"

# 2. Traefik Logs prüfen
docker logs lg-infra-traefik --tail 50

# 3. Traefik neu starten (lädt dynamic.yml neu)
docker-compose restart traefik
```

### Port 80 bereits belegt

**Problem:** Anderer Dienst läuft auf Port 80 (z.B. Apache, nginx).

**Option A: Anderen Dienst stoppen**
```bash
# macOS (Apache)
sudo apachectl stop

# Linux (nginx)
sudo systemctl stop nginx
```

**Option B: Alternativen Port nutzen**
```yaml
# docker-compose.yml
traefik:
  ports:
    - "8080:80"  # Traefik auf 8080
```

Dann URLs anpassen: `http://admin.lg.local:8080`

---

## 📚 Weitere Proxy-Domains hinzufügen

### Beispiel: Neue Service-Domain

1. **Hosts-Datei erweitern:**
   ```bash
   echo "127.0.0.1 myservice.lg.local" | sudo tee -a /etc/hosts
   ```

2. **Traefik Routing hinzufügen:**
   ```yaml
   # traefik/dynamic.yml
   routers:
     myservice-domain:
       entryPoints:
         - web
       rule: Host(`myservice.lg.local`)
       priority: 100
       service: my-service

   services:
     my-service:
       loadBalancer:
         servers:
           - url: http://my-service-container:3000
   ```

3. **Traefik neu starten:**
   ```bash
   docker-compose restart traefik
   ```

---

## 🔒 HTTPS (Optional)

Für lokale HTTPS-Entwicklung:

### 1. Self-Signed Certificates generieren

```bash
# In traefik/ Verzeichnis
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout cert.key \
  -out cert.crt \
  -subj "/CN=*.lg.local"
```

### 2. Traefik Config erweitern

```yaml
# traefik/traefik.yml
entryPoints:
  websecure:
    address: ":443"

# traefik/dynamic.yml
tls:
  certificates:
    - certFile: /etc/traefik/cert.crt
      keyFile: /etc/traefik/cert.key
```

### 3. Docker Compose Volumes

```yaml
traefik:
  volumes:
    - ./traefik/cert.crt:/etc/traefik/cert.crt:ro
    - ./traefik/cert.key:/etc/traefik/cert.key:ro
```

Dann sind Services unter `https://admin.lg.local` erreichbar.

---

## 📝 Best Practices

1. **Immer Proxy-Domains für Entwicklung verwenden**
   - Saubere URLs ohne Ports
   - Besser für Frontend API-Calls
   - Simulation der Production-Umgebung

2. **localhost als Fallback**
   - Path-basiertes Routing bleibt verfügbar
   - Für Legacy-Code oder CI/CD

3. **Traefik Dashboard überwachen**
   - http://traefik.lg.local zeigt alle aktiven Routers
   - Debugging von Routing-Problemen

4. **/etc/hosts regelmäßig aufräumen**
   - Alte/ungenutzte Domains entfernen
   - Kommentare für bessere Übersicht

---

## 🎯 Quick Reference

| Zugriff | Domain (ohne Port) | Legacy (mit Port) |
|---------|-------------------|-------------------|
| Admin UI | `http://admin.lg.local` | `http://localhost:80` |
| User API | `http://api.lg.local/user` | `http://localhost:80/api/user` |
| Permissions API | `http://api.lg.local/permissions` | `http://localhost:80/api/permissions` |
| API Keys | `http://api.lg.local/v1` | `http://localhost:80/api/v1` |
| Tour Service | `http://api.lg.local/tour` | `http://localhost:80/api/tour` |
| Menu Service | `http://api.lg.local/menu` | `http://localhost:80/api/menu` |
| Secrets | `http://api.lg.local/secrets` | `http://localhost:80/api/secrets` |
| Traefik Dashboard | `http://traefik.lg.local` | `http://localhost:8080` |

**Alle URLs funktionieren OHNE Port-Angabe!** 🎉
