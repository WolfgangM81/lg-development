#!/bin/bash
# scripts/status.sh
#
# Show service status

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh" 2>/dev/null || source "${SCRIPT_DIR}/lib/common.sh"

COMPOSE_FILES=$("${SCRIPT_DIR}/lib/list-compose-files.sh" 2>/dev/null || echo "")

if [ -z "$COMPOSE_FILES" ]; then
    warning "No services found"
    echo ""
    info "Run 'make prepare' to clone repositories"
    exit 0
fi

COMPOSE="docker-compose $COMPOSE_FILES"

print_header "Service Status"

$COMPOSE ps

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
