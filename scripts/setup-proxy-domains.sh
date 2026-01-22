#!/bin/bash

###############################################################################
# Setup Proxy Domains - LG Development Environment
###############################################################################
#
# This script configures /etc/hosts for local proxy domains without ports.
#
# Usage:
#   ./scripts/setup-proxy-domains.sh
#
###############################################################################

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Domains to add
DOMAINS=(
  "admin.lg.local"
  "api.lg.local"
  "traefik.lg.local"
)

# Header
echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}  Setup Proxy Domains${NC}"
echo -e "${GREEN}====================================${NC}"
echo

# Check if running on macOS or Linux
OS="$(uname)"
if [[ "$OS" != "Darwin" && "$OS" != "Linux" ]]; then
  echo -e "${RED}✗ Error: This script only supports macOS and Linux.${NC}"
  echo "For Windows, manually add to C:\\Windows\\System32\\drivers\\etc\\hosts:"
  echo
  for domain in "${DOMAINS[@]}"; do
    echo "  127.0.0.1 $domain"
  done
  exit 1
fi

# Check if /etc/hosts is writable (requires sudo)
if [[ ! -w /etc/hosts ]]; then
  echo -e "${YELLOW}⚠ /etc/hosts requires sudo access.${NC}"
  echo "You will be prompted for your password."
  echo
fi

# Check if domains already exist
MISSING_DOMAINS=()
for domain in "${DOMAINS[@]}"; do
  if ! grep -q "$domain" /etc/hosts; then
    MISSING_DOMAINS+=("$domain")
  else
    echo -e "${GREEN}✓${NC} $domain already exists in /etc/hosts"
  fi
done

# If all domains exist, exit
if [[ ${#MISSING_DOMAINS[@]} -eq 0 ]]; then
  echo
  echo -e "${GREEN}✓ All proxy domains already configured!${NC}"
  echo
  echo "You can now access services at:"
  for domain in "${DOMAINS[@]}"; do
    echo -e "  ${GREEN}→${NC} http://$domain"
  done
  echo
  exit 0
fi

# Show domains to add
echo
echo "The following domains will be added to /etc/hosts:"
for domain in "${MISSING_DOMAINS[@]}"; do
  echo -e "  ${YELLOW}+${NC} 127.0.0.1 $domain"
done
echo

# Confirmation
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${RED}✗ Aborted.${NC}"
  exit 1
fi

# Backup /etc/hosts
BACKUP_FILE="/etc/hosts.backup.$(date +%Y%m%d_%H%M%S)"
echo
echo "Creating backup: $BACKUP_FILE"
sudo cp /etc/hosts "$BACKUP_FILE"
echo -e "${GREEN}✓${NC} Backup created"

# Add domains to /etc/hosts
echo
echo "Adding domains to /etc/hosts..."
{
  echo ""
  echo "# LG Development Environment (added $(date))"
  for domain in "${MISSING_DOMAINS[@]}"; do
    echo "127.0.0.1 $domain"
  done
} | sudo tee -a /etc/hosts > /dev/null

echo -e "${GREEN}✓${NC} Domains added to /etc/hosts"

# Verify
echo
echo "Verifying configuration..."
for domain in "${MISSING_DOMAINS[@]}"; do
  if grep -q "$domain" /etc/hosts; then
    echo -e "${GREEN}✓${NC} $domain"
  else
    echo -e "${RED}✗${NC} $domain (failed to add)"
  fi
done

# Flush DNS cache
echo
echo "Flushing DNS cache..."
if [[ "$OS" == "Darwin" ]]; then
  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder
elif [[ "$OS" == "Linux" ]]; then
  # Linux varies by distribution
  if command -v systemd-resolve &> /dev/null; then
    sudo systemd-resolve --flush-caches
  elif command -v nscd &> /dev/null; then
    sudo nscd -i hosts
  fi
fi
echo -e "${GREEN}✓${NC} DNS cache flushed"

# Success
echo
echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}  ✓ Setup Complete!${NC}"
echo -e "${GREEN}====================================${NC}"
echo
echo "You can now access services at:"
for domain in "${DOMAINS[@]}"; do
  echo -e "  ${GREEN}→${NC} http://$domain"
done
echo
echo "Next steps:"
echo "  1. Start services: docker-compose up -d"
echo "  2. Test Admin UI: http://admin.lg.local"
echo "  3. Test API Gateway: http://api.lg.local/user/health"
echo "  4. Open Traefik Dashboard: http://traefik.lg.local"
echo
echo "See PROXY_DOMAINS.md for full documentation."
echo
