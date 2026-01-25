# Makefile - LG-Development Orchestrator
#
# Main orchestration for multi-repo Docker Compose setup

.PHONY: help setup prepare start stop restart logs status build config clean clean-repos test test-parallel test-coverage test-watch publish-packages publish-package cache-deps install-publish-workflows setup-github-registry setup-publish-config install-build-workflows dev-sync dev-normal dev-toggle dev-sync-status dev-sync-logs dev-sync-rebuild dev-sync-clean dev-sync-watch dev-sync-test dev-sync-check dev-sync-dashboard dev-sync-metrics dev-sync-metrics-watch dev-sync-metrics-reset

# Load environment variables
-include .env
export

# Generate compose file list dynamically
COMPOSE_FILES := $(shell ./scripts/lib/list-compose-files.sh 2>/dev/null || echo "")
COMPOSE := docker-compose $(COMPOSE_FILES)

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

# Default target
.DEFAULT_GOAL := help

help:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  $(BLUE)LG-Development Orchestrator$(NC)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "$(GREEN)Setup Commands:$(NC)"
	@echo "  make setup          - Interactive environment setup (.env)"
	@echo "  make prepare        - Clone all repos from GitHub"
	@echo ""
	@echo "$(GREEN)Development Commands:$(NC)"
	@echo "  make start          - Start all services (with dependencies)"
	@echo "  make stop           - Stop all services"
	@echo "  make restart        - Restart all services"
	@echo "  make logs [SERVICE] - View logs (all or specific)"
	@echo "  make status         - Show service status"
	@echo ""
	@echo "$(GREEN)Build Commands:$(NC)"
	@echo "  make build [SERVICE] - Build services"
	@echo "  make config          - Show final docker-compose config"
	@echo ""
	@echo "$(GREEN)Test Commands:$(NC)"
	@echo "  make test                    - Run all tests (sequential)"
	@echo "  make test-parallel           - Run all tests (parallel)"
	@echo "  make test-coverage           - Run tests with coverage"
	@echo "  make test-watch SERVICE=name - Run tests in watch mode"
	@echo ""
	@echo "$(GREEN)Package Commands:$(NC)"
	@echo "  make publish-packages           - Publish all packages to GitHub"
	@echo "  make publish-package PACKAGE=name - Publish specific package"
	@echo ""
	@echo "$(GREEN)Package Hot-Reload (⚡ Fast Development):$(NC)"
	@echo "  make dev-sync                      - Enable hot-reload (~2-3s updates)"
	@echo "  make dev-normal                    - Disable hot-reload (npm versions)"
	@echo "  make dev-toggle                    - Toggle hot-reload mode"
	@echo "  make dev-sync-status               - Check builder status"
	@echo "  make dev-sync-logs PACKAGE=name    - View compilation logs"
	@echo "  make dev-sync-rebuild              - Restart all builders"
	@echo "  make dev-sync-clean                - Clean build artifacts"
	@echo "  make dev-sync-watch                - Watch & auto-restart services (smart)"
	@echo "  make dev-sync-test                 - Test package loading (verify works)"
	@echo "  make dev-sync-check                - Verify build integrity & errors"
	@echo "  make dev-sync-dashboard            - Live dashboard (real-time status)"
	@echo "  make dev-sync-metrics              - Show build performance metrics"
	@echo "  make dev-sync-metrics-watch        - Watch & track build performance"
	@echo "  make dev-sync-metrics-reset        - Clear performance metrics"
	@echo ""
	@echo "$(GREEN)GitHub Registry Setup:$(NC)"
	@echo "  make setup-github-registry      - Configure .npmrc for all repos"
	@echo "  make setup-publish-config       - Add publishConfig to package.json"
	@echo "  make install-build-workflows    - Install build/publish workflows"
	@echo ""
	@echo "$(GREEN)Cache Commands:$(NC)"
	@echo "  make cache-deps              - Cache npm dependencies (faster tests)"
	@echo ""
	@echo "$(GREEN)Cleanup Commands:$(NC)"
	@echo "  make clean          - Stop services and remove containers"
	@echo "  make clean-repos    - Remove all cloned repos (⚠️  DANGER)"
	@echo ""

