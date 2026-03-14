#!/bin/bash
set -e

# Setup config directory
mkdir -p ~/.clawdbot
cp /app/clawdbot.json ~/.clawdbot/clawdbot.json

# If TELEGRAM_BOT_TOKEN is set in HF Secrets, inject it into config
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    sed -i "s|\"botToken\": \"TELEGRAM_BOT_TOKEN\"|\"botToken\": \"$TELEGRAM_BOT_TOKEN\"|" ~/.clawdbot/clawdbot.json
    echo "Telegram bot token configured."
else
    echo "Warning: TELEGRAM_BOT_TOKEN not set. Telegram integration will be disabled."
fi

# Start Ollama in the background
ollama serve &
OLLAMA_PID=$!

# Wait until Ollama's API is responsive
echo "Waiting for Ollama to start..."
for i in $(seq 1 30); do
    if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo "Ollama is ready."
        break
    fi
    echo "  attempt $i/30..."
    sleep 2
done

# Ensure the model is available (in case it wasn't pulled at build time)
if ! ollama list | grep -q "qwen2.5:1.5b"; then
    echo "Pulling qwen2.5:1.5b model..."
    ollama pull qwen2.5:1.5b
fi

# Start the gateway
echo "Starting application..."
exec node dist/entry.js gateway --port 7860 --verbose
