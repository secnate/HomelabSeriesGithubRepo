#!/usr/bin/env bash
set -euo pipefail

echo "===================================================================="
echo " Docker uninstall script for WSL2 (Ubuntu/Debian) - 2026 edition"
echo " This undoes the installation of Docker Engine and related components"
echo " It also deletes the pushed image and repo from Docker Hub using hub-tool"
echo " Run this INSIDE your WSL terminal (not PowerShell)"
echo "===================================================================="

# ──────────────────────────────────────────────────────────────────────────────
# Define variables (same as install script)
# ──────────────────────────────────────────────────────────────────────────────
DOCKER_HUB_USERNAME="nathanpavl"
IMAGE_NAME="sample_hello_world_flask_app"
TAG="v1.0.0"
FULL_IMAGE_NAME="${DOCKER_HUB_USERNAME}/${IMAGE_NAME}:${TAG}"

# ──────────────────────────────────────────────────────────────────────────────
# 1. Delete the image/repo from Docker Hub (install hub-tool and Go as needed)
# ──────────────────────────────────────────────────────────────────────────────
echo "→ Checking for Go (required for hub-tool)..."
install_go=0
if ! command -v go >/dev/null 2>&1; then
  echo "  Go not found — installing..."
  sudo apt update -y
  sudo apt install -y golang-go
  install_go=1
else
  echo "  Go already installed — skipping install."
fi

# Force standard Go paths
export GOPATH="${GOPATH:-$HOME/go}"
export PATH="$PATH:$GOPATH/bin"
echo "→ Go paths configured:"
echo "  GOPATH = $GOPATH"
echo "  PATH includes Go bin: $PATH"

# Clear shell command cache (fixes "command not found" after PATH change)
hash -r

echo "→ Installing Docker hub-tool (user-level install)..."
go install github.com/docker/hub-tool@latest

if [ $? -ne 0 ]; then
  echo "Failed to install hub-tool (go install error)! Skipping Docker Hub deletion."
else
  HUB_TOOL="$GOPATH/bin/hub-tool"

  echo "→ Checking hub-tool binary at: $HUB_TOOL"
  if [ -x "$HUB_TOOL" ]; then
    echo "  hub-tool binary found and executable!"

    # Test it works
    "$HUB_TOOL" --version >/dev/null 2>&1 || {
      echo "hub-tool exists but failed to run (permissions?). Skipping deletion."
      echo "  Manual check: ls -la $HUB_TOOL"
      echo "  Fix: chmod +x $HUB_TOOL"
    }

    echo "→ hub-tool ready! Logging in to Docker Hub (interactive prompt)..."
    "$HUB_TOOL" login

    echo "→ Deleting image tag from Docker Hub: ${FULL_IMAGE_NAME}"
    "$HUB_TOOL" tag rm "${FULL_IMAGE_NAME}" || echo "Warning: Tag deletion failed (may already be gone)."

    # Full repo deletion block
    echo "→ Attempting to delete the entire repository: ${IMAGE_NAME}"
    echo "  (this removes the repo if no other tags remain)"

    "$HUB_TOOL" repo rm "${IMAGE_NAME}" --force || true

    if [ $? -eq 0 ]; then
      echo "  Full repository deleted successfully!"
      echo "  If you want to double-check, you can visit visit: https://hub.docker.com/r/${DOCKER_HUB_USERNAME}/${IMAGE_NAME}"
      echo "  IMPORTANT: If [for whatever reason] still present → delete via web UI: My Hub > Repositories > select repo > Settings > Delete repository"
    else
      echo "  Repo deletion may have failed (already empty/gone, tool limitation, or needs confirmation)."
      echo "  Verify manually:"
      echo "    - Run: $HUB_TOOL repo ls"
      echo "    - Or visit: https://hub.docker.com/r/${DOCKER_HUB_USERNAME}/${IMAGE_NAME}"
      echo "  IMPORTANT: If still present → delete via web UI: My Hub > Repositories > select repo > Settings > Delete repository"
    fi

  else
    echo "hub-tool binary NOT found at $HUB_TOOL"
    echo "  → Manual fix needed (run these now):"
    echo "    1. ls -la \$HOME/go/bin   # check if hub-tool exists"
    echo "    2. If yes: export PATH=\$PATH:\$HOME/go/bin && hash -r"
    echo "    3. Then: ~/go/bin/hub-tool login"
    echo "    4. ~/go/bin/hub-tool tag rm ${FULL_IMAGE_NAME}"
    echo "    5. ~/go/bin/hub-tool repo rm ${IMAGE_NAME}"
    echo "  Or delete the repo directly in browser: https://hub.docker.com/r/${DOCKER_HUB_USERNAME}/${IMAGE_NAME}"
  fi
