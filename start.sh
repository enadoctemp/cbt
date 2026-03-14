#!/bin/bash
set -e

# Setup config directory
mkdir -p ~/.clawdbot
cp /app/clawdbot.json ~/.clawdbot/clawdbot.json

# If TELEGRAM_BOT_TOKEN is set in HF Secrets, update the config
if [ ! -z "$TELEGRAM_BOT_TOKEN" ]; then
    sed -i "s/\"botToken\": \"TELEGRAM_BOT_TOKEN\"/\"botToken\": \"$TELEGRAM_BOT_TOKEN\"/" ~/.clawdbot/clawdbot.json
fi

# Start Ollama in the background
ollama serve &

# Wait until Ollama's API is responsive
echo "Waiting for Ollama to start..."
curl --retry 30 --retry-delay 2 --retry-connrefused -sf http://localhost:11434/api/tags > /dev/null
echo "Ollama is ready."

# Start the gateway
echo "Starting application..."
exec node dist/entry.js gateway --port 7860 --verbose
