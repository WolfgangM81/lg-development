#!/bin/bash
# scripts/setup-github-registry.sh
#
# Configure GitHub Packages Registry for all repos

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "Setting up GitHub Packages Registry"

# Check GitHub CLI is authenticated
if ! gh auth status > /dev/null 2>&1; then
    die "GitHub CLI not authenticated! Run: gh auth login"
fi

# Get GitHub token
GITHUB_TOKEN=$(gh auth token)

if [ -z "$GITHUB_TOKEN" ]; then
    die "Failed to get GitHub token"
fi

GITHUB_USER="${GITHUB_USER:-WolfgangM81}"

info "GitHub User: $GITHUB_USER"
info "Token: ${GITHUB_TOKEN:0:10}..."

CONFIGURED=0
SKIPPED=0

# Configure all repos
for dir in repos/*/; do
    [ ! -f "$dir/package.json" ] && continue

    REPO=$(basename "$dir")

    print_step "Configuring $REPO"

    # Create .npmrc
    cat > "$dir/.npmrc" << EOF
# GitHub Packages Registry Configuration
@wolfgangm81:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=\${GITHUB_TOKEN}

# Fallback to npmjs for other packages
registry=https://registry.npmjs.org/

# Always authenticate for @wolfgangm81 scope
always-auth=true
EOF

    # Add .npmrc to .gitignore if not already there
    if [ -f "$dir/.gitignore" ]; then
        if ! grep -q "^\.npmrc$" "$dir/.gitignore"; then
            echo ".npmrc" >> "$dir/.gitignore"
        fi
    else
        echo ".npmrc" > "$dir/.gitignore"
    fi

    # Create .npmrc.example (safe to commit)
    cat > "$dir/.npmrc.example" << EOF
# GitHub Packages Registry Configuration
@wolfgangm81:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=YOUR_GITHUB_TOKEN_HERE

# Fallback to npmjs for other packages
registry=https://registry.npmjs.org/

# Always authenticate for @wolfgangm81 scope
always-auth=true
EOF

    success "$REPO configured"
    ((CONFIGURED++))
done

echo ""
print_header "Configuration Summary"
echo "  ${GREEN}✅ Configured: $CONFIGURED${NC}"
echo "  ${YELLOW}⊘ Skipped:    $SKIPPED${NC}"
echo ""

success "GitHub Registry configured for all repos!"
echo ""
info "Next steps:"
echo "  1. Test package install: cd repos/lg-menu-service && GITHUB_TOKEN=$GITHUB_TOKEN npm install"
echo "  2. Update package.json publishConfig"
echo "  3. Install build workflows: make install-build-workflows"
