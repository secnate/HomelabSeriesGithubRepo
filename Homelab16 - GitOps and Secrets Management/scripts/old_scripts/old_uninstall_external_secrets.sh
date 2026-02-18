#!/bin/bash
set -euo pipefail

# Colors for nicer output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}===================================================================="
echo " Uninstalling External Secrets Operator and cleanup"
echo "===================================================================="
echo -e "${NC}"

# ══════════════════════════════════════════════════════════════════════════════
# DELETE EXTERNAL SECRET RESOURCES IN APP NAMESPACE
# ══════════════════════════════════════════════════════════════════════════════
# Delete ExternalSecret and SecretStore resources before uninstalling ESO
# This ensures clean deletion and prevents dangling resources
# ══════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}→ Deleting ExternalSecret and SecretStore resources in 'app' namespace...${NC}"

# Delete ExternalSecret
if kubectl get externalsecret hello-world-secrets -n app >/dev/null 2>&1; then
  echo -e "${BLUE}  → Deleting ExternalSecret 'hello-world-secrets'...${NC}"
  kubectl delete externalsecret hello-world-secrets -n app --timeout=30s 2>/dev/null || true
else
  echo -e "${BLUE}  → ExternalSecret 'hello-world-secrets' not found. Skipping.${NC}"
fi

# Delete SecretStore
if kubectl get secretstore vault-backend -n app >/dev/null 2>&1; then
  echo -e "${BLUE}  → Deleting SecretStore 'vault-backend'...${NC}"
  kubectl delete secretstore vault-backend -n app --timeout=30s 2>/dev/null || true
else
  echo -e "${BLUE}  → SecretStore 'vault-backend' not found. Skipping.${NC}"
fi

# Delete the synced Kubernetes Secret
if kubectl get secret hello-world-secrets -n app >/dev/null 2>&1; then
  echo -e "${BLUE}  → Deleting Kubernetes Secret 'hello-world-secrets'...${NC}"
  kubectl delete secret hello-world-secrets -n app --timeout=30s 2>/dev/null || true
else
  echo -e "${BLUE}  → Kubernetes Secret 'hello-world-secrets' not found. Skipping.${NC}"
fi

echo -e "${GREEN}  → External Secret resources cleaned up.${NC}"
echo

# ══════════════════════════════════════════════════════════════════════════════
# VAULT CLEANUP (if Vault is still running)
# ══════════════════════════════════════════════════════════════════════════════
# Delete Vault role, policy, and optionally disable Kubernetes auth
# Note: If Vault was already uninstalled, this section will be skipped
# ══════════════════════════════════════════════════════════════════════════════

if kubectl get namespace vault >/dev/null 2>&1; then
  echo -e "${YELLOW}→ Vault namespace found. Cleaning up Vault-side configurations...${NC}"
  
  if kubectl get pod vault-0 -n vault >/dev/null 2>&1; then
    # Delete the Vault role (match the name created in setup)
    echo -e "${BLUE}  → Deleting Vault Kubernetes auth role 'demo-role'...${NC}"
    kubectl exec vault-0 -n vault -- vault delete auth/kubernetes/role/demo-role 2>/dev/null || true
    
    # Delete any leftover RBAC bindings we may have added
    echo -e "${BLUE}  → Deleting ESO-related ClusterRoleBindings...${NC}"
    kubectl delete clusterrolebinding eso-auth-delegator eso-token-review external-secrets-token-review 2>/dev/null || true
    
    # Delete the Vault policy
    echo -e "${BLUE}  → Deleting Vault policy 'demo-policy'...${NC}"
    kubectl exec vault-0 -n vault -- vault delete sys/policy/demo-policy 2>/dev/null || true
    
    # Optionally disable Kubernetes auth method
    echo -e "${BLUE}  → Disabling Kubernetes auth method in Vault...${NC}"
    kubectl exec vault-0 -n vault -- vault auth disable kubernetes 2>/dev/null || true
    
    echo -e "${GREEN}  → Vault cleanup complete.${NC}"
  else
    echo -e "${YELLOW}  → Vault pod not found. Skipping Vault cleanup.${NC}"
  fi
else
  echo -e "${YELLOW}→ Vault namespace not found. Vault configs already cleaned up.${NC}"
fi

echo

# ══════════════════════════════════════════════════════════════════════════════
# UNINSTALL EXTERNAL SECRETS OPERATOR
# ══════════════════════════════════════════════════════════════════════════════
# Remove the External Secrets Operator Helm release
# ══════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}→ Uninstalling External Secrets Operator Helm release...${NC}"

