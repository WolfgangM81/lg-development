#!/usr/bin/env bash

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
created=0
skipped=0
failed=0

# Dry-run mode
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo -e "${YELLOW}🔍 DRY RUN MODE - No changes will be made${NC}\n"
fi

# Check gh CLI
if ! command -v gh &> /dev/null; then
  echo -e "${RED}✗ Error: gh CLI is not installed${NC}"
  echo "Install: brew install gh"
  exit 1
fi

# Check authentication
if ! gh auth status &> /dev/null; then
  echo -e "${RED}✗ Error: Not authenticated with GitHub${NC}"
  echo "Run: gh auth login"
  exit 1
fi

# Get GitHub username
GH_USER=$(gh api user -q .login)

echo -e "${BLUE}🚀 Creating GitHub repositories for user: ${GH_USER}${NC}\n"

# Find all repos
REPOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/repos"

if [[ ! -d "$REPOS_DIR" ]]; then
  echo -e "${RED}✗ Error: repos/ directory not found${NC}"
  exit 1
fi

# Check if repos directory is empty
if [[ -z "$(ls -A "$REPOS_DIR")" ]]; then
  echo -e "${YELLOW}⊘ No repositories found in repos/${NC}"
  exit 0
fi

# Process each repo
for repo_path in "$REPOS_DIR"/*; do
  if [[ ! -d "$repo_path" ]]; then
    continue
  fi

  repo_name=$(basename "$repo_path")
  
  # Skip if not a git repo
  if [[ ! -d "$repo_path/.git" ]]; then
    echo -e "${YELLOW}⊘ $repo_name (not a git repository, skipping)${NC}"
    ((skipped++))
    continue
  fi

  # Simple description
  description="Part of the LicenseGuard platform"

  # Check if repo already exists on GitHub (with timeout)
  if timeout 5 gh repo view "$GH_USER/$repo_name" &> /dev/null; then
    echo -e "${YELLOW}⊘ $repo_name (already exists, skipping)${NC}"
    
    # Check if remote is set locally
    if ! git -C "$repo_path" remote get-url origin &> /dev/null; then
      if [[ "$DRY_RUN" == false ]]; then
        git -C "$repo_path" remote add origin "https://github.com/$GH_USER/$repo_name.git" 2>/dev/null || true
      fi
    fi
    
    ((skipped++))
    continue
  fi

  # Create repo
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${GREEN}✓ $repo_name${NC} (would create)"
    echo -e "  Description: $description"
    echo -e "  URL: https://github.com/$GH_USER/$repo_name"
    ((created++))
  else
    if gh repo create "$GH_USER/$repo_name" --private --source="$repo_path" --description="$description" 2>/dev/null; then
      # Add remote if not exists
      if ! git -C "$repo_path" remote get-url origin &> /dev/null; then
        git -C "$repo_path" remote add origin "https://github.com/$GH_USER/$repo_name.git"
      fi
      
      # Push main branch
      if git -C "$repo_path" show-ref --verify --quiet refs/heads/main; then
        git -C "$repo_path" push -u origin main &> /dev/null || true
      elif git -C "$repo_path" show-ref --verify --quiet refs/heads/master; then
        git -C "$repo_path" push -u origin master &> /dev/null || true
      fi
      
      echo -e "${GREEN}✓ $repo_name${NC} (https://github.com/$GH_USER/$repo_name)"
      ((created++))
    else
      echo -e "${RED}✗ $repo_name (failed to create)${NC}"
      ((failed++))
    fi
  fi

  # Rate limiting (only if not dry-run to speed up testing)
  if [[ "$DRY_RUN" == false ]]; then
    sleep 2
  fi
done

# Summary
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Summary:${NC} ${GREEN}$created created${NC}, ${YELLOW}$skipped skipped${NC}$([ $failed -gt 0 ] && echo -e ", ${RED}$failed failed${NC}")"

if [[ "$DRY_RUN" == true ]]; then
  echo -e "\n${YELLOW}Run without --dry-run to create repositories${NC}"
fi
