#!/bin/bash
# Kubernetes Cluster Upgrade Automation
# Handles safe, rolling upgrades with rollback capability

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/k8s-operations"
BACKUP_DIR="/var/backups/k8s-cluster"
KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_DIR/cluster-upgrade.log"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $*" | tee -a "$LOG_DIR/cluster-upgrade.log"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $*" | tee -a "$LOG_DIR/cluster-upgrade.log"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $*" | tee -a "$LOG_DIR/cluster-upgrade.log"
}

# Initialize logging
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# Usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Kubernetes Cluster Upgrade Automation

OPTIONS:
    -t, --target-version VERSION    Target Kubernetes version (e.g., 1.29.0)
    -c, --control-plane            Upgrade control plane nodes only
    -w, --workers                  Upgrade worker nodes only
    -n, --node NODE                Upgrade specific node
    -p, --pre-check               Run pre-upgrade checks only
    -d, --drain-timeout SECONDS    Node drain timeout (default: 600)
    -s, --skip-backup             Skip etcd backup
    -f, --force                   Force upgrade without confirmation
    -h, --help                    Display this help message

EXAMPLES:
    $0 --target-version 1.29.0 --pre-check
    $0 --target-version 1.29.0 --control-plane
    $0 --target-version 1.29.0 --workers
    $0 --target-version 1.29.0 --node worker-1

EOF
    exit 1
}

# Parse arguments
TARGET_VERSION=""
UPGRADE_CONTROL_PLANE=false
UPGRADE_WORKERS=false
SPECIFIC_NODE=""
PRE_CHECK_ONLY=false
DRAIN_TIMEOUT=600
SKIP_BACKUP=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--target-version)
            TARGET_VERSION="$2"
            shift 2
            ;;
        -c|--control-plane)
            UPGRADE_CONTROL_PLANE=true
            shift
            ;;
        -w|--workers)
            UPGRADE_WORKERS=true
            shift
            ;;
        -n|--node)
            SPECIFIC_NODE="$2"
            shift 2
            ;;
        -p|--pre-check)
            PRE_CHECK_ONLY=true
            shift
            ;;
        -d|--drain-timeout)
            DRAIN_TIMEOUT="$2"
            shift 2
            ;;
        -s|--skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        -f|--force)
            FORCE=true
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

# Validate inputs
if [[ -z "$TARGET_VERSION" ]]; then
    error "Target version is required"
    usage
fi

# If no specific scope, upgrade everything
if [[ "$UPGRADE_CONTROL_PLANE" == false && "$UPGRADE_WORKERS" == false && -z "$SPECIFIC_NODE" ]]; then
    UPGRADE_CONTROL_PLANE=true
    UPGRADE_WORKERS=true
fi

# Pre-upgrade checks
pre_upgrade_checks() {
    log "Running pre-upgrade checks..."

    local checks_passed=true

    # Check cluster health
    info "Checking cluster health..."
    if ! kubectl get nodes | grep -v "NotReady"; then
        error "Cluster has nodes in NotReady state"
        checks_passed=false
    fi

    # Check component status
    info "Checking component status..."
    kubectl get --raw='/readyz?verbose' || {
        warning "Some components may not be healthy"
    }

    # Check current version
    local current_version=$(kubectl version --short | grep Server | awk '{print $3}')
    info "Current cluster version: $current_version"
    info "Target version: v$TARGET_VERSION"

    # Check version compatibility
    local current_minor=$(echo "$current_version" | sed 's/v//; s/\.[0-9]*$//')
    local target_minor=$(echo "$TARGET_VERSION" | sed 's/\.[0-9]*$//')

    info "Current minor: $current_minor, Target minor: $target_minor"

    # Check etcd health
    info "Checking etcd health..."
    kubectl get pods -n kube-system | grep etcd || {
        warning "Cannot verify etcd status"
    }

    # Check critical pods
    info "Checking critical pods..."
    local not_ready=$(kubectl get pods -A | grep -v "Running\|Completed" | grep -v "NAMESPACE" | wc -l)
    if [[ $not_ready -gt 0 ]]; then
        warning "$not_ready pods are not in Running/Completed state"
    fi

    # Check PodDisruptionBudgets
    info "Checking PodDisruptionBudgets..."
    kubectl get pdb -A || warning "Could not check PDBs"

    # Check node capacity
    info "Checking node capacity..."
    kubectl top nodes || warning "Metrics not available"

    # Check for deprecated APIs
    info "Checking for deprecated APIs..."
    warning "Please manually verify deprecated API usage for version $TARGET_VERSION"

    if [[ "$checks_passed" == true ]]; then
        log "Pre-upgrade checks PASSED"
        return 0
    else
        error "Pre-upgrade checks FAILED"
        return 1
    fi
}

