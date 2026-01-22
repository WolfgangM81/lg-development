#!/bin/bash
# LG-Development: Master Migration Script
# Orchestrates entire migration from monorepo to multi-repo

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# Banner
echo ""
echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}${BOLD}║                                                      ║${NC}"
echo -e "${BLUE}${BOLD}║    🚀 LG-Development: Safe Migration Wizard 🚀      ║${NC}"
echo -e "${BLUE}${BOLD}║                                                      ║${NC}"
echo -e "${BLUE}${BOLD}║    Non-Destructive Monorepo → Multi-Repo Migration  ║${NC}"
echo -e "${BLUE}${BOLD}║                                                      ║${NC}"
echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# Check for --auto flag
AUTO_MODE=false
if [[ "$1" == "--auto" ]]; then
  AUTO_MODE=true
  echo -e "${YELLOW}🤖 Running in AUTO mode (no confirmations)${NC}"
  echo ""
fi

confirm() {
  if [ "$AUTO_MODE" = true ]; then
    return 0
  fi
  
  echo -e "${YELLOW}$1${NC}"
  read -p "Continue? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}❌ Aborted by user${NC}"
    exit 1
  fi
  echo ""
}

step() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}${BOLD}📍 STEP $1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

# ============================================================================
step "1/7: Pre-Flight Checks"
# ============================================================================

echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"

if ! command -v gh &> /dev/null; then
  echo -e "${RED}✗ GitHub CLI (gh) not installed${NC}"
  echo -e "Install: brew install gh"
  exit 1
fi
echo -e "${GREEN}✓${NC} GitHub CLI installed"

if ! gh auth status > /dev/null 2>&1; then
  echo -e "${RED}✗ GitHub CLI not authenticated${NC}"
  echo -e "Run: gh auth login"
  exit 1
fi
echo -e "${GREEN}✓${NC} GitHub CLI authenticated"

MONOREPO_ROOT="$(dirname "$PROJECT_ROOT")"
if [ ! -d "$MONOREPO_ROOT/lg-admin" ]; then
  echo -e "${RED}✗ Monorepo not found at: $MONOREPO_ROOT${NC}"
  exit 1
fi
echo -e "${GREEN}✓${NC} Monorepo found: $MONOREPO_ROOT"

if [ ! -f ".env.secrets" ]; then
  echo -e "${YELLOW}⚠${NC}  .env.secrets not found"
  echo -e "  ${BLUE}Tip:${NC} cp .env.secrets.example .env.secrets"
  confirm "Continue without secrets setup?"
fi

echo ""
echo -e "${GREEN}✅ Pre-flight checks passed!${NC}"

# ============================================================================
step "2/7: Dependency Analysis"
# ============================================================================

echo -e "${YELLOW}🔍 Analyzing project dependencies...${NC}"

if [ ! -f ".dependency-graph.json" ]; then
  echo -e "${BLUE}Running analyze-dependencies.sh...${NC}"
  ./scripts/analyze-dependencies.sh
else
  echo -e "${YELLOW}⊘${NC} Dependency graph already exists"
  confirm "Re-analyze dependencies?"
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./scripts/analyze-dependencies.sh
  fi
fi

echo ""
echo -e "${GREEN}✅ Dependency analysis complete!${NC}"

# ============================================================================
step "3/7: Copy & Prepare Projects"
# ============================================================================

echo -e "${YELLOW}📦 Copying projects from monorepo...${NC}"
echo -e "${BLUE}ℹ  Originals will remain untouched!${NC}"
echo ""

if [ -d "repos" ] && [ "$(ls -A repos 2>/dev/null)" ]; then
  echo -e "${YELLOW}⚠${NC}  repos/ directory already contains projects"
  confirm "Skip copying (use existing)?"
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}⊘ Skipping copy step${NC}"
  else
    confirm "Delete repos/ and re-copy?"
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm -rf repos
      ./scripts/copy-all.sh
    else
      echo -e "${RED}❌ Aborted${NC}"
      exit 1
    fi
  fi
else
  ./scripts/copy-all.sh
fi

echo ""
echo -e "${GREEN}✅ Projects copied and prepared!${NC}"

# ============================================================================
step "4/7: Health Check"
# ============================================================================

echo -e "${YELLOW}🏥 Running health checks...${NC}"

./scripts/health-check.sh

# ============================================================================
step "5/7: Create GitHub Repositories"
# ============================================================================

echo -e "${YELLOW}🐙 Creating GitHub repositories...${NC}"
echo ""

confirm "⚠️  This will create repositories on GitHub. Ready?"

echo -e "${BLUE}Running dry-run first...${NC}"
./scripts/create-github-repos.sh --dry-run

echo ""
confirm "Dry-run complete. Create repositories for real?"

./scripts/create-github-repos.sh

echo ""
echo -e "${GREEN}✅ GitHub repositories created!${NC}"

# ============================================================================
step "6/7: Setup Secrets"
# ============================================================================

if [ -f ".env.secrets" ]; then
  echo -e "${YELLOW}🔐 Setting up GitHub secrets...${NC}"
  
  confirm "⚠️  This will set secrets in GitHub repositories. Ready?"
  
  ./scripts/setup-secrets.sh
  
  echo ""
  echo -e "${GREEN}✅ Secrets configured!${NC}"
else
  echo -e "${YELLOW}⊘${NC} Skipping secrets (no .env.secrets file)"
  echo -e "${BLUE}💡 Tip: You can run ./scripts/setup-secrets.sh later${NC}"
fi

# ============================================================================
step "7/7: Final Summary"
# ============================================================================

echo ""
echo -e "${GREEN}${BOLD}🎉 MIGRATION COMPLETE! 🎉${NC}"
echo ""
echo -e "${BLUE}📊 What was created:${NC}"
echo ""

if [ -f ".migration-order.txt" ]; then
  REPO_COUNT=$(find repos -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  echo -e "  ${GREEN}✓${NC} $REPO_COUNT repositories prepared"
  echo -e "  ${GREEN}✓${NC} GitHub repositories created"
  echo -e "  ${GREEN}✓${NC} Secrets configured (if .env.secrets existed)"
fi

echo ""
echo -e "${BLUE}🌍 GitHub Repositories:${NC}"
GH_USER=$(gh api user --jq .login 2>/dev/null || echo "unknown")
for repo_dir in repos/*/; do
  [ -d "$repo_dir" ] || continue
  repo_name=$(basename "$repo_dir")
  echo -e "  ${GREEN}✓${NC} https://github.com/$GH_USER/$repo_name"
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  1. ${YELLOW}Review repositories:${NC} cd repos/<project>"
echo -e "  2. ${YELLOW}Push code:${NC} cd repos/<project> && git push origin main"
echo -e "  3. ${YELLOW}Tag releases:${NC} git tag v1.0.0 && git push --tags"
echo -e "  4. ${YELLOW}Test CI/CD:${NC} Check GitHub Actions runs"
echo ""
echo -e "${GREEN}🛡️  Original monorepo remains untouched:${NC}"
echo -e "   ${BLUE}→${NC} $MONOREPO_ROOT"
echo ""
echo -e "${GREEN}✅ Safe to rollback anytime by deleting:${NC}"
echo -e "   ${BLUE}→${NC} rm -rf $PROJECT_ROOT"
echo ""
