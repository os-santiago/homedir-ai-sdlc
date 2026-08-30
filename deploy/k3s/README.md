# K3s Deployment - Lightweight Kubernetes for VPS

Deployment optimizado para VPS con recursos limitados usando K3s (Kubernetes ligero).

## 📊 Resource Comparison

### Full Kubernetes
- **Control Plane**: 1-2GB RAM, 1-2 vCPU
- **Worker Node**: 1GB+ RAM
- **Total Overhead**: ~2-3GB RAM, 2 vCPU
- **Minimum VPS**: 8GB RAM, 4 vCPU

### K3s (Lightweight)
- **Control Plane**: 512MB RAM, 0.5 vCPU
- **Total Overhead**: ~512MB RAM, 0.5 vCPU
- **Minimum VPS**: **4GB RAM, 2 vCPU** ✅

### Resource Allocation for AI-SDLC on 4GB VPS

```
Total Available: 4GB RAM, 2 vCPU
├─ K3s Control Plane: 512MB RAM, 0.5 vCPU
├─ Worker Container: 2GB RAM, 1 vCPU
├─ Dashboard Container: 512MB RAM, 0.3 vCPU
└─ System Reserved: 976MB RAM, 0.2 vCPU
```

---

## 🚀 Quick Install

### Option 1: Automated Script (Recommended)

```bash
# Download and run install script
curl -sfL https://raw.githubusercontent.com/os-santiago/homedir-ai-sdlc/main/deploy/k3s/install.sh | sh -
```

### Option 2: Manual Installation

```bash
# 1. Install K3s (lightweight Kubernetes)
curl -sfL https://get.k3s.io | sh -s - \
  --disable traefik \
  --disable servicelb \
  --write-kubeconfig-mode 644

# 2. Wait for K3s to be ready
sudo k3s kubectl wait --for=condition=Ready node --all --timeout=60s

# 3. Install AI-SDLC
sudo k3s kubectl apply -k https://github.com/os-santiago/homedir-ai-sdlc/deploy/k3s/manifests

# 4. Verify deployment
sudo k3s kubectl get pods -n homedir-ai-sdlc
```

---

## 📦 What's Different from Full K8s?

### Removed Components (Save Resources)

❌ Traefik (use Caddy instead - 10MB vs 50MB)  
❌ ServiceLB (use HostPort instead)  
❌ Cloud Controller  
❌ Multiple etcd replicas (use SQLite backend)  
❌ CoreDNS overhead (minimal config)  

### Optimizations

✅ **Single binary** - K3s is one 40MB binary  
✅ **SQLite backend** - No etcd overhead  
✅ **Minimal components** - Only essentials  
✅ **Aggressive resource limits** - Tuned for VPS  
✅ **Shared PVC** - Dashboard shares worker's PVC  

---

## 📁 Structure

```
deploy/k3s/
├── install.sh              # Automated installer
├── manifests/
│   ├── kustomization.yaml  # Kustomize config
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secrets.yaml
│   ├── worker-deployment.yaml
│   ├── worker-pvc.yaml
│   ├── dashboard-deployment.yaml
│   ├── dashboard-service.yaml
│   └── ingress.yaml
└── values/
    ├── vps-2cpu-4gb.yaml   # For 4GB VPS
    ├── vps-4cpu-8gb.yaml   # For 8GB VPS
    └── production.yaml     # For dedicated cluster
```

---

## ⚙️ Resource Profiles

### Profile: VPS 2vCPU / 4GB RAM (Recommended)

**File:** `values/vps-2cpu-4gb.yaml`

```yaml
worker:
  replicas: 1
  resources:
    requests:
      cpu: 250m      # 0.25 vCPU
      memory: 512Mi
    limits:
      cpu: "1"       # Max 1 vCPU
      memory: 2Gi

dashboard:
  replicas: 1
  resources:
    requests:
      cpu: 50m       # 0.05 vCPU
      memory: 128Mi
    limits:
      cpu: 300m      # Max 0.3 vCPU
      memory: 512Mi

persistence:
  state:
    size: 5Gi        # Reduced from 10Gi
  worktrees:
    size: 10Gi       # Reduced from 20Gi
```

