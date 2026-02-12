#!/bin/bash
set -euo pipefail

# Colors for nicer output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ──────────────────────────────────────────────────────────────────────────────
# Ensure Vault is installed, running, and ready before proceeding
# ──────────────────────────────────────────────────────────────────────────────

echo -e "${GREEN}→ Checking if HashiCorp Vault is installed and ready...${NC}"

# Check if vault namespace exists
if ! kubectl get namespace vault >/dev/null 2>&1; then
  echo -e "${RED}Error: Namespace 'vault' not found. Make sure Vault is installed first.${NC}"
  echo -e "${RED}Run the Vault setup script or check: kubectl get ns vault${NC}"
  exit 1
fi

# Check if vault-0 pod is running and ready
if ! kubectl get pod vault-0 -n vault >/dev/null 2>&1; then
  echo -e "${RED}Error: Vault pod 'vault-0' not found in namespace 'vault'.${NC}"
  echo -e "${RED}Run the Vault setup script and wait for it to complete.${NC}"
  exit 1
fi

echo -e "${YELLOW}→ Waiting for Vault pod to be fully ready (up to 60s)...${NC}"
kubectl wait --for=condition=ready pod/vault-0 -n vault --timeout=60s || {
  echo -e "${RED}Error: Vault pod 'vault-0' is not ready.${NC}"
  echo -e "${RED}Check status: kubectl describe pod vault-0 -n vault${NC}"
  exit 1
}

echo -e "${GREEN}→ Vault is up and running!${NC}"
echo
echo
echo


# ══════════════════════════════════════════════════════════════════════════════
# CREATE THE "APP" NAMESPACE
# ══════════════════════════════════════════════════════════════════════════════
# After Vault checks, before ESO installation
echo -e "${YELLOW}→ Creating 'app' namespace...${NC}"
kubectl create namespace app --dry-run=client -o yaml | kubectl apply -f -

# ══════════════════════════════════════════════════════════════════════════════
# EXTERNAL SECRETS OPERATOR SETUP
# ══════════════════════════════════════════════════════════════════════════════
# External Secrets Operator (ESO) is a Kubernetes operator that syncs secrets
# from external secret management systems (like HashiCorp Vault, AWS Secrets
# Manager, etc.) into Kubernetes Secrets automatically.
#
# Why we need it:
# - Keeps secrets in Vault (single source of truth)
# - Automatically creates/updates Kubernetes Secrets from Vault
# - No need to manually copy secrets or commit them to git
# ══════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}→ Installing External Secrets Operator...${NC}"
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace \
  --set installCRDs=true

# Wait for CRDs to be fully established and registered with API server
echo -e "${YELLOW}→ Waiting for External Secrets CRDs to be registered...${NC}"

kubectl wait --for condition=established \
  crd/secretstores.external-secrets.io \
  crd/externalsecrets.external-secrets.io \
  crd/clustersecretstores.external-secrets.io \
  --timeout=60s || {
  echo -e "${RED}Error: CRDs failed to be established!${NC}"
  echo -e "${RED}Check: kubectl get crds | grep external-secrets${NC}"
  exit 1
}

echo -e "${GREEN}→ CRDs successfully registered!${NC}"
sleep 5

echo -e "${YELLOW}→ Waiting for External Secrets Operator to be ready (up to 120s)...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=external-secrets \
  -n external-secrets --timeout=120s || {
  echo -e "${RED}Error: External Secrets Operator pods not ready.${NC}"
  echo -e "${RED}Check status: kubectl get pods -n external-secrets${NC}"
  exit 1
}

echo -e "${GREEN}→ External Secrets Operator is ready!${NC}"

# ══════════════════════════════════════════════════════════════════════════════
# VAULT KUBERNETES AUTHENTICATION SETUP
# ══════════════════════════════════════════════════════════════════════════════
# We need to configure Vault to trust and authenticate Kubernetes service accounts.
# This allows pods (like External Secrets Operator) to authenticate to Vault
# using their Kubernetes service account tokens instead of managing separate credentials.
# ══════════════════════════════════════════════════════════════════════════════

# Step 1: Enable the Kubernetes auth method in Vault
echo -e "${YELLOW}→ Enabling Kubernetes auth method in Vault...${NC}"
kubectl exec vault-0 -n vault -- vault auth enable kubernetes

# Step 2: Configure HOW Vault should talk to Kubernetes to validate tokens
echo -e "${YELLOW}→ Configuring Kubernetes auth in Vault...${NC}"
kubectl exec vault-0 -n vault -- vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token