# Setup: Interactive .env generation
setup:
	@if [ ! -f scripts/setup.sh ]; then \
		echo "$(RED)❌ scripts/setup.sh not found!$(NC)"; \
		exit 1; \
	fi
	@./scripts/setup.sh

# Prepare: Clone all repos
prepare:
	@if [ ! -f .env ]; then \
		echo "$(RED)❌ .env not found! Run 'make setup' first$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f scripts/prepare.sh ]; then \
		echo "$(RED)❌ scripts/prepare.sh not found!$(NC)"; \
		exit 1; \
	fi
	@./scripts/prepare.sh

# Start with dependency resolution
start:
	@if [ -z "$(COMPOSE_FILES)" ]; then \
		echo "$(RED)❌ No repos found! Run 'make prepare' first$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f scripts/start.sh ]; then \
		echo "$(YELLOW)⚠️  scripts/start.sh not found, using direct start$(NC)"; \
		echo "$(YELLOW)🚀 Starting services...$(NC)"; \
		$(COMPOSE) up -d; \
	else \
		./scripts/start.sh; \
	fi

# Stop all services
stop:
	@if [ -n "$(COMPOSE_FILES)" ]; then \
		echo "$(YELLOW)🛑 Stopping services...$(NC)"; \
		$(COMPOSE) down; \
		echo "$(GREEN)✅ Services stopped$(NC)"; \
	else \
		echo "$(YELLOW)⊘ No services running$(NC)"; \
	fi

# Restart
restart: stop start

# Logs
logs:
ifdef SERVICE
	@$(COMPOSE) logs -f $(SERVICE)
else
	@$(COMPOSE) logs -f
endif

# Status
status:
	@if [ -f scripts/status.sh ]; then \
		./scripts/status.sh; \
	elif [ -n "$(COMPOSE_FILES)" ]; then \
		echo "$(BLUE)📊 Service Status:$(NC)"; \
		$(COMPOSE) ps; \
	else \
		echo "$(YELLOW)⊘ No services found$(NC)"; \
	fi

# Build
build:
ifdef SERVICE
	@$(COMPOSE) build $(SERVICE)
else
	@$(COMPOSE) build
endif

# Show final config (debugging)
config:
	@if [ -z "$(COMPOSE_FILES)" ]; then \
		echo "$(RED)❌ No compose files found$(NC)"; \
		exit 1; \
	fi
	@$(COMPOSE) config

# Clean
clean:
	@echo "$(YELLOW)🧹 Cleaning up...$(NC)"
	@if [ -n "$(COMPOSE_FILES)" ]; then \
		$(COMPOSE) down -v 2>/dev/null || true; \
	fi
	@echo "$(GREEN)✅ Cleanup complete$(NC)"

# Clean repos (DANGEROUS!)
clean-repos:
	@echo "$(RED)⚠️  This will DELETE all cloned repos in repos/$(NC)"
	@echo "$(RED)This cannot be undone!$(NC)"
	@read -p "Are you sure? Type 'yes' to confirm: " confirm && [ "$$confirm" = "yes" ] || (echo "Cancelled" && exit 1)
	@rm -rf repos/
	@echo "$(GREEN)✅ Repos removed$(NC)"

# Test all repositories (sequential)
test:
	@if [ ! -f scripts/test.sh ]; then \
		echo "$(RED)❌ scripts/test.sh not found!$(NC)"; \
		exit 1; \
	fi
	@./scripts/test.sh

# Test all repositories (parallel)
test-parallel:
	@if [ ! -f scripts/test-parallel.sh ]; then \
		echo "$(RED)❌ scripts/test-parallel.sh not found!$(NC)"; \
		exit 1; \
	fi
	@chmod +x scripts/test-parallel.sh
	@./scripts/test-parallel.sh

# Test with coverage
test-coverage:
	@if [ ! -f scripts/test-coverage.sh ]; then \
		echo "$(RED)❌ scripts/test-coverage.sh not found!$(NC)"; \
		exit 1; \
	fi
	@chmod +x scripts/test-coverage.sh
	@./scripts/test-coverage.sh
	@echo ""
	@echo "$(GREEN)Open coverage report:$(NC) open coverage/index.html"

# Test in watch mode (single service)
test-watch:
ifndef SERVICE
	@echo "$(RED)❌ SERVICE not specified!$(NC)"
	@echo "Usage: make test-watch SERVICE=lg-user-service"
	@exit 1
endif
	@if [ ! -d "repos/$(SERVICE)" ]; then \
		echo "$(RED)❌ repos/$(SERVICE) not found!$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)▶ Starting tests in watch mode for $(SERVICE)...$(NC)"
	@echo "$(YELLOW)Press Ctrl+C to stop$(NC)"
	@echo ""
	@cd repos/$(SERVICE) && docker run --rm -it \
		-v $$(pwd):/app \
		-w /app \
		node:20-alpine \
		sh -c "npm install && npm test -- --watch"

# Publish all packages to GitHub Packages
publish-packages:
	@if [ ! -f scripts/publish-packages.sh ]; then \
		echo "$(RED)❌ scripts/publish-packages.sh not found!$(NC)"; \
		exit 1; \
	fi
	@chmod +x scripts/publish-packages.sh
	@./scripts/publish-packages.sh

# Publish single package to GitHub Packages
publish-package:
ifndef PACKAGE
	@echo "$(RED)❌ PACKAGE not specified!$(NC)"
	@echo "Usage: make publish-package PACKAGE=lg-menu-registry"
	@exit 1
endif
	@if [ ! -d "repos/$(PACKAGE)" ]; then \
		echo "$(RED)❌ repos/$(PACKAGE) not found!$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)▶ Publishing $(PACKAGE)...$(NC)"
	@cd repos/$(PACKAGE) && \
		echo "@wolfgangm81:registry=https://npm.pkg.github.com" > .npmrc && \
		echo "//npm.pkg.github.com/:_authToken=$${GITHUB_TOKEN}" >> .npmrc && \
		npm publish
	@echo "$(GREEN)✅ $(PACKAGE) published!$(NC)"

# Cache npm dependencies in Docker volume (speeds up tests)
cache-deps:
	@if [ ! -f scripts/cache-docker-deps.sh ]; then \
		echo "$(RED)❌ scripts/cache-docker-deps.sh not found!$(NC)"; \
		exit 1; \
	fi
	@chmod +x scripts/cache-docker-deps.sh
	@./scripts/cache-docker-deps.sh

# Install auto-publish workflows in package repos
install-publish-workflows:
	@if [ ! -f scripts/install-publish-workflows.sh ]; then \
		echo "$(RED)❌ scripts/install-publish-workflows.sh not found!$(NC)"; \
		exit 1; \
	fi
	@chmod +x scripts/install-publish-workflows.sh
	@./scripts/install-publish-workflows.sh

# Setup GitHub Packages Registry for all repos
setup-github-registry:
	@if [ ! -f scripts/setup-github-registry.sh ]; then \
		echo "$(RED)❌ scripts/setup-github-registry.sh not found!$(NC)"; \
		exit 1; \
	fi
	@chmod +x scripts/setup-github-registry.sh
	@./scripts/setup-github-registry.sh

# Add publishConfig to package.json
setup-publish-config:
	@if [ ! -f scripts/setup-publish-config.sh ]; then \
		echo "$(RED)❌ scripts/setup-publish-config.sh not found!$(NC)"; \
		exit 1; \
	fi
	@chmod +x scripts/setup-publish-config.sh
	@./scripts/setup-publish-config.sh

