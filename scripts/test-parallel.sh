#!/bin/bash
# scripts/test-parallel.sh
#
# Run tests for all repositories in parallel

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Number of parallel jobs (default: number of CPU cores)
JOBS=${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}

print_header "Running Tests (Parallel)"
info "Using $JOBS parallel workers"
echo ""

if [ ! -d repos ]; then
    die "repos/ not found! Run 'make prepare' first"
fi

# Create temp directory for results
RESULTS_DIR=$(mktemp -d)
trap "rm -rf $RESULTS_DIR" EXIT

# Function to test a single repo
test_repo() {
    local dir=$1
    local repo=$(basename "$dir")
    local result_file="$RESULTS_DIR/$repo.result"
    local output_file="$RESULTS_DIR/$repo.output"

    # Skip if no package.json
    if [ ! -f "$dir/package.json" ]; then
        echo "SKIP:no-package" > "$result_file"
        return
    fi

    # Skip if no test script
    if ! grep -q '"test"' "$dir/package.json" 2>/dev/null; then
        echo "SKIP:no-tests" > "$result_file"
        return
    fi

    # Use cache volume if available
    CACHE_VOLUME="lg-dev-npm-cache"
    CACHE_MOUNT=""
    if docker volume inspect "$CACHE_VOLUME" > /dev/null 2>&1; then
        CACHE_MOUNT="-v $CACHE_VOLUME:/cache:ro"
    fi

    # Run test
    if (cd "$dir" && docker run --rm \
        -v "$(pwd):/app" \
        $CACHE_MOUNT \
        -w /app \
        node:20-alpine \
        sh -c "
            if [ -d /cache/$repo ]; then
                cp -r /cache/$repo node_modules
            fi
            npm install > /dev/null 2>&1 && npm test
        " > "$output_file" 2>&1); then
        echo "PASS" > "$result_file"
    else
        echo "FAIL" > "$result_file"
    fi
}

export -f test_repo
export RESULTS_DIR

# Get list of repos
REPOS=(repos/*/)

# Run tests in parallel
printf '%s\n' "${REPOS[@]}" | xargs -P "$JOBS" -I {} bash -c 'test_repo "$@"' _ {}

# Collect results
PASSED=0
FAILED=0
SKIPPED=0
TOTAL=0

echo ""
print_header "Test Results"

for dir in repos/*/; do
    repo=$(basename "$dir")
    result_file="$RESULTS_DIR/$repo.result"
    output_file="$RESULTS_DIR/$repo.output"

    if [ ! -f "$result_file" ]; then
        continue
    fi

    result=$(cat "$result_file")

    case "$result" in
        PASS)
            success "$repo - tests passed"
            ((PASSED++))
            ((TOTAL++))
            ;;
        FAIL)
            error "$repo - tests failed"
            ((FAILED++))
            ((TOTAL++))
            # Show last 10 lines of output
            if [ -f "$output_file" ]; then
                echo ""
                tail -n 10 "$output_file" | sed 's/^/  /'
                echo ""
            fi
            ;;
        SKIP:no-tests)
            warning "$repo - no tests"
            ((SKIPPED++))
            ;;
        SKIP:*)
            ((SKIPPED++))
            ;;
    esac
done

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
