#!/bin/bash
# scripts/setup-publish-config.sh
#
# Add publishConfig to package.json for GitHub Packages

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "Setting up publishConfig in package.json"

# Packages that should publish to GitHub
PACKAGES=(
    "lg-menu-registry"
    "lg-admin-ui"
)

UPDATED=0
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

    print_step "Updating $package"

    # Use jq to add publishConfig
    if command -v jq > /dev/null 2>&1; then
        # Add publishConfig with jq
        jq '. + {
            "publishConfig": {
                "registry": "https://npm.pkg.github.com",
                "access": "public"
            }
        }' "$dir/package.json" > "$dir/package.json.tmp"
        mv "$dir/package.json.tmp" "$dir/package.json"

        success "$package - publishConfig added"
        ((UPDATED++))
    else
        error "$package - jq not installed, skipping"
        ((SKIPPED++))
    fi
done

echo ""
print_header "Update Summary"
echo "  ${GREEN}✅ Updated: $UPDATED${NC}"
echo "  ${YELLOW}⊘ Skipped: $SKIPPED${NC}"
echo ""

if [ $UPDATED -eq 0 ]; then
    warning "No packages were updated"
    if ! command -v jq > /dev/null 2>&1; then
        info "Install jq: brew install jq"
    fi
    exit 0
fi

success "publishConfig added to all packages!"
