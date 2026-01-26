#!/bin/bash
# scripts/prepare.sh
#
# Clone all repositories from GitHub

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Check .env exists
if [ ! -f .env ]; then
    die ".env not found! Run 'make setup' first"
fi

source .env

print_header "Preparing Repositories"

GITHUB_USER="${GITHUB_USER:-WolfgangM81}"
CLONED=0
SKIPPED=0
FAILED=0

# Infrastructure repositories
print_step "Infrastructure"

INFRA_REPOS=(
    "lg-traefik"
    "lg-postgres"
    "lg-redis"
    "lg-dynamodb"
    "lg-verdaccio"
)

for repo in "${INFRA_REPOS[@]}"; do
    result=$(clone_repo "$repo" "repos" && echo "0" || echo "$?")

    if [ "$result" = "0" ]; then
        ((CLONED++))
    elif [ "$result" = "1" ]; then
        ((SKIPPED++))
    else
        ((FAILED++))
    fi
done

echo ""

# Service repositories
print_step "Services"

SERVICE_REPOS=(
    "lg-user-service"
    "lg-permissions-service"
    "lg-api-keys-service"
    "lg-tour-service"
    "lg-menu-service"
    "lg-secrets-service"
    "lg-admin"
)

for repo in "${SERVICE_REPOS[@]}"; do
    result=$(clone_repo "$repo" "repos" && echo "0" || echo "$?")

    if [ "$result" = "0" ]; then
        ((CLONED++))
    elif [ "$result" = "1" ]; then
        ((SKIPPED++))
    else
        ((FAILED++))
    fi
done

echo ""

# Package repositories
print_step "Packages"

PACKAGE_REPOS=(
    "lg-admin-ui"
    "lg-menu-registry"
    "lg-backend-common"
    "lg-types"
)

for repo in "${PACKAGE_REPOS[@]}"; do
    result=$(clone_repo "$repo" "repos" && echo "0" || echo "$?")

    if [ "$result" = "0" ]; then
        ((CLONED++))
    elif [ "$result" = "1" ]; then
        ((SKIPPED++))
    else
        ((FAILED++))
    fi
done

echo ""

# Initialize Docker networks
print_step "Docker Networks"
"${SCRIPT_DIR}/lib/init-networks.sh"

echo ""

# Generate unified docker-compose.yml
print_step "Generating docker-compose.yml"
if command -v python3 &>/dev/null; then
    python3 "${SCRIPT_DIR}/lib/collect-compose.py"
else
    warning "python3 not found - skipping compose file generation"
    info "Install Python 3 and run: python3 scripts/lib/collect-compose.py"
fi

echo ""

# Summary
print_header "Prepare Summary"
echo "  ✅ Cloned:  $CLONED"
echo "  ⊘ Skipped: $SKIPPED"
echo "  ❌ Failed:  $FAILED"
echo ""

if [ $FAILED -gt 0 ]; then
    warning "Some repositories failed to clone"
    echo ""
    info "This may be because repositories don't exist on GitHub yet"
    info "You can continue with existing repositories"
    echo ""
fi

if [ $CLONED -gt 0 ] || [ $SKIPPED -gt 0 ]; then
    success "Repositories ready!"
    echo ""
    echo "Next steps:"
    echo "  ${CYAN}make start${NC}    # Start all services"
    echo "  ${CYAN}make collect${NC}  # Regenerate docker-compose.yml"
    echo ""
else
    die "No repositories were cloned. Check GitHub authentication and repo existence."
fi
