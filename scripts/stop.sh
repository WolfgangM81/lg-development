#!/bin/bash
# scripts/stop.sh
#
# Stop all services

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

COMPOSE_FILES=$("${SCRIPT_DIR}/lib/list-compose-files.sh" 2>/dev/null || echo "")

if [ -z "$COMPOSE_FILES" ]; then
    info "No services running"
    exit 0
fi

COMPOSE="docker-compose $COMPOSE_FILES"

print_header "Stopping Services"

$COMPOSE down

echo ""
success "All services stopped"
