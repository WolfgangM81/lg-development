#!/usr/bin/env bash
# Check if any builders have compilation errors

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

VOLUME="lg-development_lg-packages-dist"
PACKAGES="menu-registry backend-common types"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Checking package build status..."
echo ""

ERRORS_FOUND=0

for pkg in $PACKAGES; do
  echo -e "${YELLOW}Checking $pkg...${NC}"

  # Check if .js and .d.ts exist
  HAS_JS=$(docker run --rm -v $VOLUME:/dist alpine test -f /dist/$pkg/index.js && echo "yes" || echo "no")
  HAS_DTS=$(docker run --rm -v $VOLUME:/dist alpine test -f /dist/$pkg/index.d.ts && echo "yes" || echo "no")

  if [ "$HAS_JS" = "no" ] || [ "$HAS_DTS" = "no" ]; then
    echo -e "${RED}❌ $pkg: Incomplete build (JS: $HAS_JS, .d.ts: $HAS_DTS)${NC}"
    echo -e "${YELLOW}Last 30 log lines:${NC}"
    docker logs lg-builder-$pkg --tail 30 2>&1 | grep -E "(error|Error|failed|Failed)" || docker logs lg-builder-$pkg --tail 30
    echo ""
    ERRORS_FOUND=$((ERRORS_FOUND + 1))
  else
    # Validate JavaScript syntax
    docker run --rm -v $VOLUME:/dist node:20-alpine node -c /dist/$pkg/index.js 2>/dev/null
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}✅ $pkg: Build successful${NC}"
    else
      echo -e "${RED}❌ $pkg: Invalid JavaScript syntax${NC}"
      docker run --rm -v $VOLUME:/dist node:20-alpine node -c /dist/$pkg/index.js
      ERRORS_FOUND=$((ERRORS_FOUND + 1))
    fi
  fi
  echo ""
done

if [ $ERRORS_FOUND -eq 0 ]; then
  echo -e "${GREEN}✅ All packages built successfully${NC}"
  exit 0
else
  echo -e "${RED}❌ Found $ERRORS_FOUND package(s) with build errors${NC}"
  echo ""
  echo "💡 Tips:"
  echo "  - Check logs: make dev-sync-logs PACKAGE=<name>"
  echo "  - Rebuild: make dev-sync-rebuild"
  echo "  - View status: make dev-sync-status"
  exit 1
fi
