#!/usr/bin/env bash
#
# install-ci-workflows.sh - Install GitHub Actions workflows for all repos
#
# This script installs appropriate CI/CD workflows based on repo type

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Installing GitHub Actions CI/CD Workflows${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if we're in the right directory
if [[ ! -d "repos" ]]; then
    echo -e "${RED}❌ Error: Must run from lg-development root directory${NC}"
    exit 1
fi

# Function to install workflow
install_workflow() {
    local REPO_PATH=$1
    local WORKFLOW_NAME=$2
    local TEMPLATE_PATH=$3

    mkdir -p "$REPO_PATH/.github/workflows"

    if [[ -f "$REPO_PATH/.github/workflows/$WORKFLOW_NAME" ]]; then
        echo -e "  ${YELLOW}⊘ $WORKFLOW_NAME already exists, skipping${NC}"
        return 0
    fi

    cp "$TEMPLATE_PATH" "$REPO_PATH/.github/workflows/$WORKFLOW_NAME"
    echo -e "  ${GREEN}✓ Installed $WORKFLOW_NAME${NC}"
}

echo -e "${GREEN}Installing workflows for services...${NC}"
echo ""

# Install service workflows
for SERVICE in repos/services/lg-*; do
    if [[ ! -d "$SERVICE" ]]; then
        continue
    fi

    SERVICE_NAME=$(basename "$SERVICE")
    echo -e "${BLUE}📦 $SERVICE_NAME${NC}"

    install_workflow "$SERVICE" "build-test.yml" "templates/workflows/service-build-test.yml"
    install_workflow "$SERVICE" "deploy-staging.yml" "templates/workflows/deploy-staging.yml"

    echo ""
done

echo -e "${GREEN}Installing workflows for packages...${NC}"
echo ""

# Install package workflows
for PACKAGE in repos/packages/lg-*; do
    if [[ ! -d "$PACKAGE" ]]; then
        continue
    fi

    PACKAGE_NAME=$(basename "$PACKAGE")
    echo -e "${BLUE}📦 $PACKAGE_NAME${NC}"

    install_workflow "$PACKAGE" "build-test-publish.yml" "templates/workflows/package-publish.yml"

    echo ""
done

echo -e "${GREEN}Installing workflows for UI apps...${NC}"
echo ""

# Install UI workflows
for UI_APP in repos/ui/lg-*; do
    if [[ ! -d "$UI_APP" ]]; then
        continue
    fi

    UI_NAME=$(basename "$UI_APP")
    echo -e "${BLUE}📦 $UI_NAME${NC}"

    install_workflow "$UI_APP" "build-test.yml" "templates/workflows/service-build-test.yml"
    install_workflow "$UI_APP" "deploy-staging.yml" "templates/workflows/deploy-staging.yml"

    echo ""
done

echo -e "${GREEN}✅ Workflows installed!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Review installed workflows:"
echo "   ${BLUE}find repos -name '*.yml' -path '*/.github/workflows/*'${NC}"
echo ""
echo "2. Configure GitHub secrets (in each repo's Settings → Secrets):"
echo "   - CODECOV_TOKEN (for code coverage)"
echo "   - GITHUB_TOKEN (already available)"
echo ""
echo "3. Enable GitHub Packages:"
echo "   - Repository Settings → Packages"
echo "   - Make package public/private as needed"
echo ""
echo "4. Test workflows:"
echo "   - Create a test PR in a repo"
echo "   - Watch GitHub Actions tab"
echo ""
echo "5. Configure branch protection (recommended):"
echo "   - Require status checks to pass"
echo "   - Require reviews before merging"
echo "   - Require signed commits"
echo ""
