# Product Requirements Document: 17-WORKLOAD-MANAGEMENT: Readme

---

## Document Information
**Project:** 17-workload-management
**Document:** README
**Version:** 1.0.0
**Date:** 2025-10-13
**Status:** READY FOR TASK-MASTER PARSING

---

## 1. EXECUTIVE SUMMARY

### 1.1 Overview
This PRD captures the requirements and implementation details for 17-WORKLOAD-MANAGEMENT: Readme.

### 1.2 Purpose
This document provides a structured specification that can be parsed by task-master to generate actionable tasks.

### 1.3 Scope
The scope includes all requirements, features, and implementation details from the original documentation.

---

## 2. REQUIREMENTS

### 2.1 Functional Requirements
**Priority:** HIGH

**REQ-001:** use medium priority


## 3. TASKS

The following tasks have been identified for implementation:

**TASK_001** [MEDIUM]: **Deployment Strategies**: Rolling updates, recreate, blue-green, and canary deployments

**TASK_002** [MEDIUM]: **StatefulSets**: Stateful applications with persistent storage (Redis, PostgreSQL)

**TASK_003** [MEDIUM]: **DaemonSets**: Node-level services (monitoring, logging, network policy)

**TASK_004** [MEDIUM]: **Jobs & CronJobs**: Batch processing and scheduled tasks

**TASK_005** [MEDIUM]: **Pod Disruption Budgets**: High availability during voluntary disruptions

**TASK_006** [MEDIUM]: **Priority Classes**: Workload scheduling prioritization

**TASK_007** [MEDIUM]: **Resource Quotas & Limits**: Resource management and governance

**TASK_008** [MEDIUM]: **Monitoring & Testing**: Validation and observability

**TASK_009** [MEDIUM]: **Name**: `podinfo-rolling`

**TASK_010** [MEDIUM]: **Replicas**: 3

**TASK_011** [MEDIUM]: **Strategy**: RollingUpdate with `maxUnavailable: 1` and `maxSurge: 1`

**TASK_012** [MEDIUM]: Liveness probe (HTTP /healthz)

**TASK_013** [MEDIUM]: Readiness probe (HTTP /readyz)

**TASK_014** [MEDIUM]: Startup probe for slow-starting containers

**TASK_015** [MEDIUM]: Pod anti-affinity for high availability

**TASK_016** [MEDIUM]: Security context with restricted PSS

**TASK_017** [MEDIUM]: Resource limits and requests

**TASK_018** [MEDIUM]: **Name**: `podinfo-recreate`

**TASK_019** [MEDIUM]: **Strategy**: Recreate (terminates all old pods before creating new ones)

**TASK_020** [MEDIUM]: **Use Case**: Stateful apps or incompatible versions

**TASK_021** [MEDIUM]: **Blue** (Stable): `podinfo-blue` - Running version 6.9.1

**TASK_022** [MEDIUM]: **Green** (New): `podinfo-green` - Running version 6.9.2

**TASK_023** [MEDIUM]: **Service**: `podinfo-bluegreen` - Switch traffic by changing version selector

**TASK_024** [MEDIUM]: **Preview Service**: `podinfo-green-preview` - Test green before switch

**TASK_025** [MEDIUM]: **Stable**: `podinfo-canary-stable` - 9 replicas (90% traffic)

**TASK_026** [MEDIUM]: **Canary**: `podinfo-canary-new` - 1 replica (10% traffic)

**TASK_027** [MEDIUM]: **Service**: `podinfo-canary` - Load balances across both versions

**TASK_028** [MEDIUM]: **Name**: `redis-cluster`

**TASK_029** [MEDIUM]: **Replicas**: 3

**TASK_030** [MEDIUM]: **Storage**: 10Gi per pod (fast-ssd StorageClass)

**TASK_031** [MEDIUM]: Ordered pod management

**TASK_032** [MEDIUM]: Persistent volume claims

**TASK_033** [MEDIUM]: Headless service for stable network identities

**TASK_034** [MEDIUM]: Pod anti-affinity for fault tolerance

**TASK_035** [MEDIUM]: ConfigMap for Redis configuration

**TASK_036** [MEDIUM]: **Name**: `postgresql`

**TASK_037** [MEDIUM]: **Replicas**: 1

