#!/usr/bin/env bash
# Simple CLI dashboard for build status

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if watch command is available
if ! command -v watch &> /dev/null; then
  echo -e "${RED}❌ 'watch' command not found!${NC}"
  echo ""
  echo "Install it with:"
  echo "  macOS:  brew install watch"
  echo "  Linux:  apt-get install procps"
  echo ""
  echo "Falling back to manual refresh mode..."
  echo "Press Ctrl+C to exit"
  echo ""

  while true; do
    clear
    "$0" --once
    sleep 2
  done
  exit 0
fi

# One-time display (used by watch or manual loop)
if [ "$1" = "--once" ]; then
  echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║     🔧 HOT-RELOAD DASHBOARD                                   ║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  # Check if dev-sync is enabled
  if ! docker-compose -f "$ROOT_DIR/docker-compose.dev-sync.yml" ps 2>/dev/null | grep -q Up; then
    echo -e "${YELLOW}⚠️  Hot-reload is DISABLED${NC}"
    echo ""
    echo "Start it with: make dev-sync"
    exit 0
  fi

  echo -e "${GREEN}📦 Builders:${NC}"
  docker-compose -f "$ROOT_DIR/docker-compose.dev-sync.yml" ps 2>/dev/null || echo "No builders running"
  echo ""

  echo -e "${GREEN}📁 Last Build Activity:${NC}"
  for pkg in menu-registry backend-common types; do
    LAST_LINE=$(docker logs lg-builder-$pkg --tail 1 2>&1)
    if echo "$LAST_LINE" | grep -qi "Found.*errors"; then
      ERROR_COUNT=$(echo "$LAST_LINE" | grep -oP '\d+(?= errors?)' || echo "0")
      if [ "$ERROR_COUNT" = "0" ]; then
        echo -e "  ${GREEN}✅ $pkg: $LAST_LINE${NC}"
      else
        echo -e "  ${RED}❌ $pkg: $LAST_LINE${NC}"
      fi
    else
      echo -e "  ${YELLOW}⏳ $pkg: $LAST_LINE${NC}"
    fi
  done

  echo ""
  echo -e "${GREEN}📊 Volume Status:${NC}"
  if docker volume inspect lg-development_lg-packages-dist &>/dev/null; then
    VOLUME_SIZE=$(docker run --rm -v lg-development_lg-packages-dist:/dist alpine du -sh /dist 2>/dev/null | cut -f1)
    echo "  Size: $VOLUME_SIZE"

    echo ""
    echo "  Contents:"
    docker run --rm -v lg-development_lg-packages-dist:/dist alpine ls -lh /dist 2>/dev/null | tail -n +2 | while read line; do
      echo "    $line"
    done
  else
    echo -e "  ${RED}Volume not created${NC}"
  fi

  echo ""
  echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
  echo -e "${YELLOW}Press Ctrl+C to exit | Refreshes every 2s${NC}"

  exit 0
fi

# Use watch to continuously refresh
watch -n 2 -c "$0 --once"
