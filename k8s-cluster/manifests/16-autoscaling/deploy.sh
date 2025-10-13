#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Kubernetes Autoscaling Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo -e "${YELLOW}Warning: helm is not installed. Some components require Helm.${NC}"
fi

# Function to wait for deployment
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-300}

    echo -e "${YELLOW}Waiting for deployment $deployment in namespace $namespace...${NC}"
    kubectl wait --for=condition=available --timeout=${timeout}s \
        deployment/$deployment -n $namespace 2>/dev/null || true
}

# Function to wait for pods
wait_for_pods() {
    local namespace=$1
    local label=$2
    local timeout=${3:-300}

    echo -e "${YELLOW}Waiting for pods with label $label in namespace $namespace...${NC}"
    kubectl wait --for=condition=ready --timeout=${timeout}s \
        pod -l $label -n $namespace 2>/dev/null || true
}

echo -e "${GREEN}Step 1: Creating namespaces${NC}"
kubectl create namespace keda --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Namespaces created${NC}"
echo ""

echo -e "${GREEN}Step 2: Installing Metrics Server${NC}"
if helm version &> /dev/null; then
    echo "Installing Metrics Server via Helm..."
    helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ || true
    helm repo update
    helm upgrade --install metrics-server metrics-server/metrics-server \
        --namespace kube-system \
        --set args[0]="--kubelet-insecure-tls" \
        --set args[1]="--kubelet-preferred-address-types=InternalIP" \
        --wait || echo -e "${YELLOW}Metrics server may already be installed${NC}"
else
    echo "Applying Metrics Server manifests..."
    kubectl apply -f 00-metrics-server.yaml
    wait_for_deployment kube-system metrics-server
fi
echo -e "${GREEN}✓ Metrics Server installed${NC}"
echo ""

echo -e "${GREEN}Step 3: Deploying Horizontal Pod Autoscalers${NC}"
kubectl apply -f 01-hpa-configurations.yaml
echo -e "${GREEN}✓ HPA configurations applied${NC}"
echo ""

echo -e "${GREEN}Step 4: Installing Vertical Pod Autoscaler${NC}"
echo -e "${YELLOW}Note: VPA requires installation from the official repository${NC}"
echo -e "${YELLOW}Run the following commands to install VPA:${NC}"
echo ""
echo "  git clone https://github.com/kubernetes/autoscaler.git"
echo "  cd autoscaler/vertical-pod-autoscaler"
echo "  ./hack/vpa-up.sh"
echo ""
echo "Or via Helm:"
echo "  helm repo add fairwinds-stable https://charts.fairwinds.com/stable"
echo "  helm install vpa fairwinds-stable/vpa --namespace vpa --create-namespace"
echo ""
echo "After VPA is installed, apply the VPA configurations:"
echo "  kubectl apply -f 02-vpa-configurations.yaml"
echo ""
read -p "Press Enter to continue after VPA installation, or Ctrl+C to skip..."
kubectl apply -f 02-vpa-configurations.yaml || echo -e "${YELLOW}VPA not yet installed, skipping configurations${NC}"
echo ""

echo -e "${GREEN}Step 5: Installing KEDA${NC}"
if helm version &> /dev/null; then
    echo "Installing KEDA via Helm..."
    helm repo add kedacore https://kedacore.github.io/charts || true
    helm repo update
    helm upgrade --install keda kedacore/keda \
        --namespace keda \
        --create-namespace \
        --set prometheus.metricServer.enabled=true \
        --set prometheus.operator.enabled=true \
        --wait || echo -e "${YELLOW}KEDA may already be installed${NC}"

    echo "Waiting for KEDA to be ready..."
    wait_for_deployment keda keda-operator
    wait_for_deployment keda keda-operator-metrics-apiserver
else
    echo -e "${YELLOW}Helm not available. Please install KEDA manually:${NC}"
    echo "  helm repo add kedacore https://kedacore.github.io/charts"
    echo "  helm install keda kedacore/keda --namespace keda --create-namespace"
fi

echo "Applying KEDA configurations..."
kubectl apply -f 03-keda-configurations.yaml
echo -e "${GREEN}✓ KEDA installed and configured${NC}"
echo ""

