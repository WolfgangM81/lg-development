#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Check if jq is available (needed for dependency mapping)
if ! command -v jq &> /dev/null; then
    echo "⚠️  jq not found - falling back to restart all services mode"
    USE_SMART_RESTART=false
else
    USE_SMART_RESTART=true
fi

PACKAGES=${1:-"menu-registry backend-common types"}

if [ "$USE_SMART_RESTART" = true ]; then
    echo "👀 Watching packages for changes: $PACKAGES"
    echo "🎯 Using smart restart (only affected services)"
    echo ""
else
    SERVICES=${2:-"menu-service user-service permissions-service api-keys-service secrets-service tour-service"}
    echo "👀 Watching packages for changes: $PACKAGES"
    echo "🔄 Will restart services: $SERVICES"
    echo ""
fi

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

      # Determine which services to restart
      if [ "$USE_SMART_RESTART" = true ] && [ -f "$SCRIPT_DIR/package-dependencies.json" ]; then
        # Smart restart: only affected services
        AFFECTED_SERVICES=$(jq -r ".\"$pkg\" | .[]" "$SCRIPT_DIR/package-dependencies.json" 2>/dev/null || echo "")

        if [ -z "$AFFECTED_SERVICES" ]; then
          echo "   ⚠️  No services depend on $pkg (check package-dependencies.json)"
          continue
        fi

        echo "   🎯 Restarting affected services: $(echo $AFFECTED_SERVICES | tr '\n' ' ')"

        for service in $AFFECTED_SERVICES; do
          SERVICE_CONTAINER=$(docker ps --filter "name=$service" --format "{{.Names}}" | head -1)
          if [ -n "$SERVICE_CONTAINER" ]; then
            echo "      🔄 $SERVICE_CONTAINER..."
            docker restart "$SERVICE_CONTAINER" > /dev/null 2>&1 || true
          fi
        done
      else
        # Fallback: restart all services
        for service in $SERVICES; do
          SERVICE_CONTAINER=$(docker ps --filter "name=$service" --format "{{.Names}}" | head -1)
          if [ -n "$SERVICE_CONTAINER" ]; then
            echo "   🔄 Restarting $SERVICE_CONTAINER..."
            docker restart "$SERVICE_CONTAINER" > /dev/null 2>&1 || true
          fi
        done
      fi

      echo "   ✅ Services restarted"
      echo ""
    fi
  done
done
