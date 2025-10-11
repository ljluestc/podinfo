# ArgoCD Canary Deployment Guide for Podinfo

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Quick Start](#quick-start)
5. [Deployment Steps](#deployment-steps)
6. [Canary Strategy](#canary-strategy)
7. [Monitoring & Observability](#monitoring--observability)
8. [Operations Guide](#operations-guide)
9. [Troubleshooting](#troubleshooting)
10. [References](#references)

## Overview

This guide provides complete instructions for implementing progressive canary deployments for the podinfo application using **ArgoCD** and **Argo Rollouts**.

### What You'll Get

✅ **Zero-downtime canary deployments** with 5-stage traffic progression (10% → 30% → 50% → 75% → 100%)
✅ **Automated analysis** using Prometheus metrics (success rate, latency, error rate)
✅ **Automatic rollback** on metric degradation
✅ **Manual approval gates** for production safety
✅ **Complete observability** with Grafana dashboards
✅ **GitOps workflow** with ArgoCD

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      User Traffic                            │
└──────────────────────┬──────────────────────────────────────┘
                       │
                ┌──────▼──────┐
                │   Ingress   │
                │  (NGINX)    │
                └──────┬──────┘
                       │
            ┌──────────┴──────────┐
            │                      │
    ┌───────▼────────┐    ┌──────▼───────┐
    │ Stable Service │    │Canary Service│
    │    (100-x%)    │    │     (x%)     │
    └───────┬────────┘    └──────┬───────┘
            │                     │
    ┌───────▼────────┐    ┌──────▼───────┐
    │ Stable Pods    │    │ Canary Pods  │
    │   (v1.0)       │    │   (v1.1)     │
    └────────────────┘    └──────────────┘
            │                     │
            └──────────┬──────────┘
                       │
                ┌──────▼──────┐
                │ Prometheus  │
                │  (Metrics)  │
                └──────┬──────┘
                       │
                ┌──────▼──────┐
                │ Analysis    │
                │  Templates  │
                └─────────────┘
```

### Canary Progression

```
Stage 1:  10% ──▶  2min + Analysis  ──▶  Next or Rollback
Stage 2:  30% ──▶  5min + Analysis  ──▶  Next or Rollback
Stage 3:  50% ──▶ Manual Approval   ──▶  Next or Rollback
Stage 4:  75% ──▶  5min + Analysis  ──▶  Next or Rollback
Stage 5: 100% ──▶  Complete
```

## Prerequisites

### Required Tools

- **Kubernetes cluster** (v1.24+)
- **kubectl** CLI installed
- **Helm** (v3+) for package management
- **Argo Rollouts kubectl plugin**

### Optional Tools

- **jq** for JSON processing
- **curl** for API testing

### Cluster Requirements

- At least 3 worker nodes for HA
- NGINX Ingress Controller installed
- Prometheus Operator (for metrics)
- cert-manager (for TLS certificates)

## Quick Start

### One-Line Installation

```bash
cd k8s-cluster/scripts
./deploy-argocd-canary.sh
```

This script will:
1. Install ArgoCD
2. Install Argo Rollouts
3. Deploy podinfo with canary strategy
4. Configure monitoring
5. Display access credentials

### Manual Installation

Follow the [Deployment Steps](#deployment-steps) section below.

## Deployment Steps

### Step 1: Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Visit: https://localhost:8080
```

### Step 2: Install Argo Rollouts

```bash
# Create namespace
kubectl create namespace argo-rollouts

# Install Argo Rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Install kubectl plugin (Linux)
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts

# Verify installation
kubectl argo rollouts version
```

### Step 3: Deploy Podinfo Rollout

```bash
# Apply all manifests
kubectl apply -f k8s-cluster/manifests/14-cicd/podinfo-rollout.yaml
kubectl apply -f k8s-cluster/manifests/14-cicd/podinfo-analysis-templates.yaml
kubectl apply -f k8s-cluster/manifests/14-cicd/podinfo-monitoring.yaml
kubectl apply -f k8s-cluster/manifests/14-cicd/podinfo-ingress.yaml

# Verify deployment
kubectl get rollout -n podinfo
kubectl argo rollouts status podinfo -n podinfo
```

### Step 4: Configure ArgoCD Application

```bash
# Apply ArgoCD Application
kubectl apply -f k8s-cluster/manifests/14-cicd/podinfo-argocd-application.yaml

# Sync application
argocd app sync podinfo --force
```

### Step 5: Setup Monitoring

```bash
# Apply ServiceMonitors
kubectl apply -f k8s-cluster/manifests/14-cicd/podinfo-monitoring.yaml

# Import Grafana dashboard
kubectl apply -f k8s-cluster/manifests/14-cicd/podinfo-grafana-dashboard.yaml
```

## Canary Strategy

### Stage Configuration

Our canary strategy implements a 5-stage progressive delivery:

#### Stage 1: Initial Canary (10%)
- **Traffic**: 10% to canary
- **Duration**: 2 minutes
- **Analysis**: Success rate, latency
- **Action**: Auto-promote or rollback

#### Stage 2: Expanded Test (30%)
- **Traffic**: 30% to canary
- **Duration**: 5 minutes
- **Analysis**: Success rate, latency, error rate
- **Action**: Auto-promote or rollback

#### Stage 3: Half Traffic (50%)
- **Traffic**: 50% to canary
- **Duration**: Manual approval required
- **Analysis**: All metrics
- **Action**: Manual promotion

#### Stage 4: Majority Traffic (75%)
- **Traffic**: 75% to canary
- **Duration**: 5 minutes
- **Analysis**: Success rate, latency
- **Action**: Auto-promote or rollback

#### Stage 5: Full Rollout (100%)
- **Traffic**: 100% to canary
- **Duration**: 1 minute stabilization
- **Action**: Complete

### Analysis Metrics

#### Success Rate
- **Threshold**: ≥ 95%
- **Measurement**: HTTP 2xx responses / total requests
- **Interval**: 30 seconds
- **Failure Limit**: 3 consecutive failures

#### Latency (P95)
- **Threshold**: ≤ 500ms
- **Measurement**: 95th percentile response time
- **Interval**: 30 seconds
- **Failure Limit**: 3 consecutive failures

#### Error Rate
- **Threshold**: ≤ 5%
- **Measurement**: HTTP 5xx responses / total requests
- **Interval**: 30 seconds
- **Failure Limit**: 3 consecutive failures

## Monitoring & Observability

### Grafana Dashboard

Access the pre-configured Grafana dashboard:

```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
# Visit: http://localhost:3000
# Dashboard: "Podinfo Canary Deployment"
```

**Dashboard Panels:**
- Request Rate (Stable vs Canary)
- Success Rate Gauges
- Latency Percentiles
- Error Rate
- Current Canary Weight
- Rollout Status
- Replica Counts
- Analysis Run Status

### Prometheus Queries

**Success Rate:**
```promql
sum(rate(http_request_duration_seconds_count{job="podinfo-canary",status=~"2.."}[5m]))
/
sum(rate(http_request_duration_seconds_count{job="podinfo-canary"}[5m]))
```

**P95 Latency:**
```promql
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket{job="podinfo-canary"}[5m])) by (le)
)
```

**Error Rate:**
```promql
sum(rate(http_request_duration_seconds_count{job="podinfo-canary",status=~"5.."}[5m]))
/
sum(rate(http_request_duration_seconds_count{job="podinfo-canary"}[5m]))
```

### Argo Rollouts Dashboard

```bash
kubectl argo rollouts dashboard -n podinfo
# Visit: http://localhost:3100
```

## Operations Guide

### Trigger a Canary Deployment

#### Method 1: Update Image via CLI
```bash
./k8s-cluster/scripts/manage-rollout.sh update-image ghcr.io/stefanprodan/podinfo:6.9.3
```

#### Method 2: Update via kubectl
```bash
kubectl argo rollouts set image podinfo podinfo=ghcr.io/stefanprodan/podinfo:6.9.3 -n podinfo
```

#### Method 3: Update via ArgoCD (GitOps)
```bash
# Update image tag in Git repository
git add kustomize/
git commit -m "Update podinfo to 6.9.3"
git push

# ArgoCD will automatically detect and sync
```

### Monitor Rollout Progress

```bash
# Watch live status
./k8s-cluster/scripts/manage-rollout.sh watch

# Get current status
./k8s-cluster/scripts/manage-rollout.sh status

# View analysis runs
./k8s-cluster/scripts/manage-rollout.sh analysis
```

### Manual Promotion

```bash
# Promote to next stage
./k8s-cluster/scripts/manage-rollout.sh promote

# Promote fully (skip all analysis)
./k8s-cluster/scripts/manage-rollout.sh promote-full
```

### Abort and Rollback

```bash
# Abort current rollout
./k8s-cluster/scripts/manage-rollout.sh abort

# Rollback to specific revision
./k8s-cluster/scripts/manage-rollout.sh history
./k8s-cluster/scripts/manage-rollout.sh rollback <revision-number>
```

### Test Canary with Header

```bash
# Test stable version
curl http://podinfo.example.com

# Test canary version
curl -H "X-Canary: true" http://podinfo.example.com

# Automated test
./k8s-cluster/scripts/manage-rollout.sh test-canary http://podinfo.example.com
```

### Pause and Resume

```bash
# Pause rollout
./k8s-cluster/scripts/manage-rollout.sh pause

# Resume rollout
./k8s-cluster/scripts/manage-rollout.sh resume
```

## Troubleshooting

### Common Issues

#### 1. Rollout Stuck in Progressing

**Symptoms**: Rollout doesn't progress beyond a stage

**Diagnosis**:
```bash
kubectl describe rollout podinfo -n podinfo
kubectl get analysisrun -n podinfo
kubectl describe analysisrun <latest-run> -n podinfo
```

**Solutions**:
- Check if Prometheus is accessible
- Verify ServiceMonitor configuration
- Check analysis template queries
- Review pod logs for errors

#### 2. Analysis Failing

**Symptoms**: Analysis runs show "Failed" status

**Diagnosis**:
```bash
kubectl logs -n podinfo deployment/podinfo-canary
kubectl get analysisrun -n podinfo -o yaml
```

**Solutions**:
- Verify Prometheus metrics are being collected
- Check metric query syntax
- Adjust analysis thresholds if too strict
- Review application logs for actual errors

#### 3. Traffic Not Splitting

**Symptoms**: All traffic goes to stable or canary

**Diagnosis**:
```bash
kubectl get ingress -n podinfo
kubectl describe ingress podinfo-canary -n podinfo
```

**Solutions**:
- Verify NGINX Ingress Controller is installed
- Check canary-weight annotation on ingress
- Ensure Argo Rollouts has permissions to update ingress
- Verify services are correctly labeled

#### 4. Automatic Rollback Not Working

**Symptoms**: Canary continues despite bad metrics

**Diagnosis**:
```bash
kubectl get analysistemplate -n podinfo
kubectl describe analysisrun <latest-run> -n podinfo
```

**Solutions**:
- Verify analysis templates are correctly referenced
- Check failureLimit settings
- Ensure Prometheus queries return valid data
- Review analysis template success conditions

### Debug Commands

```bash
# Check all resources
kubectl get all -n podinfo

# View rollout events
kubectl get events -n podinfo --sort-by='.lastTimestamp'

# Check Argo Rollouts controller logs
kubectl logs -n argo-rollouts deployment/argo-rollouts

# View analysis runs
kubectl get analysisrun -n podinfo -o yaml

# Test Prometheus connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://prometheus.monitoring.svc:9090/api/v1/query?query=up
```

## Advanced Configuration

### Custom Analysis Intervals

Edit `podinfo-analysis-templates.yaml` to adjust:

```yaml
metrics:
- name: success-rate
  interval: 60s  # Change from 30s to 60s
  successCondition: result[0] >= 0.95
  failureLimit: 5  # Change from 3 to 5
```

### Add Custom Metrics

Create new AnalysisTemplate:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: podinfo-custom-metric
  namespace: podinfo
spec:
  metrics:
  - name: custom-business-metric
    interval: 30s
    successCondition: result[0] >= 100
    provider:
      prometheus:
        address: http://prometheus.monitoring.svc:9090
        query: |
          your_custom_metric{service="podinfo"}
```

### Integrate with Service Mesh (Istio)

Replace NGINX ingress with Istio VirtualService (see comments in `podinfo-ingress.yaml`).

## Security Considerations

- **RBAC**: Limit who can promote/abort rollouts
- **Network Policies**: Restrict pod-to-pod communication
- **Image Scanning**: Scan images before deployment
- **Secrets Management**: Use external secrets operator
- **TLS**: Enable TLS for all ingress traffic

## Performance Tuning

- **Replica Count**: Adjust based on traffic (minimum 6 recommended)
- **HPA**: Configured to scale 3-10 replicas
- **Resource Limits**: CPU: 500m, Memory: 512Mi
- **Analysis Intervals**: Balance between speed and accuracy

## References

- [Argo Rollouts Documentation](https://argoproj.github.io/argo-rollouts/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Canary Deployment Best Practices](https://argoproj.github.io/argo-rollouts/features/canary/)
- [Podinfo GitHub](https://github.com/stefanprodan/podinfo)

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review Argo Rollouts documentation
3. Check application logs and events
4. Open an issue in the project repository

---

**Implementation Complete!** 🎉

All components of the ArgoCD canary deployment system are now deployed and ready for use.
