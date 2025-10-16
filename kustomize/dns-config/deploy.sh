#!/bin/bash
set -euo pipefail

# DNS Configuration Deployment Script
# This script deploys the complete DNS and service discovery configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=${DRY_RUN:-false}

echo "=================================================="
echo "DNS Configuration Deployment"
echo "=================================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi

    if command -v kustomize &> /dev/null; then
        log_info "Found kustomize: $(kustomize version --short 2>/dev/null || kustomize version)"
    else
        log_warn "kustomize not found, will use kubectl kustomize"
    fi

    log_info "Prerequisites check passed"
    echo ""
}

# Validate YAML files
validate_manifests() {
    log_info "Validating manifest files..."

    local errors=0
    for file in "$SCRIPT_DIR"/*.yaml; do
        if [ -f "$file" ] && [ "$(basename "$file")" != "kustomization.yaml" ]; then
            if ! kubectl apply --dry-run=client -f "$file" &> /dev/null; then
                log_error "Validation failed for $(basename "$file")"
                ((errors++))
            fi
        fi
    done

    if [ $errors -gt 0 ]; then
        log_error "$errors file(s) failed validation"
        exit 1
    fi

    log_info "All manifests validated successfully"
    echo ""
}

# Deploy CoreDNS configuration
deploy_coredns() {
    log_info "Deploying CoreDNS customizations..."

    kubectl apply -f "$SCRIPT_DIR/coredns-custom-configmap.yaml"

    log_info "Restarting CoreDNS to apply configuration..."
    kubectl rollout restart -n kube-system deployment/coredns
    kubectl rollout status -n kube-system deployment/coredns --timeout=120s

    log_info "CoreDNS configuration deployed successfully"
    echo ""
}

# Deploy External DNS
deploy_external_dns() {
    log_info "Deploying External DNS..."

    kubectl apply -f "$SCRIPT_DIR/external-dns-deployment.yaml"

    log_info "Waiting for External DNS to be ready..."
    kubectl wait --for=condition=available --timeout=120s \
        -n kube-system deployment/external-dns

    log_info "External DNS deployed successfully"
    echo ""
}

# Deploy service discovery examples
deploy_service_discovery() {
    log_info "Deploying service discovery examples..."

    kubectl apply -f "$SCRIPT_DIR/service-discovery-examples.yaml"

    log_info "Service discovery examples deployed"
    echo ""
}

# Deploy split-horizon DNS
deploy_split_horizon() {
    log_info "Deploying split-horizon DNS configuration..."

    kubectl apply -f "$SCRIPT_DIR/split-horizon-dns.yaml"

    log_info "Split-horizon DNS configuration deployed"
    echo ""
}

# Deploy DNS load balancing
deploy_load_balancing() {
    log_info "Deploying DNS load balancing configuration..."

    kubectl apply -f "$SCRIPT_DIR/dns-load-balancing.yaml"

    log_info "DNS load balancing configuration deployed"
    echo ""
}

# Deploy monitoring
deploy_monitoring() {
    log_info "Deploying DNS monitoring..."

    # Check if Prometheus Operator is installed
    if kubectl get crd servicemonitors.monitoring.coreos.com &> /dev/null; then
        kubectl apply -f "$SCRIPT_DIR/dns-monitoring.yaml"
        log_info "DNS monitoring deployed successfully"
    else
        log_warn "Prometheus Operator not found, skipping ServiceMonitor and PrometheusRule deployment"
        log_warn "Deploying only the debug tools pod..."
        kubectl apply -f "$SCRIPT_DIR/dns-monitoring.yaml" || true
    fi

    echo ""
}

# Run tests
run_tests() {
    log_info "Running DNS configuration tests..."

    # Deploy test pod
    kubectl run dns-test-pod --image=busybox:1.28 --rm -i --restart=Never \
        --command -- sh -c '
        echo "Testing DNS resolution..."
        echo ""
        echo "1. Testing Kubernetes DNS:"
        nslookup kubernetes.default || true
        echo ""
        echo "2. Testing external DNS:"
        nslookup google.com || true
        echo ""
        echo "3. Testing service discovery:"
        nslookup podinfo-internal.default.svc.cluster.local || true
        echo ""
        echo "DNS tests completed"
    ' || log_warn "Some DNS tests may have failed (this is expected if services don't exist yet)"

    echo ""
}

# Display deployment status
show_status() {
    log_info "Deployment Status:"
    echo ""

    echo "CoreDNS:"
    kubectl get pods -n kube-system -l k8s-app=kube-dns
    echo ""

    echo "External DNS:"
    kubectl get pods -n kube-system -l app.kubernetes.io/name=external-dns
    echo ""

    echo "DNS Debug Tools:"
    kubectl get pods -n kube-system -l app=dns-debug-tools
    echo ""

    echo "Services:"
    kubectl get svc -n default | grep podinfo || echo "No podinfo services found"
    echo ""
}

# Main deployment flow
main() {
    check_prerequisites

    if [ "$DRY_RUN" = "true" ]; then
        log_warn "Running in DRY-RUN mode - no changes will be applied"
        echo ""
    fi

    validate_manifests

    deploy_coredns
    deploy_external_dns
    deploy_service_discovery
    deploy_split_horizon
    deploy_load_balancing
    deploy_monitoring

    show_status

    # Optionally run tests
    read -p "Run DNS tests? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        run_tests
    fi

    echo ""
    log_info "=================================================="
    log_info "DNS Configuration Deployment Complete!"
    log_info "=================================================="
    echo ""
    log_info "Next steps:"
    echo "  1. Review the deployment status above"
    echo "  2. Check logs: kubectl logs -n kube-system -l k8s-app=kube-dns"
    echo "  3. Check External DNS logs: kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns"
    echo "  4. Run troubleshooting if needed: kubectl exec -n kube-system deploy/dns-debug-tools -- bash"
    echo "  5. Read the README.md for detailed usage instructions"
    echo ""
}

# Run main function
main "$@"
