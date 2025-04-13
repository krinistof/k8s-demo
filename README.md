# Kubernetes Demo README

## Purpose

Demonstrates running Rocket.rs backend with Traefik reverse-proxy set up using Kubernetes manifests.

## Local setup

### Prerequisites

* `kubectl`, `helm` installed and configured.
* Rust for the backend (see rustup.rs)
* Access to a Kubernetes cluster (Minikube, kubeadm, Kind, GKE, EKS, AKS, etc.).
* Container runtime (`docker`, `podman`, etc.) for building images.

### Setup steps

1.  **Clone Repository**
    ```bash
    git clone https://github.com/krinistof/k8s-demo.git
    cd k8s-demo
    ```

2.  **Build  Image:**
    ```bash
    # Ensure image name in manifests/deployment.yaml matches
    cd secret-server
    docker build -t secret-server:latest .
    ```
3.  **Bootstrap Traefik**
    ```bash
    # Inside the repository's directory execute the following script
    ./bootstrap.sh
    ```
    Follow the instructions to setup custom DNS.

4.  **Deploy services:**
    Deploy resources (Deployment, Service, etc.) to the cluster.
    ```bash
    # Development setup
    helm upgrade --install dev-site ./helm/my-static-site -f ./helm/my-static-site/values-dev.yaml --namespace dev --create-namespace
    # Production setup
    helm upgrade --install prod-site ./helm/my-static-site -f ./helm/my-static-site/values-prod.yaml --namespace prod --create-namespace
    ```

### Execution & Verification

1.  **Check Pod Status:**
    Verify the application pods are running.
    ```bash
    kubectl get pods -n <dev/prod>
    # Wait for STATUS 'Running'
    ```

2.  **Access Service:**

    * **Request HTTPS(via cURL)**
        ```bash
        curl -k https://dev.my-static-site.local
        # Expected output: Hello World! I am on DEV stage. This is my secret: SuperSecretDevCode.
        curl -k https://prod.my-static-site.local
        # Expected output: Hello World! I am on PROD stage. This is my secret: TopSecretProdKey.
        ```
    Note: Visiting those sites via the browser is possible, but you will need to accept the warning due to Traefik's self-signed certificate. The `-k` flag tells cURL to trust the certificate.

### Cleanup

Remove demo resources from the cluster.
```bash
helm uninstall dev-site -n dev
helm uninstall prod-site -n prod
helm uninstall traefik -n traefik-system
```
