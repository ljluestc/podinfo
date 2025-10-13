# Workload Management Configuration

This directory contains comprehensive Kubernetes workload management configurations demonstrating best practices for deployments, StatefulSets, DaemonSets, Jobs, CronJobs, and resource management.

## Overview

This implementation covers:

- **Deployment Strategies**: Rolling updates, recreate, blue-green, and canary deployments
- **StatefulSets**: Stateful applications with persistent storage (Redis, PostgreSQL)
- **DaemonSets**: Node-level services (monitoring, logging, network policy)
- **Jobs & CronJobs**: Batch processing and scheduled tasks
- **Pod Disruption Budgets**: High availability during voluntary disruptions
- **Priority Classes**: Workload scheduling prioritization
- **Resource Quotas & Limits**: Resource management and governance
- **Monitoring & Testing**: Validation and observability

## Directory Structure

```
17-workload-management/
├── 00-namespace.yaml                    # Namespace with pod security standards
├── 01-deployment-strategies.yaml        # Rolling update and recreate deployments
├── 02-blue-green-canary.yaml           # Blue-green and canary deployments
├── 03-statefulsets.yaml                # Redis cluster and PostgreSQL StatefulSets
├── 04-daemonsets.yaml                  # Node monitoring, logging, and network agents
├── 05-cronjobs-jobs.yaml               # Scheduled tasks and batch jobs
├── 06-pod-disruption-budgets.yaml      # PDBs for high availability
├── 07-priority-classes.yaml            # Priority classes and examples
├── 08-resource-quotas-limits.yaml      # ResourceQuotas and LimitRanges
├── 09-monitoring-tests.yaml            # Monitoring and validation tests
├── deploy.sh                           # Deployment script
└── README.md                           # This file
```

## Components

### 1. Deployment Strategies (01-deployment-strategies.yaml)

#### Rolling Update Deployment
- **Name**: `podinfo-rolling`
- **Replicas**: 3
- **Strategy**: RollingUpdate with `maxUnavailable: 1` and `maxSurge: 1`
- **Health Checks**:
  - Liveness probe (HTTP /healthz)
  - Readiness probe (HTTP /readyz)
  - Startup probe for slow-starting containers
- **Features**:
  - Pod anti-affinity for high availability
  - Security context with restricted PSS
  - Resource limits and requests

#### Recreate Deployment
- **Name**: `podinfo-recreate`
- **Strategy**: Recreate (terminates all old pods before creating new ones)
- **Use Case**: Stateful apps or incompatible versions

### 2. Blue-Green & Canary Deployments (02-blue-green-canary.yaml)

#### Blue-Green Deployment
- **Blue** (Stable): `podinfo-blue` - Running version 6.9.1
- **Green** (New): `podinfo-green` - Running version 6.9.2
- **Service**: `podinfo-bluegreen` - Switch traffic by changing version selector
- **Preview Service**: `podinfo-green-preview` - Test green before switch

**Traffic Switch**:
```bash
# Switch from blue to green
kubectl patch service podinfo-bluegreen -n workload-demo \
  -p '{"spec":{"selector":{"version":"green"}}}'
```

#### Canary Deployment
- **Stable**: `podinfo-canary-stable` - 9 replicas (90% traffic)
- **Canary**: `podinfo-canary-new` - 1 replica (10% traffic)
- **Service**: `podinfo-canary` - Load balances across both versions

**Canary Progression**:
```bash
# Increase canary traffic to 25%
kubectl scale deployment podinfo-canary-stable --replicas=6 -n workload-demo
kubectl scale deployment podinfo-canary-new --replicas=2 -n workload-demo

# Full rollout
kubectl scale deployment podinfo-canary-stable --replicas=0 -n workload-demo
kubectl scale deployment podinfo-canary-new --replicas=10 -n workload-demo
```

### 3. StatefulSets (03-statefulsets.yaml)

#### Redis Cluster StatefulSet
- **Name**: `redis-cluster`
- **Replicas**: 3
- **Storage**: 10Gi per pod (fast-ssd StorageClass)
- **Features**:
  - Ordered pod management
  - Persistent volume claims
  - Headless service for stable network identities
  - Pod anti-affinity for fault tolerance
  - ConfigMap for Redis configuration

#### PostgreSQL StatefulSet
- **Name**: `postgresql`
- **Replicas**: 1
- **Storage**: 20Gi (fast-ssd StorageClass)
- **Features**:
  - Persistent data storage
  - Secret-based credentials
  - Health checks via pg_isready

