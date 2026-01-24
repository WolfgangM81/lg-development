#!/bin/bash
# scripts/test-coverage.sh
#
# Run tests with coverage and aggregate results

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "Running Tests with Coverage"

if [ ! -d repos ]; then
    die "repos/ not found! Run 'make prepare' first"
fi

# Create coverage directory
COVERAGE_DIR="coverage"
mkdir -p "$COVERAGE_DIR"

PASSED=0
FAILED=0
SKIPPED=0
TOTAL=0

# Test each repo
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

    print_step "Testing $REPO (with coverage)"
    echo ""

    # Check for coverage script
    HAS_COVERAGE=false
    if grep -q '"test:coverage"' "$dir/package.json" 2>/dev/null; then
        TEST_CMD="npm run test:coverage"
        HAS_COVERAGE=true
    elif grep -q '"coverage"' "$dir/package.json" 2>/dev/null; then
        TEST_CMD="npm run coverage"
        HAS_COVERAGE=true
    else
        TEST_CMD="npm test -- --coverage"
    fi

    # Run tests with coverage
    if (cd "$dir" && docker run --rm \
        -v "$(pwd):/app" \
        -v "$(pwd)/../$COVERAGE_DIR/$REPO:/app/coverage" \
        -w /app \
        node:20-alpine \
        sh -c "npm install > /dev/null 2>&1 && $TEST_CMD"); then
        echo ""
        success "$REPO - tests passed"
        ((PASSED++))

        # Copy coverage if it exists
        if [ -d "$dir/coverage" ]; then
            cp -r "$dir/coverage" "$COVERAGE_DIR/$REPO"
            info "Coverage saved to $COVERAGE_DIR/$REPO"
        fi
    else
        echo ""
        error "$REPO - tests failed"
        ((FAILED++))
    fi

    echo ""
done

# Generate aggregate coverage report
if [ $PASSED -gt 0 ]; then
    print_step "Generating aggregate coverage report"

    # Create index.html with links to all coverage reports
    cat > "$COVERAGE_DIR/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>LG-Development - Test Coverage</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        h1 { color: #333; }
        .repo { margin: 20px 0; padding: 20px; background: #f5f5f5; border-radius: 5px; }
        .repo h2 { margin-top: 0; }
        a { color: #0366d6; text-decoration: none; }
        a:hover { text-decoration: underline; }
        .stats { display: flex; gap: 20px; margin-top: 10px; }
        .stat { padding: 10px; background: white; border-radius: 3px; }
        .stat-label { font-size: 12px; color: #666; }
        .stat-value { font-size: 24px; font-weight: bold; }
    </style>
</head>
<body>
    <h1>LG-Development - Test Coverage</h1>
    <p>Generated: $(date)</p>

    <div class="stats">
        <div class="stat">
            <div class="stat-label">Passed</div>
            <div class="stat-value" style="color: green;">$PASSED</div>
        </div>
        <div class="stat">
            <div class="stat-label">Failed</div>
            <div class="stat-value" style="color: red;">$FAILED</div>
        </div>
        <div class="stat">
            <div class="stat-label">Skipped</div>
            <div class="stat-value" style="color: orange;">$SKIPPED</div>
        </div>
    </div>
EOF

    for coverage in $COVERAGE_DIR/*/; do
        if [ -f "$coverage/index.html" ]; then
            repo=$(basename "$coverage")
            cat >> "$COVERAGE_DIR/index.html" << EOF

    <div class="repo">
        <h2>$repo</h2>
        <a href="$repo/index.html">View Coverage Report</a>
    </div>
EOF
        fi
    done

    cat >> "$COVERAGE_DIR/index.html" << EOF
</body>
</html>
EOF

    success "Aggregate coverage report: $COVERAGE_DIR/index.html"
    echo ""
    info "Open with: open $COVERAGE_DIR/index.html"
fi

# Summary
echo ""
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
