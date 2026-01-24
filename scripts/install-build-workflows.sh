#!/bin/bash
# scripts/install-build-workflows.sh
#
# Install build workflows for packages and services

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "Installing Build Workflows"

# Packages get package-build workflow
PACKAGES=(
    "lg-menu-registry"
    "lg-admin-ui"
)

# Services get service-build workflow (Docker)
SERVICES=(
    "lg-user-service"
    "lg-permissions-service"
    "lg-api-keys-service"
    "lg-menu-service"
    "lg-secrets-service"
    "lg-tour-service"
    "lg-admin"
)

INSTALLED=0
SKIPPED=0

# Install package workflows
print_step "Packages"
echo ""

for package in "${PACKAGES[@]}"; do
    dir="repos/$package"

    if [ ! -d "$dir" ]; then
        warning "$package - directory not found"
        ((SKIPPED++))
        continue
    fi

    info "Installing package workflow for $package"

    # Create .github/workflows directory
    mkdir -p "$dir/.github/workflows"

    # Copy package build template
    cp templates/package-build.yml.template "$dir/.github/workflows/build.yml"

    success "$package - package workflow installed"
    ((INSTALLED++))
done

echo ""
print_step "Services"
echo ""

# Install service workflows
for service in "${SERVICES[@]}"; do
    dir="repos/$service"

    if [ ! -d "$dir" ]; then
        warning "$service - directory not found"
        ((SKIPPED++))
        continue
    fi

    info "Installing service workflow for $service"

    # Create .github/workflows directory
    mkdir -p "$dir/.github/workflows"

    # Copy service build template
    cp templates/service-build.yml.template "$dir/.github/workflows/build.yml"

    success "$service - service workflow installed"
    ((INSTALLED++))
done

echo ""
print_header "Installation Summary"
echo "  ${GREEN}✅ Installed: $INSTALLED${NC}"
echo "  ${YELLOW}⊘ Skipped:   $SKIPPED${NC}"
echo ""

if [ $INSTALLED -eq 0 ]; then
    warning "No workflows were installed"
    exit 0
fi

success "Build workflows installed!"
echo ""
info "Next steps:"
echo "  1. Review workflows: cat repos/<repo>/.github/workflows/build.yml"
echo "  2. Commit and push: cd repos/<repo> && git add .github && git commit && git push"
echo ""
info "Workflows will trigger on:"
echo "  - Push to main → Build, test, publish/push"
echo "  - Push to develop → Build and test only"
echo "  - Manual trigger → workflow_dispatch"
