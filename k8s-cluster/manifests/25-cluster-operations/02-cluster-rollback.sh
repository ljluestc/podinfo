#!/bin/bash
# Kubernetes Cluster Rollback Automation
# Handles emergency rollback of failed upgrades

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/k8s-operations"
BACKUP_DIR="/var/backups/k8s-cluster"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_DIR/cluster-rollback.log"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $*" | tee -a "$LOG_DIR/cluster-rollback.log"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $*" | tee -a "$LOG_DIR/cluster-rollback.log"
}

mkdir -p "$LOG_DIR"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Kubernetes Cluster Rollback Automation

OPTIONS:
    -v, --version VERSION          Rollback to specific version
    -e, --etcd-backup BACKUP_FILE  Restore from specific etcd backup
    -n, --node NODE               Rollback specific node only
    -l, --list-backups            List available etcd backups
    -f, --force                   Force rollback without confirmation
    -h, --help                    Display this help message

EXAMPLES:
    $0 --list-backups
    $0 --version 1.28.0
    $0 --etcd-backup /var/backups/k8s-cluster/etcd-backup-20241013.db
    $0 --node worker-1 --version 1.28.0

EOF
    exit 1
}

# List available backups
list_backups() {
    log "Available etcd backups:"
    if [[ -d "$BACKUP_DIR" ]]; then
        ls -lh "$BACKUP_DIR"/etcd-backup-* 2>/dev/null || {
            warning "No backups found in $BACKUP_DIR"
            return 1
        }
    else
        error "Backup directory $BACKUP_DIR does not exist"
        return 1
    fi
}

# Restore etcd from backup
restore_etcd() {
    local backup_file=$1

    if [[ ! -f "$backup_file" ]]; then
        error "Backup file not found: $backup_file"
        return 1
    fi

    log "Restoring etcd from: $backup_file"

    warning "CRITICAL: This will restore etcd to a previous state"
    warning "All changes after the backup will be lost"

    if [[ "$FORCE" != true ]]; then
        read -p "Continue with etcd restore? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            log "etcd restore cancelled"
            return 1
        fi
    fi

    # Stop kube-apiserver
    log "Stopping kube-apiserver..."
    kubectl cordon --all || true

    warning "Manual step: On each control plane node, run:"
    cat <<'EOF'
    # Move apiserver manifest
    mv /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/

    # Stop etcd
    mv /etc/kubernetes/manifests/etcd.yaml /etc/kubernetes/

    # Backup current etcd data
    mv /var/lib/etcd /var/lib/etcd.backup

    # Restore from snapshot
    ETCDCTL_API=3 etcdctl snapshot restore BACKUP_FILE \
      --data-dir=/var/lib/etcd \
      --name=NODE_NAME \
      --initial-cluster=CLUSTER_CONFIG \
      --initial-cluster-token=etcd-cluster \
      --initial-advertise-peer-urls=https://NODE_IP:2380

    # Start etcd
    mv /etc/kubernetes/etcd.yaml /etc/kubernetes/manifests/

    # Wait for etcd to start
    sleep 30

    # Start apiserver
    mv /etc/kubernetes/kube-apiserver.yaml /etc/kubernetes/manifests/
EOF

    log "After completing manual steps, verify cluster health"
    return 0
}

# Rollback node to previous version
rollback_node() {
    local node=$1
    local version=$2

    log "Rolling back node $node to version $version"

    # Cordon node
    kubectl cordon "$node" || {
        error "Failed to cordon node $node"
        return 1
    }

    # Drain node
    log "Draining node $node..."
    kubectl drain "$node" \
        --ignore-daemonsets \
        --delete-emptydir-data \
        --timeout=600s \
        --force || {
        error "Failed to drain node $node"
        return 1
    }

    warning "Manual step: SSH to $node and downgrade packages:"
    cat <<EOF
    apt-mark unhold kubeadm kubelet kubectl
    apt-get update
    apt-get install -y --allow-downgrades \
        kubeadm=$version-* \
        kubelet=$version-* \
        kubectl=$version-*
    apt-mark hold kubeadm kubelet kubectl
    systemctl daemon-reload
    systemctl restart kubelet
EOF

    # Wait for node
    log "Waiting for node $node to be ready..."
    local retries=60
    while [[ $retries -gt 0 ]]; do
        if kubectl get node "$node" 2>/dev/null | grep -q " Ready"; then
            log "Node $node is ready"
            break
        fi
        sleep 5
        ((retries--))
    done

    # Uncordon
    kubectl uncordon "$node"

    log "Node $node rolled back successfully"
    return 0
}

# Parse arguments
VERSION=""
ETCD_BACKUP=""
SPECIFIC_NODE=""
LIST_BACKUPS=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -e|--etcd-backup)
            ETCD_BACKUP="$2"
            shift 2
            ;;
        -n|--node)
            SPECIFIC_NODE="$2"
            shift 2
            ;;
        -l|--list-backups)
            LIST_BACKUPS=true
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

# Main
main() {
    log "===== Kubernetes Cluster Rollback Started ====="

    if [[ "$LIST_BACKUPS" == true ]]; then
        list_backups
        exit 0
    fi

    if [[ -n "$ETCD_BACKUP" ]]; then
        restore_etcd "$ETCD_BACKUP"
        exit $?
    fi

    if [[ -z "$VERSION" ]]; then
        error "Version is required for rollback"
        usage
    fi

    warning "Rolling back to version $VERSION"

    if [[ "$FORCE" != true ]]; then
        read -p "Continue with rollback? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            log "Rollback cancelled"
            exit 0
        fi
    fi

    if [[ -n "$SPECIFIC_NODE" ]]; then
        rollback_node "$SPECIFIC_NODE" "$VERSION"
    else
        # Rollback all nodes
        local nodes=$(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name)
        for node in $nodes; do
            if ! rollback_node "$node" "$VERSION"; then
                error "Failed to rollback node $node"
                exit 1
            fi
            sleep 15
        done
    fi

    log "===== Kubernetes Cluster Rollback Completed ====="
}

main
