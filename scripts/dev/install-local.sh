#!/usr/bin/env bash
set -e

# Install package from local Verdaccio registry
# Usage: ./scripts/dev/install-local.sh lg-user-service @wolfgangm81/menu-registry

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "❌ Error: Package name and dependency required"
  echo ""
  echo "Usage: $0 <target-package> <dependency-to-install>"
  echo ""
  echo "Examples:"
  echo "  $0 lg-user-service @wolfgangm81/menu-registry"
  echo "  $0 lg-admin @wolfgangm81/admin-ui"
  exit 1
fi

TARGET_PACKAGE="$1"
DEPENDENCY="$2"
TARGET_DIR="$REPO_ROOT/repos/$TARGET_PACKAGE"

if [ ! -d "$TARGET_DIR" ]; then
  echo "❌ Error: Target directory not found: $TARGET_DIR"
  exit 1
fi

echo "📥 Installing $DEPENDENCY into $TARGET_PACKAGE from local Verdaccio..."
echo ""

cd "$TARGET_DIR"

# Create local .npmrc for Verdaccio
cat > .npmrc.local << 'EOF'
@wolfgangm81:registry=http://localhost:4873/
@licenseguard:registry=http://localhost:4873/
@apikeys:registry=http://localhost:4873/
//localhost:4873/:_authToken=""
EOF

docker run --rm \
  -v "$(pwd):/app" \
  -w /app \
  --network host \
  node:20-alpine sh -c "
    cp .npmrc.local .npmrc
    npm install $DEPENDENCY --registry http://localhost:4873/
  "

echo ""
echo "✅ Installed successfully!"

# Clean up
rm -f .npmrc.local
