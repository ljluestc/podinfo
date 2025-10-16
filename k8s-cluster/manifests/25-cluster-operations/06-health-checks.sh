#!/bin/bash
# Kubernetes Cluster Health Checks and Diagnostics
# Comprehensive health validation and diagnostic reporting

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/k8s-operations"
REPORT_DIR="/var/log/k8s-operations/reports"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Status tracking
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

mkdir -p "$LOG_DIR" "$REPORT_DIR"

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗${NC} $*"
    ((CHECKS_FAILED++))
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠${NC} $*"
    ((CHECKS_WARNING++))
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓${NC} $*"
    ((CHECKS_PASSED++))
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ${NC} $*"
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Kubernetes Cluster Health Checks and Diagnostics

OPTIONS:
    -q, --quick               Quick health check only
    -f, --full                Full comprehensive health check
    -c, --component COMP      Check specific component (nodes|pods|services|storage|network|security)
    -n, --namespace NS        Check specific namespace
    -o, --output FILE         Output report to file
    -j, --json                Output in JSON format
    -v, --verbose             Verbose output
    -h, --help                Display this help message

EXAMPLES:
    $0 --quick
    $0 --full --output /tmp/health-report.txt
    $0 --component nodes
    $0 --namespace production

EOF
    exit 1
}

# API Server health check
check_api_server() {
    log "Checking API Server..."

    # Check if kubectl works
    if kubectl cluster-info &>/dev/null; then
        success "API Server is reachable"
    else
        error "API Server is not reachable"
        return 1
    fi

    # Check API server readiness
    if kubectl get --raw /readyz?verbose 2>/dev/null | grep -q "ok"; then
        success "API Server is ready"
    else
        warning "API Server readiness check returned warnings"
    fi

    # Check API server health
    if kubectl get --raw /healthz 2>/dev/null | grep -q "ok"; then
        success "API Server is healthy"
    else
        error "API Server health check failed"
    fi

    # Check API server latency
    local start_time=$(date +%s%N)
    kubectl get nodes &>/dev/null
    local end_time=$(date +%s%N)
    local latency=$(( (end_time - start_time) / 1000000 ))

    if [ $latency -lt 1000 ]; then
        success "API Server latency: ${latency}ms (good)"
    elif [ $latency -lt 5000 ]; then
        warning "API Server latency: ${latency}ms (acceptable)"
    else
        error "API Server latency: ${latency}ms (slow)"
    fi

    return 0
}

# Node health check
check_nodes() {
    log "Checking Nodes..."

    local total_nodes=$(kubectl get nodes --no-headers | wc -l)
    local ready_nodes=$(kubectl get nodes --no-headers | grep " Ready" | wc -l)
    local not_ready_nodes=$(kubectl get nodes --no-headers | grep "NotReady" | wc -l)

    info "Total nodes: $total_nodes"
    info "Ready nodes: $ready_nodes"

    if [ $not_ready_nodes -eq 0 ]; then
        success "All nodes are Ready"
    else
        error "$not_ready_nodes nodes are NotReady"
        kubectl get nodes | grep "NotReady"
    fi

    # Check node conditions
    info "Checking node conditions..."
    while IFS= read -r node; do
        # Check for pressure conditions
        local conditions=$(kubectl get node "$node" -o json | jq -r '.status.conditions[] | select(.status=="True" and .type!="Ready") | .type' 2>/dev/null)

        if [ -n "$conditions" ]; then
            for condition in $conditions; do
                case $condition in
                    MemoryPressure)
                        warning "Node $node has MemoryPressure"
                        ;;
                    DiskPressure)
                        warning "Node $node has DiskPressure"
                        ;;
                    PIDPressure)
                        warning "Node $node has PIDPressure"
                        ;;
                    NetworkUnavailable)
                        error "Node $node has NetworkUnavailable"
                        ;;
                esac
            done
        fi
    done < <(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name)

    # Check node resources
    info "Checking node resources..."
    if kubectl top nodes &>/dev/null; then
        kubectl top nodes

        while IFS= read -r line; do
            local node=$(echo "$line" | awk '{print $1}')
            local cpu_percent=$(echo "$line" | awk '{print $3}' | tr -d '%')
            local mem_percent=$(echo "$line" | awk '{print $5}' | tr -d '%')

            if [ -n "$cpu_percent" ] && [ "$cpu_percent" != "CPU%" ]; then
                if [ "${cpu_percent%.*}" -gt 90 ]; then
                    error "Node $node CPU usage is high: ${cpu_percent}%"
                elif [ "${cpu_percent%.*}" -gt 80 ]; then
                    warning "Node $node CPU usage is elevated: ${cpu_percent}%"
                fi
            fi

            if [ -n "$mem_percent" ] && [ "$mem_percent" != "MEMORY%" ]; then
                if [ "${mem_percent%.*}" -gt 90 ]; then
                    error "Node $node Memory usage is high: ${mem_percent}%"
                elif [ "${mem_percent%.*}" -gt 85 ]; then
                    warning "Node $node Memory usage is elevated: ${mem_percent}%"
                fi
            fi
        done < <(kubectl top nodes 2>/dev/null || echo "")
    else
        warning "Metrics server not available - cannot check resource usage"
    fi

    return 0
}

