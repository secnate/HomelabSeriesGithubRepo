#!/bin/bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════════════════════
# Colors for Nicer Output
# ══════════════════════════════════════════════════════════════════════════════
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ══════════════════════════════════════════════════════════════════════════════
# Verify ArgoCD is Installed and Running
# ══════════════════════════════════════════════════════════════════════════════
# Before creating an ArgoCD Application, we must ensure ArgoCD itself is
# installed, running, and healthy. This prevents cryptic errors if the user
# runs this script before running setup_argocd.sh
echo -e "${YELLOW}→ Verifying ArgoCD is installed and running...${NC}"

# Check if argocd namespace exists
if ! kubectl get namespace argocd >/dev/null 2>&1; then
  echo -e "${RED}✗ ArgoCD namespace not found!${NC}"
  echo -e "${YELLOW}  Please run: ./setup_argocd.sh first${NC}"
  exit 1
fi

# Check if ArgoCD server deployment exists
if ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
  echo -e "${RED}✗ ArgoCD server deployment not found!${NC}"
  echo -e "${YELLOW}  Please run: ./setup_argocd.sh first${NC}"
  exit 1
fi

# Check if ArgoCD pods are ready
echo -e "${YELLOW}→ Checking ArgoCD pod status...${NC}"
if ! kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=10s >/dev/null 2>&1; then
  echo -e "${RED}✗ ArgoCD server pods are not ready!${NC}"
  echo -e "${YELLOW}  Current status:${NC}"
  kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server
  echo -e "${YELLOW}  Wait for pods to be ready, then try again${NC}"
  exit 1
fi

echo -e "${GREEN}✓ ArgoCD is installed and running${NC}"

# ══════════════════════════════════════════════════════════════════════════════
# Create the App Namespace
# ══════════════════════════════════════════════════════════════════════════════
# Even though the ArgoCD Application has CreateNamespace=true, we create it
# explicitly here to ensure it exists before ArgoCD tries to deploy
echo -e "${YELLOW}→ Creating 'app' namespace...${NC}"
kubectl create namespace app --dry-run=client -o yaml | kubectl apply -f -

# ══════════════════════════════════════════════════════════════════════════════
# Create the Homelab16 ArgoCD Project
# ══════════════════════════════════════════════════════════════════════════════
# ArgoCD Projects provide logical grouping and security boundaries for applications.
# We create the Homelab16 project to contain all applications for this homelab.
echo -e "${YELLOW}→ Creating Homelab16 ArgoCD Project...${NC}"
kubectl apply -f argocd/homelab16-project.yaml

echo -e "${GREEN}✓ Homelab16 project created${NC}"

# ══════════════════════════════════════════════════════════════════════════════
# Apply the ArgoCD Application Manifest
# ══════════════════════════════════════════════════════════════════════════════
# This creates an ArgoCD Application resource that tells ArgoCD:
# - What Git repo to watch
# - Which path contains the manifests
# - Where to deploy them (namespace: app)
# - How to sync (automatically with prune and selfHeal)
echo -e "${YELLOW}→ Creating ArgoCD Application for hello-world-app...${NC}"
kubectl apply -f argocd/hello-world-application.yaml

# ══════════════════════════════════════════════════════════════════════════════
# Wait for ArgoCD to Perform Initial Sync
# ══════════════════════════════════════════════════════════════════════════════
# ArgoCD will detect the new Application and start syncing immediately.
# We give it some time to pull from Git and deploy the resources.
echo -e "${YELLOW}→ Waiting for ArgoCD to perform initial sync (30 seconds)...${NC}"
sleep 30

# ══════════════════════════════════════════════════════════════════════════════
# Check ArgoCD Application Status
# ══════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}→ Checking ArgoCD Application status...${NC}"
kubectl get application hello-world-app -n argocd

# ══════════════════════════════════════════════════════════════════════════════
# Wait for Deployment to Be Ready
# ══════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}→ Waiting for deployment to be ready (up to 120 seconds)...${NC}"
kubectl wait --for=condition=Available deployment/hello-world-app-deployment -n app --timeout=120s || {
    echo -e "${RED}✗ Deployment not ready after timeout${NC}"
    echo -e "${YELLOW}→ Current pod status:${NC}"
    kubectl get pods -n app
    echo -e "${YELLOW}→ Check ArgoCD UI for details: https://localhost:8080${NC}"
    exit 1
}

# ══════════════════════════════════════════════════════════════════════════════
# Check Pod Status
# ══════════════════════════════════════════════════════════════════════════════
echo -e "${YELLOW}→ Current pod status:${NC}"
kubectl get pods -n app

# ══════════════════════════════════════════════════════════════════════════════
# Set Up Port Forwarding for the Application
# ══════════════════════════════════════════════════════════════════════════════
sleep 30
echo -e "${YELLOW}→ Setting up port forwarding for the application...${NC}"
kubectl port-forward -n app svc/helloworld-app 5000:80 > /dev/null 2>&1 &
sleep 3

# ══════════════════════════════════════════════════════════════════════════════
# Verify Port Forward Started Successfully
# ══════════════════════════════════════════════════════════════════════════════
if pgrep -f "kubectl port-forward.*helloworld-app" > /dev/null; then
  echo -e "${GREEN}✓ Port forwarding active on port 5000${NC}"
else
  echo -e "${RED}✗ Port forwarding failed to start${NC}"
fi

# ══════════════════════════════════════════════════════════════════════════════
# Display Success Message
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ GitOps CD Pipeline is now active!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "Application:  ${BLUE}hello-world-app${NC}"
echo -e "Namespace:    ${BLUE}app${NC}"
echo -e "App URL:      ${BLUE}http://localhost:5000${NC}"
echo -e "ArgoCD UI:    ${BLUE}https://localhost:8080${NC}"
echo ""
echo -e "${YELLOW}ArgoCD will now automatically deploy changes from Git${NC}"
echo -e "${YELLOW}Any updates to manifests in Git will sync within 3 minutes${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""