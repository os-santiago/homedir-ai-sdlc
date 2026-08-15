# VPS Setup Instructions

One-time setup instructions for deploying the AI-SDLC worker on a VPS.

## Prerequisites

- VPS with Ubuntu 22.04+ or similar
- User account: `homedir-sdlc` (non-root)
- GitHub CLI installed
- SCC (Claude Code) installed
- Git installed
- Systemd user services enabled

## Setup Steps

### 1. Create State Directory

```bash
# Create directory structure
sudo mkdir -p /var/lib/homedir-sdlc/{logs,issues,prs,run-summaries}

# Set ownership
sudo chown -R homedir-sdlc:homedir-sdlc /var/lib/homedir-sdlc

# Set permissions
sudo chmod 755 /var/lib/homedir-sdlc
sudo chmod 755 /var/lib/homedir-sdlc/{logs,issues,prs,run-summaries}
```

### 2. Install Scripts

```bash
# Clone the repository
cd /tmp
git clone https://github.com/os-santiago/homedir-ai-sdlc.git
cd homedir-ai-sdlc

# Copy scripts to user bin
sudo -u homedir-sdlc mkdir -p /home/homedir-sdlc/.local/bin
sudo -u homedir-sdlc cp platform/scripts/*.sh /home/homedir-sdlc/.local/bin/
sudo -u homedir-sdlc chmod +x /home/homedir-sdlc/.local/bin/*.sh

# Copy config
sudo -u homedir-sdlc mkdir -p /home/homedir-sdlc/.local/share/homedir-sdlc
sudo -u homedir-sdlc cp platform/config/*.yaml /home/homedir-sdlc/.local/share/homedir-sdlc/
```

### 3. Configure Environment

```bash
# Create config directory
sudo -u homedir-sdlc mkdir -p /home/homedir-sdlc/.config/homedir-sdlc

# Copy environment template
sudo -u homedir-sdlc cp platform/env.sdlc.example \
  /home/homedir-sdlc/.config/homedir-sdlc/env

# Edit the env file to add secrets
sudo -u homedir-sdlc nano /home/homedir-sdlc/.config/homedir-sdlc/env
```

**Required secrets to add:**

- `GH_TOKEN` or configure with `gh auth login`
- SCC profile configuration (NVIDIA API key or other provider)

### 4. Install Systemd Services

```bash
# Create systemd user directory
sudo -u homedir-sdlc mkdir -p /home/homedir-sdlc/.config/systemd/user

# Copy service and timer
sudo -u homedir-sdlc cp platform/systemd/user/homedir-sdlc-worker.service \
  /home/homedir-sdlc/.config/systemd/user/

sudo -u homedir-sdlc cp platform/systemd/user/homedir-sdlc-worker.timer \
  /home/homedir-sdlc/.config/systemd/user/

# Reload systemd
sudo -u homedir-sdlc systemctl --user daemon-reload

# Enable lingering (allows user services to run without login)
sudo loginctl enable-linger homedir-sdlc

# Enable and start the timer
sudo -u homedir-sdlc systemctl --user enable --now homedir-sdlc-worker.timer
```

### 5. Verify Installation

```bash
# Check timer status
sudo -u homedir-sdlc systemctl --user status homedir-sdlc-worker.timer

# Check service status
sudo -u homedir-sdlc systemctl --user status homedir-sdlc-worker.service

# View logs
sudo tail -f /var/lib/homedir-sdlc/logs/worker.log

# Check heartbeat
sudo cat /var/lib/homedir-sdlc/heartbeat.json
```

### 6. Test Manual Execution

```bash
# Run one reconciliation cycle manually
sudo -u homedir-sdlc /home/homedir-sdlc/.local/bin/homedir-sdlc-worker.sh reconcile

# Verify logs
sudo tail -100 /var/lib/homedir-sdlc/logs/worker.log

# Check for errors
sudo grep -i error /var/lib/homedir-sdlc/logs/worker.log | tail -20
```

## Troubleshooting

### GitHub CLI Not Found

**Symptom:**
```
missing required command: gh
```

**Solution:**

1. Verify GitHub CLI is installed:
   ```bash
   sudo -u homedir-sdlc which gh
   ```

2. If installed but not in PATH, ensure systemd service has correct PATH:
   ```bash
   grep "Environment=PATH" /home/homedir-sdlc/.config/systemd/user/homedir-sdlc-worker.service
   ```

   Should include: `/home/homedir-sdlc/.local/bin`

