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
cd your-project-name
```

2. Copy `.env.example` to `.env` and configure:
```sh
cp .env.example .env
# Edit .env with your settings
```

3. Start the container:
```sh
make up
# or: docker-compose up -d
```

4. Connect to the container:
```sh
make shell
# or: docker-compose exec agent-sandbox /bin/zsh
```

5. Run Claude Code:
```sh
claude --dangerously-skip-permissions
```

See [USAGE.md](./USAGE.md) for detailed instructions.

### VS Code Devcontainer Usage

This repository supports VS Code Devcontainer for a seamless development experience:

1. First, start the Docker Compose environment:
```sh
make up
```

2. Open the project in VS Code:
```sh
code .
```

3. When prompted, click "Reopen in Container" or use the Command Palette:
   - Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS)
   - Type "Dev Containers: Reopen in Container"

4. VS Code will attach to the running container and you'll be ready to develop in `/srv/product`

**Note:** The devcontainer now attaches to the existing Docker Compose container instead of building its own. This provides faster startup and consistent environments between CLI and VS Code usage.

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
