#!/bin/bash
# scripts/lib/detect-ports.sh
#
# Detect occupied ports and find free alternatives for LG services
# Writes results to .env.ports (sourced by start script)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Check if a port is available
is_port_free() {
    local port=$1
    ! lsof -i :"$port" -P -n >/dev/null 2>&1
}

# Find next free port starting from given port
find_free_port() {
    local port=$1
    local max_tries=100
    local tried=0

    while [ $tried -lt $max_tries ]; do
        if is_port_free "$port"; then
            echo "$port"
            return 0
        fi
        port=$((port + 1))
        tried=$((tried + 1))
    done

    echo "0"
    return 1
}

# Resolve port: check default, fallback to alternative range
resolve_port() {
    local var_name=$1
    local default_port=$2
    local alt_port=$3

    if is_port_free "$default_port"; then
        echo "  ✅ $var_name=$default_port"
        echo "${var_name}=${default_port}" >> "$PORTS_FILE"
    else
        # Find what's using the port
        local blocker
        blocker=$(lsof -i :"$default_port" -P -n 2>/dev/null | awk 'NR==2 {print $1}' || echo "unknown")

        local free_port
        free_port=$(find_free_port "$alt_port")
        if [ "$free_port" != "0" ]; then
            echo "  ⚠️  $var_name=$free_port (Port $default_port belegt von: $blocker)"
            echo "${var_name}=${free_port}" >> "$PORTS_FILE"
            CONFLICTS=$((CONFLICTS + 1))

            # Special hint for HTTP port
            if [ "$var_name" = "TRAEFIK_HTTP_PORT" ] && [ "$free_port" != "80" ]; then
                PORT_80_BLOCKED=true
                PORT_80_BLOCKER="$blocker"
            fi
        else
            echo "  ❌ $var_name: kein freier Port gefunden!"
            echo "${var_name}=${default_port}" >> "$PORTS_FILE"
        fi
    fi
}

echo "🔍 Detecting available ports..."
echo ""

PORTS_FILE="${ROOT_DIR}/.env.ports"
PORT_80_BLOCKED=false
PORT_80_BLOCKER=""
cat > "$PORTS_FILE" <<EOF
# Auto-generated port configuration
# Generated at: $(date)
# Re-run: ./scripts/lib/detect-ports.sh

EOF

CONFLICTS=0

#                  ENV_VAR                 DEFAULT  ALTERNATIVE
resolve_port       TRAEFIK_HTTP_PORT       80       8180
resolve_port       TRAEFIK_HTTPS_PORT      443      8443
resolve_port       TRAEFIK_DASHBOARD_PORT  8080     8181
resolve_port       POSTGRES_PORT           5432     5433
resolve_port       REDIS_PORT              6379     6380
resolve_port       VERDACCIO_PORT          4873     4874
resolve_port       DYNAMODB_PORT           8000     8001

echo ""

if [ $CONFLICTS -gt 0 ]; then
    echo "ℹ️  $CONFLICTS Port(s) umbelegt wegen Konflikten"

    # Special message for port 80
    if [ "$PORT_80_BLOCKED" = "true" ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "⚠️  Port 80 belegt von: $PORT_80_BLOCKER"
        echo ""
        echo "   URLs mit Port: http://admin.lg.local:${TRAEFIK_HTTP_PORT:-8180}/"
        echo ""
        echo "   Für URLs ohne Port: $PORT_80_BLOCKER stoppen"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
else
    echo "✅ Alle Ports verfügbar - URLs ohne Port möglich"
fi

echo ""
echo "📄 Port config: .env.ports"
