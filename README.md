# Claude Code

![](https://img.shields.io/badge/Node.js-18%2B-brightgreen?style=flat-square) [![npm]](https://www.npmjs.com/package/@anthropic-ai/claude-code)

[npm]: https://img.shields.io/npm/v/@anthropic-ai/claude-code.svg?style=flat-square

Claude Code is an agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster by executing routine tasks, explaining complex code, and handling git workflows -- all through natural language commands. Use it in your terminal, IDE, or tag @claude on Github.

**Learn more in the [official documentation](https://docs.anthropic.com/en/docs/claude-code/overview)**.

<img src="./demo.gif" />

## Get started

### Option 1: Sandbox CLI (Recommended for this repository)

This repository includes a secure containerized environment for running Claude Code with network restrictions.

1. Clone this repository and navigate to it:
```sh
git clone https://github.com/chemitaro/agent-sandbox.git [your-project-name]
cd [your-project-name]
```

2. Install the `sandbox` command (optional but recommended):
```sh
./scripts/install-sandbox.sh
# This creates /usr/local/bin/sandbox -> <repo>/host/sandbox
```
If you prefer not to install it, you can run `./host/sandbox` directly from this repo.

3. (Optional) Create `.env` in the repo root for secrets shared across all sandboxes:
```sh
# .env (git-ignored)
GH_TOKEN=ghp_xxxxxxxxxxxx
GEMINI_API_KEY=...
```
The tool never overwrites `.env`. It injects dynamic values via process env at runtime.

4. Start from any project directory:
```sh
# Build, start, and open a shell (default)
sandbox

# Or explicit subcommands
sandbox up
sandbox build
sandbox stop
sandbox down
sandbox status
sandbox name
```

**Mount behavior**
- If no args are given and the directory is a Git worktree, `mount-root` is auto-detected as the LCA of worktrees; `workdir` is the current directory.
- If no args are given and the directory is not Git-managed, `mount-root = workdir = current directory`.
- You can override explicitly:
```sh
sandbox shell --mount-root /path/to/repo --workdir /path/to/repo/worktrees/feature-a
```

### Local agent settings (`.agent-home/`)

This sandbox no longer uses shared/external Docker volumes for agent configs.  
Instead, it bind-mounts host-local folders under `.agent-home/`:

- `.agent-home/.claude` → `/home/node/.claude`
- `.agent-home/.codex` → `/home/node/.codex`
- `.agent-home/.gemini` → `/home/node/.gemini`
- `.agent-home/.opencode` → `/home/node/.config/opencode`
- `.agent-home/.opencode-data` → `/home/node/.local/share/opencode`
- `.agent-home/commandhistory` → `/commandhistory`

`.agent-home/` is created automatically when you run `sandbox shell/up/build` (and for stop/down only when a matching container exists).  
On first use, each CLI generates its config into these folders, and subsequent runs reuse them.  

If you are upgrading from an older version, you may have existing Docker volumes
(`claude-code-config`, `codex-cli-config`, `gemini-cli-config`, `claude-code-bashhistory`);
copy their contents once into `.agent-home/` before starting the container.

5. Run Claude Code:
```sh
# Inside the container
claude --dangerously-skip-permissions

# Or use tmux sessions (from host)
make tmux-claude my-project      # Start tmux session with Claude
make tmux-claude-wt feature-xyz  # Start in specific worktree
make tmux-opencode my-project    # Start tmux session with OpenCode
make tmux-opencode-wt feature-xyz  # Start in specific worktree
```

6. One-command tmux sessions (inside container):
```sh
# Always attach to a unique session in /srv/mount
tmux-claude   # Unique Claude Code session named "claude"
tmux-codex    # Unique Codex CLI session named "codex"
tmux-opencode # Unique OpenCode session named "opencode"

# Both commands:
# - Attach if the session already exists
# - Otherwise create the session in /srv/mount and start the tool
```

### Git access inside the container
- `.git`メタデータは自動で読み取り専用にマウントされるため、`git commit`/`merge`/`push`などの書き込み系コマンドはPermission deniedになります。
- `git status`や`git diff`などの参照系コマンドは利用できます。
- 変更はコンテナ内で編集し、コミットやプッシュはホスト側のターミナルから実行してください。

### pre-commit
開発対象リポジトリで `pre-commit` を使う場合は、コンテナ内で `pre-commit install` を実行してください。

See [CLAUDE.md](./CLAUDE.md) for detailed usage instructions.

### VS Code Devcontainer Usage

Devcontainer support is not actively maintained for the dynamic mount workflow.
If you need it, treat it as experimental and prefer the `sandbox` CLI for daily use.

### Option 2: Global Installation

1. Install Claude Code:

```sh
npm install -g @anthropic-ai/claude-code
```

2. Navigate to your project directory and run `claude`.

## Reporting Bugs

We welcome your feedback. Use the `/bug` command to report issues directly within Claude Code, or file a [GitHub issue](https://github.com/anthropics/claude-code/issues).

## Data collection, usage, and retention

When you use Claude Code, we collect feedback, which includes usage data (such as code acceptance or rejections), associated conversation data, and user feedback submitted via the `/bug` command.

### How we use your data

We may use feedback to improve our products and services, but we will not train generative models using your feedback from Claude Code. Given their potentially sensitive nature, we store user feedback transcripts for only 30 days.

If you choose to send us feedback about Claude Code, such as transcripts of your usage, Anthropic may use that feedback to debug related issues and improve Claude Code's functionality (e.g., to reduce the risk of similar bugs occurring in the future).

### Privacy safeguards

We have implemented several safeguards to protect your data, including limited retention periods for sensitive information, restricted access to user session data, and clear policies against using feedback for model training.

For full details, please review our [Commercial Terms of Service](https://www.anthropic.com/legal/commercial-terms) and [Privacy Policy](https://www.anthropic.com/legal/privacy).
