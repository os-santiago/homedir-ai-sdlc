#!/bin/bash
# Script para actualizar configuración VPS post PR #9
# Ejecutar como: ssh homedir-sdlc@72.60.141.165 'bash -s' < update-vps.sh

set -e

echo "=== Actualización VPS - PR #9 ==="
echo ""

echo "Paso 1: Pull latest changes"
cd /tmp
if [ ! -d homedir-ai-sdlc ]; then
  git clone https://github.com/os-santiago/homedir-ai-sdlc.git
fi
cd homedir-ai-sdlc
git pull origin main
echo "Commit actual: $(git log --oneline -1)"
echo ""

echo "Paso 2: Backup systemd service"
cp ~/.config/systemd/user/homedir-sdlc-worker.service \
   ~/.config/systemd/user/homedir-sdlc-worker.service.backup 2>/dev/null || echo "(sin backup previo)"
echo ""

echo "Paso 3: Copiar nuevo systemd service"
cp platform/systemd/user/homedir-sdlc-worker.service \
   ~/.config/systemd/user/
echo "✓ Service actualizado"
echo ""

echo "Paso 4: Verificar PATH en service"
grep "Environment=PATH" ~/.config/systemd/user/homedir-sdlc-worker.service
echo ""

echo "Paso 5: Actualizar env file (STATE_DIR)"
sed -i 's|HOMEDIR_SDLC_STATE_DIR=.*|HOMEDIR_SDLC_STATE_DIR=/var/lib/homedir-sdlc|' ~/.config/homedir-sdlc/env
sed -i 's|HOMEDIR_SDLC_LOGFILE=.*|HOMEDIR_SDLC_LOGFILE=/var/lib/homedir-sdlc/logs/worker.log|' ~/.config/homedir-sdlc/env
sed -i 's|HOMEDIR_SDLC_HEARTBEAT_FILE=.*|HOMEDIR_SDLC_HEARTBEAT_FILE=/var/lib/homedir-sdlc/heartbeat.json|' ~/.config/homedir-sdlc/env
sed -i 's|HOMEDIR_SDLC_OPENCLAW_LOGFILE=.*|HOMEDIR_SDLC_OPENCLAW_LOGFILE=/var/lib/homedir-sdlc/logs/openclaw-listener.log|' ~/.config/homedir-sdlc/env
echo "✓ ENV actualizado"
echo ""

echo "Paso 6: Verificar STATE_DIR en env"
grep HOMEDIR_SDLC_STATE_DIR ~/.config/homedir-sdlc/env
echo ""

echo "Paso 7: Reload systemd"
systemctl --user daemon-reload
echo "✓ Systemd reloaded"
echo ""

echo "Paso 8: Restart timer"
systemctl --user restart homedir-sdlc-worker.timer
echo "✓ Timer restarted"
echo ""

echo "Paso 9: Verificar timer status"
systemctl --user is-active homedir-sdlc-worker.timer
echo ""

echo "Paso 10: Verificar gh disponible"
which gh
gh --version | head -1
echo ""

echo "==================================="
echo "✅ ACTUALIZACIÓN COMPLETA"
echo "==================================="
echo ""
echo "Próximos pasos:"
echo "1. Esperar 3 minutos para el próximo ciclo"
echo "2. Verificar logs: sudo tail -50 /var/lib/homedir-sdlc/logs/worker.log"
echo "3. Verificar heartbeat: sudo cat /var/lib/homedir-sdlc/heartbeat.json"
echo "4. Buscar errores: sudo grep -i 'missing.*gh' /var/lib/homedir-sdlc/logs/worker.log"
