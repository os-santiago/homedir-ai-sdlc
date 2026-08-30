#!/usr/bin/env bash
set -euo pipefail

# Copy sc-agent config to user home if not exists
# This ensures config is available regardless of which user runs the container
if [ ! -d "${HOME}/.sc-agent" ]; then
    mkdir -p "${HOME}/.sc-agent"
    cp -r /.sc-agent/config.json "${HOME}/.sc-agent/"
fi

# Inject API key from environment based on active profile
ACTIVE_PROFILE=$(jq -r '.activeProfile' "${HOME}/.sc-agent/config.json")

if [ "$ACTIVE_PROFILE" = "openai" ] && [ -n "${OPENAI_API_KEY:-}" ]; then
    echo "Configuring OpenAI API key from environment..."
    jq --arg key "$OPENAI_API_KEY" \
       '.profiles.openai.apiKey = $key | .profiles."openai-fast".apiKey = $key' \
       "${HOME}/.sc-agent/config.json" > "${HOME}/.sc-agent/config.json.tmp" && \
       mv "${HOME}/.sc-agent/config.json.tmp" "${HOME}/.sc-agent/config.json"
elif [ "$ACTIVE_PROFILE" = "nvidia" ] && [ -n "${NVIDIA_API_KEY:-}" ]; then
    echo "Configuring NVIDIA API key from environment..."
    jq --arg key "$NVIDIA_API_KEY" \
       '.profiles.nvidia.apiKey = $key | .profiles."nvidia-fast".apiKey = $key' \
       "${HOME}/.sc-agent/config.json" > "${HOME}/.sc-agent/config.json.tmp" && \
       mv "${HOME}/.sc-agent/config.json.tmp" "${HOME}/.sc-agent/config.json"
fi

# Execute the implementation service
exec ./implementation-service
