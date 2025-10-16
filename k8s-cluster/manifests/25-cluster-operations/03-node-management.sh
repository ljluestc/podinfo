#!/bin/bash
# Kubernetes Node Management Automation
# Handles node cordoning, draining, repair, and replacement

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/k8s-operations"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_DIR/node-management.log"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $*" | tee -a "$LOG_DIR/node-management.log"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $*" | tee -a "$LOG_DIR/node-management.log"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $*" | tee -a "$LOG_DIR/node-management.log"
}

mkdir -p "$LOG_DIR"

usage() {
    cat <<EOF
Usage: $0 COMMAND [OPTIONS]

Kubernetes Node Management Automation

COMMANDS:
    cordon NODE [NODE...]          Mark node(s) as unschedulable
    uncordon NODE [NODE...]        Mark node(s) as schedulable
    drain NODE [OPTIONS]           Safely drain node for maintenance
    repair NODE                    Attempt to repair unhealthy node
    replace NODE                   Replace failed node
    health-check [NODE]            Check node health
    list-tainted                   List nodes with taints
    remove-taint NODE TAINT        Remove taint from node

DRAIN OPTIONS:
    --timeout SECONDS              Drain timeout (default: 600)
    --grace-period SECONDS         Pod termination grace period (default: 30)
    --force                        Force deletion of pods
    --ignore-daemonsets           Ignore DaemonSet pods (default: true)
    --delete-emptydir-data        Delete pods using emptyDir (default: true)

EXAMPLES:
    $0 cordon worker-1 worker-2
    $0 drain worker-1 --timeout 900
    $0 repair worker-1
    $0 replace worker-1
    $0 health-check
    $0 list-tainted

EOF
    exit 1
}

# Cordon nodes
cordon_nodes() {
    local nodes=("$@")

    for node in "${nodes[@]}"; do
        log "Cordoning node: $node"
        if kubectl cordon "$node"; then
            log "Node $node cordoned successfully"
        else
            error "Failed to cordon node $node"
            return 1
        fi
    done

    return 0
}

# Uncordon nodes
uncordon_nodes() {
    local nodes=("$@")

    for node in "${nodes[@]}"; do
        log "Uncordoning node: $node"
        if kubectl uncordon "$node"; then
            log "Node $node uncordoned successfully"
        else
            error "Failed to uncordon node $node"
            return 1
        fi
    done

    return 0
}

# Drain node safely
drain_node() {
    local node=$1
    local timeout=600
    local grace_period=30
    local force=false
    local ignore_daemonsets=true
    local delete_emptydir=true

    shift

    # Parse drain options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --timeout)
                timeout=$2
                shift 2
                ;;
            --grace-period)
                grace_period=$2
                shift 2
                ;;
            --force)
                force=true
                shift
                ;;
            --ignore-daemonsets)
                ignore_daemonsets=true
                shift
                ;;
            --delete-emptydir-data)
                delete_emptydir=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    log "Draining node: $node"
    log "Timeout: ${timeout}s, Grace period: ${grace_period}s"

    # Check PodDisruptionBudgets
    info "Checking PodDisruptionBudgets..."
    kubectl get pdb -A -o wide || warning "Could not check PDBs"

    # Build drain command
    local drain_cmd="kubectl drain $node"
    drain_cmd="$drain_cmd --timeout=${timeout}s"
    drain_cmd="$drain_cmd --grace-period=$grace_period"

    if [[ "$force" == true ]]; then
        drain_cmd="$drain_cmd --force"
    fi

    if [[ "$ignore_daemonsets" == true ]]; then
        drain_cmd="$drain_cmd --ignore-daemonsets"
    fi

    if [[ "$delete_emptydir" == true ]]; then
        drain_cmd="$drain_cmd --delete-emptydir-data"
    fi

    # Execute drain
    info "Executing: $drain_cmd"
    if eval "$drain_cmd"; then
        log "Node $node drained successfully"

        # Wait for pods to be rescheduled
        sleep 10

        # Verify no pods remain
        local remaining_pods=$(kubectl get pods --all-namespaces --field-selector spec.nodeName="$node" --no-headers 2>/dev/null | grep -v "DaemonSet" | wc -l || echo 0)

        if [[ $remaining_pods -eq 0 ]]; then
            log "All pods evicted from $node"
        else
            warning "$remaining_pods pods still running on $node"
        fi

        return 0
    else
        error "Failed to drain node $node"
        return 1
    fi
}

