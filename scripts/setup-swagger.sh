#!/usr/bin/env bash
#
# setup-swagger.sh - Install Swagger/OpenAPI documentation for all services
#
# This script adds Swagger UI and OpenAPI documentation to all services

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📚 Setting up Swagger/OpenAPI Documentation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if we're in the right directory
if [[ ! -d "repos/services" ]]; then
    echo -e "${RED}❌ Error: Must run from lg-development root directory${NC}"
    exit 1
fi

# Service configurations
declare -A SERVICES=(
    ["lg-user-service"]="3002:User Service:User authentication and management"
    ["lg-permissions-service"]="3003:Permissions Service:RBAC and organizational units"
    ["lg-api-keys-service"]="3001:API Keys Service:API key validation"
    ["lg-menu-service"]="3005:Menu Service:Hierarchical menu management"
    ["lg-tour-service"]="3004:Tour Service:NextStepjs integration"
    ["lg-secrets-service"]="3007:Secrets Service:Encrypted secrets management"
)

echo -e "${GREEN}Installing Swagger dependencies...${NC}"
echo ""

for SERVICE_DIR in "${!SERVICES[@]}"; do
    SERVICE_PATH="repos/services/$SERVICE_DIR"

    if [[ ! -d "$SERVICE_PATH" ]]; then
        echo -e "${YELLOW}⊘ $SERVICE_DIR: Not found, skipping${NC}"
        continue
    fi

    echo -e "${BLUE}📦 $SERVICE_DIR${NC}"

    # Parse service config
    IFS=':' read -r PORT NAME DESCRIPTION <<< "${SERVICES[$SERVICE_DIR]}"

    # Install swagger dependencies
    echo "  - Installing swagger-jsdoc and swagger-ui-express..."
    docker run --rm -v "$(pwd)/$SERVICE_PATH:/app" -w /app node:20-alpine sh -c "
        npm install --save swagger-jsdoc swagger-ui-express
        npm install --save-dev @types/swagger-jsdoc @types/swagger-ui-express
    " 2>&1 | grep -v "^npm WARN" || true

    # Copy swagger setup template
    echo "  - Creating src/swagger.ts..."
    if [[ ! -f "$SERVICE_PATH/src/swagger.ts" ]]; then
        cp templates/swagger-setup.ts "$SERVICE_PATH/src/swagger.ts"

        # Customize for this service
        sed -i.tmp "s/const SERVICE_NAME = .*/const SERVICE_NAME = '$NAME';/" "$SERVICE_PATH/src/swagger.ts"
        sed -i.tmp "s/const SERVICE_DESCRIPTION = .*/const SERVICE_DESCRIPTION = '$DESCRIPTION';/" "$SERVICE_PATH/src/swagger.ts"
        sed -i.tmp "s/const SERVICE_PORT = .*/const SERVICE_PORT = $PORT;/" "$SERVICE_PATH/src/swagger.ts"
        rm "$SERVICE_PATH/src/swagger.ts.tmp"

        echo -e "  ${GREEN}✓ Created swagger.ts${NC}"
    else
        echo -e "  ${YELLOW}⊘ swagger.ts already exists${NC}"
    fi

    # Add swagger to server.ts if not already present
    if [[ -f "$SERVICE_PATH/src/server.ts" ]]; then
        if ! grep -q "setupSwagger" "$SERVICE_PATH/src/server.ts"; then
            echo "  - Adding setupSwagger to server.ts..."
            echo "    ${YELLOW}(Manual step required - see documentation)${NC}"
        else
            echo -e "  ${GREEN}✓ setupSwagger already in server.ts${NC}"
        fi
    fi

    echo ""
done

echo -e "${GREEN}✅ Swagger dependencies installed!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Add setupSwagger to each service's server.ts:"
echo "   ${BLUE}import { setupSwagger } from './swagger';${NC}"
echo "   ${BLUE}setupSwagger(app);${NC}"
echo ""
echo "2. Annotate routes with OpenAPI comments (see templates/swagger-route-example.ts)"
echo ""
echo "3. Rebuild services:"
echo "   ${BLUE}docker-compose up -d --build${NC}"
echo ""
echo "4. Access Swagger UI:"
echo "   ${BLUE}http://api.lg.local/user/api-docs${NC}      (User Service)"
echo "   ${BLUE}http://api.lg.local/permissions/api-docs${NC} (Permissions Service)"
echo "   ${BLUE}http://api.lg.local/v1/api-docs${NC}         (API Keys Service)"
echo ""
echo "5. Create aggregator (optional):"
echo "   ${BLUE}./scripts/create-swagger-aggregator.sh${NC}"
echo ""
