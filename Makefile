# Sandbox Project Makefile (legacy flow removed)
# ------------------------------------------------
# Use the sandbox CLI directly. These targets are lightweight helpers.

SANDBOX_CMD ?= ./host/sandbox
GIT_ROOT := $(shell git rev-parse --show-toplevel 2>/dev/null || pwd)

# Get tmux session helper
TMUX_SESSION_SCRIPT := scripts/get-tmux-session.sh
GET_TMUX_SESSION = $(shell if [ -x $(TMUX_SESSION_SCRIPT) ]; then $(TMUX_SESSION_SCRIPT); else echo "non-tmux"; fi)

# Get session name from command line arguments
# - Filter out tmux wrapper targets and the internal base target
# - SESSION_NAME represents the base name (without agent suffix)
SESSION_NAME := $(filter-out tmux-% _tmux-agent-base,$(MAKECMDGOALS))

# Agent variant for tmux session naming (e.g., claude, gemini, codex)
# Session names will be: $(SESSION_NAME)-$(AGENT_NAME)
AGENT_NAME ?= claude
AGENT_SUFFIX := -$(AGENT_NAME)

# Install sandbox command symlink
.PHONY: install
install:
	@scripts/install-sandbox.sh

# Internal base target for tmux-claude commands (do not call directly)
.PHONY: _tmux-agent-base
_tmux-agent-base:
	@# Determine session name: use provided name or fallback to repo basename
	@if [ -z "$(SESSION_NAME)" ]; then \
		SESSION_BASE="$(notdir $(GIT_ROOT))"; \
		echo "📌 Using repo name for session: $$SESSION_BASE$(AGENT_SUFFIX)"; \
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
		tmux send-keys -t "=$$FULL_SESSION_NAME:" "cd $(GIT_ROOT) && $(SANDBOX_CMD) shell" Enter; \
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
		CLAUDE_CMD="echo '📂 Working in repo directory' && tmux-claude"

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
		CLAUDE_CMD="echo '📂 Working in repo directory' && tmux-codex"

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

# Tmux session with OpenCode (simple)
.PHONY: tmux-opencode
tmux-opencode:
	@$(MAKE) _tmux-agent-base \
		SESSION_NAME="$(SESSION_NAME)" \
		AGENT_NAME="opencode" \
		ERROR_MSG="Session name is optional" \
		USAGE_CMD="tmux-opencode [session-name]" \
		EXAMPLE_CMD="tmux-opencode or tmux-opencode my-project" \
		CLAUDE_CMD="echo '📂 Working in repo directory' && tmux-opencode"

# Tmux session with OpenCode for worktree
.PHONY: tmux-opencode-wt
tmux-opencode-wt:
	@$(MAKE) _tmux-agent-base \
		SESSION_NAME="$(SESSION_NAME)" \
		AGENT_NAME="opencode" \
		ERROR_MSG="Worktree name is required" \
		USAGE_CMD="tmux-opencode-wt <worktree-name>" \
		EXAMPLE_CMD="tmux-opencode-wt feature-auth" \
		CLAUDE_CMD="echo '📂 Entering worktree: $(SESSION_NAME)' && cd $(SESSION_NAME) && opencode"

# Help command
.PHONY: help
help:
	@echo "Sandbox Project - Available Commands:"
	@echo "────────────────────────────────────"
	@echo "Install:"
	@echo "  make install       - Install /usr/local/bin/sandbox symlink"
	@echo ""
	@echo "Tmux Sessions:"
	@echo "  make tmux-claude [name]     - Start tmux session with Claude (default: repo-name-claude)"
	@echo "  make tmux-claude-wt <name>  - Start tmux session with Claude in specific worktree"
	@echo "  make tmux-codex [name]      - Start tmux session with Codex (default: repo-name-codex)"
	@echo "  make tmux-codex-wt <name>   - Start tmux session with Codex in specific worktree"
	@echo "  make tmux-opencode [name]   - Start tmux session with OpenCode (default: repo-name-opencode)"
	@echo "  make tmux-opencode-wt <name> - Start tmux session with OpenCode in specific worktree"
	@echo ""
	@echo "Primary usage is the sandbox CLI:"
	@echo "  sandbox help"
	@echo "  sandbox shell|up|build|stop|down|status|name"
	@echo "────────────────────────────────────"

# Default target
.DEFAULT_GOAL := help

# Catch-all target to prevent "No rule to make target" errors when using positional arguments
%:
	@:
