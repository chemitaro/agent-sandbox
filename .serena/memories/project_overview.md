# Project overview

- Purpose: Docker Compose-based sandbox environment for running agentic coding tools (Claude Code, Codex, Gemini, OpenCode) with host-mounted workspaces and local agent config persistence.
- Core tech: Docker/Docker Compose, Bash scripts, Makefile, Node packages for CLI tools.
- Key structure:
  - `docker-compose.yml`, `Dockerfile`: container definition
  - `scripts/`: host-side helper scripts (bash/js)
  - `.agent-home/`: host-persisted agent configs (bind-mounted)
  - `.spec-dock/`: requirements/design/plan/report docs for spec-driven workflow
  - `host/`: host-side CLI entrypoints (e.g., `host/sandbox` to be added)
