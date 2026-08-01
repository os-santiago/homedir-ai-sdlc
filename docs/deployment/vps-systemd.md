# Deployment VPS con Systemd

Guía completa para deployar el AI-SDLC worker en un VPS usando systemd timer.

## Prerequisitos

- VPS con Ubuntu 20.04+ o similar
- Usuario `homedir-sdlc` (o customizable)
- Acceso SSH configurado
- GitHub CLI (`gh`) instalado
- Git instalado
- jq instalado
- SCC (Software Construction Copilot) instalado

## Opción 1: Bootstrap Automático (Recomendado)

### Bootstrap con Sudo (System-wide)

```bash
curl -fsSL https://raw.githubusercontent.com/os-santiago/homedir-ai-sdlc/main/platform/scripts/homedir-sdlc-bootstrap.sh | sudo bash
```

Este script:
- Crea usuario `homedir-sdlc` si no existe
- Instala dependencias (gh, git, jq)
- Descarga scripts del worker
- Configura systemd units (system-wide)
- Habilita timer

### Bootstrap sin Sudo (User-owned)

Si no tienes acceso sudo:

```bash
curl -fsSL https://raw.githubusercontent.com/os-santiago/homedir-ai-sdlc/main/platform/scripts/homedir-sdlc-user-bootstrap.sh | bash
```

Este script:
- Instala en `~/.local/bin`
- Configura systemd user units
- No requiere sudo

## Opción 2: Deployment Manual

### 1. Crear Usuario

```bash
sudo useradd -m -s /bin/bash homedir-sdlc
sudo passwd homedir-sdlc  # Opcional, para login interactivo
```

### 2. Instalar Dependencias

```bash
# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update
sudo apt-get install gh git jq python3 build-essential -y

# SCC (Software Construction Copilot)
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
curl -L "https://github.com/anthropics/scc/releases/latest/download/scc-linux-${ARCH}" -o /tmp/scc
sudo mv /tmp/scc /usr/local/bin/scc
sudo chmod +x /usr/local/bin/scc
```

### 3. Clonar Repositorio y Copiar Scripts

```bash
sudo su - homedir-sdlc
mkdir -p ~/.local/bin ~/.local/state/homedir-sdlc ~/.local/share/homedir-sdlc

# Clonar repo temporalmente
cd /tmp
git clone https://github.com/os-santiago/homedir-ai-sdlc.git
cd homedir-ai-sdlc

# Copiar scripts
cp platform/scripts/homedir-sdlc-*.sh ~/.local/bin/
cp platform/scripts/sdlc-*.sh ~/.local/bin/
cp platform/scripts/policy-*.sh ~/.local/bin/
chmod +x ~/.local/bin/*.sh

# Copiar configuración
cp platform/config/autonomous-decision-policy.yaml ~/.local/share/homedir-sdlc/
cp platform/env.sdlc.example ~/.config/homedir-sdlc/env

# Limpiar
cd ~
rm -rf /tmp/homedir-ai-sdlc
```

### 4. Configurar Environment

Editar `~/.config/homedir-sdlc/env`:

