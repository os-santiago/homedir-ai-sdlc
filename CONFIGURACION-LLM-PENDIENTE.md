# Configuración LLM Pendiente para Completar E2E Tests

## Estado Actual

✅ **E2E Test Principal COMPLETADO**: Issue #1559 → PR #1560  
⚠️ **Tests Adicionales BLOQUEADOS**: Issues #1557, #1558

## Problema

Todos los proveedores LLM configurados están inactivos o no disponibles:

### Implementation Service
- Configuración actual: `openai` profile
- Problema: `OPENAI_API_KEY` no existe en GitHub Secrets
- Estado: `Error: OpenAI API requires an API key`

### Worker SCC
- Configuración actual: `nvidia/nemotron-3-ultra-550b-a55b`
- Problema: Modelo no disponible
- Estado: Fallos continuos en generación

## Solución Requerida

### Opción 1: Configurar OpenAI (Recomendado)

**Paso 1:** Agregar secret en GitHub
```bash
gh secret set OPENAI_API_KEY --repo os-santiago/homedir-ai-sdlc
# Pegar el API key de OpenAI cuando solicite
```

**Paso 2:** Re-deployar
- El deployment workflow ya está configurado para usar OPENAI_API_KEY
- PR #46 ya implementó toda la configuración necesaria
- Solo falta el secreto

**Paso 3:** Resetear issues
```bash
gh issue edit 1558 --remove-label scc-failed --add-label scc-queued
gh issue edit 1557 --add-label scc-queued
```

### Opción 2: Configurar Anthropic Claude

**Paso 1:** Crear config-anthropic.json
```json
{
  "model": {
    "provider": "anthropic",
    "baseUrl": "https://api.anthropic.com",
    "model": "claude-3-5-sonnet-20241022"
  }
}
```

**Paso 2:** Agregar secret
```bash
gh secret set ANTHROPIC_API_KEY --repo os-santiago/homedir-ai-sdlc
```

**Paso 3:** Actualizar Containerfile y deployment workflow

### Opción 3: Actualizar Worker a OpenAI

**Actualizar Worker config:**
```bash
# En el VPS
podman exec ai-sdlc-worker bash -c '
cat > /root/.sc-agent/config.json << EOF
{
  "model": {
    "provider": "openai",
    "model": "gpt-4o-mini"
  },
  "profiles": {
    "openai": {
      "provider": "openai",
      "model": "gpt-4o-mini"
    }
  },
  "activeProfile": "openai"
}
EOF
'
```

**Agregar OPENAI_API_KEY al worker.env:**
```bash
echo "OPENAI_API_KEY=sk-..." >> /etc/homedir-sdlc/worker.env
```

**Restart worker:**
```bash
podman restart ai-sdlc-worker
```

## Validación

Una vez configurado OpenAI:

1. **Test manual:**
   ```bash
   podman exec ai-sdlc-worker scc chat -m openai -yq "say hello"
   ```

2. **Resetear issues:**
   ```bash
   gh issue edit 1558 --remove-label scc-failed --add-label scc-queued
   gh issue edit 1557 --add-label scc-queued
   ```

3. **Monitorear procesamiento:**
   - Worker procesará en próximo ciclo (~3 minutos)
   - Esperado: PRs creados para ambos issues
   - Duración estimada: 15-25 minutos cada uno

## Métricas de Éxito

- ✅ Issue #1559: COMPLETADO (22 minutos)
- ⏳ Issue #1558: Esperando configuración LLM
- ⏳ Issue #1557: Esperando configuración LLM

## Siguiente Paso

**ACCIÓN INMEDIATA REQUERIDA:**

```bash
# 1. Agregar OPENAI_API_KEY a GitHub Secrets
gh secret set OPENAI_API_KEY --repo os-santiago/homedir-ai-sdlc

# 2. Verificar que el secreto existe
gh secret list --repo os-santiago/homedir-ai-sdlc | grep OPENAI

# 3. Re-deployar (automáticamente usará el nuevo secret)
gh workflow run deploy-production.yml --repo os-santiago/homedir-ai-sdlc

# 4. Una vez deployado, resetear issues
gh issue edit 1558 --remove-label scc-failed --add-label scc-queued --repo os-santiago/homedir
gh issue edit 1557 --add-label scc-queued --repo os-santiago/homedir
```

## Tiempo Estimado

- Configurar OpenAI: 2 minutos
- Deployment: 3-4 minutos
- Procesamiento Issue #1558: 15-25 minutos
- Procesamiento Issue #1557: 15-25 minutos

**Total: ~45-60 minutos para completar todos los E2E tests**

---

**Fecha**: 2026-08-30  
**Estado**: Configuración LLM pendiente  
**Bloqueador**: OPENAI_API_KEY no configurado en GitHub Secrets
