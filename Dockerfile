FROM ubuntu:24.04

ARG TZ
ENV TZ="$TZ"

# Install Node.js 20
RUN apt update && apt install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt install -y nodejs

# Create node user explicitly (Ubuntu 24.04 doesn't create node user automatically)
RUN groupadd -r node && useradd -r -g node -s /bin/bash -m node

# Install Git latest version from official PPA
RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt install -y software-properties-common && \
    add-apt-repository ppa:git-core/ppa -y && \
    apt update && \
    apt install -y git && \
    echo "✅ Git version: $(git --version)" && \
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
  tree

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
# This will be overridden by make shell/start commands when accessed from tmux
ENV TMUX_SESSION_NAME=non-tmux

# Create sandbox and product directories and set permissions
# /opt/sandbox: Internal sandbox tools (isolated from host)
# /srv/product: User workspace (mounted from host)
RUN mkdir -p /opt/sandbox /srv/product /home/node/.claude /home/node/.config/nvim && \
  chown -R node:node /opt/sandbox /srv/product /home/node/.claude /home/node/.config

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

# Copy npm configuration files to a temporary location that won't be overwritten by volume mount
COPY --chown=node:node package.json .npmrc /tmp/npm-setup/

# Install npm packages based on package.json from temporary location
# Clear npm cache to ensure latest versions are fetched
RUN cd /tmp/npm-setup && npm cache clean --force && npm run install-global && rm -rf /tmp/npm-setup

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

# Ensure uv is in PATH
ENV PATH="/home/node/.local/bin:$PATH"

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
# - /srv/product: Host-mounted directory (changes sync with host)
#   Should be mounted from host using bind mount in docker-compose.yml:
#   volumes:
#     - ${SOURCE_PATH}:/srv/product
#   
# This ensures sandbox environment modifications stay in container
# while user workspace changes are preserved on host