**TASK_038** [MEDIUM]: **Storage**: 20Gi (fast-ssd StorageClass)

**TASK_039** [MEDIUM]: Persistent data storage

**TASK_040** [MEDIUM]: Secret-based credentials

**TASK_041** [MEDIUM]: Health checks via pg_isready

**TASK_042** [MEDIUM]: **Name**: `node-monitor`

**TASK_043** [MEDIUM]: **Image**: prom/node-exporter:v1.8.2

**TASK_044** [MEDIUM]: **Purpose**: Collect node-level metrics

**TASK_045** [MEDIUM]: Runs on all nodes (including control plane)

**TASK_046** [MEDIUM]: Host network access

**TASK_047** [MEDIUM]: Tolerations for control plane nodes

**TASK_048** [MEDIUM]: Resource limits: 200m CPU, 128Mi memory

**TASK_049** [MEDIUM]: **Name**: `log-collector`

**TASK_050** [MEDIUM]: **Image**: fluent/fluentd-kubernetes-daemonset

**TASK_051** [MEDIUM]: **Purpose**: Collect container logs

**TASK_052** [MEDIUM]: ServiceAccount with RBAC

**TASK_053** [MEDIUM]: Host path mounts for log access

**TASK_054** [MEDIUM]: ConfigMap for Fluentd configuration

**TASK_055** [MEDIUM]: **Name**: `network-policy-agent`

**TASK_056** [MEDIUM]: **Purpose**: Network policy enforcement simulation

**TASK_057** [MEDIUM]: **Schedule**: Daily at 2 AM (`0 2 * * *`)

**TASK_058** [MEDIUM]: **Purpose**: PostgreSQL database backups

**TASK_059** [MEDIUM]: Retains last 3 successful and 5 failed jobs

**TASK_060** [MEDIUM]: Cleanup policy (keeps 7 days of backups)

**TASK_061** [MEDIUM]: TTL: 24 hours after completion

**TASK_062** [MEDIUM]: PVC for backup storage (50Gi)

**TASK_063** [MEDIUM]: **Schedule**: Every 30 minutes (`*/30 * * * *`)

**TASK_064** [MEDIUM]: **Purpose**: Redis cache maintenance

**TASK_065** [MEDIUM]: **Concurrency**: Replace (stops old job if running)

**TASK_066** [MEDIUM]: **Schedule**: Weekly on Sunday (`0 0 * * 0`)

**TASK_067** [MEDIUM]: **Purpose**: Rotate and compress logs

**TASK_068** [MEDIUM]: **Type**: One-time Job

**TASK_069** [MEDIUM]: **Purpose**: Database schema migrations

**TASK_070** [MEDIUM]: Waits for database availability

**TASK_071** [MEDIUM]: Idempotent migrations

**TASK_072** [MEDIUM]: TTL: 1 hour after completion

**TASK_073** [MEDIUM]: **Completions**: 5

**TASK_074** [MEDIUM]: **Parallelism**: 3

**TASK_075** [MEDIUM]: **Mode**: Indexed

**TASK_076** [MEDIUM]: **Purpose**: Parallel data processing demonstration

**TASK_077** [MEDIUM]: **podinfo-rolling-pdb**: `minAvailable: 2` (keeps 2 pods running)

**TASK_078** [MEDIUM]: **podinfo-blue-pdb**: `minAvailable: 1` (keeps 1 blue pod)

**TASK_079** [MEDIUM]: **podinfo-green-pdb**: `minAvailable: 1` (keeps 1 green pod)

**TASK_080** [MEDIUM]: **podinfo-canary-stable-pdb**: `minAvailable: 80%` (keeps 80% of stable pods)

**TASK_081** [MEDIUM]: **redis-cluster-pdb**: `minAvailable: 2` (keeps 2 Redis nodes)

**TASK_082** [MEDIUM]: **critical-service-pdb**: `minAvailable: 100%` (prevents all disruptions)

**TASK_083** [MEDIUM]: **workload-demo-quota**: Overall namespace limits

**TASK_084** [MEDIUM]: CPU requests: 50 cores, limits: 100 cores

**TASK_085** [MEDIUM]: Memory requests: 50Gi, limits: 100Gi

**TASK_086** [MEDIUM]: Storage: 500Gi, 10 PVCs

**TASK_087** [MEDIUM]: Pods: 100, Services: 50

