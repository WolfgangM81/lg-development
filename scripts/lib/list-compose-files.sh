#!/bin/bash
# scripts/lib/list-compose-files.sh
#
# Generate list of -f flags for docker-compose
# Output: -f repos/infrastructure/lg-traefik/docker-compose.yml -f ... ...
#
# Searches both legacy flat structure (repos/<name>/) and current nested
# structure (repos/infrastructure/, repos/services/, repos/ui/).

set -e

COMPOSE_FILES=""

# Helper function to add a compose file if it exists and hasn't been added.
add_compose_file() {
    local file=$1
    # Skip if file doesn't exist
    [ -f "$file" ] || return
    # Skip if already added (avoids dupes between auto-discovery and explicit lookups)
    case " $COMPOSE_FILES " in
        *" -f $file "*) return ;;
    esac
    COMPOSE_FILES="$COMPOSE_FILES -f $file"
}

# Helper: try multiple paths for a named repo, take the first that exists.
find_repo_compose() {
    local repo=$1
    # Possible locations in priority order
    for candidate in \
        "repos/${repo}/docker-compose.yml" \
        "repos/infrastructure/${repo}/docker-compose.yml" \
        "repos/services/${repo}/docker-compose.yml" \
        "repos/ui/${repo}/docker-compose.yml" \
    ; do
        if [ -f "$candidate" ]; then
            echo "$candidate"
            return
        fi
    done
}

# Layer 0: Infrastructure (fixed order for dependencies)
INFRA_ORDER=(
    "lg-traefik"
    "lg-postgres"
    "lg-redis"
    "lg-dynamodb"
    "lg-verdaccio"
    "lg-monitoring"
)

for repo in "${INFRA_ORDER[@]}"; do
    found=$(find_repo_compose "$repo")
    [ -n "$found" ] && add_compose_file "$found"
done

# Layer 1: Backend services — discover all repos/services/lg-*-service/
if [ -d "repos/services" ]; then
    for service_dir in repos/services/lg-*-service/; do
        [ -d "$service_dir" ] && add_compose_file "${service_dir}docker-compose.yml"
    done
fi
# Legacy fallback (flat layout)
for service_dir in repos/lg-*-service/; do
    [ -d "$service_dir" ] && add_compose_file "${service_dir}docker-compose.yml"
done

# Layer 2: Frontend / UI — discover repos/ui/lg-*/
if [ -d "repos/ui" ]; then
    for ui_dir in repos/ui/lg-*/; do
        [ -d "$ui_dir" ] && add_compose_file "${ui_dir}docker-compose.yml"
    done
fi
# Legacy fallback (named single repos)
for repo in lg-admin lg-management lg-admin-ui; do
    found=$(find_repo_compose "$repo")
    [ -n "$found" ] && add_compose_file "$found"
done

# Output (trim leading space)
echo "${COMPOSE_FILES# }"
