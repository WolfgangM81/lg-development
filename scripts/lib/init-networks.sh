#!/bin/bash
# scripts/lib/init-networks.sh
#
# Initialize Docker networks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Networks to create
NETWORKS=("lg-public" "lg-internal")

echo "🌐 Initializing Docker networks..."
echo ""

for network in "${NETWORKS[@]}"; do
    if docker network inspect "$network" >/dev/null 2>&1; then
        print_substep "$network (already exists)"
    else
        print_substep "Creating $network..."
        if docker network create "$network" >/dev/null; then
            success "$network created"
        else
            error "Failed to create $network"
            exit 1
        fi
    fi
done

echo ""
success "All networks ready!"