**TASK_088** [MEDIUM]: **critical-workload-quota**: For critical priority workloads

**TASK_089** [MEDIUM]: **best-effort-quota**: For best-effort workloads

**TASK_090** [MEDIUM]: **container-limits**: Default container resources

**TASK_091** [MEDIUM]: Default: 500m CPU, 512Mi memory

**TASK_092** [MEDIUM]: Requests: 100m CPU, 128Mi memory

**TASK_093** [MEDIUM]: Max: 4 CPU, 8Gi memory

**TASK_094** [MEDIUM]: Min: 10m CPU, 16Mi memory

**TASK_095** [MEDIUM]: **pod-limits**: Pod-level limits

**TASK_096** [MEDIUM]: **pvc-limits**: Storage limits (1Gi - 100Gi)

**TASK_097** [MEDIUM]: Prometheus monitoring for workload metrics

**TASK_098** [MEDIUM]: Scrapes metrics every 30s

**TASK_099** [MEDIUM]: **test-deployments**: Validates all workloads are running

**TASK_100** [MEDIUM]: **load-test-workloads**: Load testing for deployments

**TASK_101** [HIGH]: Kubernetes cluster (v1.28+)

**TASK_102** [HIGH]: Storage provisioner configured

**TASK_103** [HIGH]: Prometheus operator (for ServiceMonitor)

**TASK_104** [HIGH]: kubectl configured

**TASK_105** [HIGH]: **Use Rolling Updates** for most stateless applications

**TASK_106** [MEDIUM]: Configure appropriate `maxUnavailable` and `maxSurge`

**TASK_107** [MEDIUM]: Set `minReadySeconds` to ensure stability

**TASK_108** [HIGH]: **Blue-Green for Zero-Downtime**

**TASK_109** [MEDIUM]: Test green deployment thoroughly before switch

**TASK_110** [MEDIUM]: Keep blue running for quick rollback

**TASK_111** [HIGH]: **Canary for Risk Mitigation**

**TASK_112** [MEDIUM]: Start with small percentage (10%)

**TASK_113** [MEDIUM]: Monitor metrics before increasing traffic

**TASK_114** [MEDIUM]: Automate with Argo Rollouts or Flagger

**TASK_115** [MEDIUM]: Liveness: Detects and restarts unhealthy pods

**TASK_116** [MEDIUM]: Readiness: Controls traffic routing

**TASK_117** [MEDIUM]: Startup: For slow-starting applications

**TASK_118** [MEDIUM]: Databases, message queues, distributed systems

**TASK_119** [MEDIUM]: Requires stable network identities and storage

**TASK_120** [MEDIUM]: `OrderedReady`: Sequential startup (default)

**TASK_121** [MEDIUM]: `Parallel`: All pods start simultaneously

**TASK_122** [MEDIUM]: Use appropriate StorageClass

**TASK_123** [MEDIUM]: Enable volume expansion

**TASK_124** [MEDIUM]: Regular backups

**TASK_125** [MEDIUM]: Monitoring agents, log collectors

**TASK_126** [MEDIUM]: Network plugins, storage daemons

**TASK_127** [MEDIUM]: `RollingUpdate`: Gradual updates (default)

**TASK_128** [MEDIUM]: Set `maxUnavailable` to control speed

**TASK_129** [HIGH]: **Add tolerations** for control plane nodes if needed

**TASK_130** [MEDIUM]: `activeDeadlineSeconds`: Max runtime

**TASK_131** [MEDIUM]: `startingDeadlineSeconds`: Grace period for missed start

**TASK_132** [MEDIUM]: `ttlSecondsAfterFinished`: Auto-delete completed jobs

**TASK_133** [MEDIUM]: `successfulJobsHistoryLimit` / `failedJobsHistoryLimit`

**TASK_134** [MEDIUM]: `Forbid`: Only one job at a time

**TASK_135** [MEDIUM]: `Replace`: Stop old job, start new

**TASK_136** [MEDIUM]: `Allow`: Multiple jobs can run

**TASK_137** [MEDIUM]: Use `minAvailable` for absolute numbers

**TASK_138** [MEDIUM]: Use `maxUnavailable` for flexibility

**TASK_139** [MEDIUM]: Node drains for maintenance

**TASK_140** [MEDIUM]: Cluster upgrades