### 4. DaemonSets (04-daemonsets.yaml)

#### Node Monitor DaemonSet
- **Name**: `node-monitor`
- **Image**: prom/node-exporter:v1.8.2
- **Purpose**: Collect node-level metrics
- **Features**:
  - Runs on all nodes (including control plane)
  - Host network access
  - Tolerations for control plane nodes
  - Resource limits: 200m CPU, 128Mi memory

#### Log Collector DaemonSet
- **Name**: `log-collector`
- **Image**: fluent/fluentd-kubernetes-daemonset
- **Purpose**: Collect container logs
- **Features**:
  - ServiceAccount with RBAC
  - Host path mounts for log access
  - ConfigMap for Fluentd configuration

#### Network Policy Agent
- **Name**: `network-policy-agent`
- **Purpose**: Network policy enforcement simulation

### 5. Jobs & CronJobs (05-cronjobs-jobs.yaml)

#### Database Backup CronJob
- **Schedule**: Daily at 2 AM (`0 2 * * *`)
- **Purpose**: PostgreSQL database backups
- **Features**:
  - Retains last 3 successful and 5 failed jobs
  - Cleanup policy (keeps 7 days of backups)
  - TTL: 24 hours after completion
  - PVC for backup storage (50Gi)

#### Cache Cleanup CronJob
- **Schedule**: Every 30 minutes (`*/30 * * * *`)
- **Purpose**: Redis cache maintenance
- **Concurrency**: Replace (stops old job if running)

#### Log Rotation CronJob
- **Schedule**: Weekly on Sunday (`0 0 * * 0`)
- **Purpose**: Rotate and compress logs

#### Database Migration Job
- **Type**: One-time Job
- **Purpose**: Database schema migrations
- **Features**:
  - Waits for database availability
  - Idempotent migrations
  - TTL: 1 hour after completion

#### Data Processing Parallel Job
- **Completions**: 5
- **Parallelism**: 3
- **Mode**: Indexed
- **Purpose**: Parallel data processing demonstration

### 6. Pod Disruption Budgets (06-pod-disruption-budgets.yaml)

Pod Disruption Budgets ensure high availability during voluntary disruptions (node drains, upgrades):

- **podinfo-rolling-pdb**: `minAvailable: 2` (keeps 2 pods running)
- **podinfo-blue-pdb**: `minAvailable: 1` (keeps 1 blue pod)
- **podinfo-green-pdb**: `minAvailable: 1` (keeps 1 green pod)
- **podinfo-canary-stable-pdb**: `minAvailable: 80%` (keeps 80% of stable pods)
- **redis-cluster-pdb**: `minAvailable: 2` (keeps 2 Redis nodes)
- **critical-service-pdb**: `minAvailable: 100%` (prevents all disruptions)

**Testing PDBs**:
```bash
# Try draining a node
kubectl drain <node-name> --ignore-daemonsets

# Check PDB status
kubectl get pdb -n workload-demo
```

### 7. Priority Classes (07-priority-classes.yaml)

Priority classes control pod scheduling and preemption:

| Priority Class | Value | Preemption | Use Case |
|---------------|-------|------------|----------|
| critical-priority | 1,000,000 | Yes | Critical system services |
| high-priority | 100,000 | Yes | Production services |
| medium-priority | 10,000 | Yes | Standard services (default) |
| low-priority | 1,000 | Yes | Background jobs |
| best-effort-priority | 100 | Never | Dev/test workloads |

**Example Usage**:
```yaml
spec:
  priorityClassName: high-priority
```

### 8. Resource Quotas & Limits (08-resource-quotas-limits.yaml)

#### ResourceQuota
- **workload-demo-quota**: Overall namespace limits
  - CPU requests: 50 cores, limits: 100 cores
  - Memory requests: 50Gi, limits: 100Gi
  - Storage: 500Gi, 10 PVCs
  - Pods: 100, Services: 50

- **critical-workload-quota**: For critical priority workloads
- **best-effort-quota**: For best-effort workloads

#### LimitRange
- **container-limits**: Default container resources
  - Default: 500m CPU, 512Mi memory
  - Requests: 100m CPU, 128Mi memory
  - Max: 4 CPU, 8Gi memory
  - Min: 10m CPU, 16Mi memory

- **pod-limits**: Pod-level limits
- **pvc-limits**: Storage limits (1Gi - 100Gi)

