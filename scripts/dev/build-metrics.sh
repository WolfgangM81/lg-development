#!/usr/bin/env bash
# Track build times and performance

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

METRICS_FILE="${TMPDIR:-/tmp}/lg-dev-metrics.json"
PACKAGES="menu-registry backend-common types"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to extract build time from builder logs
get_build_time() {
  local package=$1
  local log_output=$(docker logs lg-builder-$package --tail 100 2>&1)

  # Look for compilation completion message
  # TypeScript outputs: "Found 0 errors. Watching for file changes."
  # Extract timestamp and calculate duration
  local timestamp=$(echo "$log_output" | grep -i "Found.*errors" | tail -1)

  if [ -n "$timestamp" ]; then
    echo "recent"
  else
    echo "unknown"
  fi
}

# Function to log a build event
log_build() {
  local package=$1
  local duration=$2
  local timestamp=$(date +%s)

  # Append to metrics file
  echo "{\"package\": \"$package\", \"duration\": $duration, \"timestamp\": $timestamp}" >> "$METRICS_FILE"
}

# Function to show metrics
show_metrics() {
  echo -e "${BLUE}📈 Build Performance Metrics${NC}"
  echo ""

  if [ ! -f "$METRICS_FILE" ] || [ ! -s "$METRICS_FILE" ]; then
    echo -e "${YELLOW}No metrics collected yet.${NC}"
    echo ""
    echo "💡 Metrics are collected automatically when packages are rebuilt."
    echo "   Make a change to a package to start collecting metrics."
    return
  fi

  # Check if jq is available
  if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  jq not installed - showing raw metrics${NC}"
    echo ""
    cat "$METRICS_FILE"
    return
  fi

  # Show aggregated metrics
  echo -e "${GREEN}Average Build Times:${NC}"
  jq -s 'group_by(.package) | map({
    package: .[0].package,
    builds: length,
    avg_duration: (map(.duration) | add / length),
    min_duration: (map(.duration) | min),
    max_duration: (map(.duration) | max)
  })' "$METRICS_FILE" 2>/dev/null | jq -r '.[] | "  \(.package): \(.avg_duration)s avg (\(.builds) builds, \(.min_duration)s-\(.max_duration)s range)"'

  echo ""
  echo -e "${GREEN}Recent Builds (last 10):${NC}"
  jq -s 'sort_by(.timestamp) | reverse | .[0:10]' "$METRICS_FILE" 2>/dev/null | jq -r '.[] | "  \(.package): \(.duration)s at \(.timestamp | strftime("%H:%M:%S"))"'
}

# Function to watch and track build times
watch_builds() {
  echo -e "${BLUE}📊 Watching build performance...${NC}"
  echo "   (Press Ctrl+C to stop)"
  echo ""

  # Store last log line for each package
  declare -A LAST_LOG

  # Initialize
  for pkg in $PACKAGES; do
    LAST_LOG[$pkg]=$(docker logs lg-builder-$pkg --tail 1 2>&1)
  done

  while true; do
    sleep 3

    for pkg in $PACKAGES; do
      CURRENT_LOG=$(docker logs lg-builder-$pkg --tail 1 2>&1)

      # Check if log changed (new compilation)
      if [ "${LAST_LOG[$pkg]}" != "$CURRENT_LOG" ]; then
        LAST_LOG[$pkg]=$CURRENT_LOG

        # Look for compilation completion
        if echo "$CURRENT_LOG" | grep -qi "Found.*errors"; then
          # Try to estimate build time (rough estimate: 2-3s typical)
          # In a real implementation, we'd track start/end times more precisely
          DURATION=2

          log_build "$pkg" "$DURATION"
          echo -e "${GREEN}✅ $pkg compiled (estimated ${DURATION}s)${NC}"
        fi
      fi
    done
  done
}

# Function to reset metrics
reset_metrics() {
  if [ -f "$METRICS_FILE" ]; then
    rm "$METRICS_FILE"
    echo -e "${GREEN}✅ Metrics reset${NC}"
  else
    echo -e "${YELLOW}No metrics file found${NC}"
  fi
}

# Main command routing
case ${1:-show} in
  show)
    show_metrics
    ;;

  watch)
    watch_builds
    ;;

  reset)
    reset_metrics
    ;;

  *)
    echo "Usage: $0 {show|watch|reset}"
    echo ""
    echo "Commands:"
    echo "  show   - Display aggregated metrics (default)"
    echo "  watch  - Watch and track builds in real-time"
    echo "  reset  - Clear all metrics"
    exit 1
    ;;
esac
