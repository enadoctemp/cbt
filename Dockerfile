FROM node:22-bookworm

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    curl \
    tini \
    ffmpeg \
    git \
    jq \
    libvips-dev \
    build-essential \
    zstd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Ollama
RUN curl -fsSL https://ollama.com/install.sh | sh

# Enable corepack (pnpm)
RUN corepack enable

WORKDIR /app

# Clone openclaw source into the working directory
RUN git clone https://github.com/openclaw/openclaw.git .tmp_repo \
    && cp -r .tmp_repo/. . \
    && rm -rf .tmp_repo

# Install root dependencies (package.json already present from git clone)
RUN pnpm install

# Copy your config files on top (overrides cloned defaults)
COPY . .

# Install UI dependencies BEFORE building
RUN pnpm ui:install

# Build backend
RUN pnpm build

# Build UI
RUN pnpm ui:build

# Pre-pull the Ollama model at build time for faster startup
RUN ollama serve & sleep 5 && ollama pull qwen2.5:1.5b && pkill ollama || true

# Hugging Face Spaces runs as user 1000
# node:22-bookworm already has UID 1000 (node user), so rename it to "user"
RUN usermod -l user -d /home/user -m node && chown -R user /app

# Ensure Ollama models and app data are accessible by the user
RUN mkdir -p /home/user/.ollama /home/user/clawd && chown -R user /home/user

# Sync models pulled as root into user home
RUN chown -R user /root/.ollama 2>/dev/null || true; \
    cp -r /root/.ollama/. /home/user/.ollama/ 2>/dev/null || true; \
    chown -R user /home/user/.ollama 2>/dev/null || true

USER user

ENV HOME=/home/user
ENV OLLAMA_MODELS=/home/user/.ollama/models
ENV NODE_ENV=production

# Hugging Face Spaces expects port 7860
EXPOSE 7860

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bash", "start.sh"]