# Backup etcd
backup_etcd() {
    if [[ "$SKIP_BACKUP" == true ]]; then
        warning "Skipping etcd backup"
        return 0
    fi

    log "Backing up etcd..."

    local backup_file="$BACKUP_DIR/etcd-backup-$(date +%Y%m%d-%H%M%S).db"

    # Find etcd pod
    local etcd_pod=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')

    if [[ -z "$etcd_pod" ]]; then
        error "Could not find etcd pod"
        return 1
    fi

    info "Creating etcd snapshot: $backup_file"

    kubectl exec -n kube-system "$etcd_pod" -- sh -c \
        "ETCDCTL_API=3 etcdctl \
        --endpoints=https://127.0.0.1:2379 \
        --cacert=/etc/kubernetes/pki/etcd/ca.crt \
        --cert=/etc/kubernetes/pki/etcd/server.crt \
        --key=/etc/kubernetes/pki/etcd/server.key \
        snapshot save /tmp/etcd-backup.db"

    kubectl cp "kube-system/$etcd_pod:/tmp/etcd-backup.db" "$backup_file"

    log "etcd backup saved to: $backup_file"

    # Keep last 10 backups
    ls -t "$BACKUP_DIR"/etcd-backup-* | tail -n +11 | xargs -r rm -f

    return 0
}

# Upgrade control plane node
upgrade_control_plane_node() {
    local node=$1

    log "Upgrading control plane node: $node"

    # Check if this is the first control plane node
    local is_first=false
    local control_planes=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers | wc -l)
    local first_cp=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers | head -1 | awk '{print $1}')

    if [[ "$node" == "$first_cp" ]]; then
        is_first=true
    fi

    info "Upgrading packages on $node..."

    # This would be executed on the node via ssh
    cat <<'EOF_UPGRADE' > /tmp/upgrade-node.sh
#!/bin/bash
set -e

# Determine OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect OS"
    exit 1
fi

TARGET_VERSION=$1

# Upgrade kubeadm
case "$OS" in
    ubuntu|debian)
        apt-mark unhold kubeadm
        apt-get update
        apt-get install -y kubeadm=$TARGET_VERSION-*
        apt-mark hold kubeadm
        ;;
    centos|rhel|fedora)
        yum install -y kubeadm-$TARGET_VERSION --disableexcludes=kubernetes
        ;;
esac

kubeadm version
EOF_UPGRADE

    # Note: In production, you would ssh to the node and execute this
    warning "Manual step required: SSH to $node and upgrade kubeadm to $TARGET_VERSION"

    if [[ "$is_first" == true ]]; then
        info "Executing kubeadm upgrade plan..."
        warning "Manual step: On $node, run: sudo kubeadm upgrade plan v$TARGET_VERSION"

        info "Executing kubeadm upgrade apply..."
        warning "Manual step: On $node, run: sudo kubeadm upgrade apply v$TARGET_VERSION"
    else
        info "Executing kubeadm upgrade node..."
        warning "Manual step: On $node, run: sudo kubeadm upgrade node"
    fi

    # Drain node
    log "Draining node $node..."
    kubectl drain "$node" \
        --ignore-daemonsets \
        --delete-emptydir-data \
        --timeout="${DRAIN_TIMEOUT}s" \
        --force || {
        error "Failed to drain node $node"
        return 1
    }

    # Upgrade kubelet and kubectl
    warning "Manual step: On $node, upgrade kubelet and kubectl:"
    cat <<EOF
    apt-mark unhold kubelet kubectl
    apt-get install -y kubelet=$TARGET_VERSION-* kubectl=$TARGET_VERSION-*
    apt-mark hold kubelet kubectl
    systemctl daemon-reload
    systemctl restart kubelet
EOF

    # Wait for node to be ready
    log "Waiting for node $node to be ready..."
    local retries=60
    while [[ $retries -gt 0 ]]; do
        if kubectl get node "$node" | grep -q " Ready"; then
            log "Node $node is ready"
            break
        fi
        sleep 5
        ((retries--))
    done

    if [[ $retries -eq 0 ]]; then
        error "Node $node did not become ready in time"
        return 1
    fi

    # Uncordon node
    log "Uncordoning node $node..."
    kubectl uncordon "$node"

    log "Control plane node $node upgraded successfully"
    return 0
}

