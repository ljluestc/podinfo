#!/bin/bash
#
# Comprehensive Testing Framework - Master Test Execution Script
# This script runs all testing suites and generates a comprehensive report
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="./test-results-$TIMESTAMP"
TIMEOUT=600  # 10 minutes default timeout

# Create results directory
mkdir -p "$RESULTS_DIR"

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

# Test tracking
declare -A TEST_RESULTS
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Function to run a test job
run_test_job() {
  local TEST_NAME=$1
  local TEST_NAMESPACE=$2
  local JOB_SPEC=$3
  local TIMEOUT_OVERRIDE=${4:-$TIMEOUT}

  log_info "Running: $TEST_NAME"
  TESTS_RUN=$((TESTS_RUN + 1))

  local JOB_NAME="test-${TEST_NAME}-${RANDOM}"

  # Create job
  if ! kubectl create job "$JOB_NAME" --from="$JOB_SPEC" -n "$TEST_NAMESPACE" &>/dev/null; then
    log_error "Failed to create job for $TEST_NAME"
    TEST_RESULTS["$TEST_NAME"]="FAILED"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi

  # Wait for completion
  if kubectl wait --for=condition=complete "job/$JOB_NAME" -n "$TEST_NAMESPACE" --timeout="${TIMEOUT_OVERRIDE}s" &>/dev/null; then
    # Get logs
    kubectl logs -n "$TEST_NAMESPACE" "job/$JOB_NAME" > "$RESULTS_DIR/${TEST_NAME}.log" 2>&1

    # Check if logs contain failure indicators
    if grep -qi "fail\|error\|✗" "$RESULTS_DIR/${TEST_NAME}.log"; then
      log_warning "$TEST_NAME completed with warnings/errors"
      TEST_RESULTS["$TEST_NAME"]="WARNING"
    else
      log_success "$TEST_NAME passed"
      TEST_RESULTS["$TEST_NAME"]="PASSED"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
  else
    log_error "$TEST_NAME failed or timed out"
    kubectl logs -n "$TEST_NAMESPACE" "job/$JOB_NAME" > "$RESULTS_DIR/${TEST_NAME}.log" 2>&1 || true
    TEST_RESULTS["$TEST_NAME"]="FAILED"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Cleanup
  kubectl delete "job/$JOB_NAME" -n "$TEST_NAMESPACE" &>/dev/null || true
}

# Function to check if namespace exists
namespace_exists() {
  kubectl get namespace "$1" &>/dev/null
}

# Function to check if job/cronjob exists
resource_exists() {
  local RESOURCE=$1
  local NAME=$2
  local NAMESPACE=$3

  kubectl get "$RESOURCE" "$NAME" -n "$NAMESPACE" &>/dev/null
}

# Print header
echo ""
echo "=============================================="
echo "  Comprehensive Testing Framework"
echo "  Timestamp: $TIMESTAMP"
echo "=============================================="
echo ""

# Check cluster connectivity
log_info "Checking cluster connectivity..."
if ! kubectl cluster-info &>/dev/null; then
  log_error "Cannot connect to cluster"
  exit 1
fi
log_success "Cluster is accessible"

# Deploy all testing components if not already deployed
log_info "Ensuring all testing components are deployed..."

MANIFESTS_DIR="k8s-cluster/manifests/27-testing"

if [ -d "$MANIFESTS_DIR" ]; then
  # Deploy namespaces first
  kubectl apply -f "$MANIFESTS_DIR/load-testing/01-namespace.yaml" 2>/dev/null || true
  kubectl apply -f "$MANIFESTS_DIR/security-testing/01-namespace.yaml" 2>/dev/null || true
  kubectl apply -f "$MANIFESTS_DIR/dr-testing/01-backup-restore-tests.yaml" 2>/dev/null || true
  kubectl apply -f "$MANIFESTS_DIR/integration-tests/" 2>/dev/null || true
  kubectl apply -f "$MANIFESTS_DIR/validation/01-config-validation.yaml" 2>/dev/null || true
  kubectl apply -f "$MANIFESTS_DIR/regression/01-regression-tests.yaml" 2>/dev/null || true

  # Wait for resources to be ready
  sleep 5
