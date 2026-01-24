#!/bin/bash
# scripts/test.sh
#
# Run tests for all repositories

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "Running Tests"

if [ ! -d repos ]; then
    die "repos/ not found! Run 'make prepare' first"
fi

PASSED=0
FAILED=0
SKIPPED=0
TOTAL=0

# Find all repos with tests
for dir in repos/*/; do
    [ ! -f "$dir/package.json" ] && continue

    REPO=$(basename "$dir")

    # Check if repo has test script
    if ! grep -q '"test"' "$dir/package.json" 2>/dev/null; then
        warning "$REPO - no tests"
        ((SKIPPED++))
        continue
    fi

    ((TOTAL++))

    print_step "Testing $REPO"
    echo ""

    # Run tests in Docker
    if (cd "$dir" && docker run --rm \
        -v "$(pwd):/app" \
        -w /app \
        node:20-alpine \
        sh -c "npm install > /dev/null 2>&1 && npm test"); then
        echo ""
        success "$REPO - tests passed"
        ((PASSED++))
    else
        echo ""
        error "$REPO - tests failed"
        ((FAILED++))
    fi

    echo ""
done

# Summary
print_header "Test Summary"
echo "  ${GREEN}✅ Passed:  $PASSED/$TOTAL${NC}"
echo "  ${RED}❌ Failed:  $FAILED/$TOTAL${NC}"
echo "  ${YELLOW}⊘ Skipped: $SKIPPED${NC}"
echo ""

if [ $FAILED -gt 0 ]; then
    die "$FAILED test suite(s) failed"
fi

if [ $PASSED -eq 0 ] && [ $TOTAL -eq 0 ]; then
    warning "No tests found"
    exit 0
fi

success "All tests passed!"