# Pod health check
check_pods() {
    local namespace=${1:-}

    log "Checking Pods..."

    local ns_flag=""
    if [ -n "$namespace" ]; then
        ns_flag="-n $namespace"
        info "Checking namespace: $namespace"
    else
        ns_flag="-A"
        info "Checking all namespaces"
    fi

    # Count pod states
    local total_pods=$(kubectl get pods $ns_flag --no-headers 2>/dev/null | wc -l)
    local running_pods=$(kubectl get pods $ns_flag --no-headers 2>/dev/null | grep "Running" | wc -l)
    local pending_pods=$(kubectl get pods $ns_flag --no-headers 2>/dev/null | grep "Pending" | wc -l)
    local failed_pods=$(kubectl get pods $ns_flag --no-headers 2>/dev/null | grep -E "Error|Failed|CrashLoopBackOff|ImagePullBackOff" | wc -l)

    info "Total pods: $total_pods"
    info "Running pods: $running_pods"
    info "Pending pods: $pending_pods"
    info "Failed pods: $failed_pods"

    if [ $failed_pods -eq 0 ]; then
        success "No failed pods"
    else
        error "$failed_pods pods are in failed state"
        kubectl get pods $ns_flag | grep -E "Error|Failed|CrashLoopBackOff|ImagePullBackOff"
    fi

    if [ $pending_pods -gt 0 ]; then
        warning "$pending_pods pods are pending"
        kubectl get pods $ns_flag | grep "Pending" | head -5
    fi

    # Check for restart loops
    info "Checking for restart loops..."
    local restart_threshold=5
    while IFS= read -r line; do
        local pod=$(echo "$line" | awk '{print $2}')
        local namespace=$(echo "$line" | awk '{print $1}')
        local restarts=$(echo "$line" | awk '{print $5}')

        if [ "$restarts" -gt $restart_threshold ]; then
            warning "Pod $namespace/$pod has $restarts restarts"
        fi
    done < <(kubectl get pods $ns_flag -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,READY:.status.conditions[?\(@.type==\'Ready\'\)].status,RESTARTS:.status.containerStatuses[0].restartCount 2>/dev/null | grep -v "NAMESPACE")

    return 0
}

# Service health check
check_services() {
    log "Checking Services..."

    # Check for services without endpoints
    info "Checking for services without endpoints..."

    local services_without_endpoints=0
    while IFS= read -r ns; do
        while IFS= read -r svc; do
            local endpoints=$(kubectl get endpoints -n "$ns" "$svc" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
            if [ -z "$endpoints" ]; then
                warning "Service $ns/$svc has no endpoints"
                ((services_without_endpoints++))
            fi
        done < <(kubectl get svc -n "$ns" --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null)
    done < <(kubectl get ns --no-headers -o custom-columns=NAME:.metadata.name)

    if [ $services_without_endpoints -eq 0 ]; then
        success "All services have endpoints"
    else
        warning "$services_without_endpoints services have no endpoints"
    fi

    return 0
}

# Storage health check
check_storage() {
    log "Checking Storage..."

    # Check PVCs
    local pending_pvcs=$(kubectl get pvc -A --no-headers 2>/dev/null | grep "Pending" | wc -l)
    local bound_pvcs=$(kubectl get pvc -A --no-headers 2>/dev/null | grep "Bound" | wc -l)

    info "Bound PVCs: $bound_pvcs"
    info "Pending PVCs: $pending_pvcs"

    if [ $pending_pvcs -eq 0 ]; then
        success "No pending PVCs"
    else
        warning "$pending_pvcs PVCs are pending"
        kubectl get pvc -A | grep "Pending"
    fi

    # Check PV capacity
    info "Checking PV capacity..."
    if command -v jq &>/dev/null; then
        kubectl get pvc -A -o json 2>/dev/null | jq -r '.items[] | select(.status.phase=="Bound") | "\(.metadata.namespace)/\(.metadata.name) \(.status.capacity.storage)"' | while read -r line; do
            info "PVC: $line"
        done
    fi

    return 0
}

# Network health check
check_network() {
    log "Checking Network..."

    # Check network policies
    local netpol_count=$(kubectl get networkpolicy -A --no-headers 2>/dev/null | wc -l)
    info "Network policies: $netpol_count"

    # Check DNS
    info "Checking DNS..."
    if kubectl get svc -n kube-system kube-dns &>/dev/null || kubectl get svc -n kube-system coredns &>/dev/null; then
        success "DNS service is present"

        # Check DNS pods
        local dns_pods=$(kubectl get pods -n kube-system -l k8s-app=kube-dns -o name 2>/dev/null || kubectl get pods -n kube-system -l k8s-app=kube-dns -o name 2>/dev/null)
        if [ -n "$dns_pods" ]; then
            success "DNS pods are running"
        else
            error "DNS pods not found"
        fi
    else
        error "DNS service not found"
    fi

    # Check CNI
    info "Checking CNI plugin..."
    if kubectl get pods -n kube-system -l k8s-app=calico-node &>/dev/null; then
        success "Calico CNI detected"
    elif kubectl get pods -n kube-system -l app=cilium &>/dev/null; then
        success "Cilium CNI detected"
    elif kubectl get pods -n kube-system -l k8s-app=flannel &>/dev/null; then
        success "Flannel CNI detected"
    else
        warning "CNI plugin not detected or unknown"
    fi

    return 0
}

# Security health check
check_security() {
    log "Checking Security..."

    # Check for pods running as root
    info "Checking for privileged pods..."
    local privileged_count=0
    while IFS= read -r ns; do
        while IFS= read -r pod; do
            local is_privileged=$(kubectl get pod -n "$ns" "$pod" -o json 2>/dev/null | jq -r '.spec.containers[].securityContext.privileged // false' | grep true)
            if [ -n "$is_privileged" ]; then
                warning "Pod $ns/$pod is running as privileged"
                ((privileged_count++))
            fi
        done < <(kubectl get pods -n "$ns" --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null)
    done < <(kubectl get ns --no-headers -o custom-columns=NAME:.metadata.name)

    if [ $privileged_count -eq 0 ]; then
        success "No privileged pods detected"
    else
        warning "$privileged_count privileged pods detected"
    fi

    # Check RBAC
    info "Checking RBAC..."
    local cluster_admins=$(kubectl get clusterrolebindings -o json 2>/dev/null | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .subjects[]?.name' | wc -l)
    if [ "$cluster_admins" -gt 5 ]; then
        warning "High number of cluster-admin bindings: $cluster_admins"
    else
        success "Cluster-admin bindings: $cluster_admins (reasonable)"
    fi

    return 0
}

# Component-specific checks
check_etcd() {
    log "Checking etcd..."

    local etcd_pods=$(kubectl get pods -n kube-system -l component=etcd --no-headers 2>/dev/null | wc -l)

    if [ $etcd_pods -gt 0 ]; then
        success "etcd pods found: $etcd_pods"

        # Check etcd health
        info "Checking etcd health..."
        local etcd_pod=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

        if [ -n "$etcd_pod" ]; then
            if kubectl exec -n kube-system "$etcd_pod" -- sh -c "ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key endpoint health" &>/dev/null; then
                success "etcd cluster is healthy"
            else
                error "etcd health check failed"
            fi
        fi
    else
        warning "etcd pods not found (may be external)"
    fi

    return 0
}

# Generate comprehensive report
generate_report() {
    local output_file=${1:-}
    local report_file="${REPORT_DIR}/health-check-$(date +%Y%m%d-%H%M%S).txt"

    if [ -n "$output_file" ]; then
        report_file="$output_file"
    fi

    log "Generating health check report: $report_file"

    {
        echo "========================================="
        echo "Kubernetes Cluster Health Check Report"
        echo "Generated: $(date)"
        echo "========================================="
        echo ""
        echo "Summary:"
        echo "  Checks Passed:  $CHECKS_PASSED"
        echo "  Checks Warning: $CHECKS_WARNING"
        echo "  Checks Failed:  $CHECKS_FAILED"
        echo ""
        echo "========================================="
        echo ""
        echo "Cluster Information:"
        kubectl cluster-info
        echo ""
        kubectl version --short
        echo ""
        echo "========================================="
        echo ""
        echo "Node Status:"
        kubectl get nodes -o wide
        echo ""
        echo "========================================="
        echo ""
        echo "Pod Status by Namespace:"
        kubectl get pods -A
        echo ""
        echo "========================================="
        echo ""
        echo "Recent Events:"
        kubectl get events -A --sort-by='.lastTimestamp' | tail -50
    } > "$report_file"

    success "Report saved to: $report_file"
}

# Parse arguments
QUICK=false
FULL=false
COMPONENT=""
NAMESPACE=""
OUTPUT_FILE=""
JSON_OUTPUT=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -q|--quick)
            QUICK=true
            shift
            ;;
        -f|--full)
            FULL=true
            shift
            ;;
        -c|--component)
            COMPONENT="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -j|--json)
            JSON_OUTPUT=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            error "Unknown option: $1"
            usage
            ;;
    esac
done

# Main
main() {
    log "===== Kubernetes Cluster Health Check Started ====="

    if [ "$QUICK" == true ]; then
        check_api_server
        check_nodes
        check_pods "$NAMESPACE"
    elif [ -n "$COMPONENT" ]; then
        case "$COMPONENT" in
            nodes)
                check_nodes
                ;;
            pods)
                check_pods "$NAMESPACE"
                ;;
            services)
                check_services
                ;;
            storage)
                check_storage
                ;;
            network)
                check_network
                ;;
            security)
                check_security
                ;;
            etcd)
                check_etcd
                ;;
            *)
                error "Unknown component: $COMPONENT"
                exit 1
                ;;
        esac
    else
        # Full health check
        check_api_server
        check_etcd
        check_nodes
        check_pods "$NAMESPACE"
        check_services
        check_storage
        check_network
        check_security
    fi

    # Generate report
    if [ -n "$OUTPUT_FILE" ] || [ "$FULL" == true ]; then
        generate_report "$OUTPUT_FILE"
    fi

    echo ""
    log "===== Health Check Summary ====="
    success "Passed:  $CHECKS_PASSED"
    warning "Warnings: $CHECKS_WARNING"
    error "Failed:  $CHECKS_FAILED"

    if [ $CHECKS_FAILED -gt 0 ]; then
        exit 1
    elif [ $CHECKS_WARNING -gt 0 ]; then
        exit 2
    else
        exit 0
    fi
}

main