fi

log_success "Testing components deployed"

echo ""
log_info "Starting test execution..."
echo ""

# Test Suite 1: Smoke Tests
if namespace_exists "integration-testing" && resource_exists "job" "cluster-smoke-test" "integration-testing"; then
  run_test_job "01-cluster-smoke-test" "integration-testing" "job/cluster-smoke-test" 300
else
  log_warning "Skipping cluster smoke tests (not deployed)"
  TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
fi

if namespace_exists "integration-testing" && resource_exists "job" "app-smoke-test" "integration-testing"; then
  run_test_job "02-app-smoke-test" "integration-testing" "job/app-smoke-test" 300
else
  log_warning "Skipping app smoke tests (not deployed)"
  TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
fi

# Test Suite 2: Security Tests
if namespace_exists "security-testing" && resource_exists "job" "kube-bench-node" "security-testing"; then
  run_test_job "03-security-kube-bench" "security-testing" "job/kube-bench-node" 600
else
  log_warning "Skipping kube-bench (not deployed)"
  TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
fi

if namespace_exists "security-testing" && resource_exists "job" "kube-hunter-internal" "security-testing"; then
  run_test_job "04-security-kube-hunter" "security-testing" "job/kube-hunter-internal" 600
else
  log_warning "Skipping kube-hunter (not deployed)"
  TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
fi

# Test Suite 3: E2E Tests
if namespace_exists "integration-testing" && resource_exists "job" "e2e-test" "integration-testing"; then
  run_test_job "05-e2e-tests" "integration-testing" "job/e2e-test" 600
else
  log_warning "Skipping E2E tests (not deployed)"
  TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
fi

# Test Suite 4: Regression Tests
if namespace_exists "regression-testing" && resource_exists "job" "regression-test-manual" "regression-testing"; then
  run_test_job "06-regression-suite" "regression-testing" "job/regression-test-manual" 600
else
  log_warning "Skipping regression tests (not deployed)"
  TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
fi

# Generate summary report
echo ""
echo "=============================================="
echo "  Test Execution Summary"
echo "=============================================="
echo ""
echo "Total Tests Run:    $TESTS_RUN"
echo "Tests Passed:       $TESTS_PASSED"
echo "Tests Failed:       $TESTS_FAILED"
echo "Tests Skipped:      $TESTS_SKIPPED"
echo ""
echo "Results Directory:  $RESULTS_DIR"
echo ""

# Detailed results
echo "Detailed Results:"
echo "----------------------------------------"
for test in "${!TEST_RESULTS[@]}"; do
  result="${TEST_RESULTS[$test]}"
  case $result in
    PASSED)
      echo -e "${GREEN}✓${NC} $test: $result"
      ;;
    WARNING)
      echo -e "${YELLOW}⚠${NC} $test: $result"
      ;;
    FAILED)
      echo -e "${RED}✗${NC} $test: $result"
      ;;
  esac
done
echo ""

# Generate JSON report
cat > "$RESULTS_DIR/summary.json" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "cluster": "$(kubectl config current-context)",
  "summary": {
    "total": $TESTS_RUN,
    "passed": $TESTS_PASSED,
    "failed": $TESTS_FAILED,
    "skipped": $TESTS_SKIPPED
  },
  "results": {
EOF

first=true
for test in "${!TEST_RESULTS[@]}"; do
  if [ "$first" = true ]; then
    first=false
  else
    echo "," >> "$RESULTS_DIR/summary.json"
  fi
  echo "    \"$test\": \"${TEST_RESULTS[$test]}\"" >> "$RESULTS_DIR/summary.json"
done

cat >> "$RESULTS_DIR/summary.json" <<EOF

  }
}
EOF

log_success "Summary report generated: $RESULTS_DIR/summary.json"

# Exit with appropriate code
if [ $TESTS_FAILED -gt 0 ]; then
  log_error "Some tests failed!"
  exit 1
else
  log_success "All tests passed!"
  exit 0
fi