**TASK_141** [MEDIUM]: Auto-scaling

**TASK_142** [MEDIUM]: Reserve critical priority for essential services

**TASK_143** [MEDIUM]: Most workloads should use medium priority

**TASK_144** [MEDIUM]: Higher priority pods can evict lower priority

**TASK_145** [MEDIUM]: Can cause disruption if overused

**TASK_146** [HIGH]: **Use LimitRanges** to enforce defaults

**TASK_147** [HIGH]: **Set ResourceQuotas** to prevent resource exhaustion

**TASK_148** [MEDIUM]: `kube_deployment_status_replicas_available`

**TASK_149** [MEDIUM]: `kube_deployment_status_replicas_unavailable`

**TASK_150** [MEDIUM]: `container_memory_usage_bytes`

**TASK_151** [MEDIUM]: `container_cpu_usage_seconds_total`

**TASK_152** [MEDIUM]: `kube_job_status_succeeded`

**TASK_153** [MEDIUM]: `kube_job_status_failed`

**TASK_154** [MEDIUM]: `kube_resourcequota`

**TASK_155** [MEDIUM]: [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)

**TASK_156** [MEDIUM]: [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)

**TASK_157** [MEDIUM]: [DaemonSets](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)

**TASK_158** [MEDIUM]: [Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/)

**TASK_159** [MEDIUM]: [CronJobs](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)

**TASK_160** [MEDIUM]: [Pod Disruption Budgets](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/)

**TASK_161** [MEDIUM]: [Pod Priority and Preemption](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/)

**TASK_162** [MEDIUM]: [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)

**TASK_163** [MEDIUM]: [Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/)

**TASK_164** [HIGH]: **Pod Security Standards**: All pods use restricted PSS

**TASK_165** [HIGH]: **Security Context**: Non-root users, read-only root filesystem

**TASK_166** [HIGH]: **Network Policies**: Restrict traffic between workloads

**TASK_167** [HIGH]: **RBAC**: Minimal permissions for ServiceAccounts

**TASK_168** [HIGH]: **Secrets**: Credentials stored in Kubernetes Secrets

**TASK_169** [HIGH]: **Resource Limits**: Prevent resource exhaustion attacks

**TASK_170** [MEDIUM]: Deployments have proper health checks

**TASK_171** [MEDIUM]: StatefulSets have backup strategy

**TASK_172** [MEDIUM]: DaemonSets have resource limits

**TASK_173** [MEDIUM]: CronJobs have cleanup policies

**TASK_174** [MEDIUM]: PDBs configured for critical services

**TASK_175** [MEDIUM]: Priority classes assigned appropriately

**TASK_176** [MEDIUM]: Resource quotas configured

**TASK_177** [MEDIUM]: LimitRanges set for defaults

**TASK_178** [MEDIUM]: Monitoring configured

**TASK_179** [MEDIUM]: Logging configured

**TASK_180** [MEDIUM]: Alerts configured

**TASK_181** [MEDIUM]: Documentation updated

**TASK_182** [MEDIUM]: Runbooks created

**TASK_183** [MEDIUM]: Disaster recovery tested


## 4. DETAILED SPECIFICATIONS

### 4.1 Original Content

The following sections contain the original documentation:


#### Workload Management Configuration

# Workload Management Configuration

This directory contains comprehensive Kubernetes workload management configurations demonstrating best practices for deployments, StatefulSets, DaemonSets, Jobs, CronJobs, and resource management.


#### Overview

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


#### Directory Structure

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


#### Components

## Components


#### 1 Deployment Strategies 01 Deployment Strategies Yaml 

### 1. Deployment Strategies (01-deployment-strategies.yaml)


#### Rolling Update Deployment

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

#### Recreate Deployment
- **Name**: `podinfo-recreate`
- **Strategy**: Recreate (terminates all old pods before creating new ones)
- **Use Case**: Stateful apps or incompatible versions


#### 2 Blue Green Canary Deployments 02 Blue Green Canary Yaml 

### 2. Blue-Green & Canary Deployments (02-blue-green-canary.yaml)


#### Blue Green Deployment

#### Blue-Green Deployment
- **Blue** (Stable): `podinfo-blue` - Running version 6.9.1
- **Green** (New): `podinfo-green` - Running version 6.9.2
- **Service**: `podinfo-bluegreen` - Switch traffic by changing version selector
- **Preview Service**: `podinfo-green-preview` - Test green before switch

