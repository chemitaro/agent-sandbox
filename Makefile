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


# Docker Compose command (Git metadata is writable by default)
DOCKER_COMPOSE := docker-compose -f docker-compose.yml

# Export environment variables for Docker Compose
export HOST_SANDBOX_PATH := $(GIT_ROOT)
export HOST_USERNAME := $(CURRENT_USER)
export SOURCE_PATH
# TZ and PRODUCT_NAME are now handled by generate-env.sh script

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
validate-config: generate-env
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
	@echo "🧹 Removing generated files..."
	@rm -f $(ENV_FILE)
	@rm -f .devcontainer/devcontainer.json
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
			$(DOCKER_COMPOSE) start; \
			sleep 2; \
		fi \
	else \
		echo "🚀 Starting Claude Code Sandbox..."; \
		$(DOCKER_COMPOSE) up -d --build; \
		echo "⏳ Waiting for container to be ready..."; \
		sleep 2; \
	fi
	@echo "🔗 Connecting to product directory..."
	@TMUX_SESSION=$$($(TMUX_SESSION_SCRIPT) 2>/dev/null || echo "non-tmux"); \
	echo "📍 Host tmux session: $$TMUX_SESSION"; \
	PRODUCT_WORK_DIR=$$(grep "^PRODUCT_WORK_DIR=" $(ENV_FILE) | cut -d'=' -f2); \
	$(DOCKER_COMPOSE) exec \
		-e TMUX_SESSION_NAME="$$TMUX_SESSION" \
		-w $$PRODUCT_WORK_DIR \
		agent-sandbox /bin/zsh

# Docker Compose Commands (updated)
.PHONY: up
up: validate-config
	@echo "🚀 Starting Claude Code Sandbox..."
	@$(DOCKER_COMPOSE) down 2>/dev/null || true
	@$(DOCKER_COMPOSE) up -d
	@echo "✅ Container started. Run 'make shell' to connect."

.PHONY: down
down:
	@echo "🛑 Stopping Claude Code Sandbox..."
	@$(DOCKER_COMPOSE) down

.PHONY: shell
shell:
	@echo "🔗 Connecting to product directory..."
	@TMUX_SESSION=$$($(TMUX_SESSION_SCRIPT) 2>/dev/null || echo "non-tmux"); \
	echo "📍 Host tmux session: $$TMUX_SESSION"; \
	PRODUCT_WORK_DIR=$$(grep "^PRODUCT_WORK_DIR=" $(ENV_FILE) | cut -d'=' -f2); \
	$(DOCKER_COMPOSE) exec \
		-e TMUX_SESSION_NAME="$$TMUX_SESSION" \
		-w $$PRODUCT_WORK_DIR \
		agent-sandbox /bin/zsh

.PHONY: shell-sandbox
shell-sandbox:
	@echo "🔗 Connecting to sandbox directory..."
	@TMUX_SESSION=$$($(TMUX_SESSION_SCRIPT) 2>/dev/null || echo "non-tmux"); \
	echo "📍 Host tmux session: $$TMUX_SESSION"; \
	$(DOCKER_COMPOSE) exec \
		-e TMUX_SESSION_NAME="$$TMUX_SESSION" \
		agent-sandbox /bin/zsh

.PHONY: shell-product
shell-product:
	@echo "⚠️  Note: 'shell-product' is deprecated. Use 'shell' instead."
	@echo "🔗 Connecting to product directory..."
	@PRODUCT_WORK_DIR=$$(grep "^PRODUCT_WORK_DIR=" $(ENV_FILE) 2>/dev/null | cut -d'=' -f2 || echo "/srv/product"); \
	$(DOCKER_COMPOSE) exec -w $$PRODUCT_WORK_DIR agent-sandbox /bin/zsh

.PHONY: logs
logs:
	@$(DOCKER_COMPOSE) logs -f agent-sandbox

.PHONY: restart
restart: validate-config
	@echo "🔄 Restarting Claude Code Sandbox..."
	@$(DOCKER_COMPOSE) restart

.PHONY: status
status:
	@echo "📊 Container Status:"
	@$(DOCKER_COMPOSE) ps

.PHONY: build
build: validate-config
	@echo "🔨 Building Claude Code Sandbox image..."
	@$(DOCKER_COMPOSE) build --no-cache
	@echo "✅ Build completed."

.PHONY: rebuild
rebuild: validate-config
	@echo "🔄 Rebuilding and restarting Claude Code Sandbox..."
	@$(DOCKER_COMPOSE) down
	@$(DOCKER_COMPOSE) build --no-cache
	@$(DOCKER_COMPOSE) up -d
	@echo "✅ Container rebuilt and started. Run 'make shell' to connect."

# Claude Assistant (kept from original)
.PHONY: claude
claude:
	@echo "🤖 Starting Claude session..."
	@claude --dangerously-skip-permissions

# pre-commit (via uvx in the container)
.PHONY: pre-commit-install
pre-commit-install: validate-config
	@echo "🪝 Installing pre-commit hook in the product repo..."
	@PRODUCT_WORK_DIR=$$(grep "^PRODUCT_WORK_DIR=" $(ENV_FILE) | cut -d'=' -f2); \
	$(DOCKER_COMPOSE) exec -w $$PRODUCT_WORK_DIR agent-sandbox bash -lc "set -euo pipefail; pre-commit install; hook_path=\"$$(git rev-parse --git-path hooks/pre-commit)\"; if [ -f \"$$hook_path\" ]; then sed -i 's|^[[:space:]]*exec pre-commit |exec uvx --managed-python --python 3.12 --from pre-commit pre-commit |' \"$$hook_path\"; fi"

