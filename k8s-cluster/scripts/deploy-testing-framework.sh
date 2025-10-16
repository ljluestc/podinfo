#!/bin/bash
#
# Deploy Comprehensive Testing Framework
# This script deploys all testing components to the Kubernetes cluster
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Print header
echo ""
echo "=============================================="
echo "  Deploy Testing Framework"
echo "=============================================="
echo ""

# Check cluster connectivity
log_info "Checking cluster connectivity..."
if ! kubectl cluster-info &>/dev/null; then
  log_error "Cannot connect to cluster"
  exit 1
fi
log_success "Cluster is accessible"

# Check if manifests directory exists
MANIFESTS_DIR="k8s-cluster/manifests/27-testing"

if [ ! -d "$MANIFESTS_DIR" ]; then
  log_error "Manifests directory not found: $MANIFESTS_DIR"
  exit 1
fi

cd "$MANIFESTS_DIR"

# Deploy Conformance Testing
log_info "Deploying conformance testing..."
kubectl apply -f 01-conformance-testing.yaml
log_success "Conformance testing deployed"

# Deploy Chaos Mesh namespace
log_info "Deploying Chaos Mesh namespace..."
kubectl apply -f chaos-mesh/01-namespace.yaml
log_warning "Chaos Mesh requires Helm installation. Run:"
echo "  helm repo add chaos-mesh https://charts.chaos-mesh.org"
echo "  helm install chaos-mesh chaos-mesh/chaos-mesh --namespace=chaos-testing"

# Deploy Load Testing
log_info "Deploying load testing..."
kubectl apply -f load-testing/
log_success "Load testing deployed"

# Deploy Security Testing
log_info "Deploying security testing..."
kubectl apply -f security-testing/
log_success "Security testing deployed"

# Deploy DR Testing
log_info "Deploying disaster recovery testing..."
kubectl apply -f dr-testing/
log_success "DR testing deployed"

# Deploy Integration Tests
log_info "Deploying integration tests..."
kubectl apply -f integration-tests/
log_success "Integration tests deployed"

# Deploy Validation
log_info "Deploying continuous validation..."
kubectl apply -f validation/
log_success "Validation deployed"

# Deploy Regression Tests
log_info "Deploying regression tests..."
kubectl apply -f regression/
log_success "Regression tests deployed"

# Wait for components to be ready
log_info "Waiting for components to be ready..."
sleep 10

# Verify deployments
echo ""
log_info "Verifying deployments..."

NAMESPACES=(
  "sonobuoy"
  "chaos-testing"
  "load-testing"
  "security-testing"
  "dr-testing"
  "integration-testing"
  "validation-testing"
  "regression-testing"
)

for ns in "${NAMESPACES[@]}"; do
  if kubectl get namespace "$ns" &>/dev/null; then
    log_success "Namespace $ns exists"
  else
    log_warning "Namespace $ns not found"
  fi
done

# Print summary
echo ""
echo "=============================================="
echo "  Deployment Summary"
echo "=============================================="
echo ""
echo "The following testing components have been deployed:"
echo ""
echo "1. Conformance Testing (Sonobuoy)"
echo "   - Namespace: sonobuoy"
echo "   - Schedule: Weekly (Sunday 2 AM)"
echo ""
echo "2. Chaos Engineering (Chaos Mesh)"
echo "   - Namespace: chaos-testing"
echo "   - Note: Requires Helm installation"
echo ""
echo "3. Load Testing (k6 + Locust)"
echo "   - Namespace: load-testing"
echo "   - Schedule: Daily (4 AM)"
echo ""
echo "4. Security Testing"
echo "   - Namespace: security-testing"
echo "   - kube-bench: Weekly (Monday 3 AM)"
echo "   - kube-hunter: Weekly (Monday 2 AM)"
echo "   - Trivy: Daily (1 AM)"
echo ""
echo "5. Disaster Recovery Testing"
echo "   - Namespace: dr-testing"
echo "   - Schedule: Weekly (Sunday 5 AM)"
echo ""
echo "6. Integration Testing"
echo "   - Namespace: integration-testing"
echo "   - Smoke tests: Every 30 minutes"
echo "   - E2E tests: Every 6 hours"
echo ""
echo "7. Continuous Validation"
echo "   - Namespace: validation-testing"
echo "   - Manifests: Every 4 hours"
echo "   - Policies: Every 15 minutes"
echo "   - Security: Every 6 hours"
echo ""
echo "8. Regression Testing"
echo "   - Namespace: regression-testing"
echo "   - Schedule: Daily (6 AM)"
echo ""

log_success "Testing framework deployment complete!"
echo ""
echo "Next steps:"
echo "1. Install Chaos Mesh using Helm (see instructions above)"
echo "2. Run quick tests: ./run-quick-tests.sh"
echo "3. Run full test suite: ./run-all-tests.sh"
echo "4. View test schedules: kubectl get cronjobs -A"
echo ""
