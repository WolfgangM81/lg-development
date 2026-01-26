#!/bin/bash
# =============================================================================
# Setup Proxy Domains for lg-development
# Supports: OrbStack, Docker Desktop, Colima
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     🌐 LG-Development Proxy Domains Setup                    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# =============================================================================
# Detect Docker Environment
# =============================================================================
detect_docker_env() {
    if docker info 2>/dev/null | grep -q "orbstack"; then
        echo "orbstack"
    elif docker info 2>/dev/null | grep -q "Docker Desktop"; then
        echo "docker-desktop"
    elif docker info 2>/dev/null | grep -q "colima"; then
        echo "colima"
    else
        echo "unknown"
    fi
}

DOCKER_ENV=$(detect_docker_env)
echo -e "🐳 Docker Environment: ${GREEN}${DOCKER_ENV}${NC}"
echo ""

# =============================================================================
# Check /etc/hosts entries
# =============================================================================
DOMAINS="admin.lg.local api.lg.local traefik.lg.local"
HOSTS_MISSING=()

echo "📋 Checking /etc/hosts entries..."
for domain in $DOMAINS; do
    if grep -q "$domain" /etc/hosts 2>/dev/null; then
        echo -e "   ✅ $domain"
    else
        echo -e "   ❌ $domain ${YELLOW}(missing)${NC}"
        HOSTS_MISSING+=("$domain")
    fi
done
echo ""

# =============================================================================
# Add missing /etc/hosts entries
# =============================================================================
if [ ${#HOSTS_MISSING[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Missing /etc/hosts entries detected${NC}"
    echo ""
    echo "   Add these entries to /etc/hosts:"
    echo ""
    echo -e "   ${BLUE}# LicenseGuard Development${NC}"
    for domain in "${HOSTS_MISSING[@]}"; do
        echo "   127.0.0.1   $domain"
    done
    echo ""

    read -p "   Add entries automatically? (requires sudo) [y/N]: " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "" | sudo tee -a /etc/hosts > /dev/null
        echo "# LicenseGuard Development" | sudo tee -a /etc/hosts > /dev/null
        for domain in "${HOSTS_MISSING[@]}"; do
            echo "127.0.0.1   $domain" | sudo tee -a /etc/hosts > /dev/null
        done
        echo -e "   ${GREEN}✅ Entries added${NC}"
    else
        echo -e "   ${YELLOW}⏭️  Skipped - add manually${NC}"
    fi
    echo ""
fi

# =============================================================================
# Check Port 80 availability
# =============================================================================
echo "🔌 Checking Port 80..."
PORT_80_PROCESS=$(lsof -i :80 2>/dev/null | grep LISTEN | head -1 | awk '{print $1}')

if [ -z "$PORT_80_PROCESS" ]; then
    echo -e "   ${GREEN}✅ Port 80 is free${NC}"
    PORT_80_FREE=true
else
    echo -e "   ${YELLOW}⚠️  Port 80 is used by: ${PORT_80_PROCESS}${NC}"
    PORT_80_FREE=false
fi
echo ""

# =============================================================================
# Environment-specific recommendations
# =============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

case "$DOCKER_ENV" in
    "orbstack")
        echo -e "🚀 ${GREEN}OrbStack detected${NC}"
        echo ""
        echo "   OrbStack hat einen eingebauten Reverse Proxy auf Port 80."
        echo "   Das Label 'dev.orbstack.domains' ist bereits konfiguriert."
        echo ""
        echo -e "   ${GREEN}✅ Domains funktionieren automatisch ohne Port:${NC}"
        echo "      http://admin.lg.local/"
        echo "      http://api.lg.local/user/health"
        echo "      http://traefik.lg.local/"
        echo ""
        echo "   Alternative (mit Port):"
        echo "      http://admin.lg.local:8180/"
        ;;

    "docker-desktop")
        echo -e "🐳 ${BLUE}Docker Desktop detected${NC}"
        echo ""
        if [ "$PORT_80_FREE" = true ]; then
            echo -e "   ${GREEN}✅ Port 80 ist frei!${NC}"
            echo ""
            echo "   Für Domains ohne Port, setze in .env.ports:"
            echo "      TRAEFIK_HTTP_PORT=80"
            echo ""
            echo "   Dann: make restart"
            echo ""
            echo "   Danach funktionieren:"
            echo "      http://admin.lg.local/"
            echo "      http://api.lg.local/user/health"
        else
            echo -e "   ${YELLOW}⚠️  Port 80 ist belegt durch: ${PORT_80_PROCESS}${NC}"
            echo ""
            echo "   Optionen:"
            echo "   1. Prozess beenden der Port 80 verwendet"
            echo "   2. Port 8180 verwenden (aktuell konfiguriert):"
            echo "      http://admin.lg.local:8180/"
            echo "      http://api.lg.local:8180/user/health"
        fi
        ;;

    "colima")
        echo -e "🦙 ${BLUE}Colima detected${NC}"
        echo ""
        echo "   Colima verhält sich wie Docker Desktop."
        if [ "$PORT_80_FREE" = true ]; then
            echo "   Port 80 ist frei - setze TRAEFIK_HTTP_PORT=80 in .env.ports"
        else
            echo "   Port 80 ist belegt - verwende Port 8180"
        fi
        ;;

    *)
        echo -e "❓ ${YELLOW}Unbekannte Docker-Umgebung${NC}"
        echo ""
        echo "   Verwende Port 8180:"
        echo "      http://admin.lg.local:8180/"
        ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# =============================================================================