# Repair unhealthy node
repair_node() {
    local node=$1

    log "Attempting to repair node: $node"

    # Get node status
    info "Current node status:"
    kubectl get node "$node" -o wide

    # Check node conditions
    info "Node conditions:"
    kubectl describe node "$node" | grep -A 10 "Conditions:"

    # Common repair steps
    warning "Common repair steps to try:"
    cat <<'EOF'

1. Check kubelet service:
   ssh NODE 'systemctl status kubelet'

2. Restart kubelet:
   ssh NODE 'systemctl restart kubelet'

3. Check container runtime:
   ssh NODE 'systemctl status containerd'
   ssh NODE 'crictl ps'

4. Restart container runtime:
   ssh NODE 'systemctl restart containerd'

5. Check disk space:
   ssh NODE 'df -h'

6. Clean up disk space:
   ssh NODE 'crictl rmi --prune'
   ssh NODE 'journalctl --vacuum-time=3d'

7. Check memory:
   ssh NODE 'free -m'

8. Check system logs:
   ssh NODE 'journalctl -u kubelet -n 100'
   ssh NODE 'journalctl -u containerd -n 100'

9. Check network:
   ssh NODE 'ip addr'
   ssh NODE 'ip route'

10. Restart node (last resort):
    ssh NODE 'reboot'

EOF

    # Automated checks we can do remotely
    info "Remote diagnostics:"

    # Check if node is NotReady
    if kubectl get node "$node" | grep -q "NotReady"; then
        warning "Node is in NotReady state"

        # Check node events
        info "Recent node events:"
        kubectl get events --field-selector involvedObject.name="$node" --sort-by='.lastTimestamp' | tail -20

        # Check pods on the node
        info "Pods on this node:"
        kubectl get pods --all-namespaces --field-selector spec.nodeName="$node"

        # Suggest next steps
        warning "Recommended actions:"
        echo "1. SSH to node and check kubelet logs"
        echo "2. Restart kubelet service"
        echo "3. If issue persists, consider replacing the node"
    fi

    # Check resource pressure
    local conditions=$(kubectl get node "$node" -o json | jq -r '.status.conditions[] | select(.status=="True") | .type')

    for condition in $conditions; do
        case $condition in
            MemoryPressure)
                warning "Node has memory pressure"
                echo "Actions:"
                echo "  - Identify memory-heavy pods: kubectl top pods --all-namespaces --sort-by=memory"
                echo "  - Consider evicting non-critical pods"
                echo "  - Add more memory to the node"
                ;;
            DiskPressure)
                warning "Node has disk pressure"
                echo "Actions:"
                echo "  - Clean up container images: ssh $node 'crictl rmi --prune'"
                echo "  - Clean up logs: ssh $node 'journalctl --vacuum-time=3d'"
                echo "  - Expand disk space"
                ;;
            PIDPressure)
                warning "Node has PID pressure"
                echo "Actions:"
                echo "  - Check for runaway processes"
                echo "  - Increase PID limits"
                ;;
        esac
    done

    return 0
}

