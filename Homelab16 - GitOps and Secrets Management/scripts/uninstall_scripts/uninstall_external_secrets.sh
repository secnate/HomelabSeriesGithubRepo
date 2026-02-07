#!/bin/bash
set -euo pipefail

# Uninstall External Secrets Operator
helm uninstall external-secrets -n external-secrets || true

# Delete all External Secrets custom resources first (if any exist)
kubectl delete externalsecrets --all --all-namespaces || true
kubectl delete secretstores --all --all-namespaces || true
kubectl delete clustersecretstores --all || true

# Delete the namespace (this removes all remaining resources)
kubectl delete namespace external-secrets --timeout=60s || true

# Optional: Remove the helm repo
helm repo remove external-secrets || true