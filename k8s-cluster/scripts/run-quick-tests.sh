#!/bin/bash
#
# Quick Test Suite - Fast validation of cluster health
# This script runs a minimal set of tests for quick validation
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Print header
echo ""
echo "=============================================="
echo "  Quick Test Suite"
echo "=============================================="
echo ""

# Check cluster connectivity
log_info "Checking cluster connectivity..."
if ! kubectl cluster-info &>/dev/null; then
  log_error "Cannot connect to cluster"
  exit 1
fi
log_success "Cluster is accessible"

FAILED=0

# Test 1: Node Health
log_info "Test 1: Checking node health..."
if kubectl get nodes | grep -q "Ready"; then
  log_success "All nodes are ready"
else
  log_error "Some nodes are not ready"
  FAILED=$((FAILED + 1))
fi

# Test 2: System Pods
log_info "Test 2: Checking system pods..."
NOT_RUNNING=$(kubectl get pods -n kube-system --no-headers | grep -v "Running\|Completed" | wc -l)
if [ "$NOT_RUNNING" -eq "0" ]; then
  log_success "All system pods are running"
else
  log_error "$NOT_RUNNING system pods are not running"
  FAILED=$((FAILED + 1))
fi

# Test 3: DNS Resolution
log_info "Test 3: Testing DNS resolution..."
if kubectl run test-dns-$RANDOM --image=busybox:latest --restart=Never --rm -i --quiet -- nslookup kubernetes.default.svc.cluster.local &>/dev/null; then
  log_success "DNS resolution working"
else
  log_error "DNS resolution failed"
  FAILED=$((FAILED + 1))
fi

# Test 4: API Server Health
log_info "Test 4: Testing API server health..."
if kubectl get --raw /healthz &>/dev/null; then
  log_success "API server is healthy"
else
  log_error "API server health check failed"
  FAILED=$((FAILED + 1))
fi

# Test 5: Pod Creation
log_info "Test 5: Testing pod creation..."
if kubectl run test-pod-$RANDOM --image=nginx:alpine --restart=Never --rm -i --quiet --command -- echo "test" &>/dev/null; then
  log_success "Pod creation working"
else
  log_error "Pod creation failed"
  FAILED=$((FAILED + 1))
fi

# Summary
echo ""
echo "=============================================="
echo "  Quick Test Results"
echo "=============================================="
echo ""

if [ $FAILED -eq 0 ]; then
  log_success "All quick tests passed!"
  echo ""
  echo "Your cluster appears to be healthy."
  echo "Run './run-all-tests.sh' for comprehensive testing."
  exit 0
else
  log_error "$FAILED test(s) failed!"
  echo ""
  echo "Some issues were detected. Please investigate."
  exit 1
fi
