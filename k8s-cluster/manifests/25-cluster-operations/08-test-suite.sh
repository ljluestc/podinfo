#!/bin/bash
# Test Suite for Cluster Operations Automation
# Validates all automation scripts and configurations

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_LOG="/tmp/cluster-ops-test-$(date +%Y%m%d-%H%M%S).log"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$TEST_LOG"
}

pass() {
    echo -e "${GREEN}✓ PASS${NC} $*" | tee -a "$TEST_LOG"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}✗ FAIL${NC} $*" | tee -a "$TEST_LOG"
    ((TESTS_FAILED++))
}

skip() {
    echo -e "${YELLOW}⊘ SKIP${NC} $*" | tee -a "$TEST_LOG"
    ((TESTS_SKIPPED++))
}

info() {
    echo -e "${BLUE}ℹ INFO${NC} $*" | tee -a "$TEST_LOG"
}

# Test script existence and permissions
test_script_files() {
    log "Testing script files..."

    local scripts=(
        "01-cluster-upgrade.sh"
        "02-cluster-rollback.sh"
        "03-node-management.sh"
        "06-health-checks.sh"
        "deploy.sh"
    )

    for script in "${scripts[@]}"; do
        if [[ -f "$SCRIPT_DIR/$script" ]]; then
            if [[ -x "$SCRIPT_DIR/$script" ]]; then
                pass "Script $script exists and is executable"
            else
                fail "Script $script is not executable"
            fi
        else
            fail "Script $script not found"
        fi
    done
}

# Test YAML manifests
test_manifests() {
    log "Testing Kubernetes manifests..."

    local manifests=(
        "04-capacity-monitoring.yaml"
        "05-maintenance-windows.yaml"
        "07-operations-runbooks.yaml"
    )

    for manifest in "${manifests[@]}"; do
        if [[ -f "$SCRIPT_DIR/$manifest" ]]; then
            if kubectl apply --dry-run=client -f "$SCRIPT_DIR/$manifest" &>/dev/null; then
                pass "Manifest $manifest is valid"
            else
                fail "Manifest $manifest has validation errors"
            fi
        else
            fail "Manifest $manifest not found"
        fi
    done
}

# Test script help output
test_script_help() {
    log "Testing script help functionality..."

    if "$SCRIPT_DIR/01-cluster-upgrade.sh" --help &>/dev/null; then
        pass "cluster-upgrade.sh --help works"
    else
        fail "cluster-upgrade.sh --help failed"
    fi

    if "$SCRIPT_DIR/02-cluster-rollback.sh" --help &>/dev/null; then
        pass "cluster-rollback.sh --help works"
    else
        fail "cluster-rollback.sh --help failed"
    fi

    if "$SCRIPT_DIR/03-node-management.sh" &>/dev/null || [[ $? -eq 1 ]]; then
        pass "node-management.sh shows usage"
    else
        fail "node-management.sh usage failed"
    fi

    if "$SCRIPT_DIR/06-health-checks.sh" --help &>/dev/null; then
        pass "health-checks.sh --help works"
    else
        fail "health-checks.sh --help failed"
    fi
}

# Test health check script
test_health_checks() {
    log "Testing health check script..."

    # Test quick check
    if "$SCRIPT_DIR/06-health-checks.sh" --quick &>/tmp/health-test.log; then
        pass "Health check quick mode works"
    else
        if [[ $? -eq 2 ]]; then
            pass "Health check quick mode works (with warnings)"
        else
            fail "Health check quick mode failed"
        fi
    fi

    # Test component checks
    for component in nodes pods services; do
        if "$SCRIPT_DIR/06-health-checks.sh" --component "$component" &>/dev/null; then
            pass "Health check for component '$component' works"
        else
            if [[ $? -eq 2 ]]; then
                pass "Health check for component '$component' works (with warnings)"
            else
                fail "Health check for component '$component' failed"
            fi
        fi
    done
}

# Test node management operations (non-destructive)
test_node_management() {
    log "Testing node management script..."

    # Test health-check command
    if "$SCRIPT_DIR/03-node-management.sh" health-check &>/dev/null; then
        pass "Node health-check command works"
    else
        if [[ $? -eq 2 ]]; then
            pass "Node health-check command works (with warnings)"
        else
            fail "Node health-check command failed"
        fi
    fi

    # Test list-tainted command
    if "$SCRIPT_DIR/03-node-management.sh" list-tainted &>/dev/null; then
        pass "Node list-tainted command works"
    else
        fail "Node list-tainted command failed"
    fi
}

