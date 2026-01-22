#!/bin/bash

# ╔══════════════════════════════════════════════════════════════╗
# ║     LG-DEVELOPMENT - START (Docker Compose Up)                ║
# ╚══════════════════════════════════════════════════════════════╝

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ ! -f docker-compose.yml ]; then
    echo "❌ docker-compose.yml not found!"
    exit 1
fi

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     🚀 STARTING DOCKER STACK                                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

docker-compose up -d

echo ""
echo -e "${GREEN}✅ Stack started!${NC}"
echo ""
echo "View logs:    ./scripts/dev/logs.sh"
echo "Stop stack:   ./scripts/dev/stop.sh"
echo "Check status: docker-compose ps"
