#!/bin/bash
set -euo pipefail

# Colors for nicer output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}===================================================================="
echo " Starting HashiCorp Vault setup"
echo "==================================================================="
echo -e "${NC}"

# Add Helm repo and install Vault
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update >/dev/null
helm install vault hashicorp/vault \
  -n vault \
  --create-namespace \
  --values ./vault/vault-config.yml >/dev/null

echo -e "${GREEN}→ Vault Helm chart installed. Waiting for pod to be ready...${NC}"

# Wait for Vault pod to be ready
kubectl wait --for=condition=ready pod/vault-0 -n vault --timeout=300s

echo -e "${GREEN}→ Vault pod is ready!${NC}"

# Start port-forward in background
kubectl port-forward svc/vault-ui 8200:8200 -n vault >/dev/null 2>&1 &

PF_PID=$!
echo -e "${YELLOW}→ Port-forward started in background (PID ${PF_PID}).${NC}"
echo -e "   Vault UI should now be available at: ${BLUE}http://localhost:8200${NC}"

# ──────────────────────────────────────────────────────────────────────────────
# Install Vault CLI locally (required for vault policy/auth/kv commands)
# ──────────────────────────────────────────────────────────────────────────────

echo -e "${GREEN}→ Installing HashiCorp Vault CLI locally...${NC}"

# Add official HashiCorp APT repository (idempotent)
if [ ! -f /etc/apt/sources.list.d/hashicorp.list ]; then
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
fi

sudo apt update -y >/dev/null

# Install Vault (latest version, or pin if needed)
sudo apt install -y vault

# Verify
if ! command -v vault >/dev/null 2>&1; then
  echo -e "${RED}Error: Vault CLI installation failed.${NC}"
  echo "Check logs or install manually: https://developer.hashicorp.com/vault/install"
  exit 1
fi

echo -e "${GREEN}→ Vault CLI installed: $(vault --version)${NC}"
echo

# ──────────────────────────────────────────────────────────────────────────────
# Interactive prompt for the user to add secrets manually into the vault
# ──────────────────────────────────────────────────────────────────────────────

echo
echo -e "${YELLOW}========================================================================${NC}"
echo -e "${YELLOW} NEXT STEP: Add demo secrets to Vault manually (via browser)${NC}"
echo -e "${YELLOW}========================================================================${NC}"
echo
echo -e "1. Open your browser and go to: ${BLUE}http://localhost:8200${NC}"
echo -e "2. Log in using the initial root token (find it with):"
echo -e "   ${GREEN}kubectl get secret vault-init -n vault -o jsonpath='{.data.root_token}' | base64 -d${NC}"
echo
echo -e "3. Once logged in, go to ${BLUE}Secrets Engines → Enable new engine → KV${NC}"
echo -e "   - Path: ${GREEN}secret${NC} (or whatever path you prefer)"
echo -e "   - Version: 2"
echo
echo -e "4. Create these secrets (use fake/test values):"
echo -e "   Path: ${GREEN}secret/apps/hello-world${NC}"
echo -e "     - Key: ${YELLOW}API_KEY${NC}            Value: sk_live_abc123xyz789"
echo -e "     - Key: ${YELLOW}DATABASE_PASSWORD${NC}  Value: MySuperSecureDbPass2025!"
echo -e "     - Key: ${YELLOW}STRIPE_SECRET_KEY${NC}  Value: sk_test_51N..."
echo
echo -e "   Path: ${GREEN}secret/apps/hello-world/config${NC}"
echo -e "     - Key: ${YELLOW}APP_ENV${NC}            Value: production"
echo -e "     - Key: ${YELLOW}FEATURE_FLAG_BETA${NC}  Value: true"
echo
echo -e "${RED}Important:${NC} Write down or remember the values — you wll need them to verify"
echo -e "           injection later in the demo."
echo
echo -e "${YELLOW}When you have finished adding all secrets in the Vault UI, come back here${NC}"
echo -e "${YELLOW}and press Enter to continue.${NC}"

# Pause script until user presses Enter
read -r -p "Press Enter when secrets are added..."

echo -e "${GREEN}→ Continuing setup...${NC}"