#!/bin/bash
# LG-Development: Copy All Projects from Monorepo
# Non-destructive: Originals remain untouched!

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MONOREPO_ROOT="$(dirname "$PROJECT_ROOT")"

cd "$PROJECT_ROOT"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🚀 LG-Development: Copy All Projects${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Projects to copy
PROJECTS=(
  "lg-admin-ui:library"
  "lg-menu-registry:library"
  "lg-user-service:backend"
  "lg-permissions-service:backend"
  "lg-api-keys-service:backend"
  "lg-tour-service:backend"
  "lg-platform:infrastructure"
  "lg-management:nextjs"
  "lg-admin:vite"
  "lg-e2e-tests:testing"
)

TOTAL=${#PROJECTS[@]}
CURRENT=0
SUCCESS=0
SKIPPED=0
FAILED=0

for project_def in "${PROJECTS[@]}"; do
  IFS=':' read -r project type <<< "$project_def"
  CURRENT=$((CURRENT + 1))
  
  echo -e "${YELLOW}[$CURRENT/$TOTAL]${NC} Processing ${GREEN}$project${NC} (type: $type)..."
  
  SOURCE="$MONOREPO_ROOT/$project"
  DEST="$PROJECT_ROOT/repos/$project"
  
  if [ ! -d "$SOURCE" ]; then
    echo -e "  ${RED}✗${NC} Source not found: $SOURCE"
    FAILED=$((FAILED + 1))
    continue
  fi
  
  if [ -d "$DEST" ]; then
    echo -e "  ${YELLOW}⊘${NC} Already exists, skipping"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  
  # Copy project
  if ./scripts/copy-project.sh --source "$SOURCE" --dest "$DEST" > /tmp/copy-$project.log 2>&1; then
    echo -e "  ${GREEN}✓${NC} Copied successfully"
    
    # Prepare repo
    echo -e "  ${BLUE}🔧${NC} Preparing repo..."
    if ./scripts/prepare-repo.sh "$DEST" --type "$type" > /tmp/prepare-$project.log 2>&1; then
      echo -e "  ${GREEN}✓${NC} Prepared successfully"
      SUCCESS=$((SUCCESS + 1))
    else
      echo -e "  ${RED}✗${NC} Prepare failed (see /tmp/prepare-$project.log)"
      FAILED=$((FAILED + 1))
    fi
  else
    echo -e "  ${RED}✗${NC} Copy failed (see /tmp/copy-$project.log)"
    FAILED=$((FAILED + 1))
  fi
  
  echo ""
done

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✨ Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}✓ Success:${NC} $SUCCESS"
echo -e "  ${YELLOW}⊘ Skipped:${NC} $SKIPPED"
echo -e "  ${RED}✗ Failed:${NC}  $FAILED"
echo ""

if [ $FAILED -gt 0 ]; then
  echo -e "${RED}⚠️  Some projects failed. Check logs in /tmp/${NC}"
  exit 1
fi

echo -e "${GREEN}✅ All projects copied and prepared!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Review copied projects in repos/"
echo -e "  2. Run: ${YELLOW}./scripts/create-github-repos.sh --dry-run${NC}"
echo -e "  3. Run: ${YELLOW}./scripts/create-github-repos.sh${NC}"
