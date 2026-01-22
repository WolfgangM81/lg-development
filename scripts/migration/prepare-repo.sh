#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATES_DIR="$PROJECT_ROOT/templates"

# Usage
usage() {
    echo "Usage: $0 <repo-path> --type <library|backend|nextjs|infrastructure> [--clean-history]"
    echo ""
    echo "Examples:"
    echo "  $0 repos/lg-admin-ui --type library"
    echo "  $0 repos/lg-user-service --type backend --clean-history"
    exit 1
}

# Parse arguments
REPO_PATH=""
REPO_TYPE=""
CLEAN_HISTORY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            REPO_TYPE="$2"
            shift 2
            ;;
        --clean-history)
            CLEAN_HISTORY=true
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            if [ -z "$REPO_PATH" ]; then
                REPO_PATH="$1"
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [ -z "$REPO_PATH" ] || [ -z "$REPO_TYPE" ]; then
    usage
fi

if [[ ! "$REPO_TYPE" =~ ^(library|backend|nextjs|infrastructure)$ ]]; then
    echo -e "${RED}Error: Invalid type. Must be one of: library, backend, nextjs, infrastructure${NC}"
    exit 1
fi

# Resolve repo path
if [[ ! "$REPO_PATH" = /* ]]; then
    REPO_PATH="$PROJECT_ROOT/$REPO_PATH"
fi

if [ ! -d "$REPO_PATH" ]; then
    echo -e "${RED}Error: Repository path not found: $REPO_PATH${NC}"
    exit 1
fi

# Extract repo name
REPO_NAME=$(basename "$REPO_PATH")
echo -e "${BLUE}🔧 Preparing $REPO_NAME (type: $REPO_TYPE)...${NC}"
echo ""

cd "$REPO_PATH"

# A) Clean Git History (optional)
if [ "$CLEAN_HISTORY" = true ]; then
    echo -e "${YELLOW}⚠️  Cleaning git history...${NC}"
    
    if command -v git-filter-repo &> /dev/null; then
        # Remove .env files from history
        if git log --all --full-history -- ".env*" | grep -q commit; then
            git filter-repo --path '.env*' --invert-paths --force
            echo -e "${GREEN}✓ Removed .env files from git history${NC}"
        else
            echo -e "${GREEN}✓ No .env files found in history${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  git-filter-repo not installed, skipping history cleaning${NC}"
        echo -e "${YELLOW}   Install with: pip3 install git-filter-repo${NC}"
    fi
    echo ""
fi

# B) Apply Templates

# 1. Copy .npmrc
if [ -f "$TEMPLATES_DIR/.npmrc.template" ]; then
    cp "$TEMPLATES_DIR/.npmrc.template" .npmrc
    echo -e "${GREEN}✓ Applied .npmrc template${NC}"
fi

# 2. Copy workflow
mkdir -p .github/workflows
WORKFLOW_TEMPLATE="$TEMPLATES_DIR/${REPO_TYPE}-workflow.yml.template"
if [ -f "$WORKFLOW_TEMPLATE" ]; then
    cp "$WORKFLOW_TEMPLATE" .github/workflows/build.yml
    echo -e "${GREEN}✓ Applied workflow template (${REPO_TYPE})${NC}"
else
    echo -e "${YELLOW}⚠️  No workflow template found for type: $REPO_TYPE${NC}"
fi

# 3. Create README.md
if [ -f "$TEMPLATES_DIR/README.md.template" ]; then
    sed "s/PROJECT_NAME/$REPO_NAME/g" "$TEMPLATES_DIR/README.md.template" > README.md
    echo -e "${GREEN}✓ Created README.md${NC}"
fi

# C) Fix package.json
if [ -f "package.json" ]; then
    # Backup original
    cp package.json package.json.backup
    
    # Count replacements
    REPLACEMENT_COUNT=0
    
    # Replace workspace:* dependencies
    if grep -q '"workspace:\*"' package.json; then
        # Get list of workspace deps
        DEPS=$(grep '"workspace:\*"' package.json | sed 's/.*"\([^"]*\)".*/\1/')
        
        for DEP in $DEPS; do
            # Extract package name without scope
            PKG_NAME=$(echo "$DEP" | sed 's/@.*\///')
            
            # Replace workspace:* with @WolfgangM81/xxx: ^1.0.0
            sed -i.tmp "s/\"$DEP\": \"workspace:\*\"/\"@WolfgangM81\/$PKG_NAME\": \"^1.0.0\"/" package.json
            ((REPLACEMENT_COUNT++))
        done
    fi
    
    # Replace file:../ dependencies
    if grep -q '"file:' package.json; then
        FILE_DEPS=$(grep '"file:' package.json | sed 's/.*"\([^"]*\)".*/\1/')
        
        for DEP in $FILE_DEPS; do
            # Extract package name
            PKG_NAME=$(echo "$DEP" | sed 's/@.*\///')
            
            # Replace file path with @WolfgangM81/xxx: ^1.0.0
            sed -i.tmp "s|\"$DEP\": \"file:[^\"]*\"|\"@WolfgangM81/$PKG_NAME\": \"^1.0.0\"|" package.json
            ((REPLACEMENT_COUNT++))
        done
    fi
    
    # For libraries: Update package name to @WolfgangM81/xxx
    if [ "$REPO_TYPE" = "library" ]; then
        if ! grep -q '"name": "@WolfgangM81/' package.json; then
            sed -i.tmp "s/\"name\": \"[^\"]*\"/\"name\": \"@WolfgangM81\/$REPO_NAME\"/" package.json
            echo -e "${GREEN}✓ Updated package name to @WolfgangM81/$REPO_NAME${NC}"
        fi
    fi
    
    # Clean up temp files
    rm -f package.json.tmp
    
    if [ $REPLACEMENT_COUNT -gt 0 ]; then
        echo -e "${GREEN}✓ Fixed package.json dependencies ($REPLACEMENT_COUNT replaced)${NC}"
    else
        echo -e "${GREEN}✓ No workspace dependencies to fix${NC}"
    fi
fi

# D) Dockerfile optimization
if [ "$REPO_TYPE" = "backend" ] || [ "$REPO_TYPE" = "nextjs" ]; then
    
    # Create .dockerignore if not exists
    if [ ! -f ".dockerignore" ]; then
        cat > .dockerignore << 'EOF'
node_modules
npm-debug.log
.git
.gitignore
.env*
.DS_Store
dist
coverage
*.md
.vscode
.idea
EOF
        echo -e "${GREEN}✓ Created .dockerignore${NC}"
    fi
    
    # Check if Dockerfile exists and is multi-stage
    if [ -f "Dockerfile" ]; then
        if ! grep -q "FROM.*AS builder" Dockerfile; then
            echo -e "${YELLOW}⚠️  Dockerfile exists but is not multi-stage${NC}"
            echo -e "${YELLOW}   Consider updating to multi-stage build (see templates)${NC}"
        else
            echo -e "${GREEN}✓ Dockerfile already optimized${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  No Dockerfile found${NC}"
    fi
fi

echo ""
echo -e "${GREEN}✅ Repository prepared successfully!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Review changes: git status"
echo "  2. Test build: npm install && npm run build"
echo "  3. Create GitHub repo and push"
echo "  4. Publish to GitHub Packages: npm publish"
