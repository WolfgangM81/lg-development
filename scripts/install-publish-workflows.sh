#!/bin/bash
# scripts/install-publish-workflows.sh
#
# Install publish workflows in all package repositories

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "Installing Publish Workflows"

# Packages that should auto-publish
PACKAGES=(
    "lg-menu-registry"
    "lg-admin-ui"
)

INSTALLED=0
SKIPPED=0

for package in "${PACKAGES[@]}"; do
    dir="repos/$package"

    if [ ! -d "$dir" ]; then
        warning "$package - directory not found"
        ((SKIPPED++))
        continue
    fi

    print_step "Installing workflow for $package"

    # Create .github/workflows directory
    mkdir -p "$dir/.github/workflows"

    # Copy template
    cp templates/publish-workflow.yml.template "$dir/.github/workflows/publish.yml"

    success "$package - workflow installed"
    ((INSTALLED++))

    # Git commit
    if [ -d "$dir/.git" ]; then
        (cd "$dir" && \
            git add .github/workflows/publish.yml && \
            git diff --cached --quiet || \
            git commit -m "chore: add auto-publish workflow

- Publishes to GitHub Packages on push to main
- Runs tests before publishing
- Creates release tags automatically

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>" || true)

        info "Committed to git"
    fi

    echo ""
done

# Summary
print_header "Installation Summary"
echo "  ${GREEN}✅ Installed: $INSTALLED${NC}"
echo "  ${YELLOW}⊘ Skipped:   $SKIPPED${NC}"
echo ""

if [ $INSTALLED -eq 0 ]; then
    warning "No workflows were installed"
    exit 0
fi

success "Workflows installed!"
echo ""
info "Next steps:"
echo "  1. Review workflows: cat repos/<package>/.github/workflows/publish.yml"
echo "  2. Push to GitHub: cd repos/<package> && git push"
echo "  3. On next push to main → automatic publish to GitHub Packages"
