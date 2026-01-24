#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

SERVICES=${1:-"menu-service user-service permissions-service"}
PACKAGES=${2:-"menu-registry backend-common types"}

echo "👀 Watching packages for changes: $PACKAGES"
echo "🔄 Will restart services: $SERVICES"
echo ""

# Store last modification times
declare -A LAST_MOD

get_modification_time() {
  local package=$1
  docker run --rm -v lg-development_lg-packages-dist:/dist alpine stat -c %Y /dist/$package/index.js 2>/dev/null || echo "0"
}

# Initialize
for pkg in $PACKAGES; do
  LAST_MOD[$pkg]=$(get_modification_time $pkg)
done

echo "✅ Initial state captured. Watching for changes..."
echo "   (Press Ctrl+C to stop)"
echo ""

while true; do
  sleep 2

  for pkg in $PACKAGES; do
    CURRENT_MOD=$(get_modification_time $pkg)

    if [ "${LAST_MOD[$pkg]}" != "$CURRENT_MOD" ] && [ "$CURRENT_MOD" != "0" ]; then
      echo "📦 Change detected in $pkg"
      LAST_MOD[$pkg]=$CURRENT_MOD

      # Restart affected services
      for service in $SERVICES; do
        SERVICE_CONTAINER=$(docker ps --filter "name=$service" --format "{{.Names}}" | head -1)
        if [ -n "$SERVICE_CONTAINER" ]; then
          echo "   🔄 Restarting $SERVICE_CONTAINER..."
          docker restart "$SERVICE_CONTAINER" > /dev/null 2>&1 || true
        fi
      done

      echo "   ✅ Services restarted"
      echo ""
    fi
  done
done
