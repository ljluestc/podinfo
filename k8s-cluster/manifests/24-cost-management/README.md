# Cost Management and Optimization

This directory contains comprehensive cost management and optimization infrastructure for Kubernetes clusters using OpenCost and related tools.

## Overview

The cost management system provides:
- Real-time cost visibility and tracking
- Cost allocation by namespace, team, application, and environment
- Budget enforcement and alerting
- Right-sizing recommendations for resources
- Idle resource detection and cleanup automation
- Comprehensive dashboards for cost analysis
- Showback/chargeback reporting

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Cost Management Stack                 │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐    ┌──────────────┐    ┌───────────┐ │
│  │   OpenCost   │───▶│  Prometheus  │───▶│  Grafana  │ │
│  │ (Cost Model) │    │  (Metrics)   │    │(Dashboard)│ │
│  └──────────────┘    └──────────────┘    └───────────┘ │
│         │                                        │        │
│         ▼                                        ▼        │
│  ┌──────────────────────────────────────────────────┐   │
│  │          Cost Allocation & Tracking              │   │
│  │  • Namespace-level tracking                      │   │
│  │  • Team/Application labels                       │   │
│  │  • Environment classification                    │   │
│  └──────────────────────────────────────────────────┘   │
│         │                                                 │
│         ▼                                                 │
│  ┌──────────────────────────────────────────────────┐   │
│  │        Optimization & Automation                  │   │
│  │  • Right-sizing recommendations                   │   │
│  │  • Idle resource detection                        │   │
│  │  • Automated cleanup                              │   │
│  │  • Budget alerts                                  │   │
│  └──────────────────────────────────────────────────┘   │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

## Components

### 1. OpenCost Deployment (`01-opencost-deployment.yaml`)

**Purpose**: Deploy OpenCost for real-time cluster cost monitoring

**Features**:
- Integrates with existing Prometheus for metrics
- Provides cost allocation API
- Calculates cost per pod, namespace, and label
- Supports custom pricing models

**Configuration**:
```yaml
# Prometheus endpoint (update if needed)
PROMETHEUS_SERVER_ENDPOINT: "http://kube-prometheus-stack-prometheus.monitoring.svc:9090"

# Cloud provider (for pricing data)
CLOUD_PROVIDER: "custom"  # Options: aws, azure, gcp, custom

# Cluster ID
CLUSTER_ID: "default-cluster"
```

**Access OpenCost UI**:
```bash
# Port-forward to access locally
kubectl port-forward -n opencost svc/opencost 9003:9003

# Access at http://localhost:9003
```

### 2. Cost Allocation (`02-cost-allocation.yaml`)

**Purpose**: Configure cost tracking by teams, applications, and departments

**Required Labels** for workloads:
```yaml
labels:
  team: "platform-team"              # Team name
  application: "podinfo"             # Application identifier
  environment: "production"          # Environment type
  cost-center: "CC-1001"            # Cost center code

annotations:
  cost-allocation/team: "platform-team"
  cost-allocation/owner: "team@example.com"
  cost-allocation/budget-code: "ENG-2024-Q4"
  cost-allocation/monthly-budget: "500"
```

**Cost Allocation Dimensions**:
- Namespace: Primary allocation unit
- Team: Team ownership tracking
- Application: Per-application costs
- Environment: Dev/staging/production separation
- Cost Center: Business unit mapping
- Project: Initiative-based tracking

**Label Enforcement**:
The system includes OPA Gatekeeper policies to enforce cost allocation labels on new workloads (currently in `dryrun` mode).

To enable enforcement:
```bash
kubectl patch K8sRequiredCostLabels require-cost-labels \
  --type='json' -p='[{"op": "replace", "path": "/spec/enforcementAction", "value": "deny"}]'
```

### 3. Cost Alerts (`03-cost-alerts.yaml`)

**Purpose**: Proactive cost monitoring and budget enforcement

**Alert Types**:

1. **Budget Alerts**:
   - Warning at 80% of budget
   - Critical at 100% of budget
   - Configured per namespace via annotations

2. **Cost Spike Alerts**:
   - Detects >20% cost increases
   - Cluster-wide and namespace-level

3. **Optimization Alerts**:
   - Over-provisioned resources
   - Idle resource costs
   - Expensive pods running

4. **Storage Alerts**:
   - High storage costs
   - Unused PVCs

**Alert Routing**:
Alerts are routed to different teams based on severity:
- **Critical**: Cost team + management + PagerDuty
- **Warning**: Cost team via email and Slack
- **Info**: Platform team via email

