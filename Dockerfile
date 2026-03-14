FROM node:22-bookworm

# Install system dependencies for the application and various skills
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

RUN corepack enable

WORKDIR /app

# Copy package manifests first to leverage Docker cache
COPY package.json pnpm-lock.yaml* pnpm-workspace.yaml* ./
# Also copy ui package manifest if it exists
COPY ui/package.json ./ui/ 2>/dev/null || true

# Install dependencies
RUN pnpm install

# Copy the rest of the application
COPY . .

# Build the application
RUN pnpm build
RUN pnpm ui:install
RUN pnpm ui:build

# Pre-pull the model during build to make the space start faster
RUN ollama serve & sleep 5 && ollama pull qwen2.5:1.5b && pkill ollama || true

# Hugging Face Spaces runs as user 1000
RUN useradd -m -u 1000 user && chown -R user /app
# Ensure Ollama models and application data are accessible by the user
RUN mkdir -p /home/user/.ollama /home/user/clawd && chown -R user /home/user

# Sync models from root to user home
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
