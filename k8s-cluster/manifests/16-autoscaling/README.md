# Kubernetes Autoscaling Configuration

Comprehensive autoscaling implementation for Kubernetes clusters including HPA, VPA, KEDA, and Cluster Autoscaler.

## Overview

This directory contains production-ready autoscaling configurations for:

1. **Horizontal Pod Autoscaler (HPA)** - Scales pods based on CPU, memory, and custom metrics
2. **Vertical Pod Autoscaler (VPA)** - Optimizes resource requests and limits
3. **KEDA** - Event-driven autoscaling for various triggers
4. **Cluster Autoscaler** - Automatically scales cluster nodes

## Components

### 00-metrics-server.yaml
Metrics Server installation for collecting resource metrics. Required for HPA and VPA.

**Installation:**
```bash
kubectl apply -f 00-metrics-server.yaml
# Or via Helm:
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm install metrics-server metrics-server/metrics-server --namespace kube-system
```

### 01-hpa-configurations.yaml
Multiple HPA examples for different use cases:
- Basic CPU/memory-based scaling
- Custom metrics (Prometheus) scaling
- External metrics (cloud provider) scaling
- Multi-metric scaling strategies
- Cost-optimized configurations
- Production workload patterns

**Key Features:**
- Scale-down stabilization windows (prevents flapping)
- Multiple scaling policies (percent vs. absolute)
- Custom metric support via Prometheus adapter

### 02-vpa-configurations.yaml
VPA configurations with different update modes:
- **Off**: Recommendations only
- **Initial**: Set resources on pod creation
- **Recreate**: Delete and recreate pods
- **Auto**: Automatically update (use with caution)

**Resource Policies:**
- Min/max allowed resources
- Container-specific policies
- Controlled resources (cpu, memory)

### 03-keda-configurations.yaml
Event-driven autoscaling with multiple trigger types:
- Prometheus metrics
- Message queues (RabbitMQ, Kafka, Redis)
- Cloud services (AWS SQS)
- Cron-based scheduling
- Database queues (PostgreSQL)
- ScaledJobs for batch processing

**Trigger Authentication:**
- Secret-based authentication
- Pod identity (IRSA, Workload Identity)
- Environment variables

### 04-cluster-autoscaler.yaml
Node-level autoscaling for cloud providers:
- AWS EKS configuration
- GCP GKE configuration
- Azure AKS configuration
- Priority-based node selection
- Cost optimization strategies

**Features:**
- Node group auto-discovery
- Balance similar node groups
- Scale-down delay and stabilization
- Priority expander for node selection

### 05-monitoring-dashboards.yaml
Complete monitoring and alerting setup:
- Prometheus alert rules for autoscaling
- Grafana dashboards
- Cost tracking metrics
- Performance monitoring

**Alerts Include:**
- HPA maxed out warnings
- VPA recommendation mismatches
- Cluster Autoscaler errors
- Unschedulable pods
- KEDA scaler failures

## Quick Start

### Automated Deployment

```bash
# Make script executable
chmod +x deploy.sh

# Run deployment script
./deploy.sh
```

The script will:
1. Install Metrics Server
2. Deploy HPA configurations
3. Install VPA (requires manual step)
4. Install and configure KEDA
5. Deploy Cluster Autoscaler (requires cloud provider config)
6. Set up monitoring and alerts

### Manual Deployment

```bash
# 1. Install Metrics Server
kubectl apply -f 00-metrics-server.yaml

# 2. Deploy HPA configurations
kubectl apply -f 01-hpa-configurations.yaml

# 3. Install VPA
# Via official repo:
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler
./hack/vpa-up.sh

# Apply VPA configs
kubectl apply -f 02-vpa-configurations.yaml

# 4. Install KEDA
helm repo add kedacore https://kedacore.github.io/charts
helm install keda kedacore/keda --namespace keda --create-namespace

kubectl apply -f 03-keda-configurations.yaml

# 5. Configure and deploy Cluster Autoscaler
# Edit 04-cluster-autoscaler.yaml with your cloud provider details
kubectl apply -f 04-cluster-autoscaler.yaml

# 6. Set up monitoring
kubectl apply -f 05-monitoring-dashboards.yaml
```

## Configuration

### Cloud Provider Setup

#### AWS EKS