**Configuration**:
Update secrets in `03-cost-alerts.yaml`:
```yaml
# SMTP credentials
alertmanager-smtp-secret: "SMTP_PASSWORD_HERE"

# Slack webhook
slack-webhook-secret: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# PagerDuty integration
pagerduty-secret: "PAGERDUTY_ROUTING_KEY_HERE"
```

### 4. Right-Sizing Recommendations (`04-rightsizing-recommendations.yaml`)

**Purpose**: Automated analysis and recommendations for optimal resource sizing

**Features**:
- Analyzes 7 days of historical usage (configurable)
- Recommends CPU and memory adjustments
- Calculates potential cost savings
- Uses percentile-based recommendations (p95)
- Integrates with VPA (Vertical Pod Autoscaler)

**Execution**:
```bash
# Automated: Runs daily at 2 AM via CronJob

# Manual execution:
kubectl create -f k8s-cluster/manifests/24-cost-management/04-rightsizing-recommendations.yaml

# View results:
kubectl logs -n opencost -l app=rightsizing
```

**VPA Integration**:
Vertical Pod Autoscaler can be used for automated right-sizing:
```bash
# Install VPA (if not already installed)
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler
./hack/vpa-up.sh

# VPA will provide recommendations for pods
kubectl get vpa -A
kubectl describe vpa <vpa-name>
```

**Configuration Thresholds**:
```yaml
cpu:
  change_threshold: 0.2      # 20% difference required for recommendation
  headroom_factor: 1.3       # 30% buffer above peak usage
  min_request: "10m"         # Minimum CPU request

memory:
  change_threshold: 0.2      # 20% difference required
  headroom_factor: 1.2       # 20% buffer
  min_request: "32Mi"        # Minimum memory request
```

### 5. Idle Resource Cleanup (`05-idle-resource-cleanup.yaml`)

**Purpose**: Detect and optionally cleanup idle/unused resources

**Detection Criteria**:
- Deployments with 0 replicas for >72 hours
- PVCs not mounted for >7 days
- Completed jobs older than 48 hours
- Failed jobs older than 24 hours
- Pods in CrashLoopBackOff for >12 hours

**Safety Features**:
- Protected namespaces (kube-system, monitoring, etc.)
- Protected labels (managed-by=Helm, protected=true)
- Three modes: report, dryrun, delete
- Notification period before deletion

**Execution**:
```bash
# Automated: Runs daily at 3 AM via CronJob in 'report' mode

# Manual execution (report mode):
kubectl create job --from=cronjob/idle-resource-detector manual-check -n opencost

# View report:
kubectl logs -n opencost -l app=idle-cleanup

# Change to delete mode (use with caution):
kubectl set env cronjob/idle-resource-detector CLEANUP_MODE=delete -n opencost
```

**Protected Resources**:
To protect specific resources from cleanup:
```yaml
labels:
  protected: "true"
  # OR
  cost-optimization/exclude: "true"
```

### 6. Cost Dashboards (`06-cost-dashboards.yaml`)

**Purpose**: Comprehensive Grafana dashboards for cost visualization

**Dashboards Included**:

1. **Cost Overview Dashboard**:
   - Total monthly cluster cost
   - Cost by namespace (pie chart)
   - Cost trend over time
   - Top 10 most expensive namespaces
   - Cost by resource type (CPU/Memory/Storage)
   - Budget vs actual comparison

2. **Cost Allocation Dashboard**:
   - Cost by team
   - Cost by application
   - Cost by environment (dev/staging/prod)
   - Cost by cost center
   - Showback/chargeback reports

3. **Cost Optimization Dashboard**:
   - Potential monthly savings
   - Idle resource costs
   - Over-provisioned containers
   - Right-sizing recommendations
   - Unused PVCs
   - Idle deployments

4. **Resource Efficiency Dashboard**:
   - CPU efficiency gauge
   - Memory efficiency gauge
   - Cost efficiency score
   - Namespace efficiency heatmap
   - Request vs limit utilization

**Accessing Dashboards**:
```bash
# If Grafana is not exposed, port-forward:
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Access at http://localhost:3000
# Default credentials: admin / <check your installation>

# Dashboards are auto-imported via ConfigMap labels
```

## Deployment Instructions

### Prerequisites

1. **Prometheus** must be installed and running:
```bash
kubectl get svc -n monitoring kube-prometheus-stack-prometheus
```

2. **Grafana** should be available for dashboards:
```bash
kubectl get svc -n monitoring kube-prometheus-stack-grafana
```

