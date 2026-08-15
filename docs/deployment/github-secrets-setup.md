# GitHub Secrets Setup for CI/CD

Para que el workflow de CI/CD pueda deployar automáticamente al VPS, necesitas configurar los siguientes secrets en GitHub.

## Secrets Requeridos

### 1. `VPS_HOST`
- **Descripción**: IP o hostname del VPS
- **Ejemplo**: `72.60.141.165`

### 2. `VPS_USER`
- **Descripción**: Usuario SSH para deployment (recommend `root` o usuario con permisos de podman)
- **Ejemplo**: `root`

### 3. `VPS_SSH_KEY`
- **Descripción**: Private SSH key para autenticación
- **Formato**: Contenido completo del archivo `id_ed25519` o `id_rsa`

---

## Cómo Configurar los Secrets

### Paso 1: Ir a Settings del Repositorio

1. Navega a: https://github.com/os-santiago/homedir-ai-sdlc/settings/secrets/actions
2. O desde el repo: `Settings` → `Secrets and variables` → `Actions`

### Paso 2: Add Repository Secret

Para cada secret:

#### VPS_HOST

1. Click **"New repository secret"**
2. **Name**: `VPS_HOST`
3. **Secret**: Pegar IP del VPS
   ```
   72.60.141.165
   ```
4. Click **"Add secret"**

#### VPS_USER

1. Click **"New repository secret"**
2. **Name**: `VPS_USER`
3. **Secret**: Pegar usuario SSH
   ```
   root
   ```
4. Click **"Add secret"**

#### VPS_SSH_KEY

1. **En tu máquina local**, obtén la private key:
   ```bash
   # Para WSL
   cat /home/scanales/.ssh/id_ed25519
   
   # O si usas RSA
   cat ~/.ssh/id_rsa
   ```

2. **Copiar TODO** el contenido del archivo (incluyendo `-----BEGIN` y `-----END`)

3. En GitHub:
   - Click **"New repository secret"**
   - **Name**: `VPS_SSH_KEY`
   - **Secret**: Pegar el contenido completo de la private key
   - Click **"Add secret"**

**Ejemplo de private key format:**
```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
...
(muchas líneas más)
...
AAAAFnNjYW5hbGVzQHNjYW5hbGVzLXAxNnYBAgME
-----END OPENSSH PRIVATE KEY-----
```

---

## Verificar Configuración

### 1. Check Secrets Configurados

1. Ir a: https://github.com/os-santiago/homedir-ai-sdlc/settings/secrets/actions
2. Deberías ver:
   ```
   VPS_HOST         (set)
   VPS_USER         (set)
   VPS_SSH_KEY      (set)
   ```

### 2. Trigger Workflow Manualmente

1. Ir a: https://github.com/os-santiago/homedir-ai-sdlc/actions/workflows/deploy-production.yml
2. Click **"Run workflow"**
3. Select branch: `main`
4. Click **"Run workflow"**

### 3. Verificar Deployment

El workflow debería:
1. ✅ Build worker container
2. ✅ Build dashboard container  
3. ✅ Deploy to VPS (ahora que los secrets están configurados)

---

## Troubleshooting

### Error: "missing server host"

**Causa**: Secret `VPS_HOST` no está configurado

**Solución**: Configurar el secret como se indica arriba

### Error: "Permission denied (publickey)"

**Causa**: 
- SSH key incorrecta
- Public key no está en `~/.ssh/authorized_keys` del VPS

**Solución**:

1. Verificar que la public key esté en el VPS:
   ```bash
   ssh root@72.60.141.165 "cat ~/.ssh/authorized_keys"
   ```

2. Si no está, agregarla:
   ```bash
   # En tu máquina local
   ssh-copy-id -i ~/.ssh/id_ed25519 root@72.60.141.165
   ```

3. Verificar que el secret en GitHub tenga la **private key** correcta

### Workflow Skip Deploy Step

**Causa**: Secrets no configurados, workflow salta el deploy

**Comportamiento**: 
- ✅ Build worker: Success
- ✅ Build dashboard: Success  
- ⏭️ Deploy VPS: Skipped

**Solución**: Configurar los 3 secrets requeridos

---

## Seguridad

### ⚠️ **IMPORTANTE**

1. **NUNCA comitear private keys al repo**
   - Los secrets de GitHub están encriptados y seguros
   - NO agregar keys a archivos de código

2. **Rotar keys periódicamente**
   - Regenerar SSH keys cada 6-12 meses
   - Actualizar el secret en GitHub

3. **Usar keys dedicadas**
   - Crear una key específica para CI/CD
   - NO usar tu personal SSH key

### Generar Key Dedicada para CI/CD

```bash
# Generar nueva key
ssh-keygen -t ed25519 -C "github-actions-cicd" -f ~/.ssh/id_ed25519_cicd

# Copiar public key al VPS
ssh-copy-id -i ~/.ssh/id_ed25519_cicd.pub root@72.60.141.165

# Usar la private key en GitHub Secret
cat ~/.ssh/id_ed25519_cicd
# → Copiar contenido a VPS_SSH_KEY secret
```

---

## Environment Protection (Opcional)

Para mayor seguridad, configurar environment protection:

1. Ir a: https://github.com/os-santiago/homedir-ai-sdlc/settings/environments
2. Click en `production`
3. Configurar:
   - ✅ **Required reviewers**: Agregar tu usuario
   - ✅ **Wait timer**: 0 minutos (o tiempo deseado)
   - ✅ **Deployment branches**: Only `main`

Esto requiere aprobación manual antes de cada deploy a producción.

---

## Next Steps

Después de configurar los secrets:

1. ✅ Push to main → Trigger CI/CD automático
2. ✅ Verify deployment en VPS
3. ✅ Setup inicial VPS (si no está hecho):
   ```bash
   bash scripts/vps-initial-setup.sh
   vim /etc/homedir-sdlc/worker.env  # Add GH_TOKEN, SC_API_KEY
   ```

---

## Referencias

- GitHub Encrypted Secrets: https://docs.github.com/en/actions/security-guides/encrypted-secrets
- SSH Key Generation: https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
- Deployment Guide: [containerized-deployment.md](containerized-deployment.md)
