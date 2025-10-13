#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="workload-demo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Functions
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

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi

    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi

    # Check Kubernetes version
    K8S_VERSION=$(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}' | sed 's/v//')
    log_info "Kubernetes version: $K8S_VERSION"

    log_success "Prerequisites check passed"
}

create_storage_class() {
    log_info "Checking storage configuration..."

    # Check if storage class exists
    if kubectl get storageclass fast-ssd &> /dev/null; then
        log_warning "StorageClass 'fast-ssd' already exists, skipping creation"
    else
        log_info "Creating fast-ssd StorageClass..."
        # Note: This uses local-path provisioner as an example
        # Adjust according to your cluster's storage provider
        cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
EOF
        log_success "StorageClass created"
    fi
}

deploy_manifests() {
    log_info "Deploying workload management manifests..."

    # Array of manifest files in order
    MANIFESTS=(
        "00-namespace.yaml"
        "07-priority-classes.yaml"
        "08-resource-quotas-limits.yaml"
        "01-deployment-strategies.yaml"
        "02-blue-green-canary.yaml"
        "03-statefulsets.yaml"
        "04-daemonsets.yaml"
        "05-cronjobs-jobs.yaml"
        "06-pod-disruption-budgets.yaml"
        "09-monitoring-tests.yaml"
    )

    for manifest in "${MANIFESTS[@]}"; do
        log_info "Applying $manifest..."
        if kubectl apply -f "$SCRIPT_DIR/$manifest"; then
            log_success "$manifest applied successfully"
        else
            log_error "Failed to apply $manifest"
            exit 1
        fi
        sleep 2
    done

    log_success "All manifests applied"
}

wait_for_resources() {
    log_info "Waiting for resources to be ready..."

    # Wait for namespace
    log_info "Waiting for namespace..."
    kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/$NAMESPACE --timeout=30s

    # Wait for deployments
    log_info "Waiting for deployments..."
    kubectl wait --for=condition=available --timeout=300s \
        deployment/podinfo-rolling \
        deployment/podinfo-blue \
        deployment/podinfo-green \
        deployment/podinfo-canary-stable \
        deployment/podinfo-canary-new \
        -n $NAMESPACE 2>/dev/null || log_warning "Some deployments may not be ready yet"

    # Wait for StatefulSets
    log_info "Waiting for StatefulSets..."
    kubectl wait --for=jsonpath='{.status.readyReplicas}'=3 \
        --timeout=300s statefulset/redis-cluster -n $NAMESPACE 2>/dev/null || \
        log_warning "Redis StatefulSet may not be ready yet (requires PV provisioning)"

    kubectl wait --for=jsonpath='{.status.readyReplicas}'=1 \
        --timeout=300s statefulset/postgresql -n $NAMESPACE 2>/dev/null || \
        log_warning "PostgreSQL StatefulSet may not be ready yet (requires PV provisioning)"

    # Check DaemonSets
    log_info "Checking DaemonSets..."
    kubectl rollout status daemonset/node-monitor -n $NAMESPACE --timeout=120s 2>/dev/null || \
        log_warning "Node monitor DaemonSet may not be fully deployed"

    log_success "Resource deployment completed"
}

display_status() {
    log_info "Displaying resource status..."

    echo ""
    echo "=== Namespace ==="
    kubectl get namespace $NAMESPACE

    echo ""
    echo "=== Priority Classes ==="
    kubectl get priorityclass | grep -E "NAME|critical|high|medium|low|best-effort"

    echo ""
    echo "=== Deployments ==="
    kubectl get deployments -n $NAMESPACE

    echo ""
    echo "=== StatefulSets ==="
    kubectl get statefulsets -n $NAMESPACE

    echo ""
    echo "=== DaemonSets ==="
    kubectl get daemonsets -n $NAMESPACE

    echo ""
    echo "=== Jobs & CronJobs ==="
    kubectl get jobs,cronjobs -n $NAMESPACE

    echo ""
    echo "=== Services ==="
    kubectl get services -n $NAMESPACE

    echo ""
    echo "=== PersistentVolumeClaims ==="
    kubectl get pvc -n $NAMESPACE

    echo ""
    echo "=== Pod Disruption Budgets ==="
    kubectl get pdb -n $NAMESPACE

    echo ""
    echo "=== Resource Quotas ==="
    kubectl get resourcequota -n $NAMESPACE

    echo ""
    echo "=== Limit Ranges ==="
    kubectl get limitrange -n $NAMESPACE

    echo ""
    echo "=== Pods ==="
    kubectl get pods -n $NAMESPACE -o wide
}