**Monitoring Quotas**:
```bash
# Check quota usage
kubectl describe resourcequota -n workload-demo

# Check limit ranges
kubectl describe limitrange -n workload-demo

# Monitor resource usage
kubectl top pods -n workload-demo
kubectl top nodes
```

### 9. Monitoring & Testing (09-monitoring-tests.yaml)

#### ServiceMonitor
- Prometheus monitoring for workload metrics
- Scrapes metrics every 30s

#### Test Jobs
- **test-deployments**: Validates all workloads are running
- **load-test-workloads**: Load testing for deployments

**Running Tests**:
```bash
# Run validation tests
kubectl create job --from=cronjob/test-deployments manual-test -n workload-demo

# Check test results
kubectl logs job/manual-test -n workload-demo

# Run load tests
kubectl create -f 09-monitoring-tests.yaml
kubectl logs -f job/load-test-workloads -n workload-demo
```

## Deployment

### Prerequisites

1. Kubernetes cluster (v1.28+)
2. Storage provisioner configured
3. Prometheus operator (for ServiceMonitor)
4. kubectl configured

### Deploy All Components

```bash
# Make script executable
chmod +x deploy.sh

# Deploy everything
./deploy.sh

# Or deploy manually
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-deployment-strategies.yaml
kubectl apply -f 02-blue-green-canary.yaml
kubectl apply -f 03-statefulsets.yaml
kubectl apply -f 04-daemonsets.yaml
kubectl apply -f 05-cronjobs-jobs.yaml
kubectl apply -f 06-pod-disruption-budgets.yaml
kubectl apply -f 07-priority-classes.yaml
kubectl apply -f 08-resource-quotas-limits.yaml
kubectl apply -f 09-monitoring-tests.yaml
```

### Verify Deployment

```bash
# Check namespace
kubectl get ns workload-demo

# Check all resources
kubectl get all -n workload-demo

# Check priority classes
kubectl get priorityclass

# Check resource quotas
kubectl get resourcequota -n workload-demo

# Check PDBs
kubectl get pdb -n workload-demo

# Run validation tests
kubectl create job --from=cronjob/test-deployments validation-test -n workload-demo
kubectl logs -f job/validation-test -n workload-demo
```

## Best Practices

### Deployment Strategies

1. **Use Rolling Updates** for most stateless applications
   - Configure appropriate `maxUnavailable` and `maxSurge`
   - Set `minReadySeconds` to ensure stability

2. **Blue-Green for Zero-Downtime**
   - Test green deployment thoroughly before switch
   - Keep blue running for quick rollback

3. **Canary for Risk Mitigation**
   - Start with small percentage (10%)
   - Monitor metrics before increasing traffic
   - Automate with Argo Rollouts or Flagger

### Health Checks

1. **Always configure probes**:
   - Liveness: Detects and restarts unhealthy pods
   - Readiness: Controls traffic routing
   - Startup: For slow-starting applications

2. **Tune probe parameters**:
   ```yaml
   livenessProbe:
     initialDelaySeconds: 5
     periodSeconds: 10
     timeoutSeconds: 5
     failureThreshold: 3
   ```

### StatefulSets

1. **Use for stateful workloads**:
   - Databases, message queues, distributed systems
   - Requires stable network identities and storage

2. **Configure pod management policy**:
   - `OrderedReady`: Sequential startup (default)
   - `Parallel`: All pods start simultaneously

3. **Plan storage carefully**:
   - Use appropriate StorageClass
   - Enable volume expansion
   - Regular backups

### DaemonSets

1. **Use for node-level services**:
   - Monitoring agents, log collectors
   - Network plugins, storage daemons

2. **Configure update strategy**:
   - `RollingUpdate`: Gradual updates (default)
   - Set `maxUnavailable` to control speed

3. **Add tolerations** for control plane nodes if needed

### Jobs & CronJobs

1. **Set appropriate deadlines**:
   - `activeDeadlineSeconds`: Max runtime
   - `startingDeadlineSeconds`: Grace period for missed start

2. **Configure cleanup**:
   - `ttlSecondsAfterFinished`: Auto-delete completed jobs
   - `successfulJobsHistoryLimit` / `failedJobsHistoryLimit`

3. **Handle concurrency**:
   - `Forbid`: Only one job at a time
   - `Replace`: Stop old job, start new
   - `Allow`: Multiple jobs can run

### Pod Disruption Budgets

