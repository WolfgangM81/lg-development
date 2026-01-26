#!/bin/bash
# scripts/start.sh
#
# Start LG services using generated docker-compose.yml
# Detects free ports and starts all services with a single docker compose up

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/lib/common.sh"

print_header "Starting Services"

# Step 1: Check docker-compose.yml exists
if [ ! -f "${ROOT_DIR}/docker-compose.yml" ]; then
    warning "docker-compose.yml not found!"
    echo ""
    info "Generating docker-compose.yml..."
    if command -v python3 &>/dev/null; then
        python3 "${SCRIPT_DIR}/lib/collect-compose.py"
    else
        die "python3 not found. Run 'make prepare' first or install Python 3."
    fi
fi

# Step 2: Detect free ports
print_step "Detecting available ports..."
bash "${SCRIPT_DIR}/lib/detect-ports.sh"
echo ""

# Step 3: Load environment
if [ -f "${ROOT_DIR}/.env" ]; then
    set -a
    source "${ROOT_DIR}/.env"
    set +a
fi

if [ -f "${ROOT_DIR}/.env.ports" ]; then
    set -a
    source "${ROOT_DIR}/.env.ports"
    set +a
fi

# Build DATABASE_URL and REDIS_URL from components
export DATABASE_URL="postgres://${POSTGRES_USER:-licenseguard}:${POSTGRES_PASSWORD:-changeme}@postgres:5432/${POSTGRES_DB:-licenseguard}"
export REDIS_URL="redis://:${REDIS_PASSWORD:-changeme}@redis:6379"
export NODE_ENV="${NODE_ENV:-development}"

# Step 4: Start all services
print_step "Starting all services..."
docker compose \
    --env-file "${ROOT_DIR}/.env" \
    --env-file "${ROOT_DIR}/.env.ports" \
    up -d --build 2>&1

echo ""

# Step 5: Show status
print_step "Service Status"
echo ""

docker ps --filter "name=lg-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || true

echo ""

# Step 6: Print access info
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Access Services"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  ${GREEN}Traefik Dashboard:${NC} http://localhost:${TRAEFIK_DASHBOARD_PORT:-8080}"
echo -e "  ${GREEN}Traefik HTTP:${NC}      http://localhost:${TRAEFIK_HTTP_PORT:-80}"
echo ""
echo -e "  ${GREEN}PostgreSQL:${NC}        localhost:${POSTGRES_PORT:-5432}"
echo -e "  ${GREEN}Redis:${NC}             localhost:${REDIS_PORT:-6379}"
echo -e "  ${GREEN}Verdaccio:${NC}         http://localhost:${VERDACCIO_PORT:-4873}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
info "View logs:    ${CYAN}make logs${NC}"
info "Check status: ${CYAN}make status${NC}"
info "Stop all:     ${CYAN}make stop${NC}"
echo ""
