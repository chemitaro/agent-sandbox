# Sandbox Project Makefile
# ========================

# Configuration
CONFIG_FILE := sandbox.config
ENV_FILE := .env

# Dynamic values
CURRENT_DIR := $(shell pwd)
CURRENT_USER := $(shell whoami)
GIT_ROOT := $(shell git rev-parse --show-toplevel 2>/dev/null || echo $(CURRENT_DIR))

# Include .env if it exists
-include $(ENV_FILE)

# Default values
SOURCE_PATH ?= $(HOME)/workspace/product

# Export environment variables for Docker Compose
export HOST_SANDBOX_PATH := $(GIT_ROOT)
export HOST_USERNAME := $(CURRENT_USER)
export SOURCE_PATH
# TZ is now handled by generate-env.sh script

# Timezone is now handled by generate-env.sh script

# Get tmux session helper
TMUX_SESSION_SCRIPT := scripts/get-tmux-session.sh
GET_TMUX_SESSION = $(shell if [ -x $(TMUX_SESSION_SCRIPT) ]; then $(TMUX_SESSION_SCRIPT); else echo "non-tmux"; fi)

# Generate .env file
.PHONY: generate-env
generate-env:
	@scripts/generate-env.sh

# Validate configuration
.PHONY: validate-config
validate-config:
	@scripts/generate-env.sh --validate

# Initialize configuration
.PHONY: init
init:
	@if [ -f $(CONFIG_FILE) ]; then \
		echo "⚠️  $(CONFIG_FILE) already exists"; \
	else \
		cp sandbox.config.example $(CONFIG_FILE); \
		echo "✅ Created $(CONFIG_FILE) from example"; \
		echo "📝 Please edit $(CONFIG_FILE) with your settings"; \
	fi

# Show current configuration
.PHONY: show-config
show-config: generate-env
	@echo "📊 Current Configuration:"
	@echo "─────────────────────────"
	@echo "User Settings (from $(CONFIG_FILE)):"
	@if [ -f $(CONFIG_FILE) ]; then \
		grep -E '^[[:space:]]*[A-Z_][A-Z0-9_]*[[:space:]]*=' $(CONFIG_FILE) | sed 's/=/ = /' || true; \
	else \
		echo "  No configuration file found"; \
	fi
	@echo ""
	@echo "Auto-detected Values:"
	@echo "  Sandbox Path = $(GIT_ROOT)"
	@echo "  Username = $(CURRENT_USER)"
	@# Extract timezone from generated .env file
	@echo "  Timezone = $$(grep '^TZ=' $(ENV_FILE) | cut -d'=' -f2)"
	@echo "─────────────────────────"

# Clean generated files
.PHONY: clean-env
clean-env:
	@echo "🧹 Removing generated .env file..."
	@rm -f $(ENV_FILE)
	@echo "✅ Cleaned up"

# Quick start command - one command to rule them all
.PHONY: start
start: validate-config
	@# Get dynamic container name from .env file
	@DYNAMIC_CONTAINER_NAME=$$(grep "^CONTAINER_NAME=" $(ENV_FILE) | cut -d'=' -f2); \
	if [ -z "$$DYNAMIC_CONTAINER_NAME" ]; then \
		DYNAMIC_CONTAINER_NAME="agent-sandbox"; \
	fi; \
	echo "🔍 Checking container: $$DYNAMIC_CONTAINER_NAME"; \
	if docker ps -a --format "table {{.Names}}" | grep -q "^$$DYNAMIC_CONTAINER_NAME$$"; then \
		if docker ps --format "table {{.Names}}" | grep -q "^$$DYNAMIC_CONTAINER_NAME$$"; then \
			echo "✅ Container is already running"; \
		else \
			echo "🔄 Container exists but stopped. Starting it..."; \
			docker-compose start; \
			sleep 2; \
		fi \
	else \
		echo "🚀 Starting Claude Code Sandbox..."; \
		docker-compose up -d; \
		echo "⏳ Waiting for container to be ready..."; \
		sleep 2; \
	fi
	@echo "🔗 Connecting to product directory..."
	@TMUX_SESSION=$$($(TMUX_SESSION_SCRIPT) 2>/dev/null || echo "non-tmux"); \
	echo "📍 Host tmux session: $$TMUX_SESSION"; \
	docker-compose exec \
		-e TMUX_SESSION_NAME="$$TMUX_SESSION" \
		-w /srv/product \
		agent-sandbox /bin/zsh

# Docker Compose Commands (updated)
.PHONY: up
up: validate-config
	@echo "🚀 Starting Claude Code Sandbox..."
	@docker-compose down 2>/dev/null || true
	@docker-compose up -d
	@echo "✅ Container started. Run 'make shell' to connect."

.PHONY: down
down:
	@echo "🛑 Stopping Claude Code Sandbox..."
	@docker-compose down

.PHONY: shell
shell:
	@echo "🔗 Connecting to product directory..."
	@TMUX_SESSION=$$($(TMUX_SESSION_SCRIPT) 2>/dev/null || echo "non-tmux"); \
	echo "📍 Host tmux session: $$TMUX_SESSION"; \
	docker-compose exec \
		-e TMUX_SESSION_NAME="$$TMUX_SESSION" \
		-w /srv/product \
		agent-sandbox /bin/zsh

