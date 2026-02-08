#!/usr/bin/env bash
set -euo pipefail

echo "===================================================================="
echo " Docker setup script for WSL2 (Ubuntu/Debian) - 2026 edition"
echo " This installs Docker Engine directly in WSL — no Docker Desktop needed"
echo " You should run this script INSIDE your WSL terminal (not PowerShell)"
echo "===================================================================="

# ──────────────────────────────────────────────────────────────────────────────
# 1. Update system & install prerequisites
# ──────────────────────────────────────────────────────────────────────────────
echo "→ Updating package index and upgrading existing packages..."
sudo apt update -y
sudo apt upgrade -y

echo "→ Installing required dependencies..."
sudo apt install -y ca-certificates curl gnupg lsb-release

# ──────────────────────────────────────────────────────────────────────────────
# 2. Add official Docker GPG key and repository (current 2026 method)
# ──────────────────────────────────────────────────────────────────────────────
echo "→ Adding Docker's official GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "→ Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y

# ──────────────────────────────────────────────────────────────────────────────
# 3. Install Docker Engine + CLI + compose plugin
# ──────────────────────────────────────────────────────────────────────────────
echo "→ Installing Docker Engine, CLI, containerd, buildx and compose plugin..."
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ──────────────────────────────────────────────────────────────────────────────
# 4. Add current user to docker group → run docker without sudo
# ──────────────────────────────────────────────────────────────────────────────
echo "→ Adding $USER to docker group (log out & back in after script finishes)..."
sudo usermod -aG docker "$USER"

# ──────────────────────────────────────────────────────────────────────────────
# 5. Start & enable Docker service
#    (WSL usually doesn't use full systemd by default, so we use service)
# ──────────────────────────────────────────────────────────────────────────────
echo "→ Starting Docker service..."
sudo service docker start || true

# Quick check if docker is running
if ! sudo docker info >/dev/null 2>&1; then
  echo "⚠️  Docker daemon did not start automatically."
  echo "    Try: sudo service docker start"
  echo "    Or enable systemd in WSL if you prefer (advanced): edit /etc/wsl.conf"
else
  echo "→ Docker is running!"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 6. Verify versions
# ──────────────────────────────────────────────────────────────────────────────
echo
echo "Docker versions:"
sudo docker --version
sudo docker compose version   # Note: it's "docker compose" (v2 plugin), not docker-compose
echo

# ──────────────────────────────────────────────────────────────────────────────
# 7. We get the Hello World Application Finally Built
# ──────────────────────────────────────────────────────────────────────────────

DOCKER_HUB_USERNAME="nathanpavl"
IMAGE_NAME="sample_hello_world_flask_app"
TAG="v1.0.0"
APPLICATION_PATH="app"

FULL_IMAGE_NAME="${DOCKER_HUB_USERNAME}/${IMAGE_NAME}:${TAG}"

echo
echo "Building & pushing Docker image: ${FULL_IMAGE_NAME}"
echo

# Make sure we're in the right directory or adjust path
echo "→ Building image from the following path: ${APPLICATION_PATH}"
sudo docker build -t "${FULL_IMAGE_NAME}" "${APPLICATION_PATH}"

if [ $? -eq 0 ]; then
  echo "Build successful! Image: ${FULL_IMAGE_NAME}"
  
  echo "→ Ensuring logged in to Docker Hub (will prompt if needed)..."
  sudo docker login

  echo "→ Pushing to Docker Hub..."
  sudo docker push "${FULL_IMAGE_NAME}"

  if [ $? -eq 0 ]; then
    echo "Push successful!"
  else
    echo "Push failed! Check credentials (docker login) or network."
  fi
else
  echo "Build failed!"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 8. Prepare the Kubernetes namespace for deployment
# ──────────────────────────────────────────────────────────────────────────────

APP_NAMESPACE="app"

kubectl config set-context --current --namespace=default >/dev/null 2>&1
echo "→ Checking if namespace '${APP_NAMESPACE}' exists in Kubernetes..."

if kubectl get namespace "${APP_NAMESPACE}" >/dev/null 2>&1; then
  echo "  Namespace '${APP_NAMESPACE}' already exists → skipping creation."
else
  echo "  Namespace '${APP_NAMESPACE}' not found → creating it..."
  kubectl create namespace "${APP_NAMESPACE}"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 9. Deploying the application with Kubernetes
# ──────────────────────────────────────────────────────────────────────────────

echo "→ Deploying the application with Kubernetes..."

KUBERNETES_MANIFESTS_PATH="${APPLICATION_PATH}/kubernetes_manifests"

# Apply the Application manifests
kubectl apply -f "${KUBERNETES_MANIFESTS_PATH}/helloworld-deployment.yaml" -n "${APP_NAMESPACE}"
kubectl apply -f "${KUBERNETES_MANIFESTS_PATH}/helloworld-service.yaml"   -n "${APP_NAMESPACE}"

# Wait for the Deployment to report all replicas ready
echo "→ Waiting for deployment to be ready (up to 120s)..."
kubectl wait --for=condition=Available deployment/hello-world-app-deployment -n "${APP_NAMESPACE}" --timeout=120s

if [ $? -eq 0 ]; then
  echo "  Deployment is available — all pods should be ready soon."
  # Small grace period so port-forward doesn't start too early
  sleep 5
else
  echo "  Timeout waiting for deployment. Showing current status:"
  kubectl get pods -n "${APP_NAMESPACE}" -l app=helloworld-app
  kubectl describe deployment hello-world-app-deployment -n "${APP_NAMESPACE}"
  # Halting script execution here because it failed
  exit 1
fi

# Forward local port 5000 → Service port 80
kubectl port-forward -n "${APP_NAMESPACE}" svc/helloworld-app 5000:80 &

echo "The application is ready -- It Can Be Accessed At http://localhost:5000"