FROM ubuntu:24.04

ARG TZ
ENV TZ="$TZ"

# Install Node.js 20
RUN apt update && apt install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt install -y nodejs

# Install basic development tools and iptables/ipset
RUN apt update && apt install -y less \
  git \
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
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
  apt update && \
  apt install -y docker-ce-cli docker-compose-plugin

# Create docker group with standard GID (999)
RUN groupadd -g 999 docker || true

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
RUN mkdir -p /opt/sandbox /srv/product /home/node/.claude /home/node/.config/nvim && \
  chown -R node:node /opt/sandbox /srv/product /home/node/.claude /home/node/.config

WORKDIR /opt/sandbox

RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_${ARCH}.deb" && \
  sudo dpkg -i "git-delta_0.18.2_${ARCH}.deb" && \
  rm "git-delta_0.18.2_${ARCH}.deb"

# Add node user to docker group for Docker-on-Docker
RUN usermod -aG docker node

# Set up non-root user
USER node

# Install global packages
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# Copy npm configuration files
COPY --chown=node:node package.json .npmrc ./

# Install npm packages based on package.json
RUN npm install --global

# Set the default shell to zsh rather than sh
ENV SHELL=/bin/zsh

# Default powerline10k theme
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.2.0/zsh-in-docker.sh)" -- \
  -p git \
  -p fzf \
  -a "source /usr/share/doc/fzf/examples/key-bindings.zsh" \
  -a "source /usr/share/doc/fzf/examples/completion.zsh" \
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