if helm list -n external-secrets 2>/dev/null | grep -q external-secrets; then
  helm uninstall external-secrets -n external-secrets
  echo -e "${GREEN}  → External Secrets Operator uninstalled.${NC}"
else
  echo -e "${BLUE}  → External Secrets Operator Helm release not found. Skipping.${NC}"
fi

echo

# ══════════════════════════════════════════════════════════════════════════════
# DELETE NAMESPACES
# ══════════════════════════════════════════════════════════════════════════════
# Delete the external-secrets and app namespaces
# ══════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}→ Deleting namespaces...${NC}"

# Delete external-secrets namespace
if kubectl get namespace external-secrets >/dev/null 2>&1; then
  echo -e "${BLUE}  → Deleting 'external-secrets' namespace...${NC}"
  kubectl delete namespace external-secrets --timeout=60s
  echo -e "${GREEN}  → Namespace 'external-secrets' deleted.${NC}"
else
  echo -e "${BLUE}  → Namespace 'external-secrets' not found. Already deleted.${NC}"
fi

# Delete app namespace
if kubectl get namespace app >/dev/null 2>&1; then
  echo -e "${BLUE}  → Deleting 'app' namespace...${NC}"
  kubectl delete namespace app --timeout=60s
  echo -e "${GREEN}  → Namespace 'app' deleted.${NC}"
else
  echo -e "${BLUE}  → Namespace 'app' not found. Already deleted.${NC}"
fi

echo

# ══════════════════════════════════════════════════════════════════════════════
# REMOVE HELM REPOSITORY
# ══════════════════════════════════════════════════════════════════════════════
# Remove the external-secrets Helm repository from local Helm config
# ══════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}→ Removing external-secrets Helm repository...${NC}"

if helm repo list 2>/dev/null | grep -q external-secrets; then
  helm repo remove external-secrets
  echo -e "${GREEN}  → Helm repository removed.${NC}"
else
  echo -e "${BLUE}  → external-secrets Helm repo not found. Already removed.${NC}"
fi

echo

# ══════════════════════════════════════════════════════════════════════════════
# DELETE CRDs (Custom Resource Definitions)
# ══════════════════════════════════════════════════════════════════════════════
# Warning: CRDs are cluster-wide and affect all namespaces
# Only delete if you're completely removing External Secrets from your cluster
# ══════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}→ Checking for External Secrets CRDs...${NC}"

CRD_COUNT=$(kubectl get crds 2>/dev/null | grep -c "external-secrets.io" || echo "0")

if [ "$CRD_COUNT" -gt 0 ]; then
  echo -e "${BLUE}  → Found $CRD_COUNT External Secrets CRD(s).${NC}"
  echo -e "${YELLOW}  → Do you want to delete them? (This is cluster-wide and irreversible)${NC}"
  echo -e "${RED}     WARNING: Only proceed if no other namespaces use External Secrets!${NC}"
  read -p "    Delete CRDs? [y/N]: " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}  → Deleting External Secrets CRDs...${NC}"
    kubectl delete crds -l app.kubernetes.io/name=external-secrets --timeout=60s
    echo -e "${GREEN}  → CRDs deleted.${NC}"
  else
    echo -e "${YELLOW}  → Skipping CRD deletion (they remain in the cluster).${NC}"
  fi
else
  echo -e "${BLUE}  → No External Secrets CRDs found.${NC}"
fi

echo
echo -e "${GREEN}===================================================================="
echo " External Secrets Operator cleanup complete!"
echo "===================================================================="
echo -e "${NC}"
echo
echo -e "${YELLOW}Summary of what was removed:${NC}"
echo -e "  ${BLUE}✓${NC} ExternalSecret 'hello-world-secrets' (app namespace)"
echo -e "  ${BLUE}✓${NC} SecretStore 'vault-backend' (app namespace)"
echo -e "  ${BLUE}✓${NC} Kubernetes Secret 'hello-world-secrets' (app namespace)"
echo -e "  ${BLUE}✓${NC} Vault role 'demo-role'"
echo -e "  ${BLUE}✓${NC} Vault policy 'demo-policy'"
echo -e "  ${BLUE}✓${NC} Vault Kubernetes auth method (disabled)"
echo -e "  ${BLUE}✓${NC} External Secrets Operator Helm release"
echo -e "  ${BLUE}✓${NC} Namespace 'external-secrets'"
echo -e "  ${BLUE}✓${NC} Namespace 'app'"
echo -e "  ${BLUE}✓${NC} Helm repository 'external-secrets'"
echo