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
# NOTE: ArgoCD Handles Application Resources
# ══════════════════════════════════════════════════════════════════════════════
# In the GitOps approach, the SecretStore, ExternalSecret, and synced Kubernetes
# Secret are managed by ArgoCD. When you delete the ArgoCD Application (via
# uninstall_app_in_argocd.sh), those resources are automatically cleaned up.
#
# This script only handles:
# 1. Vault-side cleanup (policy, role, auth method)
# 2. ESO operator uninstallation
# 3. CRD cleanup (optional)
# ══════════════════════════════════════════════════════════════════════════════

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Note: SecretStore, ExternalSecret, and app namespace${NC}"
echo -e "${BLUE}      are managed by ArgoCD and cleaned up separately${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
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
# DELETE EXTERNAL-SECRETS NAMESPACE
# ══════════════════════════════════════════════════════════════════════════════
# Delete the external-secrets namespace
# Note: The 'app' namespace is managed by ArgoCD and deleted via uninstall_app_in_argocd.sh
# ══════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}→ Deleting external-secrets namespace...${NC}"

if kubectl get namespace external-secrets >/dev/null 2>&1; then
  echo -e "${BLUE}  → Deleting 'external-secrets' namespace...${NC}"
  kubectl delete namespace external-secrets --timeout=90s || {
    echo -e "${YELLOW}  → Namespace stuck, forcing cleanup...${NC}"
    kubectl patch namespace external-secrets -p '{"spec":{"finalizers":null}}' --type=merge || true
    kubectl delete namespace external-secrets --force --grace-period=0 || true
  }
  echo -e "${GREEN}  → Namespace 'external-secrets' deleted.${NC}"
else
  echo -e "${BLUE}  → Namespace 'external-secrets' not found. Already deleted.${NC}"
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

echo -e "${YELLOW}→ Deleting External Secrets CRDs (cluster-wide resources)...${NC}"

CRD_COUNT=$(kubectl get crds 2>/dev/null | grep -c "external-secrets.io" || echo "0")

if [ "$CRD_COUNT" -gt 0 ]; then
  echo -e "${BLUE}  → Found $CRD_COUNT External Secrets CRD(s). Deleting...${NC}"
  kubectl delete crds -l app.kubernetes.io/name=external-secrets --timeout=60s || \
    echo -e "${YELLOW}    (Some CRDs may already be deleted)${NC}"
  echo -e "${GREEN}  → CRDs deleted.${NC}"
else
  echo -e "${BLUE}  → No External Secrets CRDs found.${NC}"
fi

echo
echo -e "${GREEN}===================================================================="
echo " External Secrets Operator cleanup complete!"
echo "===================================================================="
echo -e "${NC}"
echo -e "${YELLOW}Summary of what was removed:${NC}"
echo -e "  ${BLUE}✓${NC} Vault role 'demo-role'"
echo -e "  ${BLUE}✓${NC} Vault policy 'demo-policy'"
echo -e "  ${BLUE}✓${NC} Vault Kubernetes auth method (disabled)"
echo -e "  ${BLUE}✓${NC} External Secrets Operator Helm release"
echo -e "  ${BLUE}✓${NC} Namespace 'external-secrets'"
echo -e "  ${BLUE}✓${NC} Helm repository 'external-secrets'"
echo -e "  ${BLUE}✓${NC} External Secrets CRDs (cluster-wide)"
echo
echo -e "${BLUE}Note: SecretStore, ExternalSecret, and app namespace${NC}"
echo -e "${BLUE}      are managed by ArgoCD (cleaned via uninstall_app_in_argocd.sh)${NC}"
echo