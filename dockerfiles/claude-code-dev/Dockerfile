FROM node:22-slim

# Install git, curl, and base tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    gnupg \
    unzip \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Install Java 25 (Temurin)
RUN curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public | \
    gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(. /etc/os-release && echo $VERSION_CODENAME) main" | \
    tee /etc/apt/sources.list.d/adoptium.list && \
    apt-get update && \
    apt-get install -y temurin-25-jdk && \
    rm -rf /var/lib/apt/lists/*

# Install Maven
ARG MAVEN_VERSION=3.9.16
RUN curl -fsSL https://downloads.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
    | tar -xzC /opt && \
    ln -s /opt/apache-maven-${MAVEN_VERSION} /opt/maven

ENV JAVA_HOME=/usr/lib/jvm/temurin-25-jdk-amd64
ENV MAVEN_HOME=/opt/maven
ENV PATH="${JAVA_HOME}/bin:${MAVEN_HOME}/bin:${PATH}"

# Install GitHub CLI (gh)
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