```bash
mkdir -p ~/.config/homedir-sdlc
cat > ~/.config/homedir-sdlc/env << 'EOF'
# Repository
HOMEDIR_SDLC_REPO=os-santiago/homedir

# Labels
HOMEDIR_SDLC_TRIGGER_LABEL=ready-to-implement
HOMEDIR_SDLC_QUEUE_LABEL=scc-queued
HOMEDIR_SDLC_RUNNING_LABEL=scc-running
HOMEDIR_SDLC_PR_LABEL=scc-pr-open
HOMEDIR_SDLC_PR_TRACK_LABEL=ai-sdlc-track
HOMEDIR_SDLC_WAITING_CHECKS_LABEL=scc-waiting-checks
HOMEDIR_SDLC_FAILING_CHECKS_LABEL=scc-failing-checks
HOMEDIR_SDLC_APPROVED_LABEL=scc-approved
HOMEDIR_SDLC_MERGED_LABEL=scc-merged
HOMEDIR_SDLC_FAILED_LABEL=scc-failed
HOMEDIR_SDLC_NEEDS_HUMAN_LABEL=needs-human

# Paths
HOMEDIR_SDLC_WORKDIR=/srv/homedir-sdlc/worktrees/homedir
HOMEDIR_SDLC_STATE_DIR=/home/homedir-sdlc/.local/state/homedir-sdlc
HOMEDIR_SDLC_LOGFILE=/home/homedir-sdlc/.local/state/homedir-sdlc/logs/worker.log

# Worker Configuration
HOMEDIR_SDLC_MAX_ISSUES_PER_RUN=1
HOMEDIR_SDLC_MAX_REMEDIATION_ATTEMPTS=5
HOMEDIR_SDLC_PR_REVIEW_DELAY_SECONDS=600
HOMEDIR_SDLC_ENABLE_AUTOMERGE=false

# SCC
SCC_BIN=/usr/local/bin/scc
HOMEDIR_SDLC_SCC_TIMEOUT_SECONDS=1800
HOMEDIR_SDLC_SCC_PROFILE=nvidia
HOMEDIR_SDLC_SCC_CLEAR_HISTORY=true
HOMEDIR_SDLC_SCC_PERMISSIONS=unlimited

# GitHub Token (REQUIRED - set your token here)
GH_TOKEN=ghp_YOUR_TOKEN_HERE

# Alerts (optional)
HOMEDIR_SDLC_ALERTS_ENABLED=false
HOMEDIR_SDLC_ALERT_WEBHOOK_URL=
EOF
```

**IMPORTANTE**: Editar y configurar `GH_TOKEN` con un token válido de GitHub.

### 5. Crear Directorios de Estado

```bash
sudo mkdir -p /srv/homedir-sdlc/worktrees
sudo chown -R homedir-sdlc:homedir-sdlc /srv/homedir-sdlc

mkdir -p ~/.local/state/homedir-sdlc/{issues,prs,run-summaries,autonomous-decisions,logs}
```

### 6. Configurar Systemd Timer (User Service)

```bash
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/homedir-sdlc-worker.service << 'EOF'
[Unit]
Description=AI-SDLC Worker
After=network.target

[Service]
Type=oneshot
ExecStart=/home/homedir-sdlc/.local/bin/homedir-sdlc-worker.sh reconcile
EnvironmentFile=/home/homedir-sdlc/.config/homedir-sdlc/env
WorkingDirectory=/home/homedir-sdlc
StandardOutput=append:/home/homedir-sdlc/.local/state/homedir-sdlc/logs/worker.log
StandardError=append:/home/homedir-sdlc/.local/state/homedir-sdlc/logs/worker.log

[Install]
WantedBy=default.target
EOF

cat > ~/.config/systemd/user/homedir-sdlc-worker.timer << 'EOF'
[Unit]
Description=AI-SDLC Worker Timer
Requires=homedir-sdlc-worker.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=3min
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Reload y habilitar
systemctl --user daemon-reload
systemctl --user enable --now homedir-sdlc-worker.timer
```

### 7. Verificar Deployment

```bash
# Ver status del timer
systemctl --user status homedir-sdlc-worker.timer

# Ver últimos logs
journalctl --user -u homedir-sdlc-worker -f

# Verificar heartbeat
cat ~/.local/state/homedir-sdlc/heartbeat.json | jq '.'

# Ver issues elegibles
gh issue list -R os-santiago/homedir --label ready-to-implement
```

## Opción 3: Deployment con Ansible

Usar el playbook incluido:

```bash
cd ansible
ansible-playbook -i inventory.yml playbooks/sdlc-runner.yml \
  -e "gh_token=ghp_YOUR_TOKEN" \
  -e "target_repo=os-santiago/homedir"
```

## GitHub Actions Deployment

El workflow `.github/workflows/deploy-worker.yml` puede deployar automáticamente cuando hay push a main.

### Configurar Secrets

En GitHub: Settings → Secrets and variables → Actions

**Secrets necesarios**:
- `VPS_SSH_KEY` - Private SSH key para conectar al VPS
- `DEPLOY_SSH_KNOWN_HOSTS` - (Opcional) Known hosts del VPS

**Variables necesarias**:
- `VPS_HOST` - Hostname o IP del VPS
- `VPS_USER` - Usuario con permisos sudo (default: homedir-sdlc)
- `VPS_PORT` - Puerto SSH (default: 22)
- `WORKER_SSH_USER` - Usuario del worker (default: homedir-sdlc)

