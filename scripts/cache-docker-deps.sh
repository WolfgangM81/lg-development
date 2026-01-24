#!/bin/bash
# scripts/cache-docker-deps.sh
#
# Pre-install npm dependencies in a cached Docker volume

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "Caching Docker Dependencies"

if [ ! -d repos ]; then
    die "repos/ not found! Run 'make prepare' first"
fi

# Create Docker volume for caching
CACHE_VOLUME="lg-dev-npm-cache"

if docker volume inspect "$CACHE_VOLUME" > /dev/null 2>&1; then
    info "Using existing cache volume: $CACHE_VOLUME"
else
    info "Creating cache volume: $CACHE_VOLUME"
    docker volume create "$CACHE_VOLUME"
fi

CACHED=0
FAILED=0
SKIPPED=0

for dir in repos/*/; do
    [ ! -f "$dir/package.json" ] && continue

    REPO=$(basename "$dir")
    print_step "Caching dependencies for $REPO"

    # Install dependencies into cache volume
    if docker run --rm \
        -v "$(cd "$dir" && pwd):/app:ro" \
        -v "$CACHE_VOLUME:/cache" \
        -w /tmp/build \
        node:20-alpine \
        sh -c "
            cp -r /app/* . &&
            npm install &&
            cp -r node_modules /cache/$REPO
        " > /dev/null 2>&1; then
        success "$REPO dependencies cached"
        ((CACHED++))
    else
        error "$REPO failed to cache"
        ((FAILED++))
    fi
done

echo ""
print_header "Cache Summary"
echo "  ${GREEN}✅ Cached:  $CACHED${NC}"
echo "  ${RED}❌ Failed:  $FAILED${NC}"
echo "  ${YELLOW}⊘ Skipped: $SKIPPED${NC}"
echo ""

if [ $FAILED -gt 0 ]; then
    warning "$FAILED repo(s) failed to cache"
fi

success "Dependencies cached in Docker volume: $CACHE_VOLUME"
echo ""
info "Use cached volume in tests with: -v $CACHE_VOLUME:/app/node_modules"