fi

# Cleanup hub-tool stuff (even if skipped)
echo "→ Cleaning up hub-tool config..."
rm -rf ~/.hub || true

echo "→ Uninstalling hub-tool binary..."
rm -f "$GOPATH/bin/hub-tool" || true

echo "→ Uninstalling Go (if installed by this script)..."
if [ $install_go -eq 1 ]; then
  sudo apt purge -y golang-go
  sudo apt autoremove -y
else
  echo "  Go was not installed by this script — skipping uninstall."
fi

# ──────────────────────────────────────────────────────────────────────────────
# 2. Delete local image (if exists) — use sudo for consistency
# ──────────────────────────────────────────────────────────────────────────────
echo "→ Deleting local Docker image (if exists): ${FULL_IMAGE_NAME}"
if sudo docker image inspect "${FULL_IMAGE_NAME}" >/dev/null 2>&1; then
  sudo docker rmi "${FULL_IMAGE_NAME}"
else
  echo "  Local image not found — skipping."
fi

# ──────────────────────────────────────────────────────────────────────────────
# 3. Stop Docker service
# ──────────────────────────────────────────────────────────────────────────────
echo "→ Stopping Docker service..."
sudo service docker stop || true

# ──────────────────────────────────────────────────────────────────────────────
# 4. Remove user from docker group
# ──────────────────────────────────────────────────────────────────────────────
echo "→ Removing $USER from docker group..."
sudo gpasswd -d "$USER" docker || true

# Optionally remove group if empty
if ! getent group docker | grep -q '\S'; then
  sudo groupdel docker || true
fi

# ──────────────────────────────────────────────────────────────────────────────
# 5. Uninstall Docker packages
# ──────────────────────────────────────────────────────────────────────────────
echo "→ Uninstalling Docker packages..."
sudo apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Clean up residuals
sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker || true

# ──────────────────────────────────────────────────────────────────────────────
# 6. Remove Docker repository
# ──────────────────────────────────────────────────────────────────────────────
echo "→ Removing Docker repository..."
sudo rm -f /etc/apt/sources.list.d/docker.list || true

# ──────────────────────────────────────────────────────────────────────────────
# 7. Remove Docker GPG key
# ──────────────────────────────────────────────────────────────────────────────
echo "→ Removing Docker GPG key..."
sudo rm -f /etc/apt/keyrings/docker.gpg || true

# ──────────────────────────────────────────────────────────────────────────────
# 8. Update apt
# ──────────────────────────────────────────────────────────────────────────────
sudo apt update -y

# ──────────────────────────────────────────────────────────────────────────────
# 9. Autoremove leftovers
# ──────────────────────────────────────────────────────────────────────────────
echo "→ Removing unused dependencies (if safe)..."
sudo apt autoremove -y

# ──────────────────────────────────────────────────────────────────────────────
# 10. Clean up Kubernetes resources created by make init
# ──────────────────────────────────────────────────────────────────────────────

echo
echo "→ Cleaning up Kubernetes resources created by 'make init'..."

APP_NAMESPACE="app"
DEPLOYMENT_NAME="hello-world-app-deployment"
SERVICE_NAME="helloworld-app"

# Stop any background kubectl port-forward processes for this app
echo "→ Terminating any kubectl port-forward processes..."
pkill -f "kubectl port-forward.*svc/${SERVICE_NAME}.*5000:80" 2>/dev/null || true

