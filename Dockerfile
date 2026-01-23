FROM ubuntu:24.04

ARG TZ
ENV TZ="$TZ"

# Product name for dynamic workspace path
ARG PRODUCT_NAME
ENV PRODUCT_NAME="$PRODUCT_NAME"
ENV PRODUCT_WORK_DIR="/srv/$PRODUCT_NAME"

# Install Node.js 20
RUN apt update && apt install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt install -y nodejs

# Create node user explicitly (Ubuntu 24.04 doesn't create node user automatically)
RUN groupadd -r node && useradd -r -g node -s /bin/bash -m node

# Install Git latest version from official PPA
# NOTE: add-apt-repository uses Launchpad API (api.launchpad.net). Some networks block it.
#       We add the PPA manually via ppa.launchpadcontent.net to avoid the API dependency.
RUN set -eux; \
    apt update; \
    DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends ca-certificates curl gnupg; \
    codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"; \
    ppa_base="https://ppa.launchpadcontent.net/git-core/ppa/ubuntu"; \
    tmpdir="$(mktemp -d)"; \
    curl -fsSL "$ppa_base/dists/$codename/Release.gpg" -o "$tmpdir/Release.gpg"; \
    signer="$(gpg --list-packets "$tmpdir/Release.gpg" 2>/dev/null | awk '/issuer fpr v4/ {print $NF; exit} /issuer key ID/ {print $NF; exit} /keyid/ {gsub(/^0x/,"",$NF); print $NF; exit}')"; \
    signer="$(printf '%s' "$signer" | tr -cd '0-9A-Fa-f')"; \
    test -n "$signer"; \
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${signer}" -o "$tmpdir/git-core-ppa-key.asc"; \
    gpg --dearmor -o /usr/share/keyrings/git-core-ppa.gpg "$tmpdir/git-core-ppa-key.asc"; \
    echo "deb [signed-by=/usr/share/keyrings/git-core-ppa.gpg] $ppa_base $codename main" > /etc/apt/sources.list.d/git-core-ppa.list; \
    rm -rf "$tmpdir"; \
    apt update; \
    DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends git; \
    echo "✅ Git version: $(git --version)"; \
    rm -rf /var/lib/apt/lists/*

# Install basic development tools and iptables/ipset
RUN apt update && apt install -y less \
  procps \
  sudo \
  fzf \
  zsh \
  man-db \
  unzip \
  gnupg2 \
  gh \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  jq \
  curl \
  ca-certificates \
  lsb-release \
  gosu \
  neovim \
  tree \
  tmux \
  make

# Install Docker CLI and Compose plugin (Docker-on-Docker approach)
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
  apt update && \
  apt install -y docker-ce-cli docker-compose-plugin

# Create docker group (let system assign GID)
RUN if ! getent group docker; then groupadd docker; fi

# Ensure default node user has access to /usr/local/share
RUN mkdir -p /usr/local/share/npm-global && \
  chown -R node:node /usr/local/share

ARG USERNAME=node

# Persist bash history.
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

# Set `DEVCONTAINER` environment variable to help with orientation
ENV DEVCONTAINER=true

# Set default TMUX_SESSION_NAME for direct docker access
# This can be overridden by host-side tooling when accessed from tmux
ENV TMUX_SESSION_NAME=non-tmux

# Create sandbox and workspace directories and set permissions
# /opt/sandbox: Internal sandbox tools (isolated from host)
# /srv/${PRODUCT_NAME}: Legacy workspace path (container-side). Dynamic mount uses /srv/mount at runtime.
RUN mkdir -p /opt/sandbox /srv/${PRODUCT_NAME} /home/node/.claude /home/node/.codex /home/node/.gemini /home/node/.config/opencode /home/node/.local/share/opencode /home/node/.cache/opencode /home/node/.config/nvim && \
  chown -R node:node /opt/sandbox /srv/${PRODUCT_NAME} /home/node/.claude /home/node/.codex /home/node/.gemini /home/node/.config /home/node/.local /home/node/.cache && \
  ln -s /home/node/.codex /home/node/.config/codex || true && \
  ln -s /home/node/.gemini /home/node/.config/gemini || true

# Ensure /opt/sandbox remains container-internal (not affected by host mounts)
VOLUME ["/opt/sandbox"]

