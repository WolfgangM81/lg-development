#!/bin/bash
# scripts/logs.sh
#
# View LG service logs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/lib/common.sh"

if [ ! -f "${ROOT_DIR}/docker-compose.yml" ]; then
    die "No docker-compose.yml found! Run 'make prepare' first"
fi

SERVICE=${1:-}

if [ -n "$SERVICE" ]; then
    info "Viewing logs for: $SERVICE"
    echo ""
    docker compose logs -f "$SERVICE"
else
    info "Viewing logs for all services"
    echo "  Tip: Use 'make logs SERVICE=name' for specific service"
    echo ""
    docker compose logs -f
fi
