FROM node:22-slim

# Install git (required by Claude Code) and basic tools
RUN apt-get update && apt-get install -y git curl && rm -rf /var/lib/apt/lists/*

# Install Claude Code globally inside the container
RUN npm install -g @anthropic-ai/claude-code

# Suppress background auto-updates since the container is read-only
ENV DISABLE_AUTOUPDATER=1

# Create the directory as root, then hand ownership to node user
RUN mkdir -p /home/brian && chown node:node /home/brian

# Run as non-root for extra safety
# RUN useradd -m -u 1000 claudeuser # can't do this as the node user is using id 1000
# USER claudeuser
USER node
ENV HOME=/home/brian

# Create a non-root working directory
WORKDIR /workspace

ENTRYPOINT ["claude"]

