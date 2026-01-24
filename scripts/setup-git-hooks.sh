#!/bin/bash
# scripts/setup-git-hooks.sh
#
# Setup Git hooks with Docker-based testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "Setting up Git Hooks"

# Packages to configure
PACKAGES=(
    "lg-menu-registry"
    "lg-admin-ui"
    "lg-backend-common"
    "lg-types"
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

    # Add husky to devDependencies
    if command -v jq > /dev/null 2>&1; then
        jq '.devDependencies += {
            "husky": "^9.0.0"
        } | .scripts += {
            "prepare": "husky || true"
        }' "$dir/package.json" > "$dir/package.json.tmp"
        mv "$dir/package.json.tmp" "$dir/package.json"
    fi

    # Create .husky directory
    mkdir -p "$dir/.husky"
    mkdir -p "$dir/.husky/_"

    # Create husky init script first
    cat > "$dir/.husky/_/husky.sh" << 'EOF'
#!/bin/sh
if [ -z "$husky_skip_init" ]; then
  debug () {
    if [ "$HUSKY_DEBUG" = "1" ]; then
      echo "husky (debug) - $1"
    fi
  }

  readonly hook_name="$(basename "$0")"
  debug "starting $hook_name..."

  if [ "$HUSKY" = "0" ]; then
    debug "HUSKY env variable is set to 0, skipping hook"
    exit 0
  fi

  if [ -f ~/.huskyrc ]; then
    debug "sourcing ~/.huskyrc"
    . ~/.huskyrc
  fi

  export readonly husky_skip_init=1
  sh -e "$0" "$@"
  exitCode="$?"

  if [ $exitCode != 0 ]; then
    echo "husky - $hook_name hook exited with code $exitCode (error)"
  fi

  exit $exitCode
fi
EOF
    chmod +x "$dir/.husky/_/husky.sh"

    # Copy hooks (after husky.sh exists)
    cp templates/husky-pre-commit "$dir/.husky/pre-commit"
    cp templates/husky-pre-push "$dir/.husky/pre-push"
    cp templates/husky-commit-msg "$dir/.husky/commit-msg"

    # Make hooks executable
    chmod +x "$dir/.husky/pre-commit"
    chmod +x "$dir/.husky/pre-push"
    chmod +x "$dir/.husky/commit-msg"

    success "$package - Git hooks configured"
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

success "Git hooks configured!"
echo ""
info "Hooks installed:"
echo "  pre-commit  → Runs tests in Docker before commit"
echo "  pre-push    → Runs tests in Docker before push"
echo "  commit-msg  → Validates conventional commit format"
echo ""
info "Skip hooks (wenn nötig):"
echo "  HUSKY=0 git commit -m '...'  # Skip all hooks"
echo "  git commit --no-verify       # Skip pre-commit & commit-msg"
echo "  git push --no-verify         # Skip pre-push"
echo ""
info "Next steps:"
echo "  1. Install husky: cd repos/<package> && docker run --rm -v \$(pwd):/app -w /app node:20-alpine npm install"
echo "  2. Test hooks: git commit -m 'test: check hooks'"
