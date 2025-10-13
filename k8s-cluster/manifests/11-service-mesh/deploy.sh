#!/bin/bash
# Service Mesh Deployment Script
# This script deploys Istio service mesh with all components

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ISTIO_VERSION="${ISTIO_VERSION:-1.20.0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi

    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster."
        exit 1
    fi

    # Check istioctl
    if ! command -v istioctl &> /dev/null; then
        log_warn "istioctl not found. Will download Istio."
        download_istio
    fi

    log_info "Prerequisites check completed."
}

download_istio() {
    log_info "Downloading Istio ${ISTIO_VERSION}..."

    cd /tmp
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -

    export PATH="/tmp/istio-${ISTIO_VERSION}/bin:$PATH"

    log_info "Istio downloaded to /tmp/istio-${ISTIO_VERSION}"
    log_warn "Add to PATH permanently: export PATH=\"/tmp/istio-${ISTIO_VERSION}/bin:\$PATH\""
}

install_istio_operator() {
    log_info "Installing Istio operator..."

    istioctl operator init

    log_info "Waiting for operator to be ready..."
    kubectl wait --for=condition=available --timeout=300s \
        deployment/istio-operator -n istio-operator

    log_info "Istio operator installed successfully."
}

deploy_istio_control_plane() {
    log_info "Deploying Istio control plane..."

    # Create istio-system namespace
    kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -

    # Deploy IstioOperator
    kubectl apply -f "${SCRIPT_DIR}/00-istio-operator.yaml"

    log_info "Waiting for Istio control plane to be ready (this may take 2-3 minutes)..."
    kubectl wait --for=condition=available --timeout=300s \
        deployment/istiod -n istio-system

    log_info "Istio control plane deployed successfully."
}

configure_mtls() {
    log_info "Configuring mTLS and security policies..."

    kubectl apply -f "${SCRIPT_DIR}/01-mtls-security.yaml"

    log_info "mTLS and security policies configured."
}

deploy_observability() {
    log_info "Deploying observability components..."

    # Create observability namespace
    kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

    # Check if Jaeger operator is installed
    if ! kubectl get crd jaegers.jaegertracing.io &> /dev/null; then
        log_warn "Jaeger operator not found. Installing..."
        kubectl apply -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.51.0/jaeger-operator.yaml -n observability

        log_info "Waiting for Jaeger operator..."
        sleep 30
    fi

    # Deploy distributed tracing
    kubectl apply -f "${SCRIPT_DIR}/03-distributed-tracing.yaml"

    # Deploy observability dashboards
    kubectl apply -f "${SCRIPT_DIR}/04-observability.yaml"

    log_info "Observability components deployed."
}

install_monitoring() {
    log_info "Checking monitoring stack..."

    if ! kubectl get namespace monitoring &> /dev/null; then
        log_warn "Monitoring namespace not found. Installing Prometheus stack..."

        # Check helm
        if ! command -v helm &> /dev/null; then
            log_error "Helm not found. Please install Helm to deploy monitoring."
            log_warn "Skipping monitoring installation. Install manually with:"
            log_warn "  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts"
            log_warn "  helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring --create-namespace"
            return
        fi

        # Add Prometheus Helm repo
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo update

        # Install Prometheus stack
        helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
            --namespace monitoring \
            --create-namespace \
            --set prometheus.prometheusSpec.retention=30d \
            --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi \
            --wait

        log_info "Prometheus stack installed."
    else
        log_info "Monitoring namespace exists. Assuming monitoring stack is installed."
    fi
}

enable_sidecar_injection() {
    log_info "Enabling sidecar injection..."

    # Apply namespace configurations
    kubectl apply -f "${SCRIPT_DIR}/05-namespace-config.yaml"

    # Label namespaces for injection
    kubectl label namespace podinfo istio-injection=enabled --overwrite
    kubectl label namespace default istio-injection=enabled --overwrite

    log_info "Sidecar injection enabled."
}

configure_traffic_management() {
    log_info "Configuring traffic management..."

    kubectl apply -f "${SCRIPT_DIR}/02-traffic-management.yaml"

    log_info "Traffic management configured."
}