if pgrep -f "kubectl port-forward.*${SERVICE_NAME}" >/dev/null; then
  echo "  Warning: Some port-forward processes may still be running:"
  pgrep -fl "kubectl port-forward"
  echo "  You can kill them manually with: pkill -f 'kubectl port-forward.*${SERVICE_NAME}'"
else
  echo "  No port-forward processes found."
fi

# Delete Service
echo "→ Deleting Service '${SERVICE_NAME}' in namespace '${APP_NAMESPACE}'..."
kubectl delete service "${SERVICE_NAME}" \
  -n "${APP_NAMESPACE}" \
  --ignore-not-found=true \
  --grace-period=0 2>/dev/null || true

# Delete Deployment (cascades to ReplicaSets & Pods)
echo "→ Deleting Deployment '${DEPLOYMENT_NAME}' in namespace '${APP_NAMESPACE}'..."
kubectl delete deployment "${DEPLOYMENT_NAME}" \
  -n "${APP_NAMESPACE}" \
  --ignore-not-found=true \
  --grace-period=0 \
  --cascade=foreground 2>/dev/null || true

# Wait briefly for cascading deletion
sleep 5

# Wait until pods are gone
echo "→ Waiting for pods to terminate (up to 60s)..."
kubectl wait --for=delete pod -l app=helloworld-app \
  -n "${APP_NAMESPACE}" \
  --timeout=60s 2>/dev/null || true

# Show remaining pods (should be none)
echo "  Remaining pods in namespace '${APP_NAMESPACE}':"
kubectl get pods -n "${APP_NAMESPACE}" -l app=helloworld-app 2>/dev/null || echo "  No pods found."

# ──────────────────────────────────────────────────────────────────────────────
# 11. Force-delete the namespace (even if hidden/system resources remain, e.g. 
#           Events, EndpointSlices, lingering ConfigMaps/Secrets, or stuck finalizers)
# ──────────────────────────────────────────────────────────────────────────────
echo "→ Deleting namespace '${APP_NAMESPACE}' (force mode)..."

# First try normal delete
kubectl delete namespace "${APP_NAMESPACE}" --ignore-not-found=true || true

# If still present, remove finalizers and force delete
if kubectl get namespace "${APP_NAMESPACE}" >/dev/null 2>&1; then
  echo "  Namespace still exists → removing finalizers and forcing deletion..."

  # Remove finalizers (common reason namespaces get stuck)
  kubectl patch namespace "${APP_NAMESPACE}" \
    -p '{"spec":{"finalizers":null}}' \
    --type=merge 2>/dev/null || true

  # Force delete
  kubectl delete namespace "${APP_NAMESPACE}" \
    --force --grace-period=0 || true

  # Quick wait & check
  sleep 3
  if kubectl get namespace "${APP_NAMESPACE}" >/dev/null 2>&1; then
    echo "  Warning: Namespace '${APP_NAMESPACE}' still present after force delete."
    echo "  Check manually: kubectl describe ns ${APP_NAMESPACE}"
    echo "  Or run: kubectl delete ns ${APP_NAMESPACE} --force --grace-period=0"
  else
    echo "  Namespace '${APP_NAMESPACE}' successfully deleted."
  fi
else
  echo "  Namespace '${APP_NAMESPACE}' already gone."
fi

# ──────────────────────────────────────────────────────────────────────────────
# Final notes
# ──────────────────────────────────────────────────────────────────────────────
echo
echo "Uninstall complete!"
echo "IMPORTANT:"
echo "  - Close and reopen your WSL terminal to fully apply group changes."
echo "  - If you enabled systemd in /etc/wsl.conf, revert that manually if desired."
echo "  - Run 'sudo apt autoremove' again if needed for any leftovers."
echo "  - Double-check repo deletion on https://hub.docker.com/r/${DOCKER_HUB_USERNAME}/${IMAGE_NAME}"
echo "    (refresh after a few minutes — Docker Hub may have delayed cleanup)"
echo "===================================================================="