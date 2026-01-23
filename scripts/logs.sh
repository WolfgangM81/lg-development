#!/bin/bash
# scripts/logs.sh
#
# View service logs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

SERVICE=${1:-}

COMPOSE_FILES=$("${SCRIPT_DIR}/lib/list-compose-files.sh" 2>/dev/null || echo "")

if [ -z "$COMPOSE_FILES" ]; then
    die "No services found! Run 'make prepare' first"
fi

COMPOSE="docker-compose $COMPOSE_FILES"

if [ -n "$SERVICE" ]; then
    info "Viewing logs for: $SERVICE"
    echo ""
    $COMPOSE logs -f "$SERVICE"
else
    info "Viewing logs for all services"
    echo "  Tip: Use 'make logs SERVICE=name' for specific service"
    echo ""
    $COMPOSE logs -f
fi
