#!/bin/bash
set -e

# Script to join worker nodes to the cluster

echo "===== Join Worker Node ====="

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_error() {
    echo -e "${RED}[!]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[*]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   exit 1
fi

# Prompt for node labels and taints
print_warning "Configure worker node properties"
read -p "Enter node labels (e.g., env=production,tier=frontend) [optional]: " NODE_LABELS
read -p "Enter node taints (e.g., dedicated=gpu:NoSchedule) [optional]: " NODE_TAINTS

# Prompt for join command parameters
print_warning "You need the worker join command from the control plane"
echo "kubeadm join k8s-api.example.com:6443 --token <token> \\"
echo "    --discovery-token-ca-cert-hash sha256:<hash>"
echo ""

read -p "Enter the API server endpoint (e.g., k8s-api.example.com:6443): " API_ENDPOINT
read -p "Enter the bootstrap token: " TOKEN
read -p "Enter the CA cert hash (sha256:...): " CA_HASH

# Build kubeadm join command
JOIN_CMD="kubeadm join $API_ENDPOINT --token $TOKEN --discovery-token-ca-cert-hash $CA_HASH"

# Add node registration options if labels/taints specified
if [ ! -z "$NODE_LABELS" ] || [ ! -z "$NODE_TAINTS" ]; then
    EXTRA_ARGS=""
    [ ! -z "$NODE_LABELS" ] && EXTRA_ARGS="$EXTRA_ARGS --node-labels=$NODE_LABELS"
    [ ! -z "$NODE_TAINTS" ] && EXTRA_ARGS="$EXTRA_ARGS --node-taints=$NODE_TAINTS"
    JOIN_CMD="$JOIN_CMD $EXTRA_ARGS"
fi

print_status "Joining worker node..."
eval "$JOIN_CMD"

print_status "Worker node joined successfully!"
print_warning "Verify node status from control plane: kubectl get nodes"
