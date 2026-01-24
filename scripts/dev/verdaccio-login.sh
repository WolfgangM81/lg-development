#!/usr/bin/env bash
set -e

# Login to local Verdaccio and save token for reuse
# Usage: ./scripts/dev/verdaccio-login.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN_FILE="$SCRIPT_DIR/.verdaccio-token"

echo "🔐 Logging in to local Verdaccio..."
echo ""

# Create or get auth token (use timestamp to avoid conflicts)
USERNAME="dev$(date +%s)"
AUTH_RESPONSE=$(curl -s -X PUT http://localhost:4873/-/user/org.couchdb.user:$USERNAME \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$USERNAME\",\"password\":\"devpass123\"}")

# Try to extract token (handles both "token":"xxx" and "token": "xxx" formats)
AUTH_TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"token"[^}]*' | sed 's/"token"[^"]*"//' | sed 's/[",: ]//g')

# If user exists, token might already be in response
if [ -z "$AUTH_TOKEN" ]; then
  echo "❌ Failed to create/login user"
  echo "Response: $AUTH_RESPONSE"
  echo ""
  echo "Try removing existing user and retry:"
  echo "  docker exec lg-development-infra-verdaccio-1 rm -f /verdaccio/conf/htpasswd"
  echo "  docker restart lg-development-infra-verdaccio-1"
  exit 1
fi

# Save token
echo "$AUTH_TOKEN" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"

echo "✅ Login successful!"
echo ""
echo "Token saved to: $TOKEN_FILE"
echo ""
echo "📦 You can now use ./scripts/dev/publish-local.sh to publish packages"
