#!/bin/bash
# scripts/lib/dependency-graph.sh
#
# Build and display dependency graph

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Dependency Graph"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Layer 0: Infrastructure (no dependencies)
echo -e "${BLUE}Layer 0 (Infrastructure):${NC}"
echo "  ├─ lg-traefik"
echo "  ├─ lg-postgres"
echo "  ├─ lg-redis"
echo "  ├─ lg-dynamodb"
echo "  └─ lg-verdaccio"
echo ""

# Layer 1: Services (depend on infrastructure)
echo -e "${BLUE}Layer 1 (Services):${NC}"

# Check which services exist
SERVICES=()
for service_dir in repos/lg-*-service/; do
    if [ -d "$service_dir" ]; then
        service_name=$(basename "$service_dir")
        SERVICES+=("$service_name")
    fi
done

for i in "${!SERVICES[@]}"; do
    local service="${SERVICES[$i]}"
    if [ $i -eq $((${#SERVICES[@]} - 1)) ]; then
        echo "  └─ $service → depends on: postgres, redis, traefik"
    else
        echo "  ├─ $service → depends on: postgres, redis, traefik"
    fi
done

echo ""

# Layer 2: Frontend (depends on services)
echo -e "${BLUE}Layer 2 (Frontend):${NC}"
if [ -d "repos/lg-admin" ]; then
    echo "  └─ lg-admin → depends on: user-service, permissions-service"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
