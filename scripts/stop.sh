#!/bin/bash
# scripts/stop.sh
#
# Stop all LG services

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/lib/common.sh"

if [ ! -f "${ROOT_DIR}/docker-compose.yml" ]; then
    info "No docker-compose.yml found - nothing to stop"
    exit 0
fi

print_header "Stopping Services"

docker compose down

echo ""
success "All services stopped"