# Replace failed node
replace_node() {
    local node=$1

    log "Replacing node: $node"

    warning "This will:"
    echo "  1. Cordon the node"
    echo "  2. Drain all pods"
    echo "  3. Remove the node from the cluster"
    echo "  4. Provide instructions for adding a new node"

    read -p "Continue? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        log "Node replacement cancelled"
        return 0
    fi

    # Cordon
    log "Cordoning node..."
    kubectl cordon "$node" || {
        error "Failed to cordon node"
        return 1
    }

    # Drain
    log "Draining node..."
    kubectl drain "$node" \
        --ignore-daemonsets \
        --delete-emptydir-data \
        --timeout=600s \
        --force || {
        error "Failed to drain node"
        return 1
    }

    # Delete node
    log "Removing node from cluster..."
    kubectl delete node "$node" || {
        warning "Failed to delete node from cluster"
    }

    log "Node $node removed from cluster"

    # Provide instructions for adding new node
    info "To add a new node to replace $node:"
    cat <<'EOF'

1. Provision a new node with the same specifications

2. On the new node, install Kubernetes components:
   curl -fsSL https://get.k8s.io | bash

3. Get the join command from a control plane node:
   kubeadm token create --print-join-command

4. On the new node, run the join command:
   sudo kubeadm join ...

5. Verify the new node:
   kubectl get nodes

6. Label the new node appropriately:
   kubectl label node NEW_NODE node-role.kubernetes.io/worker=worker

EOF

    return 0
}

# Node health check
health_check() {
    local specific_node=${1:-}

    log "Running node health checks..."

    if [[ -n "$specific_node" ]]; then
        nodes="$specific_node"
    else
        nodes=$(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name)
    fi

    for node in $nodes; do
        info "Checking node: $node"

        # Node status
        local status=$(kubectl get node "$node" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
        if [[ "$status" == "True" ]]; then
            echo "  ✓ Status: Ready"
        else
            echo "  ✗ Status: NotReady"
        fi

        # Resource usage
        local cpu_usage=$(kubectl top node "$node" 2>/dev/null | tail -1 | awk '{print $3}' || echo "N/A")
        local mem_usage=$(kubectl top node "$node" 2>/dev/null | tail -1 | awk '{print $5}' || echo "N/A")
        echo "  CPU: $cpu_usage"
        echo "  Memory: $mem_usage"

        # Conditions
        local conditions=$(kubectl get node "$node" -o json | jq -r '.status.conditions[] | select(.status=="True") | .type' | grep -v "Ready" || echo "None")
        if [[ "$conditions" != "None" && -n "$conditions" ]]; then
            warning "  Conditions: $conditions"
        fi

        # Taints
        local taints=$(kubectl get node "$node" -o jsonpath='{.spec.taints[*].key}' || echo "None")
        if [[ -n "$taints" && "$taints" != "None" ]]; then
            echo "  Taints: $taints"
        fi

        # Pod count
        local pod_count=$(kubectl get pods --all-namespaces --field-selector spec.nodeName="$node" --no-headers 2>/dev/null | wc -l)
        echo "  Pods: $pod_count"

        echo ""
    done

    return 0
}

# List tainted nodes
list_tainted() {
    log "Listing tainted nodes..."

    kubectl get nodes -o json | jq -r '.items[] | select(.spec.taints != null) | {name:.metadata.name, taints:.spec.taints} | "\(.name): \(.taints | map(.key + "=" + .effect) | join(", "))"'
}

# Remove taint
remove_taint() {
    local node=$1
    local taint=$2

    log "Removing taint '$taint' from node $node"

    if kubectl taint node "$node" "$taint-"; then
        log "Taint removed successfully"
        return 0
    else
        error "Failed to remove taint"
        return 1
    fi
}

# Main
if [[ $# -eq 0 ]]; then
    usage
fi

COMMAND=$1
shift

case "$COMMAND" in
    cordon)
        cordon_nodes "$@"
        ;;
    uncordon)
        uncordon_nodes "$@"
        ;;
    drain)
        if [[ $# -eq 0 ]]; then
            error "Node name required"
            usage
        fi
        drain_node "$@"
        ;;
    repair)
        if [[ $# -eq 0 ]]; then
            error "Node name required"
            usage
        fi
        repair_node "$1"
        ;;
    replace)
        if [[ $# -eq 0 ]]; then
            error "Node name required"
            usage
        fi
        replace_node "$1"
        ;;
    health-check)
        health_check "$@"
        ;;
    list-tainted)
        list_tainted
        ;;
    remove-taint)
        if [[ $# -lt 2 ]]; then
            error "Node name and taint required"
            usage
        fi
        remove_taint "$1" "$2"
        ;;
    *)
        error "Unknown command: $COMMAND"
        usage
        ;;
esac
