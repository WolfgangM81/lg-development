#!/bin/bash
# scripts/lib/wait-for-health.sh
#
# Wait for services to become healthy

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

MAX_WAIT=${1:-120}

echo "⏳ Waiting for services to become healthy..."
echo ""

# Services with healthchecks
HEALTH_SERVICES=(
    "lg-infra-postgres"
    "lg-infra-redis"
    "lg-backend-user"
    "lg-backend-permissions"
    "lg-backend-api-keys"
    "lg-backend-tour"
    "lg-backend-menu"
    "lg-backend-secrets"
)

WAITED=0
ALL_HEALTHY=false

while [ $WAITED -lt $MAX_WAIT ]; do
    ALL_HEALTHY=true

    for service in "${HEALTH_SERVICES[@]}"; do
        # Check if container exists
        if ! docker ps -a --format '{{.Names}}' | grep -q "^${service}$"; then
            continue  # Skip if not started
        fi

        # Check health status
        health=$(docker inspect --format='{{.State.Health.Status}}' "$service" 2>/dev/null || echo "none")

        if [ "$health" != "healthy" ] && [ "$health" != "none" ]; then
            ALL_HEALTHY=false
            break
        fi
    done

    if [ "$ALL_HEALTHY" = true ]; then
        echo ""
        success "All services are healthy!"
        exit 0
    fi

    sleep 2
    WAITED=$((WAITED + 2))
    echo -n "."
done

echo ""
warning "Some services did not become healthy in ${MAX_WAIT}s"
echo ""
echo "Check status with: make status"
echo "View logs with: make logs"
exit 0  # Don't fail, just warn
