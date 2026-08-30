# KUBECONFIG_K3S Secret Setup

## Kubeconfig Modificado (Listo para Usar)

El kubeconfig del VPS con la IP pública configurada:

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJkekNDQVIyZ0F3SUJBZ0lCQURBS0JnZ3Foa2pPUFFRREFqQWpNU0V3SHdZRFZRUUREQmhyTTNNdGMyVnkKZG1WeUxXTmhRREUzT0RjME5EVXdPRFF3SGhjTk1qWXdPREl5TWpNek1USTBXaGNOTXpZd09ERTVNak16TVRJMApXakFqTVNFd0h3WURWUVFEREJock0zTXRjMlZ5ZG1WeUxXTmhRREUzT0RjME5EVXdPRFF3V1RBVEJnY3Foa2pPClBRSUJCZ2dxaGtqT1BRTUJCd05DQUFReEU3OFVEb0ZLTjZvdzRDNkcvY2ZlZ3N1aHVGK1prOVBuOVFuOXJPS28KYTd2eHVEY0J1cU1aVGZnVFVFeERRSXJvTGd1RGl3WHdtUGdDRk8zM1JNTURvMEl3UURBT0JnTlZIUThCQWY4RQpCQU1DQXFRd0R3WURWUjBUQVFIL0JBVXdBd0VCL3pBZEJnTlZIUTRFRmdRVVdTcXRJcDNEcm5CM3I1RVZySUFOCmxnTkV6RTR3Q2dZSUtvWkl6ajBFQXdJRFNBQXdSUUloQVBzNTk3K3ArcWFiUkhjNlNRQTVjaUJrRXBkSy91SVgKRUppdW9ISTJrS2RRQWlBRThFbWVQblhKRzJwTzlJbUNua0o4d1NEeEhSSWdmSW9ZSmV1eWZraUp5QT09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
    server: https://72.60.141.165:6443
  name: default
contexts:
- context:
    cluster: default
    user: default
  name: default
current-context: default
kind: Config
users:
- name: default
  user:
    client-certificate-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJrRENDQVRlZ0F3SUJBZ0lJVForTVpienpobGN3Q2dZSUtvWkl6ajBFQXdJd0l6RWhNQjhHQTFVRUF3d1kKYXpOekxXTnNhV1Z1ZEMxallVQXhOemczTkRRMU1EZzBNQjRYRFRJMk1EZ3lNakl6TXpFeU5Gb1hEVEkzTURneQpNakl6TXpFeU5Gb3dNREVYTUJVR0ExVUVDaE1PYzNsemRHVnRPbTFoYzNSbGNuTXhGVEFUQmdOVkJBTVRESE41CmMzUmxiVHBoWkcxcGJqQlpNQk1HQnlxR1NNNDlBZ0VHQ0NxR1NNNDlBd0VIQTBJQUJPQXV0N2w3bWp6endNMFYKdXo2RllLNGhxSXp3SHBwWWZEOXNEbjhWd3VFSG90OHYraTEyNTdaZEp3WnRSQkN5MElDamdrSFNTbUdTa2xaRgp5ajdGRVBlalNEQkdNQTRHQTFVZER3RUIvd1FFQXdJRm9EQVRCZ05WSFNVRUREQUtCZ2dyQmdFRkJRY0RBakFmCkJnTlZIU01FR0RBV2dCVDFGWTRVUkprTWs0STIyK1dwdEE4Sk43SmJjVEFLQmdncWhrak9QUVFEQWdOSEFEQkUKQWlCRzk3bkpmeVZVN3lKM29MMWpBTUpXdmdGVjg1WjVKN3ZRUjViSE5USlZEUUlnWkN4THY1N3cwVkFhQ2JsVwpSUFdMenUxN3lqM2FLdkk2S3dqU2FyOG5YYWc9Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0KLS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJkakNDQVIyZ0F3SUJBZ0lCQURBS0JnZ3Foa2pPUFFRREFqQWpNU0V3SHdZRFZRUUREQmhyTTNNdFkyeHAKWlc1MExXTmhRREUzT0RjME5EVXdPRFF3SGhjTk1qWXdPREl5TWpNek1USTBXaGNOTXpZd09ERTVNak16TVRJMApXakFqTVNFd0h3WURWUVFEREJock0zTXRZMnhwWlc1MExXTmhRREUzT0RjME5EVXdPRFF3V1RBVEJnY3Foa2pPClBRSUJCZ2dxaGtqT1BRTUJCd05DQUFUYkhwVW12dFJGeVRxdVJMRzA3NDc2ZW5DalRDVkpBeTJHY24wN2Y1dmcKMkRDL0kxWWt1M3ZwbVZsQXpBaFdhNGNDV20xSFFTY1NXa2l1aExsNFg5YzFvMEl3UURBT0JnTlZIUThCQWY4RQpCQU1DQXFRd0R3WURWUjBUQVFIL0JBVXdBd0VCL3pBZEJnTlZIUTRFRmdRVTlSV09GRVNaREpPQ050dmxxYlFQCkNUZXlXM0V3Q2dZSUtvWkl6ajBFQXdJRFJ3QXdSQUlnZk9FNStYd1JYZVZXVE5xeVdYZnpGNFJRT3MzM3JvTngKdlg0VmppdWJvK3NDSURMQ0k0aWlSQnBpamZxL2UxYWxXVE1nSXFnTTMrb1ZNRjNiYW5YV3Vkb2wKLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
    client-key-data: LS0tLS1CRUdJTiBFQyBQUklWQVRFIEtFWS0tLS0tCk1IY0NBUUVFSU44c0liQ3NCZ2RJUG1MaTJDaGpUWngzV1hkV2llVmZXQXRRblF5Zm9ONDdvQW9HQ0NxR1NNNDkKQXdFSG9VUURRZ0FFNEM2M3VYdWFQUFBBelJXN1BvVmdyaUdvalBBZW1saDhQMndPZnhYQzRRZWkzeS82TFhibgp0bDBuQm0xRUVMTFFnS09DUWRKS1laS1NWa1hLUHNVUTl3PT0KLS0tLS1FTkQgRUMgUFJJVkFURSBLRVktLS0tLQo=