run_tests() {
    log_info "Running validation tests..."

    # Create test job
    if kubectl get job test-deployments -n $NAMESPACE &> /dev/null; then
        log_warning "Test job already exists, deleting..."
        kubectl delete job test-deployments -n $NAMESPACE
        sleep 5
    fi

    log_info "Creating validation test job..."
    kubectl create job --from=cronjob/test-deployments validation-test -n $NAMESPACE 2>/dev/null || \
        log_warning "Could not create test job. CronJob may not be ready yet."

    # Wait for job to complete
    log_info "Waiting for test job to complete (this may take a few minutes)..."
    kubectl wait --for=condition=complete --timeout=300s job/validation-test -n $NAMESPACE 2>/dev/null || \
        log_warning "Test job did not complete. Check logs manually: kubectl logs job/validation-test -n $NAMESPACE"

    # Show test results
    log_info "Test results:"
    kubectl logs job/validation-test -n $NAMESPACE 2>/dev/null || \
        log_warning "Could not retrieve test logs"

    echo ""
}

show_usage() {
    cat <<EOF
Workload Management Deployment Script

Usage: $0 [OPTIONS]

OPTIONS:
    --skip-tests        Skip validation tests
    --skip-wait         Skip waiting for resources
    --cleanup           Delete all resources
    --status            Show status only (no deployment)
    --help              Show this help message

EXAMPLES:
    # Full deployment with tests
    $0

    # Deploy without tests
    $0 --skip-tests

    # Show status only
    $0 --status

    # Cleanup all resources
    $0 --cleanup

EOF
}

cleanup() {
    log_warning "Cleaning up workload management resources..."

    read -p "Are you sure you want to delete all resources? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Cleanup cancelled"
        exit 0
    fi

    log_info "Deleting namespace..."
    kubectl delete namespace $NAMESPACE --timeout=120s

    log_info "Deleting priority classes..."
    kubectl delete priorityclass \
        critical-priority \
        high-priority \
        medium-priority \
        low-priority \
        best-effort-priority \
        2>/dev/null || log_warning "Some priority classes may not exist"

    log_info "Deleting cluster roles and bindings..."
    kubectl delete clusterrole workload-tester-cluster log-collector 2>/dev/null || true
    kubectl delete clusterrolebinding workload-tester-cluster log-collector 2>/dev/null || true

    log_success "Cleanup completed"
}

# Main execution
main() {
    SKIP_TESTS=false
    SKIP_WAIT=false
    STATUS_ONLY=false
    CLEANUP=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --skip-wait)
                SKIP_WAIT=true
                shift
                ;;
            --status)
                STATUS_ONLY=true
                shift
                ;;
            --cleanup)
                CLEANUP=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    echo ""
    log_info "=================================="
    log_info "Workload Management Deployment"
    log_info "=================================="
    echo ""

    # Handle cleanup
    if [ "$CLEANUP" = true ]; then
        cleanup
        exit 0
    fi

    # Check prerequisites
    check_prerequisites

    # Status only mode
    if [ "$STATUS_ONLY" = true ]; then
        display_status
        exit 0
    fi

    # Create storage class
    create_storage_class

    # Deploy manifests
    deploy_manifests

    # Wait for resources
    if [ "$SKIP_WAIT" = false ]; then
        wait_for_resources
    fi

    # Display status
    display_status

    # Run tests
    if [ "$SKIP_TESTS" = false ]; then
        echo ""
        run_tests
    fi

    echo ""
    log_success "=================================="
    log_success "Deployment completed successfully!"
    log_success "=================================="
    echo ""

    log_info "Next steps:"
    echo "  1. Check resource status: kubectl get all -n $NAMESPACE"
    echo "  2. View pod logs: kubectl logs -f <pod-name> -n $NAMESPACE"
    echo "  3. Run tests: kubectl create job --from=cronjob/test-deployments manual-test -n $NAMESPACE"
    echo "  4. Monitor quotas: kubectl describe resourcequota -n $NAMESPACE"
    echo "  5. Test blue-green: kubectl patch service podinfo-bluegreen -n $NAMESPACE -p '{\"spec\":{\"selector\":{\"version\":\"green\"}}}'"
    echo ""
    log_info "For more information, see README.md"
}

# Run main function
main "$@"