WORKDIR /opt/sandbox

RUN ARCH=$(dpkg --print-architecture) && \
  curl -L -o "git-delta_0.18.2_${ARCH}.deb" "https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_${ARCH}.deb" && \
  sudo dpkg -i "git-delta_0.18.2_${ARCH}.deb" && \
  rm "git-delta_0.18.2_${ARCH}.deb"

# Add node user to docker group for Docker-on-Docker
RUN usermod -aG docker node

# Set up non-root user
USER node

# Install global packages
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# Ensure npm cache directory exists (may be mounted as a shared volume at runtime)
RUN mkdir -p /home/node/.npm/_cache

# Set the default shell to zsh rather than sh
ENV SHELL=/bin/zsh

# Default powerline10k theme
RUN sh -c "$(curl -fsSL https://github.com/deluan/zsh-in-docker/releases/download/v1.2.0/zsh-in-docker.sh)" -- \
  -p git \
  -p fzf \
  -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  -a "alias vim='nvim'" \
  -a "alias vi='nvim'" \
  -x

# Install uv (Python package manager) - available for projects that need it
USER node
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Ensure uv and claude are in PATH
ENV PATH="/home/node/.local/bin:$PATH"

# Prefer uv-managed Python and pin to Python 3.12 (latest stable) for tools like pre-commit
ENV UV_MANAGED_PYTHON=1
ENV UV_PYTHON=3.12
ENV PRE_COMMIT_HOME=/home/node/.cache/pre-commit

# Pre-install uv-managed Python to avoid runtime downloads (especially under firewall restrictions)
RUN uv python install 3.12 --default

# Provide a `pre-commit` command via uvx (fallback to `uv tool run` if uvx is unavailable)
RUN cat > /home/node/.local/bin/pre-commit <<'SH' && chmod +x /home/node/.local/bin/pre-commit
#!/usr/bin/env bash
set -euo pipefail

PY="${UV_PYTHON:-3.12}"
FROM="pre-commit"
if [ -n "${PRE_COMMIT_VERSION:-}" ]; then
  FROM="pre-commit==${PRE_COMMIT_VERSION}"
fi

if command -v uvx >/dev/null 2>&1; then
  exec uvx --managed-python --python "$PY" --from "$FROM" pre-commit "$@"
fi

exec uv tool run --managed-python --python "$PY" --from "$FROM" pre-commit "$@"
SH

# CLI config/cache directories are stored under /home/node and can be persisted via host bind mounts.

# Switch back to root for script setup
USER root

# Install Cursor CLI
RUN curl https://cursor.com/install -fsS | bash

# Copy and set up scripts
COPY scripts/init-firewall.sh /usr/local/bin/
COPY scripts/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-firewall.sh /usr/local/bin/docker-entrypoint.sh && \
  echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall && \
  echo "node ALL=(root) NOPASSWD: /usr/bin/docker, /usr/bin/docker-compose" >> /etc/sudoers.d/node-docker && \
  chmod 0440 /etc/sudoers.d/node-firewall /etc/sudoers.d/node-docker

# Copy Slack notification script
COPY scripts/slack-notify.js /opt/sandbox/scripts/
RUN chmod +x /opt/sandbox/scripts/slack-notify.js && \
    ln -s /opt/sandbox/scripts/slack-notify.js /usr/local/bin/slack-notify

# Set up Docker environment
ENV DOCKER_CONFIG=/home/node/.docker
ENV DOCKER_HOST=unix:///var/run/docker.sock

# Create Docker config directory for node user
RUN mkdir -p /home/node/.docker && \
  chown -R node:node /home/node/.docker

# Stay as root for entrypoint
# ENTRYPOINT will switch to node user after setup
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/bin/zsh"]

# Volume Strategy:
# - /opt/sandbox: Container-internal volume (changes don't affect host)
#   Contains sandbox tools, scripts, and configurations
#   Defined as VOLUME to ensure isolation from host filesystem
# 
# - /srv/mount: Host-mounted directory (changes sync with host)
#   Should be mounted from host using bind mount in docker-compose.yml:
#   volumes:
#     - ${SOURCE_PATH}:/srv/mount
#   
# This ensures sandbox environment modifications stay in container
# while user workspace changes are preserved on host
