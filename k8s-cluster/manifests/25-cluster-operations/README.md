# Kubernetes Cluster Operations Automation

Comprehensive automation for cluster upgrades, node management, capacity planning, and operational maintenance.

## Overview

This directory contains automation tools and configurations for managing Kubernetes cluster operations:

- **Cluster Upgrades**: Automated, safe cluster version upgrades with rollback capability
- **Node Management**: Tools for cordoning, draining, repairing, and replacing nodes
- **Capacity Monitoring**: Proactive capacity monitoring and forecasting
- **Maintenance Windows**: Scheduled maintenance automation
- **Health Checks**: Comprehensive cluster health validation
- **Operational Runbooks**: Detailed procedures for common operations

## Components

### 1. Cluster Upgrade Automation

**Script**: `01-cluster-upgrade.sh`

Automates Kubernetes cluster upgrades with safety checks and rollback capability.

```bash
# Pre-upgrade checks
k8s-cluster-upgrade --target-version 1.29.0 --pre-check

# Upgrade control plane
k8s-cluster-upgrade --target-version 1.29.0 --control-plane

# Upgrade workers
k8s-cluster-upgrade --target-version 1.29.0 --workers

# Upgrade specific node
k8s-cluster-upgrade --target-version 1.29.0 --node worker-1
```

**Features**:
- Pre-upgrade validation
- Automatic etcd backup
- Rolling upgrades
- Node-by-node progression
- Health checks between upgrades
- Comprehensive logging

### 2. Cluster Rollback

**Script**: `02-cluster-rollback.sh`

Handles rollback of failed upgrades and emergency recovery.

```bash
# List available backups
k8s-cluster-rollback --list-backups

# Rollback to specific version
k8s-cluster-rollback --version 1.28.0

# Restore from etcd backup
k8s-cluster-rollback --etcd-backup /path/to/backup.db

# Rollback specific node
k8s-cluster-rollback --node worker-1 --version 1.28.0
```

**Features**:
- Version rollback
- etcd restore capability
- Node-specific rollback
- Safety confirmations

### 3. Node Management

**Script**: `03-node-management.sh`

Comprehensive node lifecycle management.

```bash
# Cordon nodes
k8s-node-management cordon worker-1 worker-2

# Drain node for maintenance
k8s-node-management drain worker-1 --timeout 900

# Uncordon node
k8s-node-management uncordon worker-1

# Repair unhealthy node
k8s-node-management repair worker-1

# Replace failed node
k8s-node-management replace worker-1

# Health check
k8s-node-management health-check

# List tainted nodes
k8s-node-management list-tainted

# Remove taint
k8s-node-management remove-taint worker-1 node.kubernetes.io/disk-pressure
```

**Features**:
- Safe node draining with PDB awareness
- Automated repair diagnostics
- Node replacement workflows
- Taint management
- Health monitoring

### 4. Capacity Monitoring

**Manifest**: `04-capacity-monitoring.yaml`

Prometheus rules and dashboards for capacity planning.

```bash
# Deploy capacity monitoring
kubectl apply -f 04-capacity-monitoring.yaml

# View capacity alerts
kubectl get prometheusrules -n monitoring capacity-monitoring-rules -o yaml

# Check capacity metrics
kubectl top nodes
kubectl top pods -A
```

**Alerts**:
- Node CPU/Memory capacity warnings
- Cluster-wide capacity thresholds
- Pod capacity alerts
- Storage capacity monitoring
- 7-day capacity forecasting
- Growth trend analysis

**Metrics**:
- `cluster:cpu_usage:ratio` - Cluster CPU utilization
- `cluster:memory_usage:ratio` - Cluster memory utilization
- `node:cpu_usage:ratio` - Per-node CPU utilization
- `node:memory_usage:ratio` - Per-node memory utilization

### 5. Maintenance Windows

**Manifest**: `05-maintenance-windows.yaml`

Automated maintenance window scheduling and execution.

```bash
# Deploy maintenance automation
kubectl apply -f 05-maintenance-windows.yaml

# View scheduled maintenance
kubectl get cronjob -n kube-system

# Manually trigger maintenance
kubectl create job --from=cronjob/weekly-maintenance -n kube-system manual-maintenance

# View maintenance logs
kubectl logs -n kube-system -l app=maintenance-scheduler
```

**Scheduled Windows**:
- **Weekly Maintenance**: Sunday 2 AM (4 hours)
  - Cleanup old resources
  - Restart monitoring components
  - Health verification

- **Monthly Patching**: 1st of month, 1 AM (8 hours)
  - System package updates
  - Rolling node restarts
  - Application scaling

**Features**:
- Automated backup before maintenance
- Notification integration (Slack, email, PagerDuty)
- Pre/post-task execution
- Health verification
- Maintenance reporting