**Traffic Switch**:
```bash

#### Switch From Blue To Green

# Switch from blue to green
kubectl patch service podinfo-bluegreen -n workload-demo \
  -p '{"spec":{"selector":{"version":"green"}}}'
```


#### Canary Deployment

#### Canary Deployment
- **Stable**: `podinfo-canary-stable` - 9 replicas (90% traffic)
- **Canary**: `podinfo-canary-new` - 1 replica (10% traffic)
- **Service**: `podinfo-canary` - Load balances across both versions

**Canary Progression**:
```bash

#### Increase Canary Traffic To 25 

# Increase canary traffic to 25%
kubectl scale deployment podinfo-canary-stable --replicas=6 -n workload-demo
kubectl scale deployment podinfo-canary-new --replicas=2 -n workload-demo


#### Full Rollout

# Full rollout
kubectl scale deployment podinfo-canary-stable --replicas=0 -n workload-demo
kubectl scale deployment podinfo-canary-new --replicas=10 -n workload-demo
```


#### 3 Statefulsets 03 Statefulsets Yaml 

### 3. StatefulSets (03-statefulsets.yaml)


#### Redis Cluster Statefulset

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


#### Postgresql Statefulset

#### PostgreSQL StatefulSet
- **Name**: `postgresql`
- **Replicas**: 1
- **Storage**: 20Gi (fast-ssd StorageClass)
- **Features**:
  - Persistent data storage
  - Secret-based credentials
  - Health checks via pg_isready


#### 4 Daemonsets 04 Daemonsets Yaml 

### 4. DaemonSets (04-daemonsets.yaml)


#### Node Monitor Daemonset

#### Node Monitor DaemonSet
- **Name**: `node-monitor`
- **Image**: prom/node-exporter:v1.8.2
- **Purpose**: Collect node-level metrics
- **Features**:
  - Runs on all nodes (including control plane)
  - Host network access
  - Tolerations for control plane nodes
  - Resource limits: 200m CPU, 128Mi memory


#### Log Collector Daemonset

#### Log Collector DaemonSet
- **Name**: `log-collector`
- **Image**: fluent/fluentd-kubernetes-daemonset
- **Purpose**: Collect container logs
- **Features**:
  - ServiceAccount with RBAC
  - Host path mounts for log access
  - ConfigMap for Fluentd configuration


#### Network Policy Agent

#### Network Policy Agent
- **Name**: `network-policy-agent`
- **Purpose**: Network policy enforcement simulation


#### 5 Jobs Cronjobs 05 Cronjobs Jobs Yaml 

### 5. Jobs & CronJobs (05-cronjobs-jobs.yaml)


#### Database Backup Cronjob

#### Database Backup CronJob
- **Schedule**: Daily at 2 AM (`0 2 * * *`)
- **Purpose**: PostgreSQL database backups
- **Features**:
  - Retains last 3 successful and 5 failed jobs
  - Cleanup policy (keeps 7 days of backups)
  - TTL: 24 hours after completion
  - PVC for backup storage (50Gi)


#### Cache Cleanup Cronjob

#### Cache Cleanup CronJob
- **Schedule**: Every 30 minutes (`*/30 * * * *`)
- **Purpose**: Redis cache maintenance
- **Concurrency**: Replace (stops old job if running)


#### Log Rotation Cronjob

#### Log Rotation CronJob
- **Schedule**: Weekly on Sunday (`0 0 * * 0`)
- **Purpose**: Rotate and compress logs


#### Database Migration Job

#### Database Migration Job
- **Type**: One-time Job
- **Purpose**: Database schema migrations
- **Features**:
  - Waits for database availability
  - Idempotent migrations
  - TTL: 1 hour after completion


#### Data Processing Parallel Job

#### Data Processing Parallel Job
- **Completions**: 5
- **Parallelism**: 3
- **Mode**: Indexed
- **Purpose**: Parallel data processing demonstration


#### 6 Pod Disruption Budgets 06 Pod Disruption Budgets Yaml 

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

#### Try Draining A Node

# Try draining a node
kubectl drain <node-name> --ignore-daemonsets


#### Check Pdb Status

