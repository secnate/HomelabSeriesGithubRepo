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
# Documentation Reference
# ══════════════════════════════════════════════════════════════════════════════
# This ArgoCD installation script is based off the documentation at:
#   https://argo-cd.readthedocs.io/en/stable/getting_started/
# ══════════════════════════════════════════════════════════════════════════════

# ══════════════════════════════════════════════════════════════════════════════
# Create the "argocd" Namespace (Idempotent)
# ══════════════════════════════════════════════════════════════════════════════
# Using --dry-run=client with apply makes this command idempotent, so re-running
# the script won't fail if the namespace already exists
echo -e "${YELLOW}→ Creating 'argocd' namespace...${NC}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# ══════════════════════════════════════════════════════════════════════════════
# Install ArgoCD Components
# ══════════════════════════════════════════════════════════════════════════════
# This installs all ArgoCD components: API server, repo server, application
# controller, and the web UI. The --server-side flag handles CRD installation
# more reliably, and --force-conflicts resolves any ownership conflicts.
echo -e "${YELLOW}→ Installing ArgoCD components...${NC}"
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# ══════════════════════════════════════════════════════════════════════════════
# Wait for ArgoCD Pods to Be Ready
# ══════════════════════════════════════════════════════════════════════════════
# ArgoCD takes 2-3 minutes to fully start up. We wait for the server pod to be
# ready before proceeding, otherwise the port-forward and password retrieval
# will fail. Timeout is set to 300 seconds (5 minutes) to be safe.
echo -e "${YELLOW}→ Waiting for ArgoCD pods to be ready (this may take 2-3 minutes)...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# ══════════════════════════════════════════════════════════════════════════════
# Set Up Port Forwarding for ArgoCD UI Access
# ══════════════════════════════════════════════════════════════════════════════
# Due to WSL2 networking quirks (NodePort doesn't auto-forward to Windows host),
# we use port-forward to expose ArgoCD at https://localhost:8080. The process
# runs in background, and we capture its PID for verification.
echo -e "${YELLOW}→ Setting up port forwarding for ArgoCD UI...${NC}"
kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
PORT_FORWARD_PID=$!
sleep 30


# ══════════════════════════════════════════════════════════════════════════════
# Retrieve the Default Admin Password
# ══════════════════════════════════════════════════════════════════════════════
# ArgoCD generates a random initial admin password and stores it in a Kubernetes
# secret. We extract and decode it here for display to the user. This password
# should be changed after first login in a production environment.
echo -e "${YELLOW}→ Retrieving ArgoCD admin password...${NC}"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# ══════════════════════════════════════════════════════════════════════════════
# Display ArgoCD Access Information
# ══════════════════════════════════════════════════════════════════════════════
# Present the user with all information needed to access ArgoCD: URL, username,
# and the auto-generated password. Also remind them about the self-signed cert.
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ ArgoCD is ready!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "URL:      ${BLUE}https://localhost:8080${NC}"
echo -e "Username: ${BLUE}admin${NC}"
echo -e "Password: ${BLUE}${ARGOCD_PASSWORD}${NC}"
echo ""
echo -e "${YELLOW}Note: Accept the self-signed certificate warning in your browser${NC}"
echo -e "${YELLOW}Note: To stop port-forward, run: pkill -f 'port-forward.*argocd-server'${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""