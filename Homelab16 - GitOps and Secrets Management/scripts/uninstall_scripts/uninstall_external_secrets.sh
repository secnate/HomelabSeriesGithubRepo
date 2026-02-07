#!/bin/bash
set -euo pipefail

# We uninstall External Secrets
#kubectl get SecretStores,ClusterSecretStores,ExternalSecrets --all-namespaces
#helm delete external-secrets --namespace external-secrets