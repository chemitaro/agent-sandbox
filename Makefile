# Sandbox Project Makefile
# -----------------------
# Keep only published helper commands.

# Install sandbox command symlink
.PHONY: install
install:
	@scripts/install-sandbox.sh

# Help command
.PHONY: help
help:
	@echo "Sandbox Project - Available Commands:"
	@echo "────────────────────────────────────"
	@echo "make install   - Install /usr/local/bin/sandbox symlink"
	@echo "make help      - Show this help"
	@echo ""
	@echo "Primary usage is the sandbox CLI:"
	@echo "  sandbox help"
	@echo "  sandbox shell|up|build|stop|down|status|name"
	@echo "────────────────────────────────────"

# Default target
.DEFAULT_GOAL := help