# Install build workflows for packages and services
install-build-workflows:
	@if [ ! -f scripts/install-build-workflows.sh ]; then \
		echo "$(RED)❌ scripts/install-build-workflows.sh not found!$(NC)"; \
		exit 1; \
	fi
	@chmod +x scripts/install-build-workflows.sh
	@./scripts/install-build-workflows.sh

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Package Hot-Reload Commands
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Start with package hot-reload (recommended for package development)
dev-sync:
	@if [ ! -f scripts/dev/sync-packages.sh ]; then \
		echo "$(RED)❌ scripts/dev/sync-packages.sh not found!$(NC)"; \
		exit 1; \
	fi
	@./scripts/dev/sync-packages.sh enable
	@echo ""
	@echo "$(GREEN)💡 Tip: Edit packages and see changes in ~2-3s!$(NC)"

# Start without package hot-reload (uses npm-installed versions)
dev-normal:
	@if [ ! -f scripts/dev/sync-packages.sh ]; then \
		echo "$(RED)❌ scripts/dev/sync-packages.sh not found!$(NC)"; \
		exit 1; \
	fi
	@./scripts/dev/sync-packages.sh disable
	@echo "$(YELLOW)📦 Using npm-installed package versions$(NC)"

# Toggle current mode (enable ↔ disable)
dev-toggle:
	@if docker-compose -f docker-compose.dev-sync.yml ps | grep -q Up; then \
		./scripts/dev/sync-packages.sh disable; \
	else \
		./scripts/dev/sync-packages.sh enable; \
	fi

# Check sync status
dev-sync-status:
	@./scripts/dev/sync-packages.sh status

# View compilation logs
dev-sync-logs:
	@./scripts/dev/sync-packages.sh logs $(PACKAGE)

# Rebuild all package builders
dev-sync-rebuild:
	@./scripts/dev/sync-packages.sh rebuild

# Clean package build artifacts
dev-sync-clean:
	@./scripts/dev/sync-packages.sh clean

# Watch packages and auto-restart services
dev-sync-watch:
	@if [ ! -f scripts/dev/watch-packages.sh ]; then \
		echo "$(RED)❌ scripts/dev/watch-packages.sh not found!$(NC)"; \
		exit 1; \
	fi
	@./scripts/dev/watch-packages.sh

# Test package loading
dev-sync-test:
	@if [ ! -f scripts/dev/test-package-loading.sh ]; then \
		echo "$(RED)❌ scripts/dev/test-package-loading.sh not found!$(NC)"; \
		exit 1; \
	fi
	@./scripts/dev/test-package-loading.sh

# Check build integrity
dev-sync-check:
	@./scripts/dev/sync-packages.sh check

# Live dashboard
dev-sync-dashboard:
	@if [ ! -f scripts/dev/dev-sync-dashboard.sh ]; then \
		echo "$(RED)❌ scripts/dev/dev-sync-dashboard.sh not found!$(NC)"; \
		exit 1; \
	fi
	@./scripts/dev/dev-sync-dashboard.sh

# Build performance metrics
dev-sync-metrics:
	@if [ ! -f scripts/dev/build-metrics.sh ]; then \
		echo "$(RED)❌ scripts/dev/build-metrics.sh not found!$(NC)"; \
		exit 1; \
	fi
	@./scripts/dev/build-metrics.sh show

# Watch build performance
dev-sync-metrics-watch:
	@if [ ! -f scripts/dev/build-metrics.sh ]; then \
		echo "$(RED)❌ scripts/dev/build-metrics.sh not found!$(NC)"; \
		exit 1; \
	fi
	@./scripts/dev/build-metrics.sh watch

# Reset build metrics
dev-sync-metrics-reset:
	@if [ ! -f scripts/dev/build-metrics.sh ]; then \
		echo "$(RED)❌ scripts/dev/build-metrics.sh not found!$(NC)"; \
		exit 1; \
	fi
	@./scripts/dev/build-metrics.sh reset
