#!/bin/bash
# scripts/setup.sh
#
# Interactive setup wizard - generates .env file

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "LG-Development Setup Wizard"

# Step 1: Check prerequisites
print_step "1/6: Checking prerequisites..."

MISSING=0

if ! check_command "docker" "Docker" "https://docs.docker.com/get-docker/"; then
    MISSING=1
fi

if ! check_command "docker-compose" "Docker Compose" "https://docs.docker.com/compose/install/"; then
    MISSING=1
fi

if ! check_command "gh" "GitHub CLI" "https://cli.github.com/"; then
    MISSING=1
fi

if [ $MISSING -eq 1 ]; then
    die "Missing required tools. Please install them and try again."
fi

echo ""

# Step 2: Check GitHub authentication
print_step "2/6: Checking GitHub authentication..."

if ! gh auth status >/dev/null 2>&1; then
    warning "Not authenticated with GitHub"
    echo ""
    info "Authenticating via SSH..."
    echo ""

    if ! gh auth login -p ssh -h github.com; then
        die "GitHub authentication failed"
    fi
else
    success "GitHub authentication OK"
fi

echo ""

# Step 3: Environment configuration
print_step "3/6: Environment Configuration"
echo ""

if [ -f .env ]; then
    warning ".env already exists"
    echo ""

    if ask_yes_no "Overwrite existing .env?" "n"; then
        info "Generating new .env..."
    else
        info "Using existing .env"
        success "Setup complete (using existing .env)"
        echo ""
        echo "Next steps:"
        echo "  make prepare    # Clone repositories"
        echo "  make start      # Start services"
        exit 0
    fi
fi

echo ""

# GitHub User
GITHUB_USER_DEFAULT=$(gh api user --jq '.login' 2>/dev/null || echo "${USER}")
ask_input "GitHub Username" "$GITHUB_USER_DEFAULT" GITHUB_USER

# Database
echo ""
echo "━━━ Database Configuration ━━━"
ask_input "Postgres Database Name" "licenseguard" POSTGRES_DB
ask_input "Postgres User" "licenseguard" POSTGRES_USER

echo ""
info "Postgres Password (leave empty to auto-generate)"
ask_password "Postgres Password" POSTGRES_PASSWORD true

if [ -z "$POSTGRES_PASSWORD" ]; then
    POSTGRES_PASSWORD=$(generate_password 16)
    success "Generated password: ${POSTGRES_PASSWORD}"
fi

# Redis
echo ""
echo "━━━ Redis Configuration ━━━"
info "Redis Password (leave empty to auto-generate)"
ask_password "Redis Password" REDIS_PASSWORD true

if [ -z "$REDIS_PASSWORD" ]; then
    REDIS_PASSWORD=$(generate_password 16)
    success "Generated password: ${REDIS_PASSWORD}"
fi

# Security
echo ""
echo "━━━ Security Configuration ━━━"
info "Generating secrets..."

JWT_SECRET=$(openssl rand -base64 32)
INTERNAL_API_KEY=$(openssl rand -hex 16)
MASTER_ENCRYPTION_KEY=$(openssl rand -base64 32)

success "Secrets generated"

# Proxy domains
echo ""
print_step "4/6: Proxy Domain Configuration"
echo ""
info "Proxy domains allow accessing services without ports:"
echo "  - http://admin.lg.local"
echo "  - http://api.lg.local/user"
echo "  - http://traefik.lg.local"
echo ""

if ask_yes_no "Setup proxy domains?" "y"; then
    USE_PROXY_DOMAINS=true
    echo ""
    info "Add these entries to /etc/hosts:"
    echo ""
    echo -e "${YELLOW}127.0.0.1 admin.lg.local api.lg.local traefik.lg.local${NC}"
    echo ""
    info "Run this command:"
    echo ""
    echo -e "${CYAN}sudo sh -c 'echo \"127.0.0.1 admin.lg.local api.lg.local traefik.lg.local\" >> /etc/hosts'${NC}"
    echo ""
    read -p "Press Enter when done (or Ctrl+C to skip)..."
else
    USE_PROXY_DOMAINS=false
    info "Skipping proxy domains (services available on localhost)"
fi

echo ""

# Write .env
print_step "5/6: Writing .env file..."

cat > .env << EOF
# ╔══════════════════════════════════════════════════════════════╗
# ║     LG-DEVELOPMENT - ENVIRONMENT CONFIGURATION                ║
# ║     Generated: $(date)                                        ║
# ╚══════════════════════════════════════════════════════════════╝

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GITHUB
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GITHUB_USER=${GITHUB_USER}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DATABASE (PostgreSQL)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}
DATABASE_URL=postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# REDIS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECURITY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
JWT_SECRET=${JWT_SECRET}
INTERNAL_API_KEY=${INTERNAL_API_KEY}
MASTER_ENCRYPTION_KEY=${MASTER_ENCRYPTION_KEY}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ENVIRONMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
NODE_ENV=development
LOG_LEVEL=debug

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PROXY DOMAINS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
USE_PROXY_DOMAINS=${USE_PROXY_DOMAINS}
EOF

success ".env file created"

echo ""

# Verify
print_step "6/6: Verifying setup..."

if [ -f .env ]; then
    success "Setup complete!"
    echo ""
    info "Environment file created at: .env"
    echo ""
    echo "Next steps:"
    echo "  ${CYAN}make prepare${NC}    # Clone repositories from GitHub"
    echo "  ${CYAN}make start${NC}      # Start all services"
    echo ""
else
    die "Setup failed! .env file was not created"
fi
