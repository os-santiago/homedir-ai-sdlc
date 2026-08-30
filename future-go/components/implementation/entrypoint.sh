#!/usr/bin/env bash
set -euo pipefail

# Copy sc-agent config to user home if not exists
# This ensures config is available regardless of which user runs the container
if [ ! -d "${HOME}/.sc-agent" ]; then
    mkdir -p "${HOME}/.sc-agent"
    cp -r /.sc-agent/config.json "${HOME}/.sc-agent/"
fi

# Execute the implementation service
exec ./implementation-service
