#!/bin/bash
# scripts/lib/list-compose-files.sh
#
# Generate list of -f flags for docker-compose
# Output: -f repos/lg-traefik/docker-compose.yml -f repos/lg-postgres/docker-compose.yml ...

set -e

COMPOSE_FILES=""

# Helper function to add compose file
add_compose_file() {
    local file=$1
    if [ -f "$file" ]; then
        COMPOSE_FILES="$COMPOSE_FILES -f $file"
    fi
}

# Layer 0: Infrastructure (fixed order for dependencies)
INFRA_ORDER=(
    "lg-traefik"
    "lg-postgres"
    "lg-redis"
    "lg-dynamodb"
    "lg-verdaccio"
)

for repo in "${INFRA_ORDER[@]}"; do
    add_compose_file "repos/${repo}/docker-compose.yml"
done

# Layer 1: Services (auto-discover)
for service_dir in repos/lg-*-service/; do
    if [ -d "$service_dir" ]; then
        add_compose_file "${service_dir}docker-compose.yml"
    fi
done

# Layer 2: Frontend
add_compose_file "repos/lg-admin/docker-compose.yml"
add_compose_file "repos/lg-management/docker-compose.yml"

# Output (trim leading space)
echo "${COMPOSE_FILES# }"
