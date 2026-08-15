# Manual VPS Update - Post PR #9 Merge

## Instrucciones para ejecutar MANUALMENTE en el VPS

El PR #9 ha sido merged exitosamente. Ahora necesitas aplicar los cambios en el VPS.

### Paso 1: SSH al VPS

```bash
ssh homedir-sdlc@72.60.141.165
```

### Paso 2: Crear directorio /var/lib/homedir-sdlc (como root)

```bash
# Cambiar a root temporalmente
sudo su -

# Crear directorio
mkdir -p /var/lib/homedir-sdlc/{logs,issues,prs,run-summaries}
chown -R homedir-sdlc:homedir-sdlc /var/lib/homedir-sdlc
chmod 755 /var/lib/homedir-sdlc
chmod 755 /var/lib/homedir-sdlc/{logs,issues,prs,run-summaries}

# Verificar
ls -la /var/lib/ | grep homedir-sdlc

# Salir de root
exit
```

### Paso 3: Pull latest changes (como homedir-sdlc)

```bash
# Clonar repo si no existe
cd /tmp
if [ ! -d homedir-ai-sdlc ]; then
  git clone https://github.com/os-santiago/homedir-ai-sdlc.git
fi
cd homedir-ai-sdlc

# Pull latest
git pull origin main

# Verificar que estamos en el commit correcto
git log --oneline -1
# Debe mostrar: bcb86fe Fix worker deployment configuration (#9)
```

### Paso 4: Actualizar systemd service

```bash
# Backup del service actual
cp ~/.config/systemd/user/homedir-sdlc-worker.service \
   ~/.config/systemd/user/homedir-sdlc-worker.service.backup

# Copiar nuevo service
cp platform/systemd/user/homedir-sdlc-worker.service \
   ~/.config/systemd/user/

# Verificar que tiene PATH correcto
grep "Environment=PATH" ~/.config/systemd/user/homedir-sdlc-worker.service
```

**Salida esperada:**
```
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
```

### Paso 5: Actualizar env file

```bash
# Actualizar STATE_DIR paths (preservando secrets)
sed -i 's|HOMEDIR_SDLC_STATE_DIR=.*|HOMEDIR_SDLC_STATE_DIR=/var/lib/homedir-sdlc|' \
  ~/.config/homedir-sdlc/env

sed -i 's|HOMEDIR_SDLC_LOGFILE=.*|HOMEDIR_SDLC_LOGFILE=/var/lib/homedir-sdlc/logs/worker.log|' \
  ~/.config/homedir-sdlc/env

sed -i 's|HOMEDIR_SDLC_HEARTBEAT_FILE=.*|HOMEDIR_SDLC_HEARTBEAT_FILE=/var/lib/homedir-sdlc/heartbeat.json|' \
  ~/.config/homedir-sdlc/env

sed -i 's|HOMEDIR_SDLC_OPENCLAW_LOGFILE=.*|HOMEDIR_SDLC_OPENCLAW_LOGFILE=/var/lib/homedir-sdlc/logs/openclaw-listener.log|' \
  ~/.config/homedir-sdlc/env

# Verificar cambios
grep -E "HOMEDIR_SDLC_(STATE_DIR|LOGFILE|HEARTBEAT)" ~/.config/homedir-sdlc/env
```

**Salida esperada:**
```
export HOMEDIR_SDLC_STATE_DIR=/var/lib/homedir-sdlc
export HOMEDIR_SDLC_LOGFILE=/var/lib/homedir-sdlc/logs/worker.log
export HOMEDIR_SDLC_HEARTBEAT_FILE=/var/lib/homedir-sdlc/heartbeat.json
export HOMEDIR_SDLC_OPENCLAW_LOGFILE=/var/lib/homedir-sdlc/logs/openclaw-listener.log
```

### Paso 6: Reload systemd

```bash
systemctl --user daemon-reload
```

### Paso 7: Restart timer

```bash
systemctl --user restart homedir-sdlc-worker.timer
```

### Paso 8: Verificar status

```bash
# Timer status
systemctl --user status homedir-sdlc-worker.timer

# Debe mostrar:
# ● homedir-sdlc-worker.timer - HomeDir autonomous SDLC worker timer
#      Loaded: loaded (/home/homedir-sdlc/.config/systemd/user/homedir-sdlc-worker.service)
#      Active: active (waiting)
```

### Paso 9: Verificar que gh funciona

```bash
# Verificar que gh está en PATH
which gh
# Debe mostrar: /home/homedir-sdlc/.local/bin/gh

gh --version
# Debe mostrar: gh version 2.x.x
```

### Paso 10: Test manual del worker

```bash
# Ejecutar un ciclo de reconciliation manualmente
~/.local/bin/homedir-sdlc-worker.sh reconcile
```

Verificar en los logs que **NO** aparezca el error:
```
missing required command: gh
```

### Paso 11: Verificar logs después de 5 minutos

```bash
# Ver últimos logs
sudo tail -50 /var/lib/homedir-sdlc/logs/worker.log

# Buscar errores
sudo grep -i error /var/lib/homedir-sdlc/logs/worker.log | tail -10

# Verificar heartbeat
sudo cat /var/lib/homedir-sdlc/heartbeat.json
```

## Verificación de Éxito

✅ **Éxito si:**
1. Timer está activo
2. No hay errores "missing gh" en logs
3. Heartbeat se actualiza cada 3 minutos
4. Worker procesa issues correctamente

❌ **Falla si:**
1. Aparece "missing required command: gh"
2. Heartbeat no se actualiza
3. Worker no procesa issues

## Troubleshooting

### Problema: "missing required command: gh"

```bash
# Verificar que PATH está en service
grep "Environment=PATH" ~/.config/systemd/user/homedir-sdlc-worker.service

# Si no está, copiar de nuevo
cp /tmp/homedir-ai-sdlc/platform/systemd/user/homedir-sdlc-worker.service \
   ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user restart homedir-sdlc-worker.timer
```

### Problema: Heartbeat no se actualiza

```bash
# Verificar que STATE_DIR es correcto
grep HOMEDIR_SDLC_STATE_DIR ~/.config/homedir-sdlc/env

# Verificar permisos
sudo ls -la /var/lib/homedir-sdlc/
sudo ls -la /var/lib/homedir-sdlc/heartbeat.json

# Si permisos incorrectos
sudo chown homedir-sdlc:homedir-sdlc /var/lib/homedir-sdlc/heartbeat.json
sudo chmod 644 /var/lib/homedir-sdlc/heartbeat.json
```

## Próximo Paso

Una vez verificado que el worker funciona correctamente, el siguiente paso es:
1. Marcar issue #8 como resuelto
2. Procesar el issue real más antiguo (#1448 - Reputation Hub text centering)
3. Verificar que el flujo E2E funciona

## Referencias

- Issue #8: https://github.com/os-santiago/homedir-ai-sdlc/issues/8
- PR #9: https://github.com/os-santiago/homedir-ai-sdlc/pull/9
- Docs: `docs/deployment/vps-setup.md`