3. **Metrics Server** for resource metrics:
```bash
kubectl get deployment metrics-server -n kube-system
```

### Installation

#### Step 1: Deploy OpenCost
```bash
kubectl apply -f k8s-cluster/manifests/24-cost-management/01-opencost-deployment.yaml
```

Verify deployment:
```bash
kubectl get pods -n opencost
kubectl logs -n opencost -l app=opencost
```

#### Step 2: Configure Cost Allocation
```bash
kubectl apply -f k8s-cluster/manifests/24-cost-management/02-cost-allocation.yaml
```

#### Step 3: Set Up Cost Alerts
```bash
# Update secrets first with your credentials
kubectl apply -f k8s-cluster/manifests/24-cost-management/03-cost-alerts.yaml
```

Verify alerts:
```bash
kubectl get prometheusrule -n opencost
```

#### Step 4: Enable Right-Sizing
```bash
kubectl apply -f k8s-cluster/manifests/24-cost-management/04-rightsizing-recommendations.yaml
```

#### Step 5: Configure Idle Resource Detection
```bash
kubectl apply -f k8s-cluster/manifests/24-cost-management/05-idle-resource-cleanup.yaml
```

#### Step 6: Import Dashboards
```bash
kubectl apply -f k8s-cluster/manifests/24-cost-management/06-cost-dashboards.yaml
```

Grafana will auto-import dashboards with the label `grafana_dashboard: "1"`.

### Verification

```bash
# Check all components
kubectl get all -n opencost

# Verify OpenCost is scraping metrics
kubectl port-forward -n opencost svc/opencost 9003:9003
curl http://localhost:9003/allocation/compute

# Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit http://localhost:9090/targets and look for opencost

# Verify alerts are loaded
kubectl get prometheusrule -n opencost cost-alerts -o yaml
```

## Usage Guide

### Viewing Costs

#### Via OpenCost API
```bash
# Port-forward OpenCost
kubectl port-forward -n opencost svc/opencost 9003:9003

# Get cost by namespace (last 24h)
curl "http://localhost:9003/allocation/compute?window=1d&aggregate=namespace"

# Get cost by label
curl "http://localhost:9003/allocation/compute?window=7d&aggregate=label:team"

# Get costs with filters
curl "http://localhost:9003/allocation/compute?window=1d&filterNamespaces=production"
```

#### Via Grafana Dashboards
1. Access Grafana (port-forward if needed)
2. Navigate to Dashboards > Browse
3. Look for "Cost Management" dashboards:
   - Cost Management - Overview
   - Cost Management - Allocation
   - Cost Management - Optimization
   - Cost Management - Resource Efficiency

### Setting Budgets

Add budget annotations to namespaces:
```bash
kubectl annotate namespace production \
  cost-allocation/monthly-budget="1000" \
  cost-allocation/team="platform-team" \
  cost-allocation/budget-code="ENG-2024-Q4"
```

### Labeling Workloads for Cost Tracking

Apply required labels to deployments:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  labels:
    team: "platform-team"
    application: "my-app"
    environment: "production"
    cost-center: "CC-1001"
  annotations:
    cost-allocation/team: "platform-team"
    cost-allocation/owner: "platform-team@example.com"
    cost-allocation/monthly-budget: "200"
spec:
  template:
    metadata:
      labels:
        team: "platform-team"
        application: "my-app"
        environment: "production"
    # ... rest of spec
```

### Generating Reports

#### Showback Report
```bash
# Query costs by team for the last month
curl "http://localhost:9003/allocation/compute?window=30d&aggregate=label:team" | jq .
```

#### Chargeback Report
Export costs from Grafana's "Cost Allocation" dashboard or use the API:
```bash
# Get detailed breakdown
curl "http://localhost:9003/allocation/compute?window=30d&aggregate=namespace,label:team" > monthly-costs.json
```

### Right-Sizing Workflow

1. **Review Recommendations**:
```bash
# View latest recommendations
kubectl logs -n opencost -l app=rightsizing --tail=100
```

2. **Apply Recommendations**:
```yaml
# Update deployment with recommended values
kubectl edit deployment <deployment-name>