**Total Usage:**
- Requests: 300m CPU / 640Mi RAM
- Limits: 1.3 CPU / 2.5Gi RAM
- **Fits comfortably in 4GB VPS**

### Profile: VPS 4vCPU / 8GB RAM (Comfortable)

**File:** `values/vps-4cpu-8gb.yaml`

```yaml
worker:
  replicas: 1
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: "2"
      memory: 4Gi

dashboard:
  replicas: 2        # HA with 2 replicas
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 1Gi
```

---

## 🔧 Installation Guide

### Prerequisites

- VPS with:
  - **Minimum**: 2 vCPU, 4GB RAM, 20GB disk
  - **Recommended**: 4 vCPU, 8GB RAM, 40GB disk
- Ubuntu 22.04 / Debian 11+ (or any systemd distro)
- Root or sudo access

### Step 1: Install K3s

```bash
# Install K3s with optimizations for VPS
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --disable traefik \
  --disable servicelb \
  --write-kubeconfig-mode 644 \
  --kube-apiserver-arg='--max-requests-inflight=100' \
  --kube-apiserver-arg='--max-mutating-requests-inflight=50'" sh -

# Verify installation
sudo k3s kubectl get nodes
```

### Step 2: Configure Secrets

```bash
# Create secrets
sudo k3s kubectl create namespace homedir-ai-sdlc

sudo k3s kubectl create secret generic ai-sdlc-secrets \
  --namespace homedir-ai-sdlc \
  --from-literal=gh-token="$GH_TOKEN" \
  --from-literal=nvidia-api-key="$NVIDIA_API_KEY"
```

### Step 3: Deploy AI-SDLC

**For 4GB VPS:**
```bash
# Clone repo
git clone https://github.com/os-santiago/homedir-ai-sdlc.git
cd homedir-ai-sdlc/deploy/k3s

# Apply manifests with 4GB profile
sudo k3s kubectl apply -k manifests/
```

**For 8GB VPS:**
```bash
# Use 8GB profile
sudo k3s kubectl apply -k manifests/ --set-file values/vps-4cpu-8gb.yaml
```

### Step 4: Setup Ingress (Caddy)

```bash
# Install Caddy (lightweight alternative to nginx-ingress)
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install caddy

# Configure Caddy
sudo tee /etc/caddy/Caddyfile << 'EOF'
homedir-ai-sdlc.opensourcesantiago.io {
    reverse_proxy localhost:30080
}
EOF

sudo systemctl restart caddy
```

### Step 5: Verify Deployment

```bash
# Check pods
sudo k3s kubectl get pods -n homedir-ai-sdlc

# Check logs
sudo k3s kubectl logs -n homedir-ai-sdlc -l app=worker -f

# Check heartbeat
sudo k3s kubectl exec -n homedir-ai-sdlc deploy/ai-sdlc-worker -- \
  cat /var/lib/homedir-sdlc/heartbeat.json
```

---

## 📊 Resource Monitoring

### Check Current Usage

```bash
# Node resources
sudo k3s kubectl top node

# Pod resources
sudo k3s kubectl top pods -n homedir-ai-sdlc

# System resources
free -h
htop
```

### Expected Usage on 4GB VPS

```
COMPONENT                CPU       MEMORY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
K3s Control Plane       100-200m   400-600Mi
ai-sdlc-worker          200-800m   500-1500Mi
ai-sdlc-dashboard       50-200m    150-400Mi
System                  100m       300Mi
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TOTAL                   450-1300m  1350-2800Mi
FREE                    ~700m      ~1200Mi
```

---