# Check PDB status
kubectl get pdb -n workload-demo
```


#### 7 Priority Classes 07 Priority Classes Yaml 

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


#### 8 Resource Quotas Limits 08 Resource Quotas Limits Yaml 

### 8. Resource Quotas & Limits (08-resource-quotas-limits.yaml)


#### Resourcequota

#### ResourceQuota
- **workload-demo-quota**: Overall namespace limits
  - CPU requests: 50 cores, limits: 100 cores
  - Memory requests: 50Gi, limits: 100Gi
  - Storage: 500Gi, 10 PVCs
  - Pods: 100, Services: 50

- **critical-workload-quota**: For critical priority workloads
- **best-effort-quota**: For best-effort workloads


#### Limitrange

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

#### Check Quota Usage

# Check quota usage
kubectl describe resourcequota -n workload-demo


#### Check Limit Ranges

# Check limit ranges
kubectl describe limitrange -n workload-demo
```


#### Monitor Resource Usage

# Monitor resource usage
kubectl top pods -n workload-demo
kubectl top nodes
```


#### 9 Monitoring Testing 09 Monitoring Tests Yaml 

### 9. Monitoring & Testing (09-monitoring-tests.yaml)


#### Servicemonitor

#### ServiceMonitor
- Prometheus monitoring for workload metrics
- Scrapes metrics every 30s


#### Test Jobs

#### Test Jobs
- **test-deployments**: Validates all workloads are running
- **load-test-workloads**: Load testing for deployments

**Running Tests**:
```bash

#### Run Validation Tests

# Run validation tests
kubectl create job --from=cronjob/test-deployments validation-test -n workload-demo
kubectl logs -f job/validation-test -n workload-demo
```


#### Check Test Results

# Check test results
kubectl logs job/manual-test -n workload-demo


#### Run Load Tests

# Run load tests
kubectl create -f 09-monitoring-tests.yaml
kubectl logs -f job/load-test-workloads -n workload-demo
```


#### Deployment

## Deployment


#### Prerequisites

### Prerequisites

1. Kubernetes cluster (v1.28+)
2. Storage provisioner configured
3. Prometheus operator (for ServiceMonitor)
4. kubectl configured


#### Deploy All Components

### Deploy All Components

```bash

#### Make Script Executable

# Make script executable
chmod +x deploy.sh


#### Deploy Everything

# Deploy everything
./deploy.sh


#### Or Deploy Manually

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


#### Verify Deployment

### Verify Deployment

```bash

#### Check Namespace

# Check namespace
kubectl get ns workload-demo


#### Check All Resources

# Check all resources
kubectl get all -n workload-demo


#### Check Priority Classes

# Check priority classes
kubectl get priorityclass


#### Check Resource Quotas

# Check resource quotas
kubectl get resourcequota -n workload-demo


#### Check Pdbs

# Check PDBs
kubectl get pdb -n workload-demo


#### Best Practices

## Best Practices


#### Deployment Strategies

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


#### Health Checks

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


#### Statefulsets

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


#### Daemonsets

### DaemonSets

1. **Use for node-level services**:
   - Monitoring agents, log collectors
   - Network plugins, storage daemons

2. **Configure update strategy**:
   - `RollingUpdate`: Gradual updates (default)
   - Set `maxUnavailable` to control speed

3. **Add tolerations** for control plane nodes if needed


#### Jobs Cronjobs

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


#### Pod Disruption Budgets

### Pod Disruption Budgets

1. **Configure for critical services**:
   - Use `minAvailable` for absolute numbers
   - Use `maxUnavailable` for flexibility

2. **Consider cluster operations**:
   - Node drains for maintenance
   - Cluster upgrades
   - Auto-scaling


#### Priority Classes

### Priority Classes

1. **Use sparingly**:
   - Reserve critical priority for essential services
   - Most workloads should use medium priority

2. **Understand preemption**:
   - Higher priority pods can evict lower priority
   - Can cause disruption if overused


#### Resource Management

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


#### Monitoring

## Monitoring


#### Key Metrics

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


#### Grafana Dashboards

### Grafana Dashboards

Import the dashboard from ConfigMap:
```bash
kubectl get configmap workload-management-dashboard -n workload-demo \
  -o jsonpath='{.data.workload-management\.json}'
```


#### Troubleshooting

