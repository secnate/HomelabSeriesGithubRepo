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