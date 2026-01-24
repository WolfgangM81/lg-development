#!/bin/bash
# scripts/publish-packages.sh
#
# Publish all packages to GitHub Packages

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "Publishing Packages to GitHub"

# Check GitHub CLI is authenticated
if ! gh auth status > /dev/null 2>&1; then
    die "GitHub CLI not authenticated! Run: gh auth login"
fi

# Get GitHub token
GITHUB_TOKEN=$(gh auth token)

if [ -z "$GITHUB_TOKEN" ]; then
    die "Failed to get GitHub token"
fi

# Packages to publish (libraries only)
PACKAGES=(
    "lg-menu-registry"
    "lg-admin-ui"
)

PUBLISHED=0
FAILED=0
SKIPPED=0

for package in "${PACKAGES[@]}"; do
    dir="repos/$package"

    if [ ! -d "$dir" ]; then
        warning "$package - directory not found"
        ((SKIPPED++))
        continue
    fi

    if [ ! -f "$dir/package.json" ]; then
        warning "$package - no package.json"
        ((SKIPPED++))
        continue
    fi

    print_step "Publishing $package"

    # Create .npmrc
    cat > "$dir/.npmrc" << EOF
@wolfgangm81:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=${GITHUB_TOKEN}
EOF

    # Check if already published
    PACKAGE_NAME=$(jq -r '.name' "$dir/package.json")
    PACKAGE_VERSION=$(jq -r '.version' "$dir/package.json")

    info "Package: $PACKAGE_NAME@$PACKAGE_VERSION"

    # Try to publish
    if (cd "$dir" && npm publish 2>&1); then
        success "$package published successfully"
        ((PUBLISHED++))
    else
        error "$package failed to publish"
        ((FAILED++))
    fi

    # Clean up .npmrc (contains token)
    rm -f "$dir/.npmrc"

    echo ""
done

# Summary
print_header "Publish Summary"
echo "  ${GREEN}✅ Published: $PUBLISHED${NC}"
echo "  ${RED}❌ Failed:    $FAILED${NC}"
echo "  ${YELLOW}⊘ Skipped:   $SKIPPED${NC}"
echo ""

if [ $FAILED -gt 0 ]; then
    die "$FAILED package(s) failed to publish"
fi

if [ $PUBLISHED -eq 0 ]; then
    warning "No packages were published"
    exit 0
fi

success "All packages published!"
echo ""
info "Install with: npm install @wolfgangm81/<package-name>"