```

## Opción 1: CLI (Más Fácil)

### Paso 1: Guardar en Archivo Temporal

Guarda el YAML de arriba en: `C:\temp\k3s-kubeconfig.yaml`

### Paso 2: Crear Secret con gh CLI

```bash
cd D:/git/homedir-ai-sdlc

# Método A: Base64 automático (recomendado)
cat C:/temp/k3s-kubeconfig.yaml | base64 -w 0 | gh secret set KUBECONFIG_K3S

# Método B: Dejar que gh secret haga el encoding
gh secret set KUBECONFIG_K3S < C:/temp/k3s-kubeconfig.yaml
```

### Paso 3: Verificar

```bash
gh secret list | grep KUBECONFIG
```

Deberías ver:
```
KUBECONFIG_K3S    2026-08-25...
```

---

## Opción 2: Web UI

### Paso 1: Codificar a Base64

Usa este sitio (o comando local):
https://www.base64encode.org/

Pega el YAML completo de arriba y copia el resultado base64.

### Paso 2: Agregar en GitHub

1. Ir a: https://github.com/os-santiago/homedir-ai-sdlc/settings/secrets/actions
2. Click "New repository secret"
3. Name: `KUBECONFIG_K3S`
4. Value: Pegar el base64
5. Click "Add secret"

---

## Verificación Post-Setup

Después de crear el secret:

```bash
# Listar todos los secrets
gh secret list

# Deberías ver estos 3:
# GH_TOKEN         ✓
# NVIDIA_API_KEY   ✓
# KUBECONFIG_K3S   ✓
```

---

## Test del Workflow

Una vez configurado el secret:

1. Merge PR #21 (`feat/k3s-secrets-deployment`)
2. El workflow `.github/workflows/deploy-k3s.yml` se ejecutará automáticamente
3. Verificar en Actions: https://github.com/os-santiago/homedir-ai-sdlc/actions

---

## Troubleshooting

### Secret no funciona

Verificar que:
- Base64 es correcto (sin saltos de línea extra)
- Server URL es `https://72.60.141.165:6443` (no 127.0.0.1)
- Certificates no fueron modificados

### Workflow falla en kubectl

Error típico: `unable to connect to server`

Verificar:
- Puerto 6443 abierto en firewall del VPS
- K3s corriendo: `ssh root@72.60.141.165 "kubectl get nodes"`
- IP correcta en el kubeconfig

---

**Listo para usar!** Una vez creado el secret, el workflow puede deployar automáticamente a K3s.