# Or use VPA to auto-apply (updateMode: "Auto")
kubectl get vpa <vpa-name> -o yaml
```

3. **Monitor Impact**:
- Check cost savings in Grafana
- Ensure application performance is maintained
- Adjust if needed

### Cost Optimization Best Practices

1. **Label Everything**:
   - Ensure all workloads have team, application, and environment labels
   - Use consistent naming conventions

2. **Set Resource Requests/Limits**:
   - Always specify resource requests
   - Use limits to prevent runaway costs

3. **Regular Reviews**:
   - Weekly review of cost dashboards
   - Monthly review of optimization recommendations
   - Quarterly budget reviews

4. **Automate Cleanup**:
   - Enable idle resource cleanup after testing
   - Set up retention policies for completed jobs

5. **Scale Down Non-Production**:
   - Scale down dev/staging environments during off-hours
   - Use node autoscaling to reduce unused capacity

6. **Use Efficient Storage**:
   - Choose appropriate storage classes
   - Clean up unused PVCs regularly
   - Use object storage for large datasets

## Cost Optimization Policies

The system includes automated policies for cost optimization:

### Auto-Scaling Policies
- Scale down idle workloads (after 60 minutes idle)
- Schedule-based scaling (dev/staging environments)
- Spot instance usage for non-critical workloads

### Resource Policies
- Enforce resource requests and limits
- Default limits for unlabeled workloads
- Right-sizing recommendations

### Storage Policies
- Automatic cleanup of unused PVCs (7 days)
- Cost-effective storage class selection
- Retention policy enforcement

## Troubleshooting

### OpenCost Not Showing Data

1. **Check Prometheus Connection**:
```bash
kubectl logs -n opencost -l app=opencost | grep -i prometheus
```

2. **Verify Metrics**:
```bash
kubectl get servicemonitor -n opencost
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Check targets at http://localhost:9090/targets
```

3. **Check Configuration**:
```bash
kubectl get configmap -n opencost opencost-config -o yaml
```

### Alerts Not Firing

1. **Check PrometheusRule**:
```bash
kubectl get prometheusrule -n opencost cost-alerts -o yaml
```

2. **Verify Alert State**:
```bash
# Access Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Check alerts at http://localhost:9090/alerts
```

3. **Check Alertmanager Config**:
```bash
kubectl get alertmanagerconfig -n opencost -o yaml
```

### Dashboards Not Appearing

1. **Check ConfigMap Labels**:
```bash
kubectl get configmap -n opencost cost-dashboards -o yaml | grep -A 2 labels
# Should have: grafana_dashboard: "1"
```

2. **Restart Grafana**:
```bash
kubectl rollout restart deployment -n monitoring kube-prometheus-stack-grafana
```

### Right-Sizing CronJob Failing

1. **Check Job Logs**:
```bash
kubectl get jobs -n opencost
kubectl logs -n opencost job/rightsizing-analyzer-<timestamp>
```

2. **Verify Permissions**:
```bash
kubectl auth can-i get pods --as=system:serviceaccount:opencost:rightsizing-analyzer
```

## Maintenance

### Regular Tasks

**Daily**:
- Review cost alerts
- Check for anomalies in dashboards

**Weekly**:
- Review right-sizing recommendations
- Check idle resource reports
- Update workload labels if needed

**Monthly**:
- Generate showback/chargeback reports
- Review budget allocations
- Optimize based on trends

**Quarterly**:
- Review pricing configuration
- Update cost center allocations
- Audit cost allocation accuracy

### Updates

Update OpenCost:
```bash
kubectl set image deployment/opencost -n opencost \
  opencost=quay.io/kubecost1/kubecost-cost-model:<new-version>
```

Update Configuration:
```bash
kubectl apply -f k8s-cluster/manifests/24-cost-management/
```

## Security Considerations

1. **RBAC**: OpenCost requires cluster-wide read access
2. **Secrets**: Store sensitive credentials in Kubernetes secrets
3. **Network Policies**: Limit OpenCost's network access
4. **API Access**: Restrict access to OpenCost API if exposed

## Cost Estimation

### Pricing Configuration

Update pricing in `01-opencost-deployment.yaml`:
```json
{
  "provider": "custom",
  "CPU": "0.031611",     # $ per CPU per hour
  "RAM": "0.004237",     # $ per GB RAM per hour
  "storage": "0.00005479", # $ per GB storage per hour
  "GPU": "0.95"          # $ per GPU per hour
}
```

For cloud providers (AWS/Azure/GCP), set the appropriate provider and optionally provide API credentials for real-time pricing.

## Support and Resources

- **OpenCost Documentation**: https://www.opencost.io/docs/
- **Prometheus Query Examples**: See dashboards for reference queries
- **Community**: OpenCost Slack / GitHub Issues

## License

This cost management setup is provided as-is for use with the Kubernetes security cluster project.

---

**Last Updated**: 2024
**Maintained By**: Platform Team
