#!/bin/bash
# scripts/setup-semantic-release.sh
#
# Setup semantic versioning with conventional commits for packages

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "Setting up Semantic Release"

# Packages to configure
PACKAGES=(
    "lg-menu-registry"
    "lg-admin-ui"
)

CONFIGURED=0
SKIPPED=0

for package in "${PACKAGES[@]}"; do
    dir="repos/$package"

    if [ ! -d "$dir" ]; then
        warning "$package - directory not found"
        ((SKIPPED++))
        continue
    fi

    print_step "Configuring $package"

    # Copy semantic-release config
    cp templates/semantic-release-config.js "$dir/.releaserc.js"

    # Copy commitlint config
    cp templates/commitlint.config.js "$dir/commitlint.config.js"

    # Update workflow
    mkdir -p "$dir/.github/workflows"
    cp templates/semantic-release-workflow.yml.template "$dir/.github/workflows/release.yml"

    # Add devDependencies to package.json
    if command -v jq > /dev/null 2>&1; then
        jq '.devDependencies += {
            "semantic-release": "^24.2.0",
            "@semantic-release/changelog": "^6.0.3",
            "@semantic-release/git": "^10.0.1",
            "@semantic-release/github": "^11.0.0",
            "conventional-changelog-conventionalcommits": "^8.0.0",
            "@commitlint/cli": "^19.0.0",
            "@commitlint/config-conventional": "^19.0.0"
        }' "$dir/package.json" > "$dir/package.json.tmp"
        mv "$dir/package.json.tmp" "$dir/package.json"
    fi

    # Create/update .gitignore
    if ! grep -q "CHANGELOG.md" "$dir/.gitignore" 2>/dev/null; then
        echo "" >> "$dir/.gitignore"
        echo "# Semantic Release" >> "$dir/.gitignore"
        echo "CHANGELOG.md" >> "$dir/.gitignore"
    fi

    success "$package configured"
    ((CONFIGURED++))
done

echo ""
print_header "Configuration Summary"
echo "  ${GREEN}✅ Configured: $CONFIGURED${NC}"
echo "  ${YELLOW}⊘ Skipped:    $SKIPPED${NC}"
echo ""

if [ $CONFIGURED -eq 0 ]; then
    warning "No packages were configured"
    exit 0
fi

success "Semantic Release configured!"
echo ""
info "Conventional Commits Format:"
echo "  feat: neue funktion          → minor version bump (1.0.0 → 1.1.0)"
echo "  fix: bug fix                 → patch version bump (1.0.0 → 1.0.1)"
echo "  feat!: breaking change       → major version bump (1.0.0 → 2.0.0)"
echo "  BREAKING CHANGE: in body     → major version bump"
echo ""
info "Branches:"
echo "  main    → stable release (1.0.0, 1.1.0, 2.0.0)"
echo "  develop → pre-release (1.1.0-beta.1, 1.1.0-beta.2)"
echo ""
info "Next steps:"
echo "  1. Install dependencies: cd repos/<package> && docker run --rm -v \$(pwd):/app -w /app node:20-alpine npm install"
echo "  2. Commit configs: git add . && git commit -m 'chore: setup semantic release'"
echo "  3. Push to GitHub: git push"
echo "  4. Use conventional commits: git commit -m 'feat: add new feature'"
