#!/bin/bash
set -e

# Kubernetes HA Cluster Setup Script
# This script initializes a highly available Kubernetes cluster

echo "===== Kubernetes HA Cluster Setup ====="
echo "This script will set up a production-ready Kubernetes cluster with:"
echo "- HA control plane (3 nodes)"
echo "- Secure etcd cluster"
echo "- Audit logging"
echo "- Encryption at rest"
echo "- RBAC with least privilege"
echo ""

# Configuration variables
CONTROL_PLANE_ENDPOINT="k8s-api.example.com:6443"
POD_SUBNET="10.244.0.0/16"
SERVICE_SUBNET="10.96.0.0/12"
KUBERNETES_VERSION="1.28.0"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    print_error "Cannot detect OS"
    exit 1
fi

print_status "Detected OS: $OS $VERSION"

# Step 1: Install prerequisites
print_status "Installing prerequisites..."
case "$OS" in
    ubuntu|debian)
        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release socat conntrack ipset
        ;;
    centos|rhel|fedora)
        yum install -y yum-utils device-mapper-persistent-data lvm2 socat conntrack ipset
        ;;
    *)
        print_error "Unsupported OS: $OS"
        exit 1
        ;;
esac

# Step 2: Disable swap
print_status "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Step 3: Configure kernel modules
print_status "Loading required kernel modules..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Step 4: Configure sysctl
print_status "Configuring sysctl parameters..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Step 5: Install containerd
print_status "Installing containerd..."
case "$OS" in
    ubuntu|debian)
        curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list
        apt-get update
        apt-get install -y containerd.io
        ;;
    centos|rhel|fedora)
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y containerd.io
        ;;
esac

# Configure containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

# Step 6: Install kubeadm, kubelet, kubectl
print_status "Installing Kubernetes components..."
case "$OS" in
    ubuntu|debian)
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
        apt-get update
        apt-get install -y kubelet kubeadm kubectl
        apt-mark hold kubelet kubeadm kubectl
        ;;
    centos|rhel|fedora)
        cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
        yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
        ;;
esac

systemctl enable kubelet

# Step 7: Generate encryption key
print_status "Generating encryption key..."
mkdir -p /etc/kubernetes
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
sed -i "s|<BASE64_ENCODED_32_BYTE_KEY>|$ENCRYPTION_KEY|g" /etc/kubernetes/encryption-config.yaml

# Step 8: Create audit log directory
print_status "Creating audit log directory..."
mkdir -p /var/log/kubernetes/audit
chmod 700 /var/log/kubernetes/audit

# Step 9: Copy configuration files
print_status "Copying configuration files..."
cp ../configs/audit-policy.yaml /etc/kubernetes/
cp ../configs/encryption-config.yaml /etc/kubernetes/

# Step 10: Initialize first control plane node
print_status "Initializing Kubernetes control plane..."
print_warning "This is the first control plane node initialization"
print_warning "For additional control plane nodes, use the join command that will be displayed"

kubeadm init \
    --config ../configs/kubeadm-config.yaml \
    --upload-certs \
    | tee /tmp/kubeadm-init.log

# Step 11: Configure kubectl for root user
print_status "Configuring kubectl..."
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Step 12: Wait for cluster to be ready
print_status "Waiting for cluster to be ready..."
sleep 30

# Step 13: Verify cluster
print_status "Verifying cluster..."
kubectl get nodes
kubectl get pods -A

print_status "Control plane setup complete!"
print_warning "Join commands have been saved to /tmp/kubeadm-init.log"
print_warning "Next steps:"
echo "  1. Install a CNI plugin (Calico/Cilium)"
echo "  2. Join additional control plane nodes"
echo "  3. Join worker nodes"
echo "  4. Configure RBAC and security policies"
echo ""
print_status "Save the join commands from /tmp/kubeadm-init.log for adding more nodes"