restart_workloads() {
    log_info "Restarting workloads to inject sidecars..."

    # Restart podinfo if it exists
    if kubectl get deployment podinfo -n podinfo &> /dev/null; then
        kubectl rollout restart deployment/podinfo -n podinfo
        log_info "Waiting for podinfo rollout..."
        kubectl rollout status deployment/podinfo -n podinfo --timeout=300s
    else
        log_warn "Podinfo deployment not found. Skipping restart."
    fi

    log_info "Workloads restarted."
}

verify_installation() {
    log_info "Verifying installation..."

    # Verify Istio installation
    istioctl verify-install

    # Check control plane pods
    log_info "Control plane pods:"
    kubectl get pods -n istio-system

    # Check mTLS
    log_info "Checking mTLS configuration:"
    kubectl get peerauthentication -A

    # Check observability pods
    log_info "Observability pods:"
    kubectl get pods -n observability

    log_info "Installation verification completed."
}

run_tests() {
    log_info "Running test suite..."

    # Deploy test suite
    kubectl apply -f "${SCRIPT_DIR}/06-test-suite.yaml"

    log_info "Waiting for tests to complete..."
    kubectl wait --for=condition=complete --timeout=300s job/mesh-test-runner -n mesh-test || true

    log_info "Test results:"
    kubectl logs -n mesh-test job/mesh-test-runner --tail=100
}

print_access_info() {
    log_info "==============================================="
    log_info "Service Mesh Deployment Completed!"
    log_info "==============================================="
    echo ""
    log_info "Access Istio components:"
    echo ""
    echo "  # Kiali (Service Mesh Visualization)"
    echo "  kubectl port-forward -n istio-system svc/kiali 20001:20001"
    echo "  http://localhost:20001/kiali"
    echo ""
    echo "  # Jaeger (Distributed Tracing)"
    echo "  kubectl port-forward -n observability svc/jaeger-query 16686:16686"
    echo "  http://localhost:16686"
    echo ""
    echo "  # Grafana (Metrics Dashboards)"
    echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
    echo "  http://localhost:3000"
    echo ""
    echo "  # Prometheus (Metrics)"
    echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
    echo "  http://localhost:9090"
    echo ""
    log_info "Useful commands:"
    echo ""
    echo "  # Check mesh status"
    echo "  istioctl proxy-status"
    echo ""
    echo "  # Analyze configuration"
    echo "  istioctl analyze -A"
    echo ""
    echo "  # Check mTLS for a service"
    echo "  istioctl authn tls-check <pod-name>.<namespace> <service>.<namespace>.svc.cluster.local"
    echo ""
    echo "  # View proxy logs"
    echo "  kubectl logs -n <namespace> <pod-name> -c istio-proxy"
    echo ""
    log_info "Documentation: ${SCRIPT_DIR}/README.md"
    log_info "==============================================="
}

# Main deployment flow
main() {
    log_info "Starting Istio Service Mesh deployment..."
    log_info "Istio version: ${ISTIO_VERSION}"
    echo ""

    # Check prerequisites
    check_prerequisites

    # Install Istio operator
    if ! kubectl get deployment istio-operator -n istio-operator &> /dev/null; then
        install_istio_operator
    else
        log_info "Istio operator already installed. Skipping."
    fi

    # Deploy Istio control plane
    if ! kubectl get deployment istiod -n istio-system &> /dev/null; then
        deploy_istio_control_plane
    else
        log_info "Istio control plane already deployed. Updating configuration..."
        kubectl apply -f "${SCRIPT_DIR}/00-istio-operator.yaml"
    fi

    # Configure mTLS
    configure_mtls

    # Install monitoring (if needed)
    install_monitoring

    # Deploy observability
    deploy_observability

    # Enable sidecar injection
    enable_sidecar_injection

    # Configure traffic management
    configure_traffic_management

    # Restart workloads
    restart_workloads

    # Verify installation
    verify_installation

    # Run tests (optional)
    read -p "Run test suite? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        run_tests
    fi

    # Print access information
    print_access_info
}

# Run main function
main "$@"
