# Deployment Notes - LiteLLM Configuration

## Latest Deployment

**Date:** 2026-08-30  
**Change:** Configure sc-agent-cli to use LiteLLM API

### Configuration

- **Endpoint:** https://litemaas.rhoai.rh-aiservices-bu.com/v1
- **Model:** Qwen3.6-35B-A3B
- **Provider:** OpenAI-compatible
- **Profile:** litellm

### Files Changed

- `future-go/components/implementation/config-litellm.json` (new)
- `future-go/components/implementation/Containerfile` (updated)

### Expected Impact

Implementation service will now use LiteLLM for code generation, resolving the SCC failures observed in Issue #1562.

---

This file triggers deployment workflow for PR #47 configuration.