# Test current configuration
# =============================================================================
echo "🧪 Testing current configuration..."
echo ""

# Determine which port to test
if [ -f "$PROJECT_ROOT/.env.ports" ]; then
    source "$PROJECT_ROOT/.env.ports"
fi
TEST_PORT=${TRAEFIK_HTTP_PORT:-8180}

# Test admin
ADMIN_RESULT=$(curl -s -o /dev/null -w "%{http_code}" "http://admin.lg.local:${TEST_PORT}/" 2>/dev/null || echo "000")
if [ "$ADMIN_RESULT" = "200" ]; then
    echo -e "   ✅ admin.lg.local:${TEST_PORT} → ${GREEN}OK${NC}"
else
    echo -e "   ❌ admin.lg.local:${TEST_PORT} → ${RED}FAILED (HTTP $ADMIN_RESULT)${NC}"
fi

# Test API
API_RESULT=$(curl -s -o /dev/null -w "%{http_code}" "http://api.lg.local:${TEST_PORT}/user/health" 2>/dev/null || echo "000")
if [ "$API_RESULT" = "200" ]; then
    echo -e "   ✅ api.lg.local:${TEST_PORT}/user/health → ${GREEN}OK${NC}"
else
    echo -e "   ❌ api.lg.local:${TEST_PORT}/user/health → ${RED}FAILED (HTTP $API_RESULT)${NC}"
fi

# Test Traefik
TRAEFIK_RESULT=$(curl -s -o /dev/null -w "%{http_code}" "http://traefik.lg.local:${TEST_PORT}/api/overview" 2>/dev/null || echo "000")
if [ "$TRAEFIK_RESULT" = "200" ]; then
    echo -e "   ✅ traefik.lg.local:${TEST_PORT} → ${GREEN}OK${NC}"
else
    echo -e "   ❌ traefik.lg.local:${TEST_PORT} → ${RED}FAILED (HTTP $TRAEFIK_RESULT)${NC}"
fi

# Test OrbStack port 80 (if OrbStack)
if [ "$DOCKER_ENV" = "orbstack" ]; then
    echo ""
    echo "   Testing OrbStack Port 80..."
    ADMIN_80=$(curl -s -o /dev/null -w "%{http_code}" "http://admin.lg.local/" 2>/dev/null || echo "000")
    if [ "$ADMIN_80" = "200" ]; then
        echo -e "   ✅ admin.lg.local (Port 80) → ${GREEN}OK${NC}"
    else
        echo -e "   ❌ admin.lg.local (Port 80) → ${YELLOW}Not working (restart Traefik?)${NC}"
    fi
fi

echo ""
echo -e "${GREEN}Setup complete!${NC}"
