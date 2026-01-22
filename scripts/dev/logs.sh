#!/bin/bash

# ╔══════════════════════════════════════════════════════════════╗
# ║     LG-DEVELOPMENT - LOGS (Docker Compose Logs)               ║
# ╚══════════════════════════════════════════════════════════════╝

if [ -n "$1" ]; then
    # Specific service
    docker-compose logs -f "$1"
else
    # All services
    docker-compose logs -f
fi
