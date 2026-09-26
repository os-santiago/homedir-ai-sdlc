#!/usr/bin/env bash
set -euo pipefail
umask 077

: "${NVIDIA_API_KEY:?NVIDIA_API_KEY must be supplied at runtime}"
export SC_PROFILE="${SC_PROFILE:-nvidia}"
if [ "$SC_PROFILE" != nvidia ]; then
    echo "Implementation service requires the nvidia profile" >&2
    exit 1
fi
mkdir -p "${HOME}/.sc-agent"
if [ ! -f "${HOME}/.sc-agent/config.json" ]; then
    cp /.sc-agent/config.json "${HOME}/.sc-agent/config.json"
fi
# Reject stale profiles instead of sending credentials to another provider.
jq -e '.activeProfile == "nvidia" and
    .model.baseUrl == "https://integrate.api.nvidia.com/v1" and
    .profiles.nvidia.baseUrl == "https://integrate.api.nvidia.com/v1"' \
    "${HOME}/.sc-agent/config.json" >/dev/null
# Keep credentials out of argv and image layers; refresh the private runtime copy.
jq '.model.apiKey = env.NVIDIA_API_KEY |
    .profiles.nvidia.apiKey = env.NVIDIA_API_KEY' \
    "${HOME}/.sc-agent/config.json" > "${HOME}/.sc-agent/config.json.tmp"
mv "${HOME}/.sc-agent/config.json.tmp" "${HOME}/.sc-agent/config.json"
exec ./implementation-service