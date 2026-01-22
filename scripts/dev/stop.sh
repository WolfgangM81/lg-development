#!/bin/bash

# ╔══════════════════════════════════════════════════════════════╗
# ║     LG-DEVELOPMENT - STOP (Docker Compose Down)               ║
# ╚══════════════════════════════════════════════════════════════╝

set -e

echo "🛑 Stopping Docker stack..."
docker-compose down
echo "✅ Stack stopped"
