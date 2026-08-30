#!/usr/bin/env bash
# Script to generate KUBECONFIG_K3S secret for GitHub Actions
# Run this on the VPS where K3s is installed

set -e

echo "=== Generating KUBECONFIG_K3S Secret ==="
echo ""

# Check if kubeconfig exists
if [[ ! -f ~/.kube/config ]]; then
  echo "ERROR: ~/.kube/config not found"
  echo "Make sure K3s is installed and configured"
  exit 1
fi

# Get current server URL
CURRENT_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
echo "Current server URL: $CURRENT_SERVER"
echo ""

# Ask for external server URL
read -p "Enter the external server URL (e.g., https://72.60.141.165:6443): " EXTERNAL_SERVER

if [[ -z "$EXTERNAL_SERVER" ]]; then
  echo "ERROR: Server URL cannot be empty"
  exit 1
fi

# Create temporary kubeconfig with external server
TEMP_CONFIG=$(mktemp)
cp ~/.kube/config "$TEMP_CONFIG"

# Replace server URL in temporary config
sed -i "s|$CURRENT_SERVER|$EXTERNAL_SERVER|g" "$TEMP_CONFIG"

echo ""
echo "=== Generated Kubeconfig (with external URL) ==="
cat "$TEMP_CONFIG"
echo ""

# Encode to base64 (single line)
ENCODED=$(cat "$TEMP_CONFIG" | base64 -w 0)

echo "=== Base64 Encoded (ready for GitHub Secret) ==="
echo ""
echo "$ENCODED"
echo ""

# Cleanup
rm "$TEMP_CONFIG"

echo ""
echo "=== Next Steps ==="
echo "1. Copy the base64 string above"
echo "2. Go to: https://github.com/os-santiago/homedir-ai-sdlc/settings/secrets/actions"
echo "3. Click 'New repository secret'"
echo "4. Name: KUBECONFIG_K3S"
echo "5. Value: Paste the base64 string"
echo "6. Click 'Add secret'"
echo ""
echo "Done! The workflow can now deploy to K3s."