## 🔄 Migration from Podman

### Side-by-Side Migration (Zero Downtime)

```bash
# 1. Install K3s (doesn't conflict with Podman)
curl -sfL https://get.k3s.io | sh -

# 2. Deploy AI-SDLC to K3s on different port
sudo k3s kubectl apply -k deploy/k3s/manifests/
# Dashboard will be on :30080 (K3s) vs :8081 (Podman)

# 3. Test K3s deployment for 48 hours
# Podman continues on :8081
# K3s runs on :30080

# 4. Compare metrics
# - Issues processed
# - Success rate
# - Resource usage

# 5. Cutover: Update Caddy to point to K3s
sudo tee /etc/caddy/Caddyfile << 'EOF'
homedir-ai-sdlc.opensourcesantiago.io {
    reverse_proxy localhost:30080  # K3s instead of :8081
}
EOF

# 6. Stop Podman after validation
podman pod stop ai-sdlc
podman pod rm ai-sdlc

# 7. Cleanup
sudo systemctl disable podman.socket
```

---

## 💰 Cost Comparison

### Current Podman Setup

```
VPS: 4GB RAM, 2 vCPU
Cost: ~$10-15/month
Overhead: ~100MB RAM for Podman
Available: 3.9GB RAM
```

### K3s Setup

```
VPS: Same (4GB RAM, 2 vCPU)
Cost: ~$10-15/month (same VPS)
Overhead: ~512MB RAM for K3s
Available: ~3.5GB RAM
```

**Trade-off:**
- ❌ 400MB less RAM available
- ✅ Declarative infrastructure
- ✅ GitOps workflow
- ✅ Better monitoring
- ✅ Easier rollback
- ✅ Production-grade patterns

---

## 🎯 When to Use Each

### Use Podman (Current)
- ✅ Maximum resource efficiency
- ✅ Simple deployment
- ✅ Minimal overhead
- ✅ VPS < 4GB RAM

### Use K3s (This Deployment)
- ✅ VPS ≥ 4GB RAM
- ✅ Want GitOps workflow
- ✅ Need declarative infra
- ✅ Professional operations
- ✅ Team collaboration

### Use Full K8s (From PR #17)
- ✅ Dedicated cluster
- ✅ Multi-node setup
- ✅ High availability required
- ✅ Enterprise requirements

---

## 🐛 Troubleshooting

### K3s Won't Start

```bash
# Check logs
sudo journalctl -u k3s -f

# Common issue: Port conflict
sudo netstat -tlnp | grep :6443

# Fix: Stop conflicting service
sudo systemctl stop kubernetes
```

### Pods Stuck in Pending

```bash
# Check events
sudo k3s kubectl get events -n homedir-ai-sdlc --sort-by='.lastTimestamp'

# Common issue: PVC not binding
sudo k3s kubectl get pvc -n homedir-ai-sdlc

# Fix: K3s uses local-path provisioner by default
# No action needed, PVC should bind automatically
```

### Out of Memory

```bash
# Check memory usage
free -h
sudo k3s kubectl top pods -A

# Reduce limits in deployment
sudo k3s kubectl edit deployment -n homedir-ai-sdlc ai-sdlc-worker

# Set lower limits:
# limits:
#   memory: 1Gi  # Down from 2Gi
```

---

## 📈 Upgrade Path

### Current State
```
VPS → Podman → Containers
```

### After K3s Migration
```
VPS → K3s → Deployments → Pods
```

### Future: Multi-Node (Optional)
```
3x VPS → K3s Cluster → HA Setup
```

---

## 🔗 References

- **K3s Documentation**: https://docs.k3s.io/
- **K3s vs K8s**: https://k3s.io/#why-k3s
- **Resource Requirements**: https://docs.k3s.io/installation/requirements

---

**Recommendation:** Start with K3s on your current 4GB VPS. It provides the benefits of Kubernetes with minimal overhead.
