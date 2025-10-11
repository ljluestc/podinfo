#!/bin/bash
set -e

# Script to join additional control plane nodes to the cluster

echo "===== Join Additional Control Plane Node ====="

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

# Prompt for join command parameters
print_warning "You need the control plane join command from the first control plane node"
print_warning "It should look like:"
echo "kubeadm join k8s-api.example.com:6443 --token <token> \\"
echo "    --discovery-token-ca-cert-hash sha256:<hash> \\"
echo "    --control-plane --certificate-key <cert-key>"
echo ""

read -p "Enter the API server endpoint (e.g., k8s-api.example.com:6443): " API_ENDPOINT
read -p "Enter the bootstrap token: " TOKEN
read -p "Enter the CA cert hash (sha256:...): " CA_HASH
read -p "Enter the certificate key: " CERT_KEY

print_status "Joining control plane node..."

# Copy encryption and audit configs
print_status "Copying configuration files..."
mkdir -p /etc/kubernetes
cp ../configs/encryption-config.yaml /etc/kubernetes/
cp ../configs/audit-policy.yaml /etc/kubernetes/

# Generate new encryption key
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
sed -i "s|<BASE64_ENCODED_32_BYTE_KEY>|$ENCRYPTION_KEY|g" /etc/kubernetes/encryption-config.yaml

# Create audit log directory
mkdir -p /var/log/kubernetes/audit
chmod 700 /var/log/kubernetes/audit

# Join the cluster
kubeadm join "$API_ENDPOINT" \
    --token "$TOKEN" \
    --discovery-token-ca-cert-hash "$CA_HASH" \
    --control-plane \
    --certificate-key "$CERT_KEY"

# Configure kubectl
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

print_status "Control plane node joined successfully!"
kubectl get nodes