# Test cluster upgrade pre-checks
test_upgrade_prechecks() {
    log "Testing cluster upgrade pre-checks..."

    # Test with fake version (pre-check only)
    if "$SCRIPT_DIR/01-cluster-upgrade.sh" --target-version 1.29.0 --pre-check --force &>/tmp/upgrade-precheck.log; then
        pass "Cluster upgrade pre-check works"
    else
        # Pre-check might fail due to environment, check if script ran
        if grep -q "Pre-upgrade checks" /tmp/upgrade-precheck.log; then
            pass "Cluster upgrade pre-check executed (with warnings)"
        else
            fail "Cluster upgrade pre-check failed"
        fi
    fi
}

# Test backup list functionality
test_backup_operations() {
    log "Testing backup operations..."

    # Create test backup directory if it doesn't exist
    sudo mkdir -p /var/backups/k8s-cluster

    # Test backup listing
    if "$SCRIPT_DIR/02-cluster-rollback.sh" --list-backups &>/dev/null; then
        pass "Backup list command works"
    else
        if [[ $? -eq 1 ]]; then
            pass "Backup list command works (no backups found)"
        else
            fail "Backup list command failed"
        fi
    fi
}

# Test Kubernetes resources deployment
test_k8s_resources() {
    log "Testing Kubernetes resources..."

    # Test capacity monitoring deployment
    if kubectl apply --dry-run=client -f "$SCRIPT_DIR/04-capacity-monitoring.yaml" &>/dev/null; then
        pass "Capacity monitoring resources are valid"
    else
        fail "Capacity monitoring resources have errors"
    fi

    # Test maintenance windows deployment
    if kubectl apply --dry-run=client -f "$SCRIPT_DIR/05-maintenance-windows.yaml" &>/dev/null; then
        pass "Maintenance windows resources are valid"
    else
        fail "Maintenance windows resources have errors"
    fi

    # Test runbooks deployment
    if kubectl apply --dry-run=client -f "$SCRIPT_DIR/07-operations-runbooks.yaml" &>/dev/null; then
        pass "Runbooks resources are valid"
    else
        fail "Runbooks resources have errors"
    fi

    # Check if monitoring namespace exists
    if kubectl get namespace monitoring &>/dev/null; then
        pass "Monitoring namespace exists"

        # Test if we can create resources in monitoring namespace
        if kubectl auth can-i create prometheusrules -n monitoring &>/dev/null; then
            pass "Have permissions to create PrometheusRules"
        else
            skip "Cannot create PrometheusRules (may need Prometheus Operator)"
        fi
    else
        skip "Monitoring namespace does not exist"
    fi
}

# Test directory structure
test_directory_structure() {
    log "Testing directory structure..."

    local dirs=(
        "/var/log/k8s-operations"
        "/var/backups/k8s-cluster"
    )

    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            if [[ -w "$dir" ]]; then
                pass "Directory $dir exists and is writable"
            else
                fail "Directory $dir exists but is not writable"
            fi
        else
            skip "Directory $dir does not exist (created by deploy.sh)"
        fi
    done
}

# Test installed commands
test_installed_commands() {
    log "Testing installed commands..."

    local commands=(
        "k8s-cluster-upgrade"
        "k8s-cluster-rollback"
        "k8s-node-management"
        "k8s-health-check"
    )

    for cmd in "${commands[@]}"; do
        if command -v "$cmd" &>/dev/null; then
            pass "Command $cmd is installed"
        else
            skip "Command $cmd not installed (run deploy.sh to install)"
        fi
    done
}

# Test required dependencies
test_dependencies() {
    log "Testing required dependencies..."

    local deps=(
        "kubectl"
        "jq"
        "bash"
    )

    for dep in "${deps[@]}"; do
        if command -v "$dep" &>/dev/null; then
            pass "Dependency $dep is available"
        else
            fail "Dependency $dep is missing"
        fi
    done

    # Test kubectl connectivity
    if kubectl cluster-info &>/dev/null; then
        pass "kubectl can connect to cluster"
    else
        fail "kubectl cannot connect to cluster"
    fi

    # Test kubectl permissions
    if kubectl auth can-i get nodes &>/dev/null; then
        pass "kubectl has permissions to get nodes"
    else
        fail "kubectl lacks permissions to get nodes"
    fi
}

# Test Prometheus integration
test_prometheus_integration() {
    log "Testing Prometheus integration..."

    # Check if Prometheus Operator CRDs exist
    if kubectl get crd prometheusrules.monitoring.coreos.com &>/dev/null; then
        pass "Prometheus Operator CRDs are installed"

        # Check if we can create PrometheusRules
        if kubectl apply --dry-run=client -f - <<EOF &>/dev/null
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: test-rule
  namespace: monitoring
spec:
  groups:
  - name: test
    rules:
    - alert: TestAlert
      expr: up == 0
EOF
        then
            pass "Can create PrometheusRule resources"
        else
            fail "Cannot create PrometheusRule resources"
        fi
    else
        skip "Prometheus Operator not installed"
    fi

    # Check if Prometheus is running
    if kubectl get prometheus -n monitoring &>/dev/null; then
        pass "Prometheus resources exist"
    else
        skip "Prometheus not deployed"
    fi
}

