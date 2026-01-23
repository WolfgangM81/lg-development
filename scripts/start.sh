#!/bin/bash
# scripts/start.sh
#
# Start services with dependency resolution

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "Starting Services"

# Build dependency graph
print_step "Analyzing dependencies..."
"${SCRIPT_DIR}/lib/dependency-graph.sh"

echo ""

# Get compose files
COMPOSE_FILES=$("${SCRIPT_DIR}/lib/list-compose-files.sh")

if [ -z "$COMPOSE_FILES" ]; then
    die "No compose files found! Run 'make prepare' first"
fi

COMPOSE="docker-compose $COMPOSE_FILES"

# Start
print_step "Starting services..."
echo ""
info "Command: docker-compose $(echo "$COMPOSE_FILES" | tr ' ' '\n' | head -3 | tr '\n' ' ')... up -d"
echo ""

$COMPOSE up -d

echo ""

# Wait for health
print_step "Waiting for services to be healthy..."
"${SCRIPT_DIR}/lib/wait-for-health.sh" 60

echo ""

# Show status
print_step "Service Status"
$COMPOSE ps

echo ""
success "All services started!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Access Services"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

source .env 2>/dev/null || true

if [ "$USE_PROXY_DOMAINS" = "true" ]; then
    echo ""
    echo "  ${GREEN}Admin UI:${NC}   http://admin.lg.local"
    echo "  ${GREEN}API:${NC}        http://api.lg.local/user/health"
    echo "  ${GREEN}Traefik:${NC}    http://traefik.lg.local"
else
    echo ""
    echo "  ${GREEN}Admin UI:${NC}   http://localhost"
    echo "  ${GREEN}API:${NC}        http://localhost/api/user/health"
    echo "  ${GREEN}Traefik:${NC}    http://localhost:8080"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
info "View logs:   ${CYAN}make logs${NC}"
info "Check status: ${CYAN}make status${NC}"
echo ""
