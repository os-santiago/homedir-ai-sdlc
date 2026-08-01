# GitHub Actions - Configuración de Secrets y Variables

Guía para configurar secrets y variables necesarios para los workflows de CI/CD.

## Ubicación

GitHub Repository → **Settings** → **Secrets and variables** → **Actions**

## Secrets Requeridos

### 1. `VPS_SSH_KEY` (Required para deploy-worker.yml)

**Tipo**: Secret  
**Descripción**: Private SSH key para conectar al VPS donde corre el worker

**Cómo obtenerlo**:

```bash
# En tu máquina local, generar key pair si no exists
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/homedir_sdlc_deploy

# Copiar public key al VPS
ssh-copy-id -i ~/.ssh/homedir_sdlc_deploy.pub homedir-sdlc@YOUR_VPS_HOST

# Copiar private key al clipboard
cat ~/.ssh/homedir_sdlc_deploy
```

Copiar TODO el contenido (incluye header y footer):
```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5...
...
-----END OPENSSH PRIVATE KEY-----
```

Pegar en GitHub Secret `VPS_SSH_KEY`.

### 2. `DEPLOY_SSH_KNOWN_HOSTS` (Opcional)

**Tipo**: Secret  
**Descripción**: Known hosts del VPS para evitar prompt de confirmación SSH

**Cómo obtenerlo**:

```bash
# Obtener fingerprint del VPS
ssh-keyscan -H YOUR_VPS_HOST

# Output ejemplo:
# |1|abc123...= ecdsa-sha2-nistp256 AAAA...
```

Copiar el output completo y pegar en GitHub Secret `DEPLOY_SSH_KNOWN_HOSTS`.

**Nota**: Si no se configura, el workflow ejecutará `ssh-keyscan` automáticamente (menos seguro pero funcional).

## Variables Requeridas

### 1. `VPS_HOST` (Required)

**Tipo**: Variable  
**Descripción**: Hostname o dirección IP del VPS

**Valor ejemplo**: `vps.example.com` o `192.168.1.100`

### 2. `VPS_USER` (Required)

**Tipo**: Variable  
**Descripción**: Usuario con permisos para deployar en el VPS

**Valor recomendado**: `homedir-sdlc` (o el usuario que ejecuta el worker)

### 3. `VPS_PORT` (Opcional)

**Tipo**: Variable  
**Descripción**: Puerto SSH del VPS  
**Default**: 22

**Valor ejemplo**: `22` o `2222` si usa puerto custom

### 4. `WORKER_SSH_USER` (Opcional)

**Tipo**: Variable  
**Descripción**: Usuario bajo el cual corre el worker  
**Default**: `homedir-sdlc`

**Valor ejemplo**: `homedir-sdlc`

## Secrets Automáticos (Provistos por GitHub)

### `GITHUB_TOKEN`

**Descripción**: Token automático para autenticación con GitHub Container Registry

**Usado en**: `build-worker-image.yml`

**Permisos**: Se configura automáticamente con:
```yaml
permissions:
  contents: read
  packages: write
```

No requiere configuración manual.

## Configuración Paso a Paso

### En GitHub Web UI

1. Ir a https://github.com/os-santiago/homedir-ai-sdlc
2. Click **Settings** (tab superior)
3. Sidebar izquierdo → **Secrets and variables** → **Actions**
4. Tab **Secrets**:
   - Click **New repository secret**
   - Name: `VPS_SSH_KEY`
   - Value: Pegar private SSH key completo
   - Click **Add secret**
   - Repetir para `DEPLOY_SSH_KNOWN_HOSTS` (opcional)

5. Tab **Variables**:
   - Click **New repository variable**
   - Name: `VPS_HOST`
   - Value: Tu hostname/IP
   - Click **Add variable**
   - Repetir para `VPS_USER`, `VPS_PORT`, `WORKER_SSH_USER`

### Via GitHub CLI

```bash
# Secrets
gh secret set VPS_SSH_KEY < ~/.ssh/homedir_sdlc_deploy
gh secret set DEPLOY_SSH_KNOWN_HOSTS --body "$(ssh-keyscan -H YOUR_VPS_HOST)"

# Variables
gh variable set VPS_HOST --body "vps.example.com"
gh variable set VPS_USER --body "homedir-sdlc"
gh variable set VPS_PORT --body "22"
gh variable set WORKER_SSH_USER --body "homedir-sdlc"
```

## Verificación

### Test Workflow Manualmente

```bash
# Trigger manual de build-worker-image
gh workflow run build-worker-image.yml

# Trigger manual de deploy-worker
gh workflow run deploy-worker.yml -f reason="Testing deployment"

# Ver run status
gh run watch
```

