# GitHub Secrets Configuration

Para habilitar CI/CD automático, configura los siguientes secrets en GitHub.

## Ubicación

Repository: `homedir-ai-sdlc/events-service` (o el nombre correcto del repositorio)

**Settings** → **Secrets and variables** → **Actions** → **New repository secret**

---

## Secrets Requeridos

### 1. QUAY_TOKEN

**Nombre del secret**: `QUAY_TOKEN`

**Valor**:
```
R2X6GT18AXCNZOPEC7MCPORFHXJ8I9YAX7ZA2X9JDIJIU4C0PDBCP1XS6ISQ1TO6
```

**Descripción**: Robot account token para autenticación en Quay.io

**✅ NOTA**: Este secret ya está configurado en el repositorio.

---

## Variables Requeridas

**Settings** → **Secrets and variables** → **Actions** → **Variables** → **New repository variable**

### 1. QUAY_USERNAME

**Nombre de la variable**: `QUAY_USERNAME`

**Valor**:
```
os-santiago+homedir_deploy
```

**Descripción**: Nombre de usuario de la robot account en Quay.io

**✅ NOTA**: Esta variable ya está configurada en el repositorio.

---

## Estado Actual

✅ **QUAY_USERNAME** → Ya configurado  
✅ **QUAY_TOKEN** → Ya configurado

El CI/CD ya está listo para funcionar. No se requiere configuración adicional de secrets.

## Verificación

Puedes verificar el CI/CD:

1. Hacer un push a la rama `main`:
   ```bash
   git add .
   git commit -m "feat: test CI/CD pipeline"
   git push origin main
   ```

2. Ir a **Actions** en GitHub para ver el workflow en ejecución

3. El workflow debería:
   - ✅ Ejecutar tests
   - ✅ Build de la imagen
   - ✅ Push a `quay.io/sergio_canales_e/ai-sdlc-events:X.Y.Z`
   - ✅ Push a `ghcr.io/os-santiago/ai-sdlc-events:X.Y.Z`
   - ✅ Crear un tag git `vX.Y.Z`
   - ✅ Crear un GitHub Release

4. Verificar en Quay.io que la imagen fue pushed correctamente:
   https://quay.io/repository/sergio_canales_e/ai-sdlc-events

---

## Troubleshooting

### Error: "Invalid username or password"

- Verificar que `QUAY_USERNAME` sea exactamente: `os-santiago+homedir_deploy`
- Verificar que `QUAY_TOKEN` sea el token completo (60 caracteres)
- Verificar que el secret no tenga espacios al inicio o final

### Error: "Permission denied"

- Verificar que la robot account tenga permisos de **Write** en el repositorio `sergio_canales_e/ai-sdlc-events` en Quay.io
- Ir a Quay.io → Repository Settings → Robot Accounts y verificar permisos

### Logs del workflow

Para ver logs detallados:
1. GitHub → Actions → Seleccionar el workflow run
2. Expandir el step "Build and Push Container Image"
3. Verificar los logs de `docker push`

---

## Seguridad

⚠️ **IMPORTANTE**: Los tokens de robot accounts son credenciales sensibles.

- ✅ Usar siempre GitHub Secrets (nunca hardcodear en el código)
- ✅ La robot account solo tiene permisos para este repositorio específico
- ✅ GitHub Secrets están encriptados y solo visibles para el owner del repo
- ✅ Los logs de GitHub Actions enmascaran los valores de los secrets

---

## Información Adicional

**Robot Account**: `os-santiago+homedir_deploy`  
**Registry**: `quay.io`  
**Repository**: `sergio_canales_e/ai-sdlc-events`  
**Workflow File**: `.github/workflows/release.yml`

**Backup Registry**: GitHub Container Registry  
**GHCR Image**: `ghcr.io/os-santiago/ai-sdlc-events`
