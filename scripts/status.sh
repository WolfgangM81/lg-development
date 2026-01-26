#!/bin/bash
# scripts/status.sh
#
# Show LG service status

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/lib/common.sh"

if [ ! -f "${ROOT_DIR}/docker-compose.yml" ]; then
    warning "No docker-compose.yml found"
    echo ""
    info "Run 'make prepare' to clone repositories and generate compose file"
    exit 0
fi

print_header "Service Status"

docker compose ps

echo ""

# Count services
RUNNING=$(docker ps --format '{{.Names}}' | grep -c '^lg-' 2>/dev/null || echo "0")
TOTAL=$(docker ps -a --format '{{.Names}}' | grep -c '^lg-' 2>/dev/null || echo "0")

if [ "$RUNNING" -eq 0 ]; then
    warning "No services running"
    echo ""
    info "Start services with: ${CYAN}make start${NC}"
elif [ "$RUNNING" -eq "$TOTAL" ]; then
    success "All $RUNNING services are running"
else
    warning "$RUNNING of $TOTAL services are running"
    echo ""
    info "Some services may have failed. Check logs: ${CYAN}make logs${NC}"
fi

echo ""
