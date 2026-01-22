#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_SECRETS="$PROJECT_ROOT/.env.secrets"

REPO_OWNER="yourusername"  # TODO: Update with actual GitHub username/org
SINGLE_REPO=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --repo)
      SINGLE_REPO="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--repo REPO_NAME]"
      exit 1
      ;;
  esac
done

# Helper functions
info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

success() {
  echo -e "  ${GREEN}✓${NC} $1"
}

error() {
  echo -e "${RED}✗${NC} $1" >&2
}

warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

# Check prerequisites
check_prerequisites() {
  info "Checking prerequisites..."
  
  # Check gh CLI
  if ! command -v gh &> /dev/null; then
    error "GitHub CLI (gh) not found. Install: brew install gh"
    exit 1
  fi
  
  # Check gh auth
  if ! gh auth status &> /dev/null; then
    error "GitHub CLI not authenticated. Run: gh auth login"
    exit 1
  fi
  success "GitHub CLI authenticated"
  
  # Check .env.secrets
  if [[ ! -f "$ENV_SECRETS" ]]; then
    error ".env.secrets not found at: $ENV_SECRETS"
    echo ""
    echo "Create it from template:"
    echo "  cp .env.secrets.example .env.secrets"
    echo "  # Edit .env.secrets with your actual secrets"
    exit 1
  fi
  success ".env.secrets found"
}

# Load secrets from .env.secrets
load_secrets() {
  info "Loading secrets from .env.secrets..."
  
  # Source the file in a subshell to avoid polluting environment
  set -a
  source "$ENV_SECRETS"
  set +a
  
  # Validate required secrets
  local missing=()
  [[ -z "${GITHUB_TOKEN:-}" ]] && missing+=("GITHUB_TOKEN")
  [[ -z "${NPM_TOKEN:-}" ]] && missing+=("NPM_TOKEN")
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing required secrets in .env.secrets:"
    for secret in "${missing[@]}"; do
      echo "  - $secret"
    done
    exit 1
  fi
  
  success "Secrets loaded"
}

# Set a secret for a repository
set_secret() {
  local repo=$1
  local secret_name=$2
  local secret_value=$3
  
  if [[ -z "$secret_value" ]]; then
    warning "$secret_name (skipped - empty)"
    return 1
  fi
  
  if echo "$secret_value" | gh secret set "$secret_name" --repo "$REPO_OWNER/$repo" 2>/dev/null; then
    success "$secret_name"
    return 0
  else
    error "$secret_name (failed)"
    return 1
  fi
}

# Set secrets for a library (lg-admin-ui, lg-menu-registry)
setup_library_secrets() {
  local repo=$1
  echo ""
  echo -e "${BLUE}$repo:${NC}"
  
  local count=0
  set_secret "$repo" "NPM_TOKEN" "$NPM_TOKEN" && ((count++)) || true
  
  return $count
}

# Set secrets for a service (lg-*-service)
setup_service_secrets() {
  local repo=$1
  echo ""
  echo -e "${BLUE}$repo:${NC}"
  
  local count=0
  set_secret "$repo" "NPM_TOKEN" "$NPM_TOKEN" && ((count++)) || true
  set_secret "$repo" "DOCKER_PASSWORD" "${DOCKER_PASSWORD:-}" && ((count++)) || true
  set_secret "$repo" "DATABASE_URL" "${DATABASE_URL:-}" && ((count++)) || true
  set_secret "$repo" "JWT_SECRET" "${JWT_SECRET:-}" && ((count++)) || true
  
  return $count
}

# Set secrets for a frontend (lg-management)
setup_frontend_secrets() {
  local repo=$1
  echo ""
  echo -e "${BLUE}$repo:${NC}"
  
  local count=0
  set_secret "$repo" "NPM_TOKEN" "$NPM_TOKEN" && ((count++)) || true
  set_secret "$repo" "DOCKER_PASSWORD" "${DOCKER_PASSWORD:-}" && ((count++)) || true
  set_secret "$repo" "NEXT_PUBLIC_API_URL" "${NEXT_PUBLIC_API_URL:-https://api.example.com}" && ((count++)) || true
  
  return $count
}

# Main setup
setup_secrets() {
  local total_secrets=0
  local total_repos=0
  
  # Define repositories by type
  local libraries=("lg-admin-ui" "lg-menu-registry")
  local services=("lg-user-service" "lg-permissions-service" "lg-license-service" "lg-tour-service" "lg-api-keys-service")
  local frontends=("lg-management" "lg-admin")
  
  # If single repo specified, only process that one
  if [[ -n "$SINGLE_REPO" ]]; then
    info "Setting up secrets for $SINGLE_REPO..."
    
    if [[ " ${libraries[@]} " =~ " ${SINGLE_REPO} " ]]; then
      setup_library_secrets "$SINGLE_REPO"
      total_secrets=$?
      total_repos=1
    elif [[ " ${services[@]} " =~ " ${SINGLE_REPO} " ]]; then
      setup_service_secrets "$SINGLE_REPO"
      total_secrets=$?
      total_repos=1
    elif [[ " ${frontends[@]} " =~ " ${SINGLE_REPO} " ]]; then
      setup_frontend_secrets "$SINGLE_REPO"
      total_secrets=$?
      total_repos=1
    else
      error "Unknown repository: $SINGLE_REPO"
      exit 1
    fi
  else
    info "Setting up secrets for all repositories..."
    
    # Process libraries
    for repo in "${libraries[@]}"; do
      setup_library_secrets "$repo"
      total_secrets=$((total_secrets + $?))
      ((total_repos++))
    done
    
    # Process services
    for repo in "${services[@]}"; do
      setup_service_secrets "$repo"
      total_secrets=$((total_secrets + $?))
      ((total_repos++))
    done
    
    # Process frontends
    for repo in "${frontends[@]}"; do
      setup_frontend_secrets "$repo"
      total_secrets=$((total_secrets + $?))
      ((total_repos++))
    done
  fi
  
  # Summary
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${GREEN}Summary:${NC} $total_secrets secrets set across $total_repos repos"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Main execution
main() {
  echo ""
  echo "🔐 Setting up GitHub Secrets..."
  echo ""
  
  check_prerequisites
  load_secrets
  setup_secrets
  
  echo ""
  success "Done!"
}

main "$@"
