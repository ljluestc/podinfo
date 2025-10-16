#!/bin/bash
# Cost Management Deployment Script
# This script deploys the complete cost management stack

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Cost Management Deployment${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Function to check if a resource exists
check_resource() {
    local resource=$1
    local namespace=$2
    local name=$3

    if kubectl get $resource -n $namespace $name &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to wait for deployment
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-300}

    echo -e "${YELLOW}Waiting for deployment $deployment in namespace $namespace...${NC}"
    kubectl wait --for=condition=available --timeout=${timeout}s \
        deployment/$deployment -n $namespace || {
        echo -e "${RED}Deployment $deployment failed to become ready${NC}"
        kubectl get pods -n $namespace
        kubectl logs -n $namespace -l app=$deployment --tail=50
        return 1
    }
    echo -e "${GREEN}✓ Deployment $deployment is ready${NC}"
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check for Prometheus
if ! check_resource svc monitoring kube-prometheus-stack-prometheus; then
    echo -e "${RED}✗ Prometheus not found in monitoring namespace${NC}"
    echo -e "${YELLOW}Please install Prometheus first:${NC}"
    echo "  kubectl apply -f k8s-cluster/manifests/12-observability/prometheus-stack.yaml"
    exit 1
fi
echo -e "${GREEN}✓ Prometheus is installed${NC}"

# Check for Metrics Server
if ! kubectl top nodes &> /dev/null; then
    echo -e "${YELLOW}⚠ Metrics Server not responding (optional but recommended)${NC}"
else
    echo -e "${GREEN}✓ Metrics Server is available${NC}"
fi

echo ""
echo -e "${GREEN}Step 1: Deploying OpenCost${NC}"
kubectl apply -f 01-opencost-deployment.yaml

echo ""
echo -e "${YELLOW}Waiting for OpenCost to be ready...${NC}"
sleep 5
wait_for_deployment opencost opencost 120

echo ""
echo -e "${GREEN}Step 2: Configuring Cost Allocation${NC}"
kubectl apply -f 02-cost-allocation.yaml
echo -e "${GREEN}✓ Cost allocation configured${NC}"

echo ""
echo -e "${GREEN}Step 3: Setting up Cost Alerts${NC}"
echo -e "${YELLOW}⚠ Remember to update alert secrets with your credentials${NC}"
kubectl apply -f 03-cost-alerts.yaml
echo -e "${GREEN}✓ Cost alerts configured${NC}"

echo ""
echo -e "${GREEN}Step 4: Deploying Right-sizing Recommendations${NC}"
kubectl apply -f 04-rightsizing-recommendations.yaml
echo -e "${GREEN}✓ Right-sizing analyzer scheduled${NC}"

echo ""
echo -e "${GREEN}Step 5: Setting up Idle Resource Detection${NC}"
kubectl apply -f 05-idle-resource-cleanup.yaml
echo -e "${GREEN}✓ Idle resource detector scheduled${NC}"

echo ""
echo -e "${GREEN}Step 6: Importing Cost Dashboards${NC}"
kubectl apply -f 06-cost-dashboards.yaml
echo -e "${GREEN}✓ Grafana dashboards imported${NC}"

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Access OpenCost UI:"
echo "   kubectl port-forward -n opencost svc/opencost 9003:9003"
echo "   Open http://localhost:9003"
echo ""
echo "2. Access Grafana Dashboards:"
echo "   kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
echo "   Open http://localhost:3000"
echo "   Look for 'Cost Management' dashboards"
echo ""
echo "3. Verify OpenCost is collecting data:"
echo "   curl http://localhost:9003/allocation/compute?window=1d"
echo ""
echo "4. Configure alert notifications:"
echo "   kubectl edit secret -n opencost alertmanager-smtp-secret"
echo "   kubectl edit secret -n opencost slack-webhook-secret"
echo ""
echo "5. Label your workloads for cost tracking:"
echo "   See README.md for labeling guidelines"
echo ""

# Check OpenCost health
echo -e "${YELLOW}Checking OpenCost health...${NC}"
kubectl get pods -n opencost
echo ""

# Show cost allocation example
echo -e "${YELLOW}Example: Add cost tracking labels to a deployment${NC}"
echo "---"
cat <<'EOF'
kubectl patch deployment my-app -p '
{
  "metadata": {
    "labels": {
      "team": "platform-team",
      "application": "my-app",
      "environment": "production",
      "cost-center": "CC-1001"
    },
    "annotations": {
      "cost-allocation/team": "platform-team",
      "cost-allocation/owner": "team@example.com",
      "cost-allocation/monthly-budget": "200"
    }
  },
  "spec": {
    "template": {
      "metadata": {
        "labels": {
          "team": "platform-team",
          "application": "my-app",
          "environment": "production"
        }
      }
    }
  }
}'
EOF
echo "---"
echo ""

echo -e "${GREEN}For detailed documentation, see README.md${NC}"
