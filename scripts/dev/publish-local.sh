#!/usr/bin/env bash
set -e

# Publish package to local Verdaccio registry for testing
# Usage: ./scripts/dev/publish-local.sh lg-menu-registry

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TOKEN_FILE="$SCRIPT_DIR/.verdaccio-token"

if [ -z "$1" ]; then
  echo "❌ Error: Package name required"
  echo ""
  echo "Usage: $0 <package-name>"
  echo ""
  echo "Available packages:"
  find "$REPO_ROOT/repos" -maxdepth 1 -type d \( -name "lg-*" -o -name "*-service" \) | grep -v node_modules | sort | xargs -n1 basename | sed 's/^/  - /'
  exit 1
fi

# Check if logged in
if [ ! -f "$TOKEN_FILE" ]; then
  echo "❌ Not logged in to Verdaccio"
  echo ""
  echo "Please run first:"
  echo "  ./scripts/dev/verdaccio-login.sh"
  exit 1
fi

AUTH_TOKEN=$(cat "$TOKEN_FILE")

PACKAGE_NAME="$1"
PACKAGE_DIR="$REPO_ROOT/repos/$PACKAGE_NAME"

if [ ! -d "$PACKAGE_DIR" ]; then
  echo "❌ Error: Package directory not found: $PACKAGE_DIR"
  exit 1
fi

echo "📦 Publishing $PACKAGE_NAME to local Verdaccio..."
echo ""

cd "$PACKAGE_DIR"

# Create local .npmrc for Verdaccio (use host.docker.internal for macOS Docker Desktop)
cat > .npmrc.local << EOF
registry=http://host.docker.internal:4873/
@wolfgangm81:registry=http://host.docker.internal:4873/
@licenseguard:registry=http://host.docker.internal:4873/
@apikeys:registry=http://host.docker.internal:4873/
//host.docker.internal:4873/:_authToken=$AUTH_TOKEN
EOF

echo "1️⃣ Running tests..."
docker run --rm -v "$(pwd):/app" -w /app node:20-alpine npm test

echo ""
echo "2️⃣ Running typecheck..."
docker run --rm -v "$(pwd):/app" -w /app node:20-alpine npm run typecheck

echo ""
echo "3️⃣ Publishing to Verdaccio..."
docker run --rm \
  -v "$(pwd):/app" \
  -w /app \
  node:20-alpine sh -c "
    cp .npmrc.local .npmrc
    npm publish --registry http://host.docker.internal:4873/
  "

PKG_NAME=$(node -p "require('./package.json').name" 2>/dev/null || echo "package")

echo ""
echo "✅ Published successfully!"
echo ""
echo "📥 To install from local registry:"
echo "   ./scripts/dev/install-local.sh <target-package> $PKG_NAME"
echo ""
echo "🔍 View in browser: http://localhost:4873/"

# Clean up
rm -f .npmrc.local
