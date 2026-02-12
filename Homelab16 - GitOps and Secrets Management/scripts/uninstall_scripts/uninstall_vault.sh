#!/bin/bash
set -euo pipefail

# Kill any kubectl port-forward processes targeting vault-ui in namespace vault
# This port forwarding was done initially because of issues getting access to the
# Hashicorp Vault in the computer browser at the https://localhost:8200 IP address
pkill -f "kubectl port-forward.*svc/vault-ui.*-n vault" || true

# We start uninstalling the HashiCorp Vault
helm uninstall vault -n vault

# And delete the namespace
kubectl delete namespace vault --timeout=60s
# And remove it from the repository
helm repo remove hashicorp

# ──────────────────────────────────────────────────────────────────────────────
# Uninstall Vault CLI (local binary only)
# ──────────────────────────────────────────────────────────────────────────────

echo "→ Uninstalling Vault CLI (local binary)..."

if command -v vault >/dev/null 2>&1; then
  sudo apt purge -y vault >/dev/null 2>&1 || true
  sudo apt autoremove -y >/dev/null 2>&1 || true
  
  # Remove repo file if no other HashiCorp tools are used
  sudo rm -f /etc/apt/sources.list.d/hashicorp.list >/dev/null 2>&1 || true
  sudo rm -f /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null 2>&1 || true
  sudo apt update -y >/dev/null 2>&1 || true
  
  if command -v vault >/dev/null 2>&1; then
    echo "  Warning: Vault CLI still present — manual removal may be needed."
  else
    echo "  Vault CLI successfully removed."
  fi
else
  echo "  Vault CLI was not installed locally — skipping."
fi

echo