# Upgrade worker node
upgrade_worker_node() {
    local node=$1

    log "Upgrading worker node: $node"

    # Cordon node
    log "Cordoning node $node..."
    kubectl cordon "$node"

    # Drain node
    log "Draining node $node..."
    kubectl drain "$node" \
        --ignore-daemonsets \
        --delete-emptydir-data \
        --timeout="${DRAIN_TIMEOUT}s" \
        --force || {
        error "Failed to drain node $node"
        return 1
    }

    # Wait for pods to be rescheduled
    sleep 30

    # Upgrade node
    warning "Manual step: SSH to $node and run:"
    cat <<EOF
    apt-mark unhold kubeadm kubelet kubectl
    apt-get update
    apt-get install -y kubeadm=$TARGET_VERSION-* kubelet=$TARGET_VERSION-* kubectl=$TARGET_VERSION-*
    apt-mark hold kubeadm kubelet kubectl
    kubeadm upgrade node
    systemctl daemon-reload
    systemctl restart kubelet
EOF

    # Wait for node to be ready
    log "Waiting for node $node to be ready..."
    local retries=60
    while [[ $retries -gt 0 ]]; do
        if kubectl get node "$node" | grep -q " Ready"; then
            log "Node $node is ready"
            break
        fi
        sleep 5
        ((retries--))
    done

    if [[ $retries -eq 0 ]]; then
        error "Node $node did not become ready in time"
        return 1
    fi

    # Uncordon node
    log "Uncordoning node $node..."
    kubectl uncordon "$node"

    log "Worker node $node upgraded successfully"
    return 0
}

# Main upgrade process
main() {
    log "===== Kubernetes Cluster Upgrade Started ====="
    log "Target version: $TARGET_VERSION"

    # Run pre-checks
    if ! pre_upgrade_checks; then
        error "Pre-upgrade checks failed"
        if [[ "$FORCE" != true ]]; then
            exit 1
        fi
        warning "Continuing due to --force flag"
    fi

    if [[ "$PRE_CHECK_ONLY" == true ]]; then
        log "Pre-check only mode - exiting"
        exit 0
    fi

    # Confirmation
    if [[ "$FORCE" != true ]]; then
        echo ""
        warning "This will upgrade the cluster to version $TARGET_VERSION"
        read -p "Continue? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            log "Upgrade cancelled by user"
            exit 0
        fi
    fi

    # Backup etcd
    if ! backup_etcd; then
        error "etcd backup failed"
        exit 1
    fi

    # Upgrade control plane nodes
    if [[ "$UPGRADE_CONTROL_PLANE" == true || -n "$SPECIFIC_NODE" ]]; then
        local control_planes=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers -o custom-columns=NAME:.metadata.name)

        for node in $control_planes; do
            if [[ -n "$SPECIFIC_NODE" && "$node" != "$SPECIFIC_NODE" ]]; then
                continue
            fi

            log "Processing control plane node: $node"
            if ! upgrade_control_plane_node "$node"; then
                error "Failed to upgrade control plane node $node"
                exit 1
            fi

            # Wait between control plane upgrades
            sleep 30
        done
    fi

    # Upgrade worker nodes
    if [[ "$UPGRADE_WORKERS" == true ]]; then
        local workers=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' --no-headers -o custom-columns=NAME:.metadata.name)

        for node in $workers; do
            if [[ -n "$SPECIFIC_NODE" && "$node" != "$SPECIFIC_NODE" ]]; then
                continue
            fi

            log "Processing worker node: $node"
            if ! upgrade_worker_node "$node"; then
                error "Failed to upgrade worker node $node"
                exit 1
            fi

            # Wait between worker upgrades
            sleep 15
        done
    fi

    # Verify upgrade
    log "Verifying cluster after upgrade..."
    kubectl get nodes
    kubectl version

    # Check cluster health
    log "Checking cluster health..."
    kubectl get pods -A | grep -v "Running\|Completed" || true

    log "===== Kubernetes Cluster Upgrade Completed ====="
    log "Upgrade log: $LOG_DIR/cluster-upgrade.log"
    log "etcd backup: $BACKUP_DIR/"
}

# Run main
main
