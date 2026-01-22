#!/bin/bash

# ╔══════════════════════════════════════════════════════════════╗
# ║     LG-DEVELOPMENT - UPDATE (Git Pull All Projects)          ║
# ╚══════════════════════════════════════════════════════════════╝

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     🔄 UPDATING PROJECTS FROM GITHUB                          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

cd projects

for dir in */; do
    if [ -d "$dir/.git" ]; then
        echo -e "${BLUE}📦 Updating ${dir%/}...${NC}"
        cd "$dir"
        BRANCH=$(git branch --show-current)
        git pull origin "$BRANCH" 2>&1 | grep -E "(Already up to date|Fast-forward|Updating)" || echo -e "${GREEN}✅ Updated${NC}"
        cd ..
    fi
done

cd ..
echo -e "${GREEN}✅ All projects updated${NC}"