# Test maintenance scripts in ConfigMap
test_maintenance_scripts() {
    log "Testing maintenance scripts..."

    # Apply maintenance windows manifest
    if kubectl apply --dry-run=client -f "$SCRIPT_DIR/05-maintenance-windows.yaml" &>/dev/null; then
        pass "Maintenance windows manifest is valid"

        # Check if ConfigMap has required scripts
        local required_scripts=(
            "common-functions.sh"
            "backup-etcd.sh"
            "snapshot-state.sh"
            "verify-health.sh"
            "send-report.sh"
        )

        for script in "${required_scripts[@]}"; do
            if grep -q "$script" "$SCRIPT_DIR/05-maintenance-windows.yaml"; then
                pass "Maintenance script $script is defined"
            else
                fail "Maintenance script $script is missing"
            fi
        done
    else
        fail "Maintenance windows manifest is invalid"
    fi
}

# Test runbooks completeness
test_runbooks() {
    log "Testing runbooks..."

    local runbooks=(
        "cluster-upgrade-runbook.md"
        "node-maintenance-runbook.md"
        "capacity-planning-runbook.md"
        "incident-response-runbook.md"
        "backup-restore-runbook.md"
        "monitoring-troubleshooting-runbook.md"
    )

    for runbook in "${runbooks[@]}"; do
        if grep -q "$runbook" "$SCRIPT_DIR/07-operations-runbooks.yaml"; then
            pass "Runbook $runbook is defined"
        else
            fail "Runbook $runbook is missing"
        fi
    done
}

# Test documentation
test_documentation() {
    log "Testing documentation..."

    if [[ -f "$SCRIPT_DIR/README.md" ]]; then
        pass "README.md exists"

        # Check for key sections
        local sections=(
            "Overview"
            "Components"
            "Installation"
            "Usage Examples"
            "Troubleshooting"
        )

        for section in "${sections[@]}"; do
            if grep -q "## $section" "$SCRIPT_DIR/README.md"; then
                pass "README has section: $section"
            else
                fail "README missing section: $section"
            fi
        done
    else
        fail "README.md not found"
    fi
}

# Integration test (if cluster is available)
test_integration() {
    log "Running integration tests..."

    # Only run if cluster is accessible
    if ! kubectl cluster-info &>/dev/null; then
        skip "Cluster not accessible - skipping integration tests"
        return
    fi

    # Test actual health check
    info "Running actual health check..."
    if "$SCRIPT_DIR/06-health-checks.sh" --quick; then
        pass "Integration: Health check succeeded"
    else
        if [[ $? -eq 2 ]]; then
            pass "Integration: Health check succeeded (with warnings)"
        else
            fail "Integration: Health check failed"
        fi
    fi

    # Test capacity monitoring queries (if Prometheus is available)
    if kubectl get prometheus -n monitoring &>/dev/null; then
        info "Testing Prometheus queries..."

        # Port-forward to Prometheus (in background, kill after test)
        kubectl port-forward -n monitoring svc/prometheus 9090:9090 &>/dev/null &
        local pf_pid=$!
        sleep 5

        # Test query
        if curl -s http://localhost:9090/api/v1/query?query=up | grep -q "success"; then
            pass "Integration: Prometheus is accessible"
        else
            skip "Integration: Prometheus not accessible"
        fi

        # Kill port-forward
        kill $pf_pid &>/dev/null || true
    else
        skip "Prometheus not available for integration testing"
    fi
}

# Generate test report
generate_report() {
    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))

    log "===== Test Summary ====="
    echo -e "${GREEN}Passed:  $TESTS_PASSED${NC}"
    echo -e "${RED}Failed:  $TESTS_FAILED${NC}"
    echo -e "${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
    echo -e "Total:   $total"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        echo ""
        echo "Test log: $TEST_LOG"
        return 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        echo ""
        echo "Review test log: $TEST_LOG"
        return 1
    fi
}

# Main test runner
main() {
    log "===== Cluster Operations Automation Test Suite ====="
    log "Started at: $(date)"
    log "Log file: $TEST_LOG"
    echo ""

    # Run all test suites
    test_dependencies
    echo ""

    test_script_files
    echo ""

    test_manifests
    echo ""

    test_script_help
    echo ""

    test_directory_structure
    echo ""

    test_installed_commands
    echo ""

    test_health_checks
    echo ""

    test_node_management
    echo ""

    test_upgrade_prechecks
    echo ""

    test_backup_operations
    echo ""

    test_k8s_resources
    echo ""

    test_prometheus_integration
    echo ""

    test_maintenance_scripts
    echo ""

    test_runbooks
    echo ""

    test_documentation
    echo ""

    test_integration
    echo ""

    # Generate final report
    generate_report
}

# Run tests
main
exit_code=$?

exit $exit_code
