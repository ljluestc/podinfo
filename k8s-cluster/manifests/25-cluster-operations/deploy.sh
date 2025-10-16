#!/bin/bash
# Deploy Cluster Operations Automation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "===== Deploying Cluster Operations Automation ====="

# Make scripts executable
echo "Making scripts executable..."
chmod +x "$SCRIPT_DIR"/*.sh

# Create necessary directories
echo "Creating directories..."
sudo mkdir -p /var/log/k8s-operations
sudo mkdir -p /var/log/k8s-operations/reports
sudo mkdir -p /var/backups/k8s-cluster

# Set permissions
sudo chmod 755 /var/log/k8s-operations
sudo chmod 755 /var/log/k8s-operations/reports
sudo chmod 700 /var/backups/k8s-cluster

# Deploy capacity monitoring
echo "Deploying capacity monitoring..."
kubectl apply -f "$SCRIPT_DIR/04-capacity-monitoring.yaml"

# Deploy maintenance windows
echo "Deploying maintenance window scheduler..."
kubectl apply -f "$SCRIPT_DIR/05-maintenance-windows.yaml"

# Deploy runbooks
echo "Deploying operational runbooks..."
kubectl apply -f "$SCRIPT_DIR/07-operations-runbooks.yaml"

# Copy scripts to /usr/local/bin for easy access
echo "Installing scripts to /usr/local/bin..."
sudo cp "$SCRIPT_DIR/01-cluster-upgrade.sh" /usr/local/bin/k8s-cluster-upgrade
sudo cp "$SCRIPT_DIR/02-cluster-rollback.sh" /usr/local/bin/k8s-cluster-rollback
sudo cp "$SCRIPT_DIR/03-node-management.sh" /usr/local/bin/k8s-node-management
sudo cp "$SCRIPT_DIR/06-health-checks.sh" /usr/local/bin/k8s-health-check

sudo chmod +x /usr/local/bin/k8s-*

echo ""
echo "✓ Deployment complete!"
echo ""
echo "Available commands:"
echo "  k8s-cluster-upgrade      - Cluster upgrade automation"
echo "  k8s-cluster-rollback     - Cluster rollback automation"
echo "  k8s-node-management      - Node management operations"
echo "  k8s-health-check         - Cluster health checks"
echo ""
echo "Verify deployment:"
echo "  kubectl get prometheusrules -n monitoring capacity-monitoring-rules"
echo "  kubectl get cronjob -n kube-system"
echo "  kubectl get configmap -n kube-system maintenance-windows-config"
echo ""
echo "View documentation:"
echo "  cat $SCRIPT_DIR/README.md"
echo ""
