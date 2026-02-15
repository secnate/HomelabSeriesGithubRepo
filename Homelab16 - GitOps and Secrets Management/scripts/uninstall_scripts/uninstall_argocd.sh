#!/bin/bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════════════════════
# Colors for Nicer Output
# ══════════════════════════════════════════════════════════════════════════════
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ══════════════════════════════════════════════════════════════════════════════
# Kill Any Running Port-Forward Processes for ArgoCD
# ══════════════════════════════════════════════════════════════════════════════
# Port-forward processes run in the background and need to be explicitly killed.
# We search for any kubectl port-forward process related to argocd-server and
# terminate it. Using || true prevents the script from exiting if no process exists.
echo -e "${YELLOW}→ Killing any running ArgoCD port-forward processes...${NC}"
pkill -f "port-forward.*argocd-server" || true
sleep 1

# ══════════════════════════════════════════════════════════════════════════════
# Delete All ArgoCD Applications First
# ══════════════════════════════════════════════════════════════════════════════
# If any ArgoCD Applications exist in the cluster, delete them first to prevent
# cascading deletion issues. This ensures a clean removal without stuck finalizers.
echo -e "${YELLOW}→ Deleting any ArgoCD Applications...${NC}"
kubectl delete applications.argoproj.io --all -n argocd --ignore-not-found=true --timeout=60s || true

# ══════════════════════════════════════════════════════════════════════════════
# Delete the ArgoCD Namespace
# ══════════════════════════════════════════════════════════════════════════════
# Deleting the namespace will cascade delete all resources within it (Deployments,
# Services, ConfigMaps, Secrets, etc.). We set a timeout to prevent hanging forever
# if something blocks deletion.
echo -e "${YELLOW}→ Deleting ArgoCD namespace (this may take 30-60 seconds)...${NC}"
kubectl delete namespace argocd --timeout=90s --ignore-not-found=true || {
    echo -e "${YELLOW}→ Namespace deletion timed out or failed, attempting force cleanup...${NC}"
    
    # ══════════════════════════════════════════════════════════════════════════
    # Force Remove Finalizers if Namespace is Stuck
    # ══════════════════════════════════════════════════════════════════════════
    # Sometimes namespaces get stuck in "Terminating" state due to finalizers.
    # This removes all finalizers from the namespace object to force deletion.
    kubectl get namespace argocd -o json 2>/dev/null | \
        jq '.spec.finalizers = []' | \
        kubectl replace --raw "/api/v1/namespaces/argocd/finalize" -f - || true
    
    sleep 2
}

# ══════════════════════════════════════════════════════════════════════════════
# Delete ArgoCD Custom Resource Definitions (CRDs)
# ══════════════════════════════════════════════════════════════════════════════
# CRDs are cluster-scoped resources that persist even after namespace deletion.
# We explicitly remove all ArgoCD CRDs to ensure no remnants remain. These include
# Application, AppProject, ApplicationSet, and other ArgoCD custom resources.
echo -e "${YELLOW}→ Deleting ArgoCD Custom Resource Definitions (CRDs)...${NC}"
kubectl delete crd applications.argoproj.io --ignore-not-found=true || true
kubectl delete crd applicationsets.argoproj.io --ignore-not-found=true || true
kubectl delete crd appprojects.argoproj.io --ignore-not-found=true || true
kubectl delete crd argocdextensions.argoproj.io --ignore-not-found=true || true

# Delete any remaining ArgoCD CRDs by label (catches any we might have missed)
kubectl delete crd -l app.kubernetes.io/part-of=argocd --ignore-not-found=true || true

# ══════════════════════════════════════════════════════════════════════════════
# Clean Up Any Lingering ClusterRoles and ClusterRoleBindings
# ══════════════════════════════════════════════════════════════════════════════
# ArgoCD creates cluster-wide RBAC resources that aren't automatically deleted
# with the namespace. We remove these explicitly to ensure complete cleanup.
echo -e "${YELLOW}→ Cleaning up ArgoCD ClusterRoles and ClusterRoleBindings...${NC}"
kubectl delete clusterrole -l app.kubernetes.io/part-of=argocd --ignore-not-found=true || true
kubectl delete clusterrolebinding -l app.kubernetes.io/part-of=argocd --ignore-not-found=true || true

# ══════════════════════════════════════════════════════════════════════════════
# Remove Any Webhook Configurations
# ══════════════════════════════════════════════════════════════════════════════
# ArgoCD may create ValidatingWebhookConfigurations or MutatingWebhookConfigurations
# that are cluster-scoped and need explicit cleanup.
echo -e "${YELLOW}→ Removing any ArgoCD webhook configurations...${NC}"
kubectl delete validatingwebhookconfiguration -l app.kubernetes.io/part-of=argocd --ignore-not-found=true || true
kubectl delete mutatingwebhookconfiguration -l app.kubernetes.io/part-of=argocd --ignore-not-found=true || true

# ══════════════════════════════════════════════════════════════════════════════
# Verify Complete Removal
# ══════════════════════════════════════════════════════════════════════════════
# Double-check that the namespace and CRDs are actually gone. If anything remains,
# alert the user so they can investigate.
echo -e "${YELLOW}→ Verifying complete removal...${NC}"
sleep 2

if kubectl get namespace argocd 2>/dev/null; then
    echo -e "${RED}✗ Warning: ArgoCD namespace still exists (may be terminating)${NC}"
    echo -e "${YELLOW}  Run 'kubectl get namespace argocd' to check status${NC}"
else
    echo -e "${GREEN}✓ ArgoCD namespace removed${NC}"
fi

if kubectl get crd applications.argoproj.io 2>/dev/null; then
    echo -e "${RED}✗ Warning: Some ArgoCD CRDs still exist${NC}"
    echo -e "${YELLOW}  Run 'kubectl get crd | grep argoproj' to see remaining CRDs${NC}"
else
    echo -e "${GREEN}✓ ArgoCD CRDs removed${NC}"
fi

# ══════════════════════════════════════════════════════════════════════════════
# Final Status Message
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ ArgoCD uninstallation complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}Removed components:${NC}"
echo -e "  • ArgoCD namespace and all resources"
echo -e "  • Custom Resource Definitions (CRDs)"
echo -e "  • ClusterRoles and ClusterRoleBindings"
echo -e "  • Webhook configurations"
echo -e "  • Port-forward processes"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""