#!/bin/bash
set -euo pipefail

# We start setting up the HashiCorp Vault
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault -n vault --create-namespace --values ./scripts/setup_scripts/configuration_yamls/vault-config.yml >/dev/null

# Wait for Vault pod ready
kubectl wait --for=condition=ready pod/vault-0 -n vault --timeout=120s

echo "Vault ready -- It Can Be Accessed At http://localhost:8200"