# Get session name from command line arguments
# - Filter out tmux wrapper targets and the internal base target
# - SESSION_NAME represents the base name (without agent suffix)
SESSION_NAME := $(filter-out tmux-% _tmux-agent-base,$(MAKECMDGOALS))

# Agent variant for tmux session naming (e.g., claude, gemini, codex)
# Session names will be: $(SESSION_NAME)-$(AGENT_NAME)
AGENT_NAME ?= claude
AGENT_SUFFIX := -$(AGENT_NAME)

# Internal base target for tmux-claude commands (do not call directly)
.PHONY: _tmux-agent-base
_tmux-agent-base:
	@# Determine session name: use provided name or fallback to PRODUCT_NAME
	@if [ -z "$(SESSION_NAME)" ]; then \
		PRODUCT_NAME=$$(grep "^PRODUCT_NAME=" $(ENV_FILE) 2>/dev/null | cut -d'=' -f2); \
		if [ -z "$$PRODUCT_NAME" ]; then \
			echo "❌ Error: No session name provided and PRODUCT_NAME not found in .env"; \
			echo "Usage: make $(USAGE_CMD) [session-name]"; \
			echo "   Without session-name: uses PRODUCT_NAME from .env"; \
			echo "   With session-name: uses provided name"; \
			echo "Example: make $(EXAMPLE_CMD)"; \
			exit 1; \
		fi; \
		SESSION_BASE="$$PRODUCT_NAME"; \
		echo "📌 Using project name for session: $$PRODUCT_NAME$(AGENT_SUFFIX)"; \
	else \
		SESSION_BASE="$(SESSION_NAME)"; \
	fi; \
	FULL_SESSION_NAME="$$SESSION_BASE$(AGENT_SUFFIX)"; \
	\
	if tmux has-session -t "=$$FULL_SESSION_NAME" 2>/dev/null; then \
		echo "⚠️  Tmux session '$$FULL_SESSION_NAME' already exists"; \
		echo "📎 Attaching to existing session..."; \
		tmux attach-session -t "=$$FULL_SESSION_NAME"; \
	else \
		echo "🌳 Creating new tmux session '$$FULL_SESSION_NAME'..."; \
		tmux new-session -d -s "$$FULL_SESSION_NAME"; \
		tmux send-keys -t "=$$FULL_SESSION_NAME:" "cd $(GIT_ROOT) && make start" Enter; \
		sleep 3; \
		tmux send-keys -t "=$$FULL_SESSION_NAME:" "$(CLAUDE_CMD)" Enter; \
		echo "📎 Attaching to new session..."; \
		tmux attach-session -t "=$$FULL_SESSION_NAME"; \
	fi

# Tmux session with Claude (simple)
.PHONY: tmux-claude
tmux-claude:
	@$(MAKE) _tmux-agent-base \
		SESSION_NAME="$(SESSION_NAME)" \
		AGENT_NAME="claude" \
		ERROR_MSG="Session name is optional" \
		USAGE_CMD="tmux-claude [session-name]" \
		EXAMPLE_CMD="tmux-claude or tmux-claude my-project" \
		CLAUDE_CMD="echo '📂 Working in product directory' && tmux-claude"

# Tmux session with Claude for worktree
.PHONY: tmux-claude-wt
tmux-claude-wt:
	@$(MAKE) _tmux-agent-base \
		SESSION_NAME="$(SESSION_NAME)" \
		AGENT_NAME="claude" \
		ERROR_MSG="Worktree name is required" \
		USAGE_CMD="tmux-claude-wt <worktree-name>" \
		EXAMPLE_CMD="tmux-claude-wt feature-auth" \
		CLAUDE_CMD="echo '📂 Entering worktree: $(SESSION_NAME)' && cd $(SESSION_NAME) && (claude --continue --dangerously-skip-permissions 2>/dev/null || claude --dangerously-skip-permissions)"

# Tmux session with Codex (simple)
.PHONY: tmux-codex
tmux-codex:
	@$(MAKE) _tmux-agent-base \
		SESSION_NAME="$(SESSION_NAME)" \
		AGENT_NAME="codex" \
		ERROR_MSG="Session name is optional" \
		USAGE_CMD="tmux-codex [session-name]" \
		EXAMPLE_CMD="tmux-codex or tmux-codex my-project" \
		CLAUDE_CMD="echo '📂 Working in product directory' && tmux-codex"

# Tmux session with Codex for worktree
.PHONY: tmux-codex-wt
tmux-codex-wt:
	@$(MAKE) _tmux-agent-base \
		SESSION_NAME="$(SESSION_NAME)" \
		AGENT_NAME="codex" \
		ERROR_MSG="Worktree name is required" \
		USAGE_CMD="tmux-codex-wt <worktree-name>" \
		EXAMPLE_CMD="tmux-codex-wt feature-auth" \
		CLAUDE_CMD="echo '📂 Entering worktree: $(SESSION_NAME)' && cd $(SESSION_NAME) && codex resume"

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
	@echo "  make tmux-claude [name]     - Start tmux session with Claude (default: PRODUCT_NAME-claude)"
	@echo "  make tmux-claude-wt <name>  - Start tmux session with Claude in specific worktree"
	@echo "  make tmux-codex [name]      - Start tmux session with Codex (default: PRODUCT_NAME-codex)"
	@echo "  make tmux-codex-wt <name>   - Start tmux session with Codex in specific worktree"
	@echo "      Note: tmux session names end with '-<agent>' (e.g., <name>-claude, <name>-codex)"
	@echo "  Git metadata is read-only inside the container; commits must be run on the host"
	@echo "────────────────────────────────────"

# Default target
.DEFAULT_GOAL := help

# Catch-all target to prevent "No rule to make target" errors when using positional arguments
%:
	@:
