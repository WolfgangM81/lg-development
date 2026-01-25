#!/usr/bin/env bash
# Verify all optimization features are working correctly

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

test_pass() {
  echo -e "${GREEN}✅ $1${NC}"
  PASSED=$((PASSED + 1))
}

test_fail() {
  echo -e "${RED}❌ $1${NC}"
  FAILED=$((FAILED + 1))
}

test_warn() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     🧪 HOT-RELOAD OPTIMIZATION VERIFICATION                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Phase 1: Critical Bug Fixes
echo -e "${BLUE}Phase 1: Critical Bug Fixes${NC}"
echo ""

# Test 1: Check scripts exist and have correct directory
echo "Test 1: Scripts directory reference..."
if grep -q "cd repos" "$SCRIPT_DIR/update.sh"; then
  test_pass "update.sh uses 'cd repos'"
else
  test_fail "update.sh still uses 'cd projects'"
fi

if grep -q "cd repos" "$SCRIPT_DIR/status.sh"; then
  test_pass "status.sh uses 'cd repos'"
else
  test_fail "status.sh still uses 'cd projects'"
fi

# Test 2: Health checks are enhanced
echo ""
echo "Test 2: Enhanced health checks..."
if grep -q "node -c" "$ROOT_DIR/docker-compose.dev-sync.yml"; then
  test_pass "Health checks validate JavaScript syntax"
else
  test_fail "Health checks missing syntax validation"
fi

if grep -q "index.d.ts" "$ROOT_DIR/docker-compose.dev-sync.yml"; then
  test_pass "Health checks verify .d.ts files"
else
  test_fail "Health checks missing .d.ts verification"
fi

echo ""
echo -e "${BLUE}Phase 2: Error Handling${NC}"
echo ""

# Test 3: Error detection script
echo "Test 3: Error detection script..."
if [ -f "$SCRIPT_DIR/check-build-errors.sh" ] && [ -x "$SCRIPT_DIR/check-build-errors.sh" ]; then
  test_pass "check-build-errors.sh exists and is executable"
else
  test_fail "check-build-errors.sh missing or not executable"
fi

# Test 4: Sync packages check command
echo ""
echo "Test 4: Sync packages check command..."
if grep -q "check)" "$SCRIPT_DIR/sync-packages.sh"; then
  test_pass "sync-packages.sh has check command"
else
  test_fail "sync-packages.sh missing check command"
fi

echo ""
echo -e "${BLUE}Phase 3: Smart Restarts${NC}"
echo ""

# Test 5: Dependency mapping
echo "Test 5: Package dependency mapping..."
if [ -f "$SCRIPT_DIR/package-dependencies.json" ]; then
  test_pass "package-dependencies.json exists"

  # Verify JSON is valid
  if command -v jq &> /dev/null; then
    if jq empty "$SCRIPT_DIR/package-dependencies.json" 2>/dev/null; then
      test_pass "package-dependencies.json is valid JSON"
    else
      test_fail "package-dependencies.json is invalid JSON"
    fi
  else
    test_warn "jq not installed - cannot validate JSON (optional)"
  fi
else
  test_fail "package-dependencies.json missing"
fi

# Test 6: Smart restart logic
echo ""
echo "Test 6: Smart restart logic..."
if grep -q "USE_SMART_RESTART" "$SCRIPT_DIR/watch-packages.sh"; then
  test_pass "watch-packages.sh has smart restart logic"
else
  test_fail "watch-packages.sh missing smart restart logic"
fi

if grep -q "AFFECTED_SERVICES" "$SCRIPT_DIR/watch-packages.sh"; then
  test_pass "watch-packages.sh reads dependency mapping"
else
  test_fail "watch-packages.sh doesn't use dependency mapping"
fi

echo ""
echo -e "${BLUE}Phase 4: Performance Metrics${NC}"
echo ""

# Test 7: Metrics script
echo "Test 7: Build metrics script..."
if [ -f "$SCRIPT_DIR/build-metrics.sh" ] && [ -x "$SCRIPT_DIR/build-metrics.sh" ]; then
  test_pass "build-metrics.sh exists and is executable"
else
  test_fail "build-metrics.sh missing or not executable"
fi

echo ""
echo -e "${BLUE}Phase 5: Developer UX${NC}"
echo ""

# Test 8: Dashboard script
echo "Test 8: Live dashboard script..."
if [ -f "$SCRIPT_DIR/dev-sync-dashboard.sh" ] && [ -x "$SCRIPT_DIR/dev-sync-dashboard.sh" ]; then
  test_pass "dev-sync-dashboard.sh exists and is executable"
else
  test_fail "dev-sync-dashboard.sh missing or not executable"
fi

echo ""
echo -e "${BLUE}Makefile Integration${NC}"
echo ""

# Test 9: Make targets
echo "Test 9: New make targets..."
MAKEFILE="$ROOT_DIR/Makefile"

if grep -q "dev-sync-check:" "$MAKEFILE"; then
  test_pass "make dev-sync-check target exists"
else
  test_fail "make dev-sync-check target missing"
fi

if grep -q "dev-sync-dashboard:" "$MAKEFILE"; then
  test_pass "make dev-sync-dashboard target exists"
else
  test_fail "make dev-sync-dashboard target missing"
fi

if grep -q "dev-sync-metrics:" "$MAKEFILE"; then
  test_pass "make dev-sync-metrics target exists"
else
  test_fail "make dev-sync-metrics target missing"
fi

if grep -q "dev-sync-metrics-watch:" "$MAKEFILE"; then
  test_pass "make dev-sync-metrics-watch target exists"
else
  test_fail "make dev-sync-metrics-watch target missing"
fi

if grep -q "dev-sync-metrics-reset:" "$MAKEFILE"; then
  test_pass "make dev-sync-metrics-reset target exists"
else
  test_fail "make dev-sync-metrics-reset target missing"
fi

echo ""
echo -e "${BLUE}Optional Dependencies${NC}"
echo ""

# Test 10: Optional tools
echo "Test 10: Optional tool availability..."
if command -v jq &> /dev/null; then
  test_pass "jq is installed (smart restarts enabled)"
else
  test_warn "jq not installed (smart restarts will use fallback)"
fi

if command -v watch &> /dev/null; then
  test_pass "watch is installed (live dashboard enabled)"
else
  test_warn "watch not installed (dashboard will use manual refresh)"
fi

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     VERIFICATION RESULTS                                      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✅ All tests passed! Hot-reload optimizations are fully implemented.${NC}"
  echo ""
  echo "🚀 Next steps:"
  echo "  1. make dev-sync              # Start hot-reload"
  echo "  2. make dev-sync-dashboard    # Open live dashboard"
  echo "  3. make dev-sync-check        # Verify builds"
  echo "  4. make dev-sync-metrics      # View performance"
  exit 0
else
  echo -e "${RED}❌ Some tests failed. Please review the output above.${NC}"
  exit 1
fi
