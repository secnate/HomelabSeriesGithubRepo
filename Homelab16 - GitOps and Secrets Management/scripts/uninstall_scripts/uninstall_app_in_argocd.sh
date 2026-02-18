#!/bin/bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════════════════════
# Colors for Nicer Output
# ══════════════════════════════════════════════════════════════════════════════
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ══════════════════════════════════════════════════════════════════════════════
# Stop Port Forwarding for the Application
# ══════════════════════════════════════════════════════════════════════════════
# Port-forward processes run in the background and need to be explicitly killed.
# Using || true prevents the script from exiting if no process exists.
echo -e "${YELLOW}→ Stopping port forwarding for application...${NC}"
pkill -f "kubectl port-forward.*helloworld-app" 2>/dev/null || true
sleep 1

# ══════════════════════════════════════════════════════════════════════════════
# Delete the ArgoCD Application
# ══════════════════════════════════════════════════════════════════════════════
# Deleting the ArgoCD Application will automatically cascade delete all
# Kubernetes resources that were deployed by it (Deployment, Service, Secrets, etc.)
# due to ArgoCD's built-in cascade deletion behavior.
echo -e "${YELLOW}→ Deleting ArgoCD Application...${NC}"
kubectl delete application hello-world-app -n argocd --ignore-not-found=true || true

# ══════════════════════════════════════════════════════════════════════════════
# Delete the Homelab16 ArgoCD Project
# ══════════════════════════════════════════════════════════════════════════════
# Remove the ArgoCD Project after all Applications using it have been deleted.
echo -e "${YELLOW}→ Deleting Homelab16 ArgoCD Project...${NC}"
kubectl delete appproject Homelab16 -n argocd --ignore-not-found=true || true

echo -e "${GREEN}✓ Homelab16 project deleted${NC}"

# ══════════════════════════════════════════════════════════════════════════════
# Wait for ArgoCD to Clean Up Resources
# ══════════════════════════════════════════════════════════════════════════════
# ArgoCD will automatically delete all resources it deployed when the
# Application is deleted. We wait for this cleanup to complete.
echo -e "${YELLOW}→ Waiting for ArgoCD to clean up resources (15 seconds)...${NC}"
sleep 15

# ══════════════════════════════════════════════════════════════════════════════
# Verify Resources Are Deleted
# ══════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}→ Checking for remaining resources...${NC}"

# Force delete deployment if it still exists
if kubectl get deployment hello-world-app -n app >/dev/null 2>&1; then
    echo -e "${YELLOW}  Deployment still exists, force deleting...${NC}"
    kubectl delete deployment hello-world-app -n app --force --grace-period=0 || true
fi

# Force delete service if it still exists
if kubectl get service helloworld-app -n app >/dev/null 2>&1; then
    echo -e "${YELLOW}  Service still exists, force deleting...${NC}"
    kubectl delete service helloworld-app -n app --force --grace-period=0 || true
fi

# ══════════════════════════════════════════════════════════════════════════════
# Wait for Pods to Terminate
# ══════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}→ Waiting for pods to terminate (up to 60 seconds)...${NC}"
kubectl wait --for=delete pod -l app=helloworld-app -n app --timeout=60s 2>/dev/null || true

# ══════════════════════════════════════════════════════════════════════════════
# Check for Remaining Pods
# ══════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}→ Checking for remaining pods...${NC}"
if kubectl get pods -n app -l app=helloworld-app 2>/dev/null | grep -q helloworld-app; then
    echo -e "${YELLOW}  Some pods still terminating:${NC}"
    kubectl get pods -n app -l app=helloworld-app
else
    echo -e "${GREEN}  ✓ No pods found${NC}"
fi

# ══════════════════════════════════════════════════════════════════════════════
# Delete the Namespace
# ══════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}→ Deleting namespace 'app'...${NC}"
kubectl delete namespace app --timeout=90s --ignore-not-found=true || {
    echo -e "${YELLOW}  Namespace deletion timed out, attempting force cleanup...${NC}"
    
    # Remove finalizers if namespace is stuck
    kubectl patch namespace app -p '{"spec":{"finalizers":null}}' --type=merge 2>/dev/null || true
    kubectl delete namespace app --force --grace-period=0 || true
    
    sleep 3
}

# ══════════════════════════════════════════════════════════════════════════════
# Verify Complete Removal
# ══════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}→ Verifying complete removal...${NC}"
sleep 2

if kubectl get namespace app >/dev/null 2>&1; then
    echo -e "${RED}✗ Warning: Namespace 'app' still exists (may be terminating)${NC}"
    echo -e "${YELLOW}  Run 'kubectl get namespace app' to check status${NC}"
else
    echo -e "${GREEN}✓ Namespace deleted${NC}"
fi

# ══════════════════════════════════════════════════════════════════════════════
# Final Status Message
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ ArgoCD Application cleanup complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Removed components:${NC}"
echo -e "  • ArgoCD Application (hello-world-app)"
echo -e "  • Kubernetes Deployment"
echo -e "  • Kubernetes Service"
echo -e "  • Application namespace"
echo -e "  • Port-forward processes"
echo -e "${GREEN}═════════════════════════${NC}"