.PHONY: shell-sandbox
shell-sandbox:
	@echo "🔗 Connecting to sandbox directory..."
	@TMUX_SESSION=$$($(TMUX_SESSION_SCRIPT) 2>/dev/null || echo "non-tmux"); \
	echo "📍 Host tmux session: $$TMUX_SESSION"; \
	docker-compose exec \
		-e TMUX_SESSION_NAME="$$TMUX_SESSION" \
		agent-sandbox /bin/zsh

.PHONY: shell-product
shell-product:
	@echo "⚠️  Note: 'shell-product' is deprecated. Use 'shell' instead."
	@echo "🔗 Connecting to product directory..."
	@docker-compose exec -w /srv/product agent-sandbox /bin/zsh

.PHONY: logs
logs:
	@docker-compose logs -f agent-sandbox

.PHONY: restart
restart:
	@echo "🔄 Restarting Claude Code Sandbox..."
	@docker-compose restart

.PHONY: status
status:
	@echo "📊 Container Status:"
	@docker-compose ps

.PHONY: build
build:
	@echo "🔨 Building Claude Code Sandbox image..."
	@docker-compose build --no-cache
	@echo "✅ Build completed."

.PHONY: rebuild
rebuild:
	@echo "🔄 Rebuilding and restarting Claude Code Sandbox..."
	@docker-compose down
	@docker-compose build --no-cache
	@docker-compose up -d
	@echo "✅ Container rebuilt and started. Run 'make shell' to connect."

# Claude Assistant (kept from original)
.PHONY: claude
claude:
	@echo "🤖 Starting Claude session..."
	@claude --dangerously-skip-permissions

# Get session name from command line arguments
SESSION_NAME := $(filter-out tmux-claude tmux-claude-wt _tmux-claude-base,$(MAKECMDGOALS))

# Internal base target for tmux-claude commands (do not call directly)
.PHONY: _tmux-claude-base
_tmux-claude-base:
	@if [ -z "$(SESSION_NAME)" ]; then \
		echo "❌ Error: $(ERROR_MSG)"; \
		echo "Usage: make $(USAGE_CMD)"; \
		echo "Example: make $(EXAMPLE_CMD)"; \
		exit 1; \
	fi
	@# Check if tmux session already exists first
	@if tmux has-session -t "$(SESSION_NAME)" 2>/dev/null; then \
		echo "⚠️  Tmux session '$(SESSION_NAME)' already exists"; \
		echo "📎 Attaching to existing session..."; \
		tmux attach-session -t "$(SESSION_NAME)"; \
	else \
		echo "🌳 Creating new tmux session '$(SESSION_NAME)'..."; \
		tmux new-session -d -s "$(SESSION_NAME)"; \
		tmux send-keys -t "$(SESSION_NAME)" "cd $(GIT_ROOT) && make start" Enter; \
		sleep 3; \
		tmux send-keys -t "$(SESSION_NAME)" "$(CLAUDE_CMD)" Enter; \
		echo "📎 Attaching to new session..."; \
		tmux attach-session -t "$(SESSION_NAME)"; \
	fi

# Tmux session with Claude (simple)
.PHONY: tmux-claude
tmux-claude:
	@$(MAKE) _tmux-claude-base \
		SESSION_NAME="$(SESSION_NAME)" \
		ERROR_MSG="Session name is required" \
		USAGE_CMD="tmux-claude <session-name>" \
		EXAMPLE_CMD="tmux-claude my-project" \
		CLAUDE_CMD="echo '📂 Working in product directory' && ccresume --add-dir /srv --dangerously-skip-permissions"

# Tmux session with Claude for worktree
.PHONY: tmux-claude-wt
tmux-claude-wt:
	@$(MAKE) _tmux-claude-base \
		SESSION_NAME="$(SESSION_NAME)" \
		ERROR_MSG="Worktree name is required" \
		USAGE_CMD="tmux-claude-wt <worktree-name>" \
		EXAMPLE_CMD="tmux-claude-wt feature-auth" \
		CLAUDE_CMD="echo '📂 Entering worktree: $(SESSION_NAME)' && cd $(SESSION_NAME) && ccresume --add-dir /srv --dangerously-skip-permissions"

# Help command
.PHONY: help
help:
	@echo "Sandbox Project - Available Commands:"
	@echo "────────────────────────────────────"
	@echo "Quick Start:"
	@echo "  make init          - Initialize sandbox.config from example"
	@echo "  make start         - Start container and connect to product directory"
	@echo ""
	@echo "Configuration:"
	@echo "  make show-config   - Display current configuration"
	@echo "  make validate-config - Validate configuration"
	@echo "  make clean-env     - Remove generated .env file"
	@echo ""
	@echo "Container Management:"
	@echo "  make up            - Start the container (auto-generates .env)"
	@echo "  make down          - Stop the container"
	@echo "  make restart       - Restart the container"
	@echo "  make rebuild       - Rebuild and restart the container"
	@echo "  make status        - Show container status"
	@echo ""
	@echo "Shell Access:"
	@echo "  make shell         - Connect to product directory (default)"
	@echo "  make shell-sandbox - Connect to sandbox directory"
	@echo "  make logs          - View container logs"
	@echo ""
	@echo "Development:"
	@echo "  make claude        - Start Claude Code session"
	@echo "  make tmux-claude <name>     - Start tmux session with Claude in product directory"
	@echo "  make tmux-claude-wt <name>  - Start tmux session with Claude in specific worktree"
	@echo "────────────────────────────────────"

# Default target
.DEFAULT_GOAL := help

# Catch-all target to prevent "No rule to make target" errors when using positional arguments
%:
	@: