#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

MODE=${1:-status}

case $MODE in
  enable)
    echo "🔄 Enabling package hot-reload..."
    cd "$ROOT_DIR"
    docker-compose -f docker-compose.dev-sync.yml up -d

    echo ""
    echo "✅ Package builders started!"
    echo ""
    echo "📦 Watching packages:"
    echo "   - lg-menu-registry"
    echo "   - lg-backend-common"
    echo "   - lg-types"
    echo ""
    echo "⚡ Changes will appear in ~2-3 seconds"
    echo "🔍 View logs: $0 logs <package-name>"
    echo ""
    echo "💡 Tip: Edit a package source file and watch the magic happen!"
    ;;

  disable)
    echo "🛑 Disabling package hot-reload..."
    cd "$ROOT_DIR"
    docker-compose -f docker-compose.dev-sync.yml down
    echo "✅ Builders stopped"
    echo "📦 Services will use npm-installed versions"
    ;;

  status)
    echo "📊 Package builder status:"
    echo ""
    cd "$ROOT_DIR"
    docker-compose -f docker-compose.dev-sync.yml ps
    echo ""
    echo "📁 Shared volume contents:"
    if docker volume inspect lg-packages-dist &>/dev/null; then
      docker run --rm -v lg-packages-dist:/dist alpine ls -lah /dist 2>/dev/null || echo "Volume exists but is empty"
    else
      echo "Volume not created yet. Run '$0 enable' first."
    fi
    ;;

  logs)
    PACKAGE=${2:-menu-registry}
    echo "📜 Logs for ${PACKAGE}-builder:"
    cd "$ROOT_DIR"
    docker-compose -f docker-compose.dev-sync.yml logs -f ${PACKAGE}-builder
    ;;

  rebuild)
    echo "🔨 Rebuilding all packages..."
    cd "$ROOT_DIR"
    docker-compose -f docker-compose.dev-sync.yml restart
    echo "✅ Builders restarted"
    ;;

  clean)
    echo "🧹 Cleaning package build artifacts..."
    cd "$ROOT_DIR"
    docker-compose -f docker-compose.dev-sync.yml down -v
    echo "✅ Build artifacts cleaned (volume removed)"
    ;;

  *)
    echo "Usage: $0 {enable|disable|status|logs [package]|rebuild|clean}"
    echo ""
    echo "Examples:"
    echo "  $0 enable              # Start hot-reload mode"
    echo "  $0 status              # Check builder status"
    echo "  $0 logs menu-registry  # View compilation logs"
    echo "  $0 logs backend-common # View backend-common logs"
    echo "  $0 logs types          # View types logs"
    echo "  $0 rebuild             # Restart all builders"
    echo "  $0 disable             # Stop hot-reload mode"
    echo "  $0 clean               # Remove build artifacts"
    exit 1
    ;;
esac