### 6. Health Checks

**Script**: `06-health-checks.sh`

Comprehensive cluster health validation and diagnostics.

```bash
# Quick health check
k8s-health-check --quick

# Full comprehensive check
k8s-health-check --full --output /tmp/report.txt

# Component-specific checks
k8s-health-check --component nodes
k8s-health-check --component pods
k8s-health-check --component storage
k8s-health-check --component network
k8s-health-check --component security

# Namespace-specific check
k8s-health-check --namespace production
```

**Checks**:
- API server health and latency
- etcd cluster health
- Node status and conditions
- Node resource usage
- Pod health and restart loops
- Service endpoints
- PVC status and capacity
- Network connectivity
- DNS functionality
- Security posture
- RBAC configuration

### 7. Operational Runbooks

**Manifest**: `07-operations-runbooks.yaml`

Detailed runbooks for common operational scenarios.

```bash
# Deploy runbooks
kubectl apply -f 07-operations-runbooks.yaml

# Access runbooks
kubectl get configmap -n kube-system cluster-operations-runbooks -o yaml

# View specific runbook
kubectl get configmap -n kube-system cluster-operations-runbooks \
  -o jsonpath='{.data.cluster-upgrade-runbook\.md}' | less
```

**Available Runbooks**:
- Cluster Upgrade Procedures
- Node Maintenance Workflows
- Capacity Planning Guidelines
- Incident Response Procedures
- Backup and Restore Operations
- Monitoring Troubleshooting

## Installation

### Prerequisites

- Kubernetes cluster (1.26+)
- kubectl configured with admin access
- Prometheus Operator installed (for monitoring)
- bash 4.0+
- jq (for JSON parsing)

### Deployment

```bash
# Clone or download this directory
cd k8s-cluster/manifests/25-cluster-operations

# Run deployment script
./deploy.sh

# Verify installation
k8s-health-check --quick
```

### Manual Installation

```bash
# Make scripts executable
chmod +x *.sh

# Create directories
sudo mkdir -p /var/log/k8s-operations
sudo mkdir -p /var/backups/k8s-cluster

# Deploy Kubernetes resources
kubectl apply -f 04-capacity-monitoring.yaml
kubectl apply -f 05-maintenance-windows.yaml
kubectl apply -f 07-operations-runbooks.yaml

# Install scripts
sudo cp 01-cluster-upgrade.sh /usr/local/bin/k8s-cluster-upgrade
sudo cp 02-cluster-rollback.sh /usr/local/bin/k8s-cluster-rollback
sudo cp 03-node-management.sh /usr/local/bin/k8s-node-management
sudo cp 06-health-checks.sh /usr/local/bin/k8s-health-check
```

## Usage Examples

### Scenario 1: Planned Cluster Upgrade

```bash
# 1. Run pre-upgrade checks
k8s-cluster-upgrade --target-version 1.29.0 --pre-check

# 2. Schedule maintenance window
# Edit 05-maintenance-windows.yaml if needed

# 3. Perform upgrade during maintenance window
k8s-cluster-upgrade --target-version 1.29.0

# 4. Verify cluster health
k8s-health-check --full

# 5. Monitor for issues
kubectl get events -A --watch
```

### Scenario 2: Node Maintenance

```bash
# 1. Identify node for maintenance
kubectl get nodes

# 2. Cordon node
k8s-node-management cordon worker-3

# 3. Drain node
k8s-node-management drain worker-3

# 4. Perform maintenance on the node
ssh worker-3 'sudo apt-get update && sudo apt-get upgrade -y'
ssh worker-3 'sudo reboot'

# 5. Wait for node to come back
watch kubectl get nodes

# 6. Uncordon node
k8s-node-management uncordon worker-3

# 7. Verify
k8s-node-management health-check worker-3
```

### Scenario 3: Capacity Planning

```bash
# 1. Check current capacity
kubectl top nodes
kubectl top pods -A

# 2. Review capacity dashboard
# Access Grafana → Kubernetes Capacity Planning

# 3. Check forecasting alerts
kubectl get prometheusrules -n monitoring capacity-monitoring-rules

# 4. If capacity warning, plan expansion
# - Add new nodes
# - Optimize workload resources
# - Scale down non-essential services

# 5. Generate capacity report
kubectl logs -n monitoring -l app=capacity-report
```

### Scenario 4: Incident Response

```bash
# 1. Detect issue
k8s-health-check --quick

# 2. Identify failed component
kubectl get pods -A | grep -v "Running"
kubectl get nodes | grep "NotReady"

# 3. Investigate
kubectl describe pod <failed-pod>
kubectl logs <failed-pod> --previous

# 4. Take corrective action
# For pod issues:
kubectl rollout restart deployment <name>
kubectl rollout undo deployment <name>

# For node issues:
k8s-node-management repair <node>
# or
k8s-node-management replace <node>

# 5. Verify resolution
k8s-health-check --full

# 6. Document incident
# Follow post-incident runbook
```

