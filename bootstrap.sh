#!/bin/bash

# bootstrap.sh - Sets up Minikube and installs Traefik for the static site deployment.
# v3: Removed --wait from helm install for Traefik to avoid LoadBalancer IP issues in Minikube.

set -eo pipefail # Exit on error, treat unset variables as error, propagate pipe failures

# -- Configuration --
MINIKUBE_PROFILE="static-site-demo" # Name for the Minikube profile
MINIKUBE_CPUS="2"                   # Number of CPUs for Minikube VM
MINIKUBE_MEMORY="4096"              # Memory for Minikube VM (in MB) - Increase if needed!
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
check_command "minikube"
check_command "helm"
check_command "kubectl"

info "Starting Minikube (profile: ${MINIKUBE_PROFILE})..."
if minikube status -p "${MINIKUBE_PROFILE}" &> /dev/null; then
    info "Minikube profile '${MINIKUBE_PROFILE}' already running."
    # Ensure kubectl context is set
    minikube update-context -p "${MINIKUBE_PROFILE}"
    kubectl config use-context "${MINIKUBE_PROFILE}"
else
    info "Starting new Minikube instance..."
    minikube start --profile "${MINIKUBE_PROFILE}" --cpus "${MINIKUBE_CPUS}" --memory "${MINIKUBE_MEMORY}" --driver=docker
    info "Minikube started."
fi

info "Adding Traefik Helm repository..."
helm repo add traefik "${TRAEFIK_HELM_REPO}" || info "Traefik repo already exists."
helm repo update traefik

info "Installing Traefik using Helm (version ${TRAEFIK_CHART_VERSION})..."
# Create namespace if it doesn't exist
kubectl create namespace "${TRAEFIK_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Install Traefik Helm chart - REMOVED --wait flag
# Helm will now exit quickly after applying manifests. We check pod readiness below.
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
info "Getting Minikube IP..."

# Get the Minikube IP, which acts as the external IP for LoadBalancer services
MINIKUBE_IP=$(minikube ip -p "${MINIKUBE_PROFILE}")
if [ -z "${MINIKUBE_IP}" ]; then
    error "Could not get Minikube IP address."
fi
info "Minikube IP: ${MINIKUBE_IP}"
info "You will need to add entries to your Windows hosts file (C:\\Windows\\System32\\drivers\\etc\\hosts) as Administrator:"
info "---"
info "${MINIKUBE_IP} dev.my-static-site.local prod.my-static-site.local"
info "---"
echo ""
info "Bootstrap complete! You can now deploy the application Helm chart."
info "Example deployment commands:"
info "  helm install dev-site ./helm/my-static-site -f ./helm/my-static-site/values-dev.yaml --namespace dev --create-namespace"
info "  helm install prod-site ./helm/my-static-site -f ./helm/my-static-site/values-prod.yaml --namespace prod --create-namespace"
echo ""
info "Access dev site (after adding to hosts file): https://dev.my-static-site.local"
info "Access prod site (after adding to hosts file): https://prod.my-static-site.local"
info "(You will likely need to accept the self-signed certificate warning in your browser)"

    