## Troubleshooting


#### Deployment Issues

### Deployment Issues

```bash

#### Check Deployment Status

# Check deployment status
kubectl rollout status deployment/<name> -n workload-demo


#### View Deployment History

# View deployment history
kubectl rollout history deployment/<name> -n workload-demo


#### Rollback To Previous Version

# Rollback to previous version
kubectl rollout undo deployment/<name> -n workload-demo


#### Check Events

# Check events
kubectl get events -n workload-demo --sort-by='.lastTimestamp'
```


#### Statefulset Issues

### StatefulSet Issues

```bash

#### Check Statefulset Status

# Check statefulset status
kubectl get statefulset -n workload-demo


#### Check Pvcs

# Check PVCs
kubectl get pvc -n workload-demo


#### Check Pod Logs

# Check pod logs
kubectl logs <pod-name> -n workload-demo


#### Force Delete Stuck Pod

# Force delete stuck pod
kubectl delete pod <pod-name> -n workload-demo --grace-period=0 --force
```


#### Resource Quota Issues

### Resource Quota Issues

```bash

#### Check Pod Resource Requests

# Check pod resource requests
kubectl describe pod <pod-name> -n workload-demo | grep -A 5 "Requests"


#### Job Cronjob Issues

### Job/CronJob Issues

```bash

#### Check Job Status

# Check job status
kubectl get jobs -n workload-demo


#### Check Cronjob Schedule

# Check cronjob schedule
kubectl get cronjobs -n workload-demo


#### Check Job Logs

# Check job logs
kubectl logs job/<job-name> -n workload-demo


#### Manually Trigger Cronjob

# Manually trigger cronjob
kubectl create job --from=cronjob/<cronjob-name> manual-run -n workload-demo
```


#### Cleanup

## Cleanup

```bash

#### Delete Namespace Removes All Resources 

# Delete namespace (removes all resources)
kubectl delete namespace workload-demo


#### Delete Priority Classes

# Delete priority classes
kubectl delete priorityclass critical-priority high-priority medium-priority low-priority best-effort-priority


#### Delete Cluster Roles And Bindings

# Delete cluster roles and bindings
kubectl delete clusterrole workload-tester-cluster log-collector
kubectl delete clusterrolebinding workload-tester-cluster log-collector
```


#### References

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


#### Security Considerations

## Security Considerations

1. **Pod Security Standards**: All pods use restricted PSS
2. **Security Context**: Non-root users, read-only root filesystem
3. **Network Policies**: Restrict traffic between workloads
4. **RBAC**: Minimal permissions for ServiceAccounts
5. **Secrets**: Credentials stored in Kubernetes Secrets
6. **Resource Limits**: Prevent resource exhaustion attacks


#### Production Checklist

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


---

## 5. TECHNICAL REQUIREMENTS

### 5.1 Dependencies
- All dependencies from original documentation apply
- Standard development environment
- Required tools and libraries as specified

### 5.2 Compatibility
- Compatible with existing infrastructure
- Follows project standards and conventions

---

## 6. SUCCESS CRITERIA

### 6.1 Functional Success Criteria
- All identified tasks completed successfully
- All requirements implemented as specified
- All tests passing

### 6.2 Quality Success Criteria
- Code meets quality standards
- Documentation is complete and accurate
- No critical issues remaining

---

## 7. IMPLEMENTATION PLAN

### Phase 1: Preparation
- Review all requirements and tasks
- Set up development environment
- Gather necessary resources

### Phase 2: Implementation
- Execute tasks in priority order
- Follow best practices
- Test incrementally

### Phase 3: Validation
- Run comprehensive tests
- Validate against requirements
- Document completion

---

## 8. TASK-MASTER INTEGRATION

### How to Parse This PRD

```bash
# Parse this PRD with task-master
task-master parse-prd --input="{doc_name}_PRD.md"

# List generated tasks
task-master list

# Start execution
task-master next
```

### Expected Task Generation
Task-master should generate approximately {len(tasks)} tasks from this PRD.

---

## 9. APPENDIX

### 9.1 References
- Original document: {doc_name}.md
- Project: {project_name}

### 9.2 Change History
| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | {datetime.now().strftime('%Y-%m-%d')} | Initial PRD conversion |

---

*End of PRD*
*Generated by MD-to-PRD Converter*
