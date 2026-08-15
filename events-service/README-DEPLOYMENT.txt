AI-SDLC Events Service - Deployment Summary
============================================

OPCION 1: Podman Pod (Recomendado)
-----------------------------------
Windows PowerShell:
  cd D:\git\homedir-ai-sdlc\events-service
  .\deployment\podman-pod-setup.ps1

Git Bash:
  cd /d/git/homedir-ai-sdlc/events-service
  chmod +x deployment/podman-pod-setup.sh
  ./deployment/podman-pod-setup.sh

Resultado:
  - Pod con PostgreSQL + AI-SDLC Service
  - Dashboard: http://localhost:8080/dashboard/

OPCION 2: Docker Compose
-------------------------
  docker compose up -d
  # o
  podman compose up -d

OPCION 3: Kubernetes
--------------------
  kubectl apply -f deployment/kubernetes/

DOCUMENTACION
-------------
- INSTALACION-PODMAN-POD.md   (Quick start)
- POD-DEPLOYMENT.md           (Documentación completa)
- QUICK-START.md              (Guía general)
- README.md                   (Overview del proyecto)

ARCHIVOS CREADOS
----------------
✓ deployment/podman-pod-setup.ps1       (Script PowerShell)
✓ deployment/podman-pod-setup.sh        (Script Bash)
✓ deployment/docker/Containerfile       (Imagen Podman/Docker)
✓ POD-DEPLOYMENT.md                     (Documentación)
✓ INSTALACION-PODMAN-POD.md            (Quick start)

SIGUIENTE PASO
--------------
Ejecutar:
  .\deployment\podman-pod-setup.ps1

Acceder:
  http://localhost:8080/dashboard/
