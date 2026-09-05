FROM node:22-slim

# Install git, curl, openssh-client, and base tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI (gh) — needed for creating and managing GitHub Issues and PRs
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    tee /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && \
    apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# Suppress background auto-updates
ENV DISABLE_AUTOUPDATER=1

# Set up home directory under node user (uid 1000)
RUN mkdir -p /home/brian && chown node:node /home/brian

USER node
ENV HOME=/home/brian
WORKDIR /workspace

ENTRYPOINT ["claude"]