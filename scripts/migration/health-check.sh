#!/bin/bash
# LG-Development: Health Check Script
# Verifies all repos are ready for GitHub push

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🏥 LG-Development: Health Check${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

check() {
  local name=$1
  local test_cmd=$2
  
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  
  if eval "$test_cmd" > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} $name"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    return 0
  else
    echo -e "  ${RED}✗${NC} $name"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    return 1
  fi
}

# Check repos directory
echo -e "${YELLOW}📂 Checking repos directory...${NC}"
check "repos/ exists" "[ -d repos ]"

if [ -d repos ]; then
  REPO_COUNT=$(find repos -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
  echo -e "  ${BLUE}ℹ${NC}  Found $REPO_COUNT repos"
fi

echo ""

# Check each repo
if [ -d repos ]; then
  for repo_dir in repos/*/; do
    [ -d "$repo_dir" ] || continue
    repo_name=$(basename "$repo_dir")
    
    echo -e "${YELLOW}📦 Checking $repo_name...${NC}"
    
    check "Git repository" "[ -d $repo_dir/.git ]"
    check "package.json exists" "[ -f $repo_dir/package.json ]"
    check ".npmrc exists" "[ -f $repo_dir/.npmrc ]"
    check "README.md exists" "[ -f $repo_dir/README.md ]"
    check ".github/workflows exists" "[ -d $repo_dir/.github/workflows ]"
    
    # Check for @WolfgangM81 scope in package.json
    if [ -f "$repo_dir/package.json" ]; then
      if grep -q '"name": "@WolfgangM81/' "$repo_dir/package.json" 2>/dev/null; then
        check "Package scoped correctly" "true"
      else
        check "Package scoped correctly" "false"
      fi
    fi
    
    # Check for workspace:* dependencies (should be replaced)
    if [ -f "$repo_dir/package.json" ]; then
      if grep -q 'workspace:\*' "$repo_dir/package.json" 2>/dev/null; then
        check "No workspace:* deps" "false"
      else
        check "No workspace:* deps" "true"
      fi
    fi
    
    echo ""
  done
fi

# Check dependency graph
echo -e "${YELLOW}🔍 Checking dependency analysis...${NC}"
check ".dependency-graph.json exists" "[ -f .dependency-graph.json ]"
check ".migration-order.txt exists" "[ -f .migration-order.txt ]"
echo ""

# Check GitHub CLI
echo -e "${YELLOW}🐙 Checking GitHub CLI...${NC}"
check "gh CLI installed" "command -v gh"
if command -v gh > /dev/null 2>&1; then
  if gh auth status > /dev/null 2>&1; then
    check "gh authenticated" "true"
    USER=$(gh api user --jq .login 2>/dev/null || echo "unknown")
    echo -e "  ${BLUE}ℹ${NC}  Authenticated as: $USER"
  else
    check "gh authenticated" "false"
  fi
fi
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📊 Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}✓ Passed:${NC} $PASSED_CHECKS / $TOTAL_CHECKS"
echo -e "  ${RED}✗ Failed:${NC} $FAILED_CHECKS / $TOTAL_CHECKS"
echo ""

if [ $FAILED_CHECKS -gt 0 ]; then
  echo -e "${RED}⚠️  Some checks failed!${NC}"
  echo -e "${YELLOW}💡 Tip: Run prepare-repo.sh again on failing repos${NC}"
  exit 1
fi

echo -e "${GREEN}✅ All health checks passed!${NC}"
echo ""
echo -e "${BLUE}Ready for GitHub migration!${NC}"
echo -e "  Next: ${YELLOW}./scripts/create-github-repos.sh --dry-run${NC}"
