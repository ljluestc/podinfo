#!/bin/bash
# deploy-argocd-canary.sh
# Complete deployment script for ArgoCD and Argo Rollouts canary deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl first."
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        print_error "Unable to connect to Kubernetes cluster."
        exit 1
    fi

    print_success "Prerequisites check passed"
}

# Install ArgoCD
install_argocd() {
    print_info "Installing ArgoCD..."

    # Create namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

    # Install ArgoCD
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    # Wait for ArgoCD to be ready
    print_info "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-repo-server -n argocd
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-dex-server -n argocd

    # Apply custom ArgoCD configuration
    if [ -f "../manifests/14-cicd/argocd-install.yaml" ]; then
        kubectl apply -f ../manifests/14-cicd/argocd-install.yaml
    fi

    print_success "ArgoCD installed successfully"
}

# Install Argo Rollouts
install_argo_rollouts() {
    print_info "Installing Argo Rollouts..."

    # Create namespace
    kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -

    # Install Argo Rollouts
    kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

    # Apply custom Argo Rollouts configuration
    kubectl apply -f ../manifests/14-cicd/argo-rollouts-install.yaml

    # Wait for Argo Rollouts to be ready
    print_info "Waiting for Argo Rollouts to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argo-rollouts -n argo-rollouts

    print_success "Argo Rollouts installed successfully"
}

# Deploy Podinfo with Rollout
deploy_podinfo() {
    print_info "Deploying Podinfo with canary rollout..."

    # Create podinfo namespace
    kubectl create namespace podinfo --dry-run=client -o yaml | kubectl apply -f -

    # Apply all podinfo manifests
    kubectl apply -f ../manifests/14-cicd/podinfo-rollout.yaml
    kubectl apply -f ../manifests/14-cicd/podinfo-analysis-templates.yaml
    kubectl apply -f ../manifests/14-cicd/podinfo-monitoring.yaml
    kubectl apply -f ../manifests/14-cicd/podinfo-ingress.yaml

    print_info "Waiting for podinfo rollout to be healthy..."
    kubectl argo rollouts status podinfo -n podinfo --timeout 5m || true

    print_success "Podinfo deployed successfully"
}

# Deploy ArgoCD Application
deploy_argocd_application() {
    print_info "Creating ArgoCD Application for Podinfo..."

    kubectl apply -f ../manifests/14-cicd/podinfo-argocd-application.yaml

    print_success "ArgoCD Application created"
}

# Install monitoring (if not already installed)
setup_monitoring() {
    print_info "Setting up monitoring..."

    # Check if Prometheus is installed
    if kubectl get namespace monitoring &> /dev/null; then
        print_info "Monitoring namespace exists, applying ServiceMonitors..."
        kubectl apply -f ../manifests/14-cicd/podinfo-monitoring.yaml

        # Apply Grafana dashboard
        kubectl apply -f ../manifests/14-cicd/podinfo-grafana-dashboard.yaml

        print_success "Monitoring configured"
    else
        print_warning "Monitoring namespace not found. Skipping ServiceMonitor deployment."
        print_info "To install Prometheus and Grafana, run:"
        print_info "  kubectl apply -f ../manifests/12-observability/"
    fi
}

# Get ArgoCD admin password
get_argocd_password() {
    print_info "Retrieving ArgoCD admin password..."

    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

    echo ""
    print_success "ArgoCD Login Credentials:"
    echo -e "  ${BLUE}Username:${NC} admin"
    echo -e "  ${BLUE}Password:${NC} $ARGOCD_PASSWORD"
    echo ""

    print_info "To access ArgoCD UI:"
    echo -e "  ${BLUE}kubectl port-forward svc/argocd-server -n argocd 8080:443${NC}"
    echo -e "  Then visit: ${BLUE}https://localhost:8080${NC}"
    echo ""
}

# Get Argo Rollouts dashboard
get_rollouts_dashboard() {
    print_info "To access Argo Rollouts dashboard:"
    echo -e "  ${BLUE}kubectl argo rollouts dashboard -n podinfo${NC}"
    echo -e "  Or use port-forward:"
    echo -e "  ${BLUE}kubectl port-forward svc/argo-rollouts-dashboard -n argo-rollouts 3100:3100${NC}"
    echo ""
}

# Display status
display_status() {
    echo ""
    print_success "=== Deployment Complete ==="
    echo ""

    print_info "Cluster Resources:"
    kubectl get all -n argocd | head -10
    echo ""
    kubectl get all -n argo-rollouts
    echo ""
    kubectl get rollout,service,ingress -n podinfo
    echo ""

    get_argocd_password
    get_rollouts_dashboard

    print_info "Next steps:"
    echo "  1. Access ArgoCD UI and login"
    echo "  2. Monitor canary rollout in Argo Rollouts dashboard"
    echo "  3. View metrics in Grafana dashboard"
    echo "  4. Test canary deployment:"
    echo -e "     ${BLUE}kubectl argo rollouts set image podinfo podinfo=ghcr.io/stefanprodan/podinfo:6.9.3 -n podinfo${NC}"
    echo ""
}

# Main deployment flow
main() {
    echo -e "${BLUE}"
    echo "========================================="
    echo " ArgoCD Canary Deployment Setup"
    echo "========================================="
    echo -e "${NC}"

    check_prerequisites

    if [ "$1" == "--skip-argocd" ]; then
        print_warning "Skipping ArgoCD installation"
    else
        install_argocd
    fi

    if [ "$1" == "--skip-rollouts" ]; then
        print_warning "Skipping Argo Rollouts installation"
    else
        install_argo_rollouts
    fi

    deploy_podinfo
    deploy_argocd_application
    setup_monitoring

    display_status

    print_success "Deployment completed successfully!"
}

# Run main function
main "$@"