### Verificar Secrets Configurados

```bash
# Listar secrets (no muestra valores)
gh secret list

# Listar variables
gh variable list
```

Output esperado:
```
VPS_SSH_KEY               Updated YYYY-MM-DD
DEPLOY_SSH_KNOWN_HOSTS    Updated YYYY-MM-DD

VPS_HOST         vps.example.com
VPS_USER         homedir-sdlc
VPS_PORT         22
WORKER_SSH_USER  homedir-sdlc
```

## Seguridad

### Rotación de SSH Keys

Se recomienda rotar keys cada 90 días:

```bash
# Generar nueva key
ssh-keygen -t ed25519 -C "github-actions-deploy-$(date +%Y%m)" -f ~/.ssh/homedir_sdlc_deploy_new

# Agregar al VPS (NO remover la vieja aún)
ssh-copy-id -i ~/.ssh/homedir_sdlc_deploy_new.pub homedir-sdlc@YOUR_VPS

# Actualizar secret en GitHub
gh secret set VPS_SSH_KEY < ~/.ssh/homedir_sdlc_deploy_new

# Verificar workflow funciona
gh workflow run deploy-worker.yml -f reason="Key rotation test"

# Si OK, remover key vieja del VPS
ssh homedir-sdlc@YOUR_VPS
# En VPS: editar ~/.ssh/authorized_keys y remover key vieja
```

### Least Privilege

El usuario SSH debe tener SOLO permisos para:
- Escribir en `~/.local/bin/`
- Reiniciar systemd user service `homedir-sdlc-worker.service`
- Leer `/var/lib/homedir-sdlc/heartbeat.json` (opcional, para verificación)

**NO debe tener**:
- Acceso sudo completo
- Permisos para modificar systemd system units
- Acceso a otros usuarios

### Audit Logs

Revisar periódicamente:

```bash
# Ver deployments recientes
gh run list --workflow=deploy-worker.yml --limit 10

# Ver logs de un deployment específico
gh run view RUN_ID --log
```

## Troubleshooting

### Error: "SSH deployment not configured"

**Causa**: Falta `VPS_HOST`, `VPS_USER`, o `VPS_SSH_KEY`

**Solución**: Verificar que todos los secrets/variables están configurados

```bash
gh secret list
gh variable list
```

### Error: "Permission denied (publickey)"

**Causa**: SSH key no está autorizado en el VPS

**Solución**: Re-copiar public key

```bash
ssh-copy-id -i ~/.ssh/homedir_sdlc_deploy.pub homedir-sdlc@YOUR_VPS
```

### Error: "Host key verification failed"

**Causa**: Known hosts no configurado o cambió fingerprint del VPS

**Solución**: Actualizar `DEPLOY_SSH_KNOWN_HOSTS`

```bash
gh secret set DEPLOY_SSH_KNOWN_HOSTS --body "$(ssh-keyscan -H YOUR_VPS_HOST)"
```

### Workflow está en "pending" indefinidamente

**Causa**: Posiblemente runners de GitHub están ocupados

**Solución**: Esperar o re-run

```bash
gh run rerun RUN_ID
```

## Workflows que Usan Secrets/Variables

### `build-worker-image.yml`

**Secrets usados**:
- `GITHUB_TOKEN` (automático) - Para push a ghcr.io

**Variables usadas**: Ninguna

**Trigger**: 
- Push a `main` en paths: `platform/**`, `container/**`, `dashboard/**`
- Pull request
- Manual dispatch

**Output**: 
- Imagen OCI: `ghcr.io/os-santiago/homedir-ai-sdlc:latest`
- Imagen tagged: `ghcr.io/os-santiago/homedir-ai-sdlc:SHA`

### `deploy-worker.yml`

**Secrets usados**:
- `VPS_SSH_KEY` (required)
- `DEPLOY_SSH_KNOWN_HOSTS` (opcional)

**Variables usadas**:
- `VPS_HOST` (required)
- `VPS_USER` (required)
- `VPS_PORT` (opcional, default: 22)
- `WORKER_SSH_USER` (opcional, default: homedir-sdlc)

**Trigger**:
- Push a `main` en paths: `platform/scripts/**`, `platform/config/**`
- Manual dispatch (con input `reason`)

**Output**:
- Scripts deployed to `~/.local/bin/` en VPS
- Systemd service restarted
- Deployment verification report

## Referencias

- [GitHub Actions Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [SSH Key Generation](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)
- [Build Worker Workflow](../../.github/workflows/build-worker-image.yml)
- [Deploy Worker Workflow](../../.github/workflows/deploy-worker.yml)