3. Reload systemd:
   ```bash
   sudo -u homedir-sdlc systemctl --user daemon-reload
   sudo -u homedir-sdlc systemctl --user restart homedir-sdlc-worker.timer
   ```

### GitHub CLI Not Authenticated

**Symptom:**
```
GitHub CLI is not authenticated on this server
```

**Solution:**

Option 1 - Using `gh auth login`:
```bash
sudo -u homedir-sdlc gh auth login
```

Option 2 - Using environment variable:
```bash
# Add to /home/homedir-sdlc/.config/homedir-sdlc/env
export GH_TOKEN=ghp_your_token_here
```

### State Directory Permission Issues

**Symptom:**
```
Permission denied: /var/lib/homedir-sdlc/heartbeat.json
```

**Solution:**
```bash
# Fix ownership
sudo chown -R homedir-sdlc:homedir-sdlc /var/lib/homedir-sdlc

# Fix permissions
sudo chmod 755 /var/lib/homedir-sdlc
sudo find /var/lib/homedir-sdlc -type f -exec chmod 644 {} \;
sudo find /var/lib/homedir-sdlc -type d -exec chmod 755 {} \;
```

### Worker Not Running

**Symptom:**
Timer is active but service never runs.

**Solution:**

1. Check timer next execution:
   ```bash
   sudo -u homedir-sdlc systemctl --user list-timers
   ```

2. Manually trigger service:
   ```bash
   sudo -u homedir-sdlc systemctl --user start homedir-sdlc-worker.service
   ```

3. Check journal for errors:
   ```bash
   sudo -u homedir-sdlc journalctl --user -u homedir-sdlc-worker.service -n 50
   ```

## Updating the Worker

To update to a new version:

```bash
# Pull latest changes
cd /tmp/homedir-ai-sdlc
git pull origin main

# Copy updated scripts
sudo -u homedir-sdlc cp platform/scripts/*.sh /home/homedir-sdlc/.local/bin/
sudo -u homedir-sdlc chmod +x /home/homedir-sdlc/.local/bin/*.sh

# Copy updated config
sudo -u homedir-sdlc cp platform/config/*.yaml /home/homedir-sdlc/.local/share/homedir-sdlc/

# Copy updated systemd files
sudo -u homedir-sdlc cp platform/systemd/user/*.service \
  /home/homedir-sdlc/.config/systemd/user/
sudo -u homedir-sdlc cp platform/systemd/user/*.timer \
  /home/homedir-sdlc/.config/systemd/user/

# Reload and restart
sudo -u homedir-sdlc systemctl --user daemon-reload
sudo -u homedir-sdlc systemctl --user restart homedir-sdlc-worker.timer
```

## Monitoring

### Heartbeat

The worker updates a heartbeat file every cycle:

```bash
sudo cat /var/lib/homedir-sdlc/heartbeat.json
```

Expected fields:
- `repo`: Repository being processed
- `status`: Current status (idle, running, error)
- `detail`: Status details
- `updated_at`: ISO 8601 timestamp

**Alert if** `updated_at` is > 15 minutes old.

### Logs

Worker logs to `/var/lib/homedir-sdlc/logs/worker.log`:

```bash
# Tail logs
sudo tail -f /var/lib/homedir-sdlc/logs/worker.log

# Recent errors
sudo grep -i error /var/lib/homedir-sdlc/logs/worker.log | tail -20

# Recent activity
sudo grep -E "(Claimed|Created PR|Merged)" /var/lib/homedir-sdlc/logs/worker.log | tail -20
```

### Metrics

Key metrics to monitor:

1. **Heartbeat age**: Should be < 5 minutes
2. **Error rate**: Should be close to 0
3. **Issue throughput**: Issues processed per day
4. **PR success rate**: PRs that merge vs. need-human

## Security Notes

1. **Never commit secrets**: Store GH_TOKEN and API keys in environment file with mode 0600
2. **Least privilege**: Worker user should NOT have sudo access
3. **Isolate worktrees**: Worktrees are in `/home/homedir-sdlc/.local/share/homedir-sdlc/worktrees/`
4. **Audit logs**: Regularly review `/var/lib/homedir-sdlc/logs/` for anomalies

## References

- [Worker Script](../../platform/scripts/homedir-sdlc-worker.sh)
- [Environment Configuration](../../platform/env.sdlc.example)
- [Systemd Service](../../platform/systemd/user/homedir-sdlc-worker.service)
- [Issue #8](https://github.com/os-santiago/homedir-ai-sdlc/issues/8) - Deployment fixes
