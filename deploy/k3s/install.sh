#!/usr/bin/env bash
# K3s Installation Script for AI-SDLC on VPS
# Optimized for 4GB RAM / 2 vCPU VPS

set -e

echo "================================================"
echo "AI-SDLC K3s Installation (VPS Optimized)"
echo "================================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root or with sudo"
  exit 1
fi

# Check minimum requirements
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -lt 3500 ]; then
  echo "⚠️  Warning: Only ${TOTAL_RAM}MB RAM detected"
  echo "   Minimum recommended: 4GB (4096MB)"
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Install K3s
echo "📦 Installing K3s (lightweight Kubernetes)..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --disable traefik \
  --disable servicelb \
  --write-kubeconfig-mode 644 \
  --kube-apiserver-arg='--max-requests-inflight=100' \
  --kube-apiserver-arg='--max-mutating-requests-inflight=50'" sh -

# Wait for K3s to be ready
echo "⏳ Waiting for K3s to be ready..."
sleep 10
k3s kubectl wait --for=condition=Ready node --all --timeout=60s

# Create namespace
echo "📁 Creating namespace..."
k3s kubectl create namespace homedir-ai-sdlc || true

# Create secrets
echo "🔐 Configuring secrets..."
echo ""
echo "Please provide your credentials:"
read -p "GitHub Token (GH_TOKEN): " GH_TOKEN
read -p "Nvidia API Key (NVIDIA_API_KEY): " NVIDIA_API_KEY

k3s kubectl create secret generic ai-sdlc-secrets \
  --namespace homedir-ai-sdlc \
  --from-literal=gh-token="$GH_TOKEN" \
  --from-literal=nvidia-api-key="$NVIDIA_API_KEY" \
  --dry-run=client -o yaml | k3s kubectl apply -f -

# Deploy AI-SDLC
echo "🚀 Deploying AI-SDLC..."
MANIFEST_URL="https://raw.githubusercontent.com/os-santiago/homedir-ai-sdlc/main/deploy/k3s/manifests"

k3s kubectl apply -f "$MANIFEST_URL/namespace.yaml"
k3s kubectl apply -f "$MANIFEST_URL/configmap.yaml"
k3s kubectl apply -f "$MANIFEST_URL/worker-pvc.yaml"
k3s kubectl apply -f "$MANIFEST_URL/worker-deployment.yaml"
k3s kubectl apply -f "$MANIFEST_URL/dashboard-deployment.yaml"
k3s kubectl apply -f "$MANIFEST_URL/dashboard-service.yaml"

# Wait for deployments
echo "⏳ Waiting for deployments to be ready..."
k3s kubectl rollout status deployment/ai-sdlc-worker -n homedir-ai-sdlc --timeout=300s
k3s kubectl rollout status deployment/ai-sdlc-dashboard -n homedir-ai-sdlc --timeout=300s

# Setup Caddy reverse proxy
echo "🌐 Setting up Caddy reverse proxy..."
if ! command -v caddy &> /dev/null; then
  echo "Installing Caddy..."
  apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
  apt update && apt install -y caddy
fi

read -p "Enter your domain (e.g., homedir-ai-sdlc.example.com): " DOMAIN

cat > /etc/caddy/Caddyfile << EOF
$DOMAIN {
    reverse_proxy localhost:30080
}
EOF

systemctl restart caddy
systemctl enable caddy

# Show status
echo ""
echo "================================================"
echo "✅ Installation Complete!"
echo "================================================"
echo ""
echo "📊 Status:"
k3s kubectl get pods -n homedir-ai-sdlc
echo ""
echo "🌐 Dashboard: https://$DOMAIN"
echo ""
echo "📝 Useful commands:"
echo "  - View logs: k3s kubectl logs -n homedir-ai-sdlc -l app=worker -f"
echo "  - Check heartbeat: k3s kubectl exec -n homedir-ai-sdlc deploy/ai-sdlc-worker -- cat /var/lib/homedir-sdlc/heartbeat.json"
echo "  - View dashboard: k3s kubectl get svc -n homedir-ai-sdlc"
echo ""
echo "💡 Tip: Add alias to ~/.bashrc:"
echo "  echo 'alias kubectl=\"k3s kubectl\"' >> ~/.bashrc"
echo ""
