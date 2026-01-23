#!/bin/bash
# scripts/lib/common.sh
#
# Common functions and utilities for orchestrator scripts

# Colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# Print functions
print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${CYAN}▶ $1${NC}"
}

print_substep() {
    echo -e "  ${MAGENTA}◆${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check and install command
check_command() {
    local cmd=$1
    local name=$2
    local install_url=$3

    if command_exists "$cmd"; then
        success "$name is installed"
        return 0
    else
        error "$name is not installed"
        if [ -n "$install_url" ]; then
            echo "  Install from: $install_url"
        fi
        return 1
    fi
}

# Clone repository
clone_repo() {
    local repo_name=$1
    local target_base=${2:-repos}
    local target_dir="${target_base}/${repo_name}"

    if [ -d "${target_dir}/.git" ]; then
        print_substep "${repo_name} (already exists, skipping)"
        return 1
    fi

    print_substep "Cloning ${repo_name}..."

    mkdir -p "${target_base}"

    if gh repo clone "${GITHUB_USER}/${repo_name}" "${target_dir}" 2>/dev/null; then
        success "${repo_name} cloned"
        return 0
    else
        error "Failed to clone ${repo_name}"
        echo "  Repository: ${GITHUB_USER}/${repo_name}"
        echo "  Check if repo exists on GitHub"
        return 2
    fi
}

# Wait for service health
wait_for_health() {
    local service=$1
    local max_wait=${2:-60}
    local waited=0

    print_substep "Waiting for ${service} to be healthy..."

    while [ $waited -lt $max_wait ]; do
        if docker ps --filter "name=${service}" --filter "health=healthy" | grep -q "${service}"; then
            success "${service} is healthy"
            return 0
        fi

        sleep 2
        waited=$((waited + 2))
        echo -n "."
    done

    echo ""
    warning "${service} did not become healthy in ${max_wait}s"
    return 1
}

# Generate random password
generate_password() {
    local length=${1:-16}
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

# Ask yes/no question
ask_yes_no() {
    local question=$1
    local default=${2:-y}

    if [ "$default" = "y" ]; then
        local prompt="[Y/n]"
    else
        local prompt="[y/N]"
    fi

    read -p "$question $prompt " -n 1 -r
    echo

    if [ -z "$REPLY" ]; then
        [ "$default" = "y" ]
    else
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

# Ask for input with default
ask_input() {
    local question=$1
    local default=$2
    local varname=$3

    if [ -n "$default" ]; then
        read -p "$question [$default]: " input
        eval "$varname=\"\${input:-$default}\""
    else
        read -p "$question: " input
        eval "$varname=\"\$input\""
    fi
}

# Ask for password (hidden input)
ask_password() {
    local question=$1
    local varname=$2
    local allow_empty=${3:-false}

    while true; do
        read -sp "$question: " password
        echo

        if [ -z "$password" ] && [ "$allow_empty" != "true" ]; then
            warning "Password cannot be empty"
            continue
        fi

        eval "$varname=\"\$password\""
        break
    done
}

# Check if running in CI
is_ci() {
    [ -n "$CI" ] || [ -n "$GITHUB_ACTIONS" ] || [ -n "$GITLAB_CI" ]
}

# Die with error message
die() {
    error "$1"
    exit 1
}
