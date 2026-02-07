#!/bin/bash
set -euo pipefail

# We start setting up the External Secrets
helm repo add external-secrets https://charts.external-secrets.io

helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace

# THE FOLLOWING WILL BE INCLUDED IN THE .SH FILE A BIT LATER IN THE HOMELAB
# kubectl apply -f "basic-external-secret.yaml"