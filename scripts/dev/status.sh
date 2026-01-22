#!/bin/bash

# ╔══════════════════════════════════════════════════════════════╗
# ║     LG-DEVELOPMENT - STATUS (Git Status Overview)            ║
# ╚══════════════════════════════════════════════════════════════╝

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     📊 PROJECT STATUS OVERVIEW                                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

cd projects

for dir in */; do
    if [ -d "$dir/.git" ]; then
        cd "$dir"
        BRANCH=$(git branch --show-current)
        
        if [[ -n $(git status -s) ]]; then
            echo -e "${YELLOW}⚠️  ${dir%/} [${BRANCH}] - HAS CHANGES${NC}"
            git status -s | head -5
        else
            echo -e "${GREEN}✅ ${dir%/} [${BRANCH}] - CLEAN${NC}"
        fi
        
        cd ..
        echo ""
    fi
done

cd ..