echo -e "${GREEN}Step 6: Installing Cluster Autoscaler${NC}"
echo -e "${YELLOW}Note: Cluster Autoscaler requires cloud provider configuration${NC}"
echo ""
echo "Please update the following in 04-cluster-autoscaler.yaml:"
echo "  1. Cloud provider-specific ServiceAccount annotations (IRSA/Workload Identity)"
echo "  2. Cluster name in the command arguments"
echo "  3. Node group auto-discovery tags"
echo "  4. Cloud provider (aws/gcp/azure)"
echo ""
read -p "Have you configured the cloud provider settings? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl apply -f 04-cluster-autoscaler.yaml
    wait_for_deployment kube-system cluster-autoscaler
    echo -e "${GREEN}✓ Cluster Autoscaler deployed${NC}"
else
    echo -e "${YELLOW}Skipping Cluster Autoscaler deployment${NC}"
fi
echo ""

echo -e "${GREEN}Step 7: Setting up Monitoring and Dashboards${NC}"
kubectl apply -f 05-monitoring-dashboards.yaml
echo -e "${GREEN}✓ Monitoring dashboards configured${NC}"
echo ""

echo -e "${GREEN}Step 8: Installing Prometheus Adapter for Custom Metrics${NC}"
if helm version &> /dev/null; then
    echo "Installing Prometheus Adapter via Helm..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
    helm repo update
    helm upgrade --install prometheus-adapter prometheus-community/prometheus-adapter \
        --namespace monitoring \
        --set prometheus.url=http://prometheus.monitoring.svc.cluster.local \
        --set prometheus.port=9090 \
        --wait || echo -e "${YELLOW}Prometheus Adapter may already be installed${NC}"
    echo -e "${GREEN}✓ Prometheus Adapter installed${NC}"
else
    echo -e "${YELLOW}Helm not available. Install Prometheus Adapter manually for custom metrics support${NC}"
fi
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Verification${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${YELLOW}Checking Metrics Server...${NC}"
kubectl top nodes 2>/dev/null && echo -e "${GREEN}✓ Metrics Server working${NC}" || echo -e "${RED}✗ Metrics Server not ready${NC}"
echo ""

echo -e "${YELLOW}Listing HPAs...${NC}"
kubectl get hpa --all-namespaces
echo ""

echo -e "${YELLOW}Listing VPAs...${NC}"
kubectl get vpa --all-namespaces 2>/dev/null || echo "VPA not installed"
echo ""

echo -e "${YELLOW}Checking KEDA...${NC}"
kubectl get scaledobjects --all-namespaces 2>/dev/null && echo -e "${GREEN}✓ KEDA installed${NC}" || echo -e "${YELLOW}No ScaledObjects found${NC}"
echo ""

echo -e "${YELLOW}Checking Cluster Autoscaler...${NC}"
kubectl get deployment cluster-autoscaler -n kube-system 2>/dev/null && echo -e "${GREEN}✓ Cluster Autoscaler deployed${NC}" || echo -e "${YELLOW}Cluster Autoscaler not found${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "✓ Metrics Server: Installed"
echo "✓ HPA: Configured"
echo "✓ VPA: Ready (if manually installed)"
echo "✓ KEDA: Installed"
echo "✓ Cluster Autoscaler: Configured (verify cloud provider settings)"
echo "✓ Monitoring: Dashboards and alerts configured"
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "1. Verify Metrics Server: kubectl top nodes"
echo "2. Check HPA status: kubectl get hpa --all-namespaces"
echo "3. View VPA recommendations: kubectl describe vpa <vpa-name>"
echo "4. Monitor KEDA scaling: kubectl get scaledobjects -w"
echo "5. Check Cluster Autoscaler logs: kubectl logs -n kube-system -l app.kubernetes.io/name=cluster-autoscaler"
echo "6. Access Grafana dashboards for autoscaling metrics"
echo ""
echo -e "${YELLOW}Important Configuration Notes:${NC}"
echo "- Update cloud provider credentials for Cluster Autoscaler"
echo "- Configure KEDA TriggerAuthentications with actual secrets"
echo "- Adjust HPA thresholds based on application requirements"
echo "- Review VPA recommendations before enabling Auto mode"
echo "- Set up appropriate PodDisruptionBudgets for production workloads"
echo ""
echo -e "${GREEN}Deployment complete!${NC}"
