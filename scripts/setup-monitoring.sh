#!/usr/bin/env bash
#
# setup-monitoring.sh - Set up Prometheus and Grafana monitoring
#
# This script installs metrics middleware in all services and starts monitoring stack

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📊 Setting up Monitoring Stack${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if we're in the right directory
if [[ ! -d "repos/services" ]]; then
    echo -e "${RED}❌ Error: Must run from lg-development root directory${NC}"
    exit 1
fi

# Step 1: Install prom-client in services
echo -e "${GREEN}Step 1: Installing prom-client dependency...${NC}"
echo ""

for SERVICE in repos/services/lg-*; do
    if [[ ! -d "$SERVICE" ]]; then
        continue
    fi

    SERVICE_NAME=$(basename "$SERVICE")
    echo -e "${BLUE}📦 $SERVICE_NAME${NC}"

    # Install prom-client
    docker run --rm -v "$(pwd)/$SERVICE:/app" -w /app node:20-alpine sh -c "
        npm install --save prom-client
    " 2>&1 | grep -v "^npm WARN" || true

    echo -e "  ${GREEN}✓ Installed prom-client${NC}"
    echo ""
done

# Step 2: Copy metrics middleware template
echo -e "${GREEN}Step 2: Copying metrics middleware...${NC}"
echo ""

declare -A SERVICES=(
    ["lg-user-service"]="user-service"
    ["lg-permissions-service"]="permissions-service"
    ["lg-api-keys-service"]="api-keys-service"
    ["lg-menu-service"]="menu-service"
    ["lg-tour-service"]="tour-service"
    ["lg-secrets-service"]="secrets-service"
)

for SERVICE_DIR in "${!SERVICES[@]}"; do
    SERVICE_PATH="repos/services/$SERVICE_DIR"
    SERVICE_NAME="${SERVICES[$SERVICE_DIR]}"

    if [[ ! -d "$SERVICE_PATH" ]]; then
        echo -e "${YELLOW}⊘ $SERVICE_DIR: Not found, skipping${NC}"
        continue
    fi

    echo -e "${BLUE}📦 $SERVICE_DIR${NC}"

    # Create middleware directory
    mkdir -p "$SERVICE_PATH/src/middleware"

    # Copy and customize metrics template
    if [[ ! -f "$SERVICE_PATH/src/middleware/metrics.ts" ]]; then
        cp templates/metrics-middleware.ts "$SERVICE_PATH/src/middleware/metrics.ts"

        # Customize SERVICE_NAME
        sed -i.tmp "s/const SERVICE_NAME = .*/const SERVICE_NAME = '$SERVICE_NAME';/" "$SERVICE_PATH/src/middleware/metrics.ts"
        rm "$SERVICE_PATH/src/middleware/metrics.ts.tmp"

        echo -e "  ${GREEN}✓ Created metrics.ts${NC}"
    else
        echo -e "  ${YELLOW}⊘ metrics.ts already exists${NC}"
    fi

    echo ""
done

# Step 3: Add /etc/hosts entries
echo -e "${GREEN}Step 3: Checking /etc/hosts entries...${NC}"
echo ""

if ! grep -q "grafana.lg.local" /etc/hosts 2>/dev/null; then
    echo -e "${YELLOW}Add to /etc/hosts:${NC}"
    echo "127.0.0.1 grafana.lg.local"
    echo "127.0.0.1 prometheus.lg.local"
    echo ""
    echo -e "${YELLOW}Run:${NC}"
    echo "sudo sh -c \"echo '127.0.0.1 grafana.lg.local' >> /etc/hosts\""
    echo "sudo sh -c \"echo '127.0.0.1 prometheus.lg.local' >> /etc/hosts\""
else
    echo -e "${GREEN}✓ Hosts already configured${NC}"
fi
echo ""

# Step 4: Start monitoring stack
echo -e "${GREEN}Step 4: Starting monitoring stack...${NC}"
echo ""

cd repos/infrastructure/lg-monitoring
docker-compose up -d
cd ../../..

echo ""
echo -e "${GREEN}✅ Monitoring setup complete!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Add metrics middleware to each service's server.ts:"
echo "   ${BLUE}import { metricsMiddleware, metricsHandler } from './middleware/metrics';${NC}"
echo "   ${BLUE}app.use(metricsMiddleware);${NC}"
echo "   ${BLUE}app.get('/metrics', metricsHandler);${NC}"
echo ""
echo "2. Rebuild services:"
echo "   ${BLUE}docker-compose up -d --build${NC}"
echo ""
echo "3. Access monitoring:"
echo "   ${BLUE}http://grafana.lg.local${NC}      (Grafana Dashboard)"
echo "   ${BLUE}http://prometheus.lg.local${NC}   (Prometheus UI)"
echo ""
echo "4. Default Grafana credentials:"
echo "   Username: admin"
echo "   Password: admin (change on first login)"
echo ""
echo "5. View service metrics:"
echo "   ${BLUE}curl http://api.lg.local/user/metrics${NC}"
echo ""