1. Create IAM role for Cluster Autoscaler:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeScalingActivities",
        "autoscaling:DescribeTags",
        "ec2:DescribeInstanceTypes",
        "ec2:DescribeLaunchTemplateVersions"
      ],
      "Resource": ["*"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup",
        "ec2:DescribeImages",
        "ec2:GetInstanceTypesFromInstanceRequirements",
        "eks:DescribeNodegroup"
      ],
      "Resource": ["*"]
    }
  ]
}
```

2. Tag Auto Scaling Groups:
```
k8s.io/cluster-autoscaler/enabled: true
k8s.io/cluster-autoscaler/<cluster-name>: owned
```

3. Update ServiceAccount annotation in `04-cluster-autoscaler.yaml`:
```yaml
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/cluster-autoscaler
```

#### GCP GKE

1. Create service account with permissions:
```bash
gcloud iam service-accounts create cluster-autoscaler
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member=serviceAccount:cluster-autoscaler@PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/container.clusterAdmin
```

2. Tag instance groups:
```
k8s-cluster-autoscaler-enabled: true
```

#### Azure AKS

1. Create managed identity
2. Assign permissions to scale VMSS
3. Update ServiceAccount with workload identity

### Custom Metrics Setup

To use custom metrics with HPA, install Prometheus Adapter:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus-adapter prometheus-community/prometheus-adapter \
  --namespace monitoring \
  --set prometheus.url=http://prometheus.monitoring.svc.cluster.local \
  --set prometheus.port=9090
```

Apply custom metric configuration from `05-monitoring-dashboards.yaml`.

### KEDA Trigger Authentication

Update the TriggerAuthentication resources with actual secrets:

```bash
# RabbitMQ
kubectl create secret generic rabbitmq-secret \
  --from-literal=host='amqp://user:password@rabbitmq.default:5672' \
  -n default

# Kafka
kubectl create secret generic kafka-secret \
  --from-literal=sasl='plaintext' \
  --from-literal=username='user' \
  --from-literal=password='password' \
  -n default

# Redis
kubectl create secret generic redis-secret \
  --from-literal=password='your-redis-password' \
  -n default

# PostgreSQL
kubectl create secret generic postgres-secret \
  --from-literal=connection_string='postgresql://user:password@postgres:5432/db' \
  -n default
```

## Testing

### Test HPA

```bash
# Create a load generator
kubectl run -i --tty load-generator --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://podinfo; done"

# Watch HPA scaling
kubectl get hpa podinfo-hpa -w

# Check metrics
kubectl top pods
```

### Test VPA

```bash
# View VPA recommendations
kubectl describe vpa podinfo-vpa

# Check recommendation vs actual
kubectl get vpa podinfo-vpa -o jsonpath='{.status.recommendation.containerRecommendations[0]}'
```

### Test KEDA

```bash
# Watch ScaledObjects
kubectl get scaledobjects -w

# Check KEDA metrics
kubectl get --raw /apis/external.metrics.k8s.io/v1beta1

# View KEDA logs
kubectl logs -n keda -l app=keda-operator
```

### Test Cluster Autoscaler

```bash
# Create unschedulable pods
kubectl create deployment scale-test --image=nginx --replicas=100
kubectl set resources deployment scale-test --requests=cpu=1,memory=1Gi

# Watch cluster scaling
kubectl get nodes -w

# View Cluster Autoscaler logs
kubectl logs -n kube-system -l app.kubernetes.io/name=cluster-autoscaler -f

# Check Cluster Autoscaler status
kubectl get configmap cluster-autoscaler-status -n kube-system -o yaml
```

## Monitoring

### View Autoscaling Metrics

```bash
# HPA metrics
kubectl get hpa --all-namespaces

# Current vs desired replicas
kubectl get hpa -o custom-columns=NAME:.metadata.name,CURRENT:.status.currentReplicas,DESIRED:.status.desiredReplicas

# VPA recommendations
kubectl get vpa --all-namespaces

# KEDA scaled objects
kubectl get scaledobjects --all-namespaces

# Cluster node count
kubectl get nodes --no-headers | wc -l
```

### Grafana Dashboards

Access Grafana dashboards (configured in `05-monitoring-dashboards.yaml`):

1. **Autoscaling Overview** - HPA, VPA, and Cluster Autoscaler metrics
2. **Cost Analysis** - Node costs and resource utilization
3. **Performance** - Scaling events and rates

### Prometheus Queries

Useful queries for autoscaling monitoring:

```promql
# HPA replica count
kube_horizontalpodautoscaler_status_current_replicas

# HPA at max capacity
kube_horizontalpodautoscaler_status_current_replicas >= kube_horizontalpodautoscaler_spec_max_replicas

# VPA recommendations vs requests
kube_verticalpodautoscaler_status_recommendation_containerrecommendations_target

# Cluster node count
cluster_autoscaler_nodes_count

# Unschedulable pods
cluster_autoscaler_unschedulable_pods_count

# KEDA scaling metrics
keda_scaledobject_errors_total
```

## Troubleshooting

### HPA Not Scaling

1. Check Metrics Server:
```bash
kubectl top nodes
kubectl top pods
```

2. Check HPA status:
```bash
kubectl describe hpa <hpa-name>
```

3. Verify metrics are available:
```bash
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes
```

### VPA Not Updating Pods

1. Check VPA status:
```bash
kubectl describe vpa <vpa-name>
```

2. Verify VPA components:
```bash
kubectl get pods -n kube-system | grep vpa
```

3. Check VPA admission controller:
```bash
kubectl logs -n kube-system -l app=vpa-admission-controller
```

### KEDA Not Triggering

1. Check ScaledObject:
```bash
kubectl describe scaledobject <scaledobject-name>
```

2. Verify trigger authentication:
```bash
kubectl get triggerauthentication
kubectl describe triggerauthentication <auth-name>
```

3. Check KEDA logs:
```bash
kubectl logs -n keda -l app=keda-operator -f
```

### Cluster Autoscaler Not Scaling Nodes

1. Check for unschedulable pods:
```bash
kubectl get pods --all-namespaces --field-selector=status.phase=Pending
```

2. View Cluster Autoscaler logs:
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=cluster-autoscaler -f
```

3. Check cloud provider permissions
4. Verify node group tags
5. Check Cluster Autoscaler status:
```bash
kubectl get configmap cluster-autoscaler-status -n kube-system -o yaml
```

## Best Practices

### HPA Best Practices

1. **Set appropriate min/max replicas** based on baseline load and capacity
2. **Use multiple metrics** for more accurate scaling decisions
3. **Configure stabilization windows** to prevent flapping
4. **Set resource requests** accurately - HPA scales based on percentage of requests
5. **Monitor scaling events** to tune thresholds

### VPA Best Practices

1. **Start with "Off" mode** to collect recommendations
2. **Use "Initial" mode** for stateful workloads
3. **Don't use VPA with HPA** on the same CPU/memory metrics
4. **Set min/max bounds** to prevent extreme recommendations
5. **Test in non-production** before enabling Auto mode

### KEDA Best Practices

1. **Use appropriate polling intervals** - balance responsiveness vs. API load
2. **Configure cooldown periods** to prevent rapid scaling
3. **Set activation thresholds** lower than scaling thresholds
4. **Use secrets** for sensitive trigger credentials
5. **Monitor trigger metrics** to ensure they're being collected

### Cluster Autoscaler Best Practices

1. **Use PodDisruptionBudgets** to protect critical workloads
2. **Configure scale-down delay** appropriately for your workloads
3. **Use mixed instance types** with priority expander for cost optimization
4. **Set cluster-autoscaler.kubernetes.io/safe-to-evict annotations** carefully
5. **Monitor for failed scale-up events**
6. **Use node affinity/taints** for workload placement control

### Cost Optimization

1. **Use scale-to-zero** for development/staging environments
2. **Implement cron-based scaling** for predictable load patterns
3. **Use spot/preemptible instances** for fault-tolerant workloads
4. **Monitor resource utilization** to tune requests/limits
5. **Use VPA recommendations** to right-size workloads
6. **Configure aggressive scale-down** for non-production
7. **Use priority expander** to prefer cheaper instance types

## Security Considerations

1. **Use IRSA/Workload Identity** for cloud provider credentials
2. **Store sensitive data in Secrets** referenced by TriggerAuthentications
3. **Apply Pod Security Standards** to autoscaler components
4. **Use RBAC** to limit access to autoscaling resources
5. **Enable audit logging** for autoscaling events
6. **Secure metrics endpoints** with authentication

## References

- [Kubernetes HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [VPA GitHub Repository](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)
- [KEDA Documentation](https://keda.sh/)
- [Cluster Autoscaler Documentation](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler)
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [Prometheus Adapter](https://github.com/kubernetes-sigs/prometheus-adapter)

## Support

For issues and questions:
- Check logs of autoscaling components
- Review Prometheus alerts
- Verify cloud provider configuration
- Test with simplified configurations
- Check resource quotas and limits

## License

This configuration is provided as-is for use with Kubernetes clusters.