## Configuration

### Capacity Alert Thresholds

Edit `04-capacity-monitoring.yaml` to adjust thresholds:

```yaml
# Example: Adjust CPU warning threshold
- alert: NodeCPUCapacityHigh
  expr: (cpu_usage / allocatable) > 0.80  # Change from 80% to your preference
  for: 30m
```

### Maintenance Window Schedule

Edit `05-maintenance-windows.yaml` to change schedules:

```yaml
# Example: Change weekly maintenance time
spec:
  schedule: "0 2 * * 0"  # Change to your preferred time (cron format)
```

### Backup Retention

Backups are automatically cleaned up, keeping the last 10 backups. To change:

```bash
# Edit backup retention in 01-cluster-upgrade.sh
# Find: ls -t "$BACKUP_DIR"/etcd-backup-* | tail -n +11
# Change 11 to (desired_retention + 1)
```

## Monitoring and Alerting

### View Active Alerts

```bash
# Prometheus alerts
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open: http://localhost:9090/alerts

# Alertmanager
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
# Open: http://localhost:9093
```

### Access Grafana Dashboards

```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
# Open: http://localhost:3000
# Dashboard: Kubernetes Capacity Planning
```

### Check Logs

```bash
# Cluster operations logs
sudo tail -f /var/log/k8s-operations/*.log

# Maintenance job logs
kubectl logs -n kube-system -l app=maintenance-scheduler --tail=100

# Health check reports
ls -lh /var/log/k8s-operations/reports/
```

## Troubleshooting

### Script Permissions

```bash
# If scripts are not executable
chmod +x /usr/local/bin/k8s-*
```

### Missing Dependencies

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install jq
sudo apt-get install -y jq  # Debian/Ubuntu
sudo yum install -y jq      # RHEL/CentOS
```

### Prometheus Rules Not Loading

```bash
# Check Prometheus Operator
kubectl get prometheus -n monitoring

# Check rule status
kubectl describe prometheusrules -n monitoring capacity-monitoring-rules

# Reload Prometheus
kubectl delete pod -n monitoring -l app.kubernetes.io/name=prometheus
```

### Maintenance Jobs Not Running

```bash
# Check CronJob schedule
kubectl get cronjob -n kube-system

# Check for suspended jobs
kubectl get cronjob -n kube-system -o yaml | grep suspend

# Manually trigger job
kubectl create job --from=cronjob/weekly-maintenance -n kube-system test-run

# Check job logs
kubectl logs -n kube-system job/test-run
```

## Best Practices

1. **Always run pre-checks** before upgrades
2. **Backup before major changes** - etcd backups are automatic but verify
3. **Test in staging first** - validate procedures in non-production
4. **Monitor during operations** - keep an eye on alerts and metrics
5. **Document changes** - use runbooks and update as needed
6. **Schedule during low-traffic periods** - maintenance windows matter
7. **Have rollback plan ready** - know how to revert changes
8. **Communicate with team** - notify stakeholders of maintenance

## Security Considerations

- Scripts require cluster-admin permissions
- Backup directory should be secured (mode 700)
- etcd backups contain sensitive data - encrypt if needed
- Service accounts follow least-privilege principle
- Audit all operations in logs

## Support and Maintenance

### Regular Reviews

- **Weekly**: Review capacity alerts and trends
- **Monthly**: Update scripts and configurations
- **Quarterly**: Test disaster recovery procedures
- **Annually**: Review and update runbooks

### Updates

Check for updates to Kubernetes and tool versions:

```bash
# Check current versions
kubectl version
kubeadm version

# Check for available updates
apt-cache policy kubeadm  # Debian/Ubuntu
yum list updates kubeadm  # RHEL/CentOS
```

## Contributing

To add new automation or improve existing tools:

1. Follow bash best practices
2. Include comprehensive error handling
3. Add logging and status reporting
4. Update documentation
5. Test in staging environment
6. Create runbook for new procedures

## References

- [Kubernetes Official Docs](https://kubernetes.io/docs/)
- [Cluster Upgrade Best Practices](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)
- [Node Management](https://kubernetes.io/docs/tasks/administer-cluster/)
- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)
- [Capacity Planning Guide](https://kubernetes.io/docs/concepts/cluster-administration/)

## License

These scripts and configurations are provided as-is for operational use.

## Version History

- **v1.0** (2024-10-13): Initial implementation
  - Cluster upgrade automation
  - Node management tools
  - Capacity monitoring
  - Maintenance windows
  - Health checks
  - Operational runbooks