1. **Configure for critical services**:
   - Use `minAvailable` for absolute numbers
   - Use `maxUnavailable` for flexibility

2. **Consider cluster operations**:
   - Node drains for maintenance
   - Cluster upgrades
   - Auto-scaling

### Priority Classes

1. **Use sparingly**:
   - Reserve critical priority for essential services
   - Most workloads should use medium priority

2. **Understand preemption**:
   - Higher priority pods can evict lower priority
   - Can cause disruption if overused

### Resource Management

1. **Always set requests and limits**:
   ```yaml
   resources:
     requests:
       cpu: 100m
       memory: 128Mi
     limits:
       cpu: 1000m
       memory: 512Mi
   ```

2. **Use LimitRanges** to enforce defaults

3. **Set ResourceQuotas** to prevent resource exhaustion

4. **Monitor usage**:
   ```bash
   kubectl top pods -n workload-demo
   kubectl top nodes
   ```

## Monitoring

### Key Metrics

1. **Deployment Health**:
   - `kube_deployment_status_replicas_available`
   - `kube_deployment_status_replicas_unavailable`

2. **Pod Resources**:
   - `container_memory_usage_bytes`
   - `container_cpu_usage_seconds_total`

3. **Job Success**:
   - `kube_job_status_succeeded`
   - `kube_job_status_failed`

4. **Quota Usage**:
   - `kube_resourcequota`

### Grafana Dashboards

Import the dashboard from ConfigMap:
```bash
kubectl get configmap workload-management-dashboard -n workload-demo \
  -o jsonpath='{.data.workload-management\.json}'
```

## Troubleshooting

### Deployment Issues

```bash
# Check deployment status
kubectl rollout status deployment/<name> -n workload-demo

# View deployment history
kubectl rollout history deployment/<name> -n workload-demo

# Rollback to previous version
kubectl rollout undo deployment/<name> -n workload-demo

# Check events
kubectl get events -n workload-demo --sort-by='.lastTimestamp'
```

### StatefulSet Issues

```bash
# Check statefulset status
kubectl get statefulset -n workload-demo

# Check PVCs
kubectl get pvc -n workload-demo

# Check pod logs
kubectl logs <pod-name> -n workload-demo

# Force delete stuck pod
kubectl delete pod <pod-name> -n workload-demo --grace-period=0 --force
```

### Resource Quota Issues

```bash
# Check quota usage
kubectl describe resourcequota -n workload-demo

# Check pod resource requests
kubectl describe pod <pod-name> -n workload-demo | grep -A 5 "Requests"

# Check limit ranges
kubectl describe limitrange -n workload-demo
```

### Job/CronJob Issues

```bash
# Check job status
kubectl get jobs -n workload-demo

# Check cronjob schedule
kubectl get cronjobs -n workload-demo

# Check job logs
kubectl logs job/<job-name> -n workload-demo

# Manually trigger cronjob
kubectl create job --from=cronjob/<cronjob-name> manual-run -n workload-demo
```

## Cleanup

```bash
# Delete namespace (removes all resources)
kubectl delete namespace workload-demo

# Delete priority classes
kubectl delete priorityclass critical-priority high-priority medium-priority low-priority best-effort-priority

# Delete cluster roles and bindings
kubectl delete clusterrole workload-tester-cluster log-collector
kubectl delete clusterrolebinding workload-tester-cluster log-collector
```

## References

- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [DaemonSets](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)
- [Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- [CronJobs](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)
- [Pod Disruption Budgets](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/)
- [Pod Priority and Preemption](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/)
- [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/)

## Security Considerations

1. **Pod Security Standards**: All pods use restricted PSS
2. **Security Context**: Non-root users, read-only root filesystem
3. **Network Policies**: Restrict traffic between workloads
4. **RBAC**: Minimal permissions for ServiceAccounts
5. **Secrets**: Credentials stored in Kubernetes Secrets
6. **Resource Limits**: Prevent resource exhaustion attacks

## Production Checklist

- [ ] Deployments have proper health checks
- [ ] StatefulSets have backup strategy
- [ ] DaemonSets have resource limits
- [ ] CronJobs have cleanup policies
- [ ] PDBs configured for critical services
- [ ] Priority classes assigned appropriately
- [ ] Resource quotas configured
- [ ] LimitRanges set for defaults
- [ ] Monitoring configured
- [ ] Logging configured
- [ ] Alerts configured
- [ ] Documentation updated
- [ ] Runbooks created
- [ ] Disaster recovery tested
