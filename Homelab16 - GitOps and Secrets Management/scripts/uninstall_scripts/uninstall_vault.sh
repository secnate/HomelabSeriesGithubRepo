#!/bin/bash
set -euo pipefail

# We kill the port forwarding process
pkill -f "port-forward.*vault" || true

# We start uninstalling the HashiCorp Vault
helm uninstall vault -n vault

# And delete the namespace
kubectl delete namespace vault --timeout=60s
# And remove it from the repository
helm repo remove hashicorp