#!/usr/bin/env bash

# Sets up Traefik on Docker Desktop Kubernetes.
# Assumes Kubernetes is already enabled in Docker Desktop settings.

set -eo pipefail # Exit on error, treat unset variables as error, propagate pipe failures

# -- Configuration --
DOCKER_K8S_CONTEXT="docker-desktop" # Expected kubectl context name
TRAEFIK_NAMESPACE="traefik-system"  # Namespace for Traefik
TRAEFIK_HELM_REPO="https://helm.traefik.io/traefik"
TRAEFIK_HELM_CHART="traefik/traefik"
TRAEFIK_HELM_RELEASE_NAME="traefik"
# Pin to a specific recent version to avoid potential issues with 'latest'
TRAEFIK_CHART_VERSION="25.0.0"

# -- Functions --
info() {
    echo "[INFO] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        error "$1 command not found. Please install it first."
    fi
}

# -- Main Script --

info "Checking prerequisites..."
check_command "kubectl"
check_command "helm"
info "Ensure Docker Desktop is running and Kubernetes is ENABLED in Docker Desktop Settings."
sleep 3 # Give user time to read

info "Checking kubectl context '${DOCKER_K8S_CONTEXT}'..."
if ! kubectl config get-contexts "${DOCKER_K8S_CONTEXT}" > /dev/null 2>&1; then
    error "Kubectl context '${DOCKER_K8S_CONTEXT}' not found. Is Kubernetes enabled in Docker Desktop?"
fi

info "Setting kubectl context to '${DOCKER_K8S_CONTEXT}'..."
kubectl config use-context "${DOCKER_K8S_CONTEXT}"

info "Checking Docker Desktop Kubernetes node status..."
if ! kubectl get node "${DOCKER_K8S_CONTEXT}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q True; then
    error "Docker Desktop Kubernetes node is not reporting Ready status. Please check Docker Desktop."
fi
info "Docker Desktop Kubernetes node is Ready."

info "Adding Traefik Helm repository..."
helm repo add traefik "${TRAEFIK_HELM_REPO}" || info "Traefik repo already exists."
helm repo update traefik

info "Installing Traefik using Helm (version ${TRAEFIK_CHART_VERSION})..."
# Create namespace if it doesn't exist
kubectl create namespace "${TRAEFIK_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Install Traefik Helm chart using DaemonSet and hostPorts for localhost access
# Removed --wait from helm install; checking pod readiness explicitly below
helm upgrade --install "${TRAEFIK_HELM_RELEASE_NAME}" "${TRAEFIK_HELM_CHART}" \
  --namespace "${TRAEFIK_NAMESPACE}" \
  --version "${TRAEFIK_CHART_VERSION}" \
  --set persistence.enabled=false \
  --set deployment.kind=DaemonSet \
  --set ports.web.hostPort=80 \
  --set ports.websecure.hostPort=443 \
  --set ports.websecure.tls.enabled=true \
  --set providers.kubernetesCRD.enabled=true \
  --set providers.kubernetesIngress.enabled=false \
  --set dashboard.enabled=true \
  --set dashboard.insecure=true \
  --timeout 10m0s \
  --debug

info "Traefik Helm installation command finished (apply manifests)."

# Explicitly wait for Traefik pods to be ready
info "Waiting for Traefik pods to become ready..."
if ! kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=traefik -n "${TRAEFIK_NAMESPACE}" --timeout=5m; then
     error "Traefik pods did not become ready in time. Check pod logs and events."
     info "Run this command to check pod details: kubectl get pods -n ${TRAEFIK_NAMESPACE} -o wide"
     info "Run this command to see pod logs: kubectl logs <pod-name> -n ${TRAEFIK_NAMESPACE}"
     info "Run this command to check pod events: kubectl describe pod <pod-name> -n ${TRAEFIK_NAMESPACE}"
     exit 1
fi
info "Traefik pods are ready."

info "---------------------------------------------------------------------"
info "IMPORTANT: Update your Windows hosts file!"
info "Edit C:\\Windows\\System32\\drivers\\etc\\hosts (as Administrator)"
info "Add or update the following line to point to localhost:"
info "---"
info "127.0.0.1  dev.my-static-site.local prod.my-static-site.local"
info "---"
info "(Remove or comment out any old lines pointing these hostnames to other IPs)"
info "---------------------------------------------------------------------"
echo ""
info "Bootstrap for Docker Desktop Kubernetes complete!"
info "You can now deploy the application Helm chart."
info "Example deployment command (ensure namespace does NOT exist first or remove --create-namespace):"
info "  helm upgrade --install dev-site ./helm/my-static-site -f ./helm/my-static-site/values-dev.yaml --namespace dev"
echo ""
info "Access dev site (after updating hosts file): https://dev.my-static-site.local"
info "(You will likely need to accept the self-signed certificate warning in your browser)"

    