# ══════════════════════════════════════════════════════════════════════════════
# VAULT POLICY - DEFINE PERMISSIONS (MUST BE CREATED FIRST!)
# ══════════════════════════════════════════════════════════════════════════════
# A policy is like a set of permissions. It defines WHAT paths in Vault can be
# accessed and WHAT actions (read, write, delete, etc.) are allowed.
#
# In this case, we're creating a policy that allows READ-ONLY access to our
# app secrets stored at secret/apps/hello-world/*
#
# NOTE: This MUST be created BEFORE the role that references it!
# ══════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}→ Creating Vault policy 'demo-policy'...${NC}"
kubectl exec -it vault-0 -n vault -- vault policy write demo-policy - <<EOF
path "secret/data/apps/hello-world/*" {
  capabilities = ["read"]
}

path "secret/data/apps/hello-world" {
  capabilities = ["read"]
}
EOF

# ══════════════════════════════════════════════════════════════════════════════
# CREATE VAULT ROLE
# ══════════════════════════════════════════════════════════════════════════════
# A role connects:
# 1. WHO can authenticate (which service accounts in which namespaces)
# 2. WHAT they can access (which policies they get)
#
# IMPORTANT: The service account and namespace must match what's used in the
# SecretStore resource. If your SecretStore is in 'default' namespace using
# the 'default' service account, then use those values here.
# ══════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}→ Creating Vault role 'demo-role'..${NC}"
kubectl exec vault-0 -n vault -- vault write auth/kubernetes/role/demo-role \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets \
  policies=demo-policy \
  ttl=24h

echo -e "${GREEN}→ Vault Kubernetes authentication configured successfully!${NC}"
echo

# ══════════════════════════════════════════════════════════════════════════════
# APPLY SECRETSTORE AND EXTERNALSECRET RESOURCES
# ══════════════════════════════════════════════════════════════════════════════
# SecretStore: Defines the connection to Vault (provider config).
# ExternalSecret: Defines which Vault secrets to sync into a Kubernetes Secret.
# ══════════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}→ Applying SecretStore for Vault connection...${NC}"
kubectl apply -f "./scripts/setup_scripts/configuration_yamls/vault-secret-store.yml"

echo -e "${YELLOW}→ Applying ExternalSecret to sync demo secrets...${NC}"
kubectl apply -f "./scripts/setup_scripts/configuration_yamls/external-secret.yml"

# Wait a moment for resources to initialize
sleep 5

# ══════════════════════════════════════════════════════════════════════════════
# VERIFY THE SETUP
# ══════════════════════════════════════════════════════════════════════════════

echo
echo -e "${YELLOW}→ Verifying setup...${NC}"
echo

# Check SecretStore status
echo -e "${BLUE}  SecretStore status:${NC}"
kubectl get secretstore vault-backend -n app 2>/dev/null || \
  echo -e "${RED}    ✗ SecretStore not found${NC}"

# Check ExternalSecret status
echo -e "${BLUE}  ExternalSecret status:${NC}"
kubectl get externalsecret hello-world-secrets -n app 2>/dev/null || \
  echo -e "${RED}    ✗ ExternalSecret not found${NC}"

# Check if Kubernetes Secret was created
echo -e "${BLUE}  Kubernetes Secret:${NC}"
if kubectl get secret hello-world-secrets -n app >/dev/null 2>&1; then
  echo -e "${GREEN}    ✓ Secret 'hello-world-secrets' exists!${NC}"
  echo -e "${BLUE}    Secret contains these keys:${NC}"
  kubectl get secret hello-world-secrets -n app -o jsonpath='{.data}' | jq -r 'keys[]' | sed 's/^/      - /'
else
  echo -e "${RED}    ✗ Secret 'hello-world-secrets' not found!${NC}"
  echo -e "${RED}    Check ExternalSecret status: kubectl describe externalsecret hello-world-secrets -n app${NC}"
fi

echo
echo -e "${GREEN}===================================================================="
echo " External Secrets Operator setup complete!"
echo "===================================================================="
echo -e "${NC}"
echo
echo -e "${YELLOW}Useful commands:${NC}"
echo -e "  ${BLUE}# View synced secret values (decoded):${NC}"
echo -e "  kubectl get secret hello-world-secrets -n default -o json | jq -r '.data | to_entries[] | \"\\(.key): \\(.value | @base64d)\"'"
echo
echo -e "  ${BLUE}# Check SecretStore status:${NC}"
echo -e "  kubectl describe secretstore vault-backend -n default"
echo
echo -e "  ${BLUE}# Check ExternalSecret status:${NC}"
echo -e "  kubectl describe externalsecret hello-world-secrets -n default"
echo
echo -e "  ${BLUE}# View ESO logs:${NC}"
echo -e "  kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets --tail=50"
echo