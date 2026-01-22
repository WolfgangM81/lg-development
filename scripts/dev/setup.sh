#!/bin/bash

# ╔══════════════════════════════════════════════════════════════╗
# ║     LG-DEVELOPMENT - SETUP (Clone Repos from GitHub)         ║
# ╚══════════════════════════════════════════════════════════════╝

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Load .env
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️  .env not found! Copying from .env.example...${NC}"
    cp .env.example .env
    echo -e "${YELLOW}⚠️  Please edit .env and add your GITHUB_TOKEN!${NC}"
    exit 1
fi

source .env

# Validate GitHub token
if [ -z "$GITHUB_TOKEN" ] || [ "$GITHUB_TOKEN" == "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" ]; then
    echo -e "${YELLOW}⚠️  GITHUB_TOKEN not configured in .env!${NC}"
    echo "Please set a valid GitHub Personal Access Token."
    exit 1
fi

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     🚀 CLONING PROJECTS FROM GITHUB                           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

mkdir -p repos
cd repos

clone_repo() {
    local repo=$1
    local flag=$2
    
    if [ "$flag" == "true" ]; then
        if [ -d "$repo" ]; then
            echo -e "${YELLOW}⏭️  $repo already exists, skipping...${NC}"
        else
            echo -e "${GREEN}📦 Cloning $repo...${NC}"
            git clone "https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${repo}.git" "$repo" 2>&1 | grep -v "Cloning into"
            echo -e "${GREEN}✅ $repo cloned${NC}"
        fi
    else
        echo -e "⏭️  $repo (skipped - flag=false)"
    fi
}

clone_repo "lg-platform" "$CLONE_LG_PLATFORM"
clone_repo "lg-user-service" "$CLONE_LG_USER_SERVICE"
clone_repo "lg-permissions-service" "$CLONE_LG_PERMISSIONS_SERVICE"
clone_repo "lg-api-keys-service" "$CLONE_LG_API_KEYS_SERVICE"
clone_repo "lg-secrets-service" "$CLONE_LG_SECRETS_SERVICE"
clone_repo "lg-tour-service" "$CLONE_LG_TOUR_SERVICE"
clone_repo "lg-menu-service" "$CLONE_LG_MENU_SERVICE"
clone_repo "lg-admin" "$CLONE_LG_ADMIN"
clone_repo "lg-admin-ui" "$CLONE_LG_ADMIN_UI"
clone_repo "lg-menu-registry" "$CLONE_LG_MENU_REGISTRY"
clone_repo "lg-e2e-tests" "$CLONE_LG_E2E_TESTS"

cd ..

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✅ SETUP COMPLETE                                         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Next steps:"
echo "  1. ./scripts/dev/start.sh       # Start Docker stack"
echo "  2. ./scripts/dev/logs.sh        # View logs"
echo "  3. ./scripts/dev/stop.sh        # Stop stack"