El workflow:
1. Valida configuración SSH
2. Copia scripts via SCP
3. Instala en `~/.local/bin` del usuario worker
4. Hace backup de versión anterior
5. Reinicia systemd service
6. Verifica deployment (busca fixes conocidos)

## Troubleshooting

### Worker no inicia

```bash
# Ver logs detallados
journalctl --user -u homedir-sdlc-worker --no-pager -n 100

# Verificar environment
cat ~/.config/homedir-sdlc/env

# Test manual
~/.local/bin/homedir-sdlc-worker.sh reconcile
```

### Sin heartbeat

```bash
# Verificar permisos
ls -la ~/.local/state/homedir-sdlc/

# Verificar lock file
ls -la ~/.local/state/homedir-sdlc/worker.lock

# Si está stuck, remover lock (CON CUIDADO)
rm ~/.local/state/homedir-sdlc/worker.lock
```

### Issues no se procesan

```bash
# Verificar labels existen
~/.local/bin/homedir-sdlc-labels.sh -R os-santiago/homedir

# Verificar admission
cat ~/.local/state/homedir-sdlc/issues/*.json | jq '.'

# Ver eligibilidad
~/.local/bin/homedir-sdlc-status.sh
```

### SCC falla

```bash
# Verificar SCC instalado
which scc
scc --version

# Verificar token
echo $GH_TOKEN | gh auth status

# Test SCC manual
cd /srv/homedir-sdlc/worktrees/homedir
scc "simple test"
```

## Diagnóstico

Ejecutar doctor script:

```bash
~/.local/bin/homedir-sdlc-doctor.sh
```

Genera reporte de:
- Estado del worker
- Configuración
- Dependencias
- Issues elegibles
- PRs abiertos
- Heartbeat age
- Locks

## Monitoreo

### Healthcheck Endpoint

Si dashboard está deployado:

```bash
curl http://localhost:8081/api/sdlc/heartbeat
curl http://localhost:8081/api/sdlc/status
```

### Métricas

```bash
# Issues procesados hoy
grep "Claimed issue" ~/.local/state/homedir-sdlc/logs/worker.log | grep "$(date +%Y-%m-%d)" | wc -l

# PRs creados
grep "Created PR" ~/.local/state/homedir-sdlc/logs/worker.log | grep "$(date +%Y-%m-%d)" | wc -l

# Errores
grep ERROR ~/.local/state/homedir-sdlc/logs/worker.log | tail -20
```

## Upgrade

### Manual

```bash
cd /tmp
git clone https://github.com/os-santiago/homedir-ai-sdlc.git
cd homedir-ai-sdlc

# Backup
cp ~/.local/bin/homedir-sdlc-worker.sh ~/.local/bin/homedir-sdlc-worker.sh.backup

# Update
cp platform/scripts/homedir-sdlc-*.sh ~/.local/bin/
chmod +x ~/.local/bin/*.sh

# Restart
systemctl --user restart homedir-sdlc-worker.service
```

### Via GitHub Actions

Push a main triggers automatic deployment si está configurado.

## Rollback

Si deployment falla:

```bash
# Restaurar backup
cp ~/.local/bin/homedir-sdlc-worker.sh.backup.YYYYMMDD_HHMMSS \
   ~/.local/bin/homedir-sdlc-worker.sh

# Restart
systemctl --user restart homedir-sdlc-worker.service
```

## Métricas de Éxito

- **Uptime**: >= 99%
- **Heartbeat age**: < 5 min
- **Issues/día**: 5-10
- **Tiempo E2E**: 16-20 min
- **Autonomía**: >= 95%

## Referencias

- [Worker script](../../platform/scripts/homedir-sdlc-worker.sh)
- [Bootstrap script](../../platform/scripts/homedir-sdlc-bootstrap.sh)
- [Doctor script](../../platform/scripts/homedir-sdlc-doctor.sh)
- [Status script](../../platform/scripts/homedir-sdlc-status.sh)
- [Autonomous SDLC model](../autonomous-sdlc.md)
- [CI Check Handling](../../platform/docs/ai-sdlc-ci-check-handling.md)
