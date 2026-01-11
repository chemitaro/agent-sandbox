# Claude Code

![](https://img.shields.io/badge/Node.js-18%2B-brightgreen?style=flat-square) [![npm]](https://www.npmjs.com/package/@anthropic-ai/claude-code)

[npm]: https://img.shields.io/npm/v/@anthropic-ai/claude-code.svg?style=flat-square

Claude Code is an agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster by executing routine tasks, explaining complex code, and handling git workflows -- all through natural language commands. Use it in your terminal, IDE, or tag @claude on Github.

**Learn more in the [official documentation](https://docs.anthropic.com/en/docs/claude-code/overview)**.

<img src="./demo.gif" />

## Get started

### Option 1: Docker Compose (Recommended for this repository)

This repository includes a secure containerized environment for running Claude Code with network restrictions.

1. Clone this repository and navigate to it:
```sh
git clone https://github.com/chemitaro/agent-sandbox.git [your-project-name]
cd [your-project-name]
```

2. Initialize configuration:
```sh
make init
# This will create sandbox.config from sandbox.config.example
```

3. Edit `sandbox.config` with your settings:
```sh
# Edit sandbox.config to set:
# SOURCE_PATH = /path/to/your/project (required)
# PRODUCT_NAME = product (required, change for different projects)
# GH_TOKEN = ghp_xxxxxxxxxxxx (optional, for private repos)
# Other optional settings...
vim sandbox.config  # or your preferred editor
```

**PRODUCT_NAME Setting**
`PRODUCT_NAME` in sandbox.config determines the workspace directory:
- Default value is `product` (creates `/srv/product`)
- Change it to set the container workspace directory
- Agent configs and shell history are persisted on the host under `.agent-home/` (git-ignored)
- Settings are isolated per sandbox repository; for fully separate settings per product, use separate sandbox clones
- Example: `PRODUCT_NAME = frontend` creates `/srv/frontend` workspace

### Local agent settings (`.agent-home/`)

This sandbox no longer uses shared/external Docker volumes for agent configs.  
Instead, it bind-mounts host-local folders under `.agent-home/`:

- `.agent-home/.claude` → `/home/node/.claude`
- `.agent-home/.codex` → `/home/node/.codex`
- `.agent-home/.gemini` → `/home/node/.gemini`
- `.agent-home/commandhistory` → `/commandhistory`

`.agent-home/` is created automatically by `make generate-env` (run implicitly by `make start/build/up/rebuild`).  
On first use, each CLI generates its config into these folders, and subsequent runs reuse them.  

If you are upgrading from an older version, you may have existing Docker volumes
(`claude-code-config`, `codex-cli-config`, `gemini-cli-config`, `claude-code-bashhistory`);
copy their contents once into `.agent-home/` before starting the container.

4. Quick start - start container and connect:
```sh
make start
# This will:
# - Validate configuration
# - Auto-generate .env and ensure .agent-home folders
# - Start the container if not running
# - Connect to /srv/${PRODUCT_NAME} directory (configured in sandbox.config)
```

Alternatively, manage containers manually:
```sh
# Start container
make up

# Connect to container
make shell          # Connect to /srv/${PRODUCT_NAME} (configured in sandbox.config)
make shell-sandbox  # Connect to /opt/sandbox

# Other commands
make status         # Check container status
make down           # Stop container
make restart        # Restart container
make rebuild        # Rebuild and restart container
```

5. Run Claude Code:
```sh
# Inside the container
claude --dangerously-skip-permissions

# Or use tmux sessions (from host)
make tmux-claude my-project      # Start tmux session with Claude
make tmux-claude-wt feature-xyz  # Start in specific worktree
```

6. One-command tmux sessions (inside container):
```sh
# Always attach to a unique session in /srv/${PRODUCT_NAME}
tmux-claude   # Unique Claude Code session named "claude"
tmux-codex    # Unique Codex CLI session named "codex"

# Both commands:
# - Attach if the session already exists
# - Otherwise create the session in /srv/${PRODUCT_NAME} and start the tool
```

### Git access inside the container
- `.git`メタデータは自動で読み取り専用にマウントされるため、`git commit`/`merge`/`push`などの書き込み系コマンドはPermission deniedになります。
- `git status`や`git diff`などの参照系コマンドは利用できます。
- 変更はコンテナ内で編集し、コミットやプッシュはホスト側のターミナルから実行してください。

### pre-commit
開発対象リポジトリで `pre-commit` を使う場合は、フック導入までまとめて実行できます：
```sh
make pre-commit-install
```

See [CLAUDE.md](./CLAUDE.md) for detailed usage instructions.

### VS Code Devcontainer Usage

This repository supports VS Code Devcontainer for a seamless development experience:

1. First, initialize and start the Docker Compose environment:
```sh
make init           # Creates sandbox.config and generates .env + .envrc
vim sandbox.config  # Configure your settings (set PRODUCT_NAME)
make up             # Start the container
```

2. Enable direnv for automatic environment loading (recommended):
```sh
# Install direnv if not already installed
# macOS: brew install direnv
# Ubuntu: apt install direnv

# Allow direnv to load .envrc in this project
direnv allow

# Now VS Code will automatically have the environment variables
code .
```

Or manually load environment:
```sh
# macOS/Linux (one-time)
set -a; source .env; set +a; code .

# Windows PowerShell (one-time)
Get-Content .env | ForEach-Object {
  if ($_ -match '^\s*([^#][^=]+)=(.*)') {
    [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
  }
}; code .
```

3. When prompted, click "Reopen in Container" or use the Command Palette:
   - Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS)
   - Type "Dev Containers: Reopen in Container"

4. VS Code will attach to the running container with workspace at `/srv/${PRODUCT_NAME}`

**Note:** The `.envrc` file is automatically generated by `make init/generate-env` and loads `.env` variables. With direnv installed and allowed, environment variables are automatically available when you enter the project directory.

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
