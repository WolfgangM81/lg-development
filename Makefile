# Makefile - LG-Development Orchestrator
#
# Main orchestration for multi-repo Docker Compose setup

.PHONY: help setup prepare start stop restart logs status build config clean clean-repos

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
