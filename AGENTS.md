# Repository Guidelines

## Project Structure & Module Organization
- `host/` — host-side `sandbox` CLI entrypoint (`host/sandbox`).
- `docker-compose.yml` / `Dockerfile` — container definition, mounts, and installed tooling.
- `scripts/` — helper scripts (entrypoint, firewall init, installer, notifications).
- `tests/` — Bash test suite (`*.test.sh`) plus shared helpers (`tests/_helpers.sh`).
- `.spec-dock/` — planning/spec docs and templates; CI may auto-sync/commit changes.
- `tools/` — local-only cloned tools (git-ignored; see `tools/README.md`).
- `.agent-home/`, `.env` — local state/config (git-ignored). Use `.env.example` as a template.

## Build, Test, and Development Commands
- `make install` — symlink `host/sandbox` to `/usr/local/bin/sandbox` (may require `sudo`).
- `sandbox help` — show commands and options (`--mount-root`, `--workdir`).
- `sandbox up` — build and start the container via Docker Compose.
- `sandbox shell` — open `/bin/zsh` inside the container (starts it if needed).
- `sandbox status|stop|down` — inspect/stop/remove the container.
- (Inside container) `npm run verify` — sanity-check installed CLIs (codex/claude/gemini/opencode).

## Coding Style & Naming Conventions
- Bash-first repo: scripts use `#!/bin/bash` and `set -euo pipefail`; prefer explicit quoting and `local` variables.
- Keep changes small and testable; update `print_help*` in `host/sandbox` when adding CLI surface area.
- Tests: name as `tests/<area>.test.sh`; shared helpers live in `tests/_helpers.sh`.

## Testing Guidelines
- Run one suite: `bash tests/sandbox_cli.test.sh`
- Run all: `for f in tests/*.test.sh; do bash "$f"; done`
- Tests should avoid calling real Docker/Git; use the existing stubs/helpers to keep runs deterministic.

## Commit & Pull Request Guidelines
- Follow Conventional Commits (as in history): `feat(sandbox): ...`, `fix: ...`, `docs: ...`, `test(tests): ...`.
- Use `[skip spec-dock-close]` in the subject when you intentionally want to skip the spec-dock auto-close workflow.
- PRs: include a short description, linked issue (if any), and the exact test commands you ran; attach logs/screenshots for behavior changes.

## Security & Configuration Tips
- Never commit secrets to `.env`; only update `.env.example` with non-sensitive defaults.
