# Alerting and Incident Management

## Overview

This directory contains comprehensive alerting and incident management configuration for the Kubernetes security cluster. The alerting system provides:

- Multi-channel notification delivery (Slack, PagerDuty, email, webhooks)
- Intelligent alert routing and grouping
- On-call rotation and escalation policies
- Comprehensive runbooks for incident response
- SLO-based alerting with error budget tracking
- Alert deduplication and correlation

## Architecture

```
┌─────────────────────┐
│   Prometheus        │
│   Alert Rules       │
└──────────┬──────────┘
           │
           │ Fires alerts
           ▼
┌─────────────────────┐
│   Alertmanager      │
│   - Routing         │
│   - Grouping        │
│   - Deduplication   │
│   - Inhibition      │
└──────────┬──────────┘
           │
           │ Routes to
           ▼
┌──────────────────────────────────────┐
│         Notification Channels        │
│                                      │
│  ┌──────────┐  ┌──────────────┐     │
│  │  Slack   │  │  PagerDuty   │     │
│  └──────────┘  └──────────────┘     │
│                                      │
│  ┌──────────┐  ┌──────────────┐     │
│  │  Email   │  │  Webhooks    │     │
│  └──────────┘  └──────────────┘     │
└──────────────────────────────────────┘
           │
           ▼
┌─────────────────────┐
│   On-Call Team      │
│   & Runbooks        │
└─────────────────────┘
```

## Components

### 1. Alertmanager Configuration (`alertmanager-config.yaml`)

High-availability Alertmanager deployment with:
- **3 replicas** for redundancy
- **Persistent storage** for alert state
- **Cluster mode** for alert deduplication across replicas
- **Template system** for custom notifications
- **Routing tree** for intelligent alert distribution
- **Inhibition rules** to suppress redundant alerts

#### Key Features:
- **Alert Grouping**: Groups related alerts by `alertname`, `cluster`, `service`, `severity`
- **Time Windows**:
  - `group_wait: 30s` - Wait before sending first notification
  - `group_interval: 5m` - Wait before sending group updates
  - `repeat_interval: 4h` - Resend interval for unresolved alerts
- **Inhibition Rules**: Automatically suppress lower severity alerts when higher severity ones are active

### 2. Alert Rules (`alert-rules.yaml`)

Comprehensive alert coverage across multiple categories:

#### Infrastructure Alerts
- Node health (NotReady, DiskPressure, MemoryPressure)
- Resource utilization (CPU, Memory, Disk)
- Kubernetes component health (API Server, Controller Manager, Scheduler, etcd)

#### Application Alerts
- Pod crash loops and restarts
- High resource usage
- OOMKills
- Pod availability

#### Security Alerts
- Unauthorized API access
- Policy violations
- Privileged containers
- Certificate expiration
- Runtime security events (Falco)

#### Network Alerts
- High error rates
- Network policy violations

#### Storage Alerts
- PVC pending
- PV low space
- Inode exhaustion

#### SLO Alerts
- Availability breaches
- Latency violations
- Error budget consumption

#### Watchdog
- Dead man's switch to verify alerting pipeline health

### 3. On-Call and Escalation (`oncall-escalation.yaml`)

Defines on-call rotations and escalation policies:

#### On-Call Rotations:
- **Primary On-Call**: Weekly rotation, first responder
- **Secondary On-Call**: Weekly rotation, escalation target
- **Security On-Call**: 24/7 dedicated security team

#### Escalation Policies:
1. **Critical Infrastructure** (0m → 15m → 30m)
   - Level 1: Primary on-call (immediate)
   - Level 2: Secondary on-call (if not acknowledged)
   - Level 3: Engineering manager (if not resolved)

2. **Security Incidents** (0m → 10m → 20m)
   - Level 1: Security + Primary on-call (immediate)
   - Level 2: Security team lead
   - Level 3: CISO

3. **Application Alerts** (0m → 30m → 60m)
   - Level 1: Slack notification
   - Level 2: Page primary on-call
   - Level 3: Page secondary on-call

4. **Warning Alerts** (0m → 4h)
   - Level 1: Slack notification
   - Level 2: Page on-call if unresolved

5. **SLO Breaches** (0m → 2h → 24h)
   - Level 1: Slack + email
   - Level 2: Engineering manager
   - Level 3: Leadership team

#### Alert SLAs:
- **Critical**: Acknowledge in 15m, resolve in 4h
- **High**: Acknowledge in 30m, resolve in 8h
- **Warning**: Acknowledge in 4h, resolve in 24h
- **Security**: Acknowledge in 10m, resolve in 2h

### 4. Runbooks (`runbooks.yaml`)

Comprehensive troubleshooting guides for common incidents:

- **Node Not Ready**: Diagnosis and recovery steps for node failures
- **Pod Crash Looping**: Common causes and solutions for pod restarts
- **API Server Down**: Critical recovery procedures for API server outages
- **High CPU/Memory**: Resource troubleshooting and optimization
- **Certificate Expiring**: Certificate renewal procedures
- **PVC Pending**: Storage provisioning troubleshooting
- **Security Alerts**: Security incident response procedures

Each runbook includes:
- Alert description and severity
- Impact assessment
- Step-by-step diagnosis procedures
- Resolution steps with commands
- Prevention recommendations
- Related alerts

### 5. SLO Configuration (`slo-config.yaml`)

Implements Service Level Objective tracking and error budget alerting:

#### SLO Definitions:
- **API Server**: 99.9% availability, 95% requests < 1s
- **Frontend**: 99.5% availability, 95% requests < 500ms
- **Backend**: 99.9% availability, 99% requests < 100ms
- **Database**: 99.99% availability, 95% queries < 50ms

#### Multi-Window Multi-Burn-Rate Alerting:
Based on Google SRE Workbook methodology:

1. **Fast Burn Alerts** (Critical)
   - 5-minute and 1-hour windows
   - Detects rapid error budget consumption
   - Immediate paging

2. **Slow Burn Alerts** (Warning)
   - 1-day and 3-day windows
   - Detects gradual budget depletion
   - Early warning system

#### Recording Rules:
Pre-computed metrics for efficient querying:
- Availability ratios at multiple time windows (5m, 30m, 1h, 6h, 1d, 3d)
- Latency percentiles (p95, p99)
- Error budget calculations

## Deployment

### Prerequisites

1. **Prometheus Operator** must be installed:
   ```bash
   kubectl apply -f prometheus-stack.yaml
   ```

2. **Create secrets** with actual credentials:
   ```bash
   # Create namespace
   kubectl create namespace monitoring

   # Create Alertmanager secrets
   kubectl create secret generic alertmanager-secrets \
     --from-literal=slack-webhook-url='https://hooks.slack.com/services/YOUR/WEBHOOK' \
     --from-literal=pagerduty-critical-key='YOUR_PAGERDUTY_KEY' \
     --from-literal=pagerduty-security-key='YOUR_SECURITY_KEY' \
     --from-literal=pagerduty-slo-key='YOUR_SLO_KEY' \
     --from-literal=smtp-username='alerts@example.com' \
     --from-literal=smtp-password='YOUR_PASSWORD' \
     --from-literal=webhook-infrastructure-url='https://webhook.example.com' \
     -n monitoring

   # Create basic auth for Alertmanager UI
   htpasswd -c auth admin
   kubectl create secret generic alertmanager-basic-auth \
     --from-file=auth \
     -n monitoring
   ```

### Installation

```bash
# Apply all alerting configurations
kubectl apply -f alertmanager-config.yaml
kubectl apply -f alert-rules.yaml
kubectl apply -f oncall-escalation.yaml
kubectl apply -f runbooks.yaml
kubectl apply -f slo-config.yaml

# Verify Alertmanager deployment
kubectl get statefulset -n monitoring alertmanager
kubectl get pods -n monitoring -l app=alertmanager

# Check Alertmanager logs
kubectl logs -n monitoring alertmanager-0

# Verify alert rules are loaded
kubectl get prometheusrule -n monitoring

# Check Alertmanager status
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
# Open http://localhost:9093
```

## Configuration

### Notification Channels

#### Slack Setup:
1. Create Slack channels:
   - `#alerts-critical`
   - `#alerts-warnings`
   - `#security-alerts`
   - `#infrastructure-alerts`
   - `#app-alerts`
   - `#slo-alerts`

2. Create incoming webhooks for each channel in Slack app settings

3. Update the `alertmanager-secrets` with webhook URLs

#### PagerDuty Setup:
1. Create services in PagerDuty:
   - Critical Infrastructure Alerts
   - Security Alerts
   - Application Alerts
   - SLO Alerts

2. Configure escalation policies matching `oncall-escalation.yaml`

3. Create integration keys for each service

4. Update the `alertmanager-secrets` with integration keys

5. Set up on-call schedules in PagerDuty

#### Email Setup:
1. Configure SMTP server access

2. Update the `alertmanager-secrets` with credentials

3. Customize email templates in `alertmanager-templates` ConfigMap

### Customizing Alert Rules

Edit `alert-rules.yaml` to adjust thresholds:

```yaml
- alert: NodeHighCPU
  expr: (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance)) * 100 > 80
  for: 10m  # Adjust this
  labels:
    severity: warning  # Or 'critical'
```

### Customizing Routing

Edit the `route` section in `alertmanager-config.yaml`:

```yaml
routes:
- match:
    team: frontend
  receiver: 'frontend-team-slack'
  continue: false
```

## Testing

### Testing Alert Rules

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090

# Open http://localhost:9090/alerts to see all alerts

# Manually trigger a test alert using amtool
kubectl exec -n monitoring alertmanager-0 -- \
  amtool alert add test \
  severity=warning \
  alertname=TestAlert \
  instance=test-instance
```

### Testing Notification Delivery

```bash
# Send test alert to Slack
kubectl exec -n monitoring alertmanager-0 -- \
  amtool alert add slack_test \
  severity=critical \
  alertname=SlackTest \
  summary="Test alert for Slack"

# Send test to PagerDuty
kubectl exec -n monitoring alertmanager-0 -- \
  amtool alert add pagerduty_test \
  severity=critical \
  alertname=PagerDutyTest \
  summary="Test alert for PagerDuty"
```

### Testing Alert Grouping

```bash
# Send multiple similar alerts
for i in {1..5}; do
  kubectl exec -n monitoring alertmanager-0 -- \
    amtool alert add group_test_$i \
    severity=warning \
    alertname=GroupTest \
    instance=instance-$i
done

# Check Alertmanager UI to see grouped alerts
```

### Testing Inhibition Rules

```bash
# Send critical alert
kubectl exec -n monitoring alertmanager-0 -- \
  amtool alert add critical_test \
  severity=critical \
  alertname=TestAlert \
  service=myservice

# Send warning alert for same service
kubectl exec -n monitoring alertmanager-0 -- \
  amtool alert add warning_test \
  severity=warning \
  alertname=TestAlert \
  service=myservice

# Warning should be inhibited - check Alertmanager UI
```

### Testing Escalation

```bash
# Send alert and don't acknowledge
# Wait for escalation timers to trigger
# Verify secondary notifications are sent
```

## Monitoring Alertmanager

### Key Metrics

```promql
# Alert firing rate
rate(alertmanager_alerts_received_total[5m])

# Notification success rate
rate(alertmanager_notifications_total{integration="slack"}[5m])
rate(alertmanager_notifications_failed_total{integration="slack"}[5m])

# Silenced alerts
alertmanager_silences_active

# Alert grouping effectiveness
alertmanager_alerts_suppressed_total
```

### Health Checks

```bash
# Check Alertmanager health
curl http://alertmanager:9093/-/healthy

# Check readiness
curl http://alertmanager:9093/-/ready

# Check cluster status
kubectl exec -n monitoring alertmanager-0 -- \
  amtool cluster show

# List active alerts
kubectl exec -n monitoring alertmanager-0 -- \
  amtool alert query
```

## Troubleshooting

### Alerts Not Firing

1. Check if metrics are being collected:
   ```bash
   # Port-forward to Prometheus
   kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090

   # Test the alert query in Prometheus UI
   ```

2. Check PrometheusRule is loaded:
   ```bash
   kubectl get prometheusrule -n monitoring
   kubectl describe prometheusrule comprehensive-alert-rules -n monitoring
   ```

3. Check Prometheus logs:
   ```bash
   kubectl logs -n monitoring prometheus-prometheus-0 -c prometheus
   ```

### Alerts Not Reaching Notification Channels

1. Check Alertmanager logs:
   ```bash
   kubectl logs -n monitoring alertmanager-0 | grep -i error
   ```

2. Verify secrets are configured:
   ```bash
   kubectl get secret alertmanager-secrets -n monitoring -o yaml
   ```

3. Test webhook URLs manually:
   ```bash
   curl -X POST -H 'Content-type: application/json' \
     --data '{"text":"Test message"}' \
     YOUR_SLACK_WEBHOOK_URL
   ```

4. Check notification logs:
   ```bash
   kubectl exec -n monitoring alertmanager-0 -- \
     amtool config show | grep -A 10 receivers
   ```

### Alert Storm

If too many alerts are firing:

1. Check what's firing:
   ```bash
   kubectl exec -n monitoring alertmanager-0 -- \
     amtool alert query --active
   ```

2. Create temporary silence:
   ```bash
   kubectl exec -n monitoring alertmanager-0 -- \
     amtool silence add alertname=ProblematicAlert \
     --duration=1h \
     --comment="Investigating issue"
   ```

3. Fix root cause and remove silence:
   ```bash
   kubectl exec -n monitoring alertmanager-0 -- \
     amtool silence expire <silence-id>
   ```

### Alertmanager Cluster Issues

```bash
# Check cluster status
kubectl exec -n monitoring alertmanager-0 -- \
  amtool cluster show

# Check peer connectivity
kubectl exec -n monitoring alertmanager-0 -- \
  amtool cluster peers

# Restart Alertmanager if needed
kubectl rollout restart statefulset/alertmanager -n monitoring
```

## Maintenance

### Regular Tasks

#### Daily:
- Review critical and high severity alerts
- Check on-call dashboard
- Verify notification delivery metrics

#### Weekly:
- Update on-call rotation
- Review alert trends
- Tune noisy alerts

#### Monthly:
- Test notification channels
- Review and update runbooks
- Analyze MTTA (Mean Time To Acknowledge) and MTTR (Mean Time To Resolve)
- Update escalation policies

#### Quarterly:
- Review SLO targets and error budgets
- Conduct alerting drills
- Update alert rules based on infrastructure changes
- Review and optimize alert grouping/routing

### Upgrading

```bash
# Backup current configuration
kubectl get configmap -n monitoring alertmanager-config -o yaml > backup-alertmanager-config.yaml
kubectl get prometheusrule -n monitoring -o yaml > backup-alert-rules.yaml

# Apply updated configurations
kubectl apply -f alertmanager-config.yaml
kubectl apply -f alert-rules.yaml

# Monitor for issues
kubectl logs -n monitoring alertmanager-0 -f
```

## Best Practices

1. **Alert Fatigue Prevention**:
   - Set appropriate thresholds
   - Use alert grouping effectively
   - Implement inhibition rules
   - Regular alert tuning

2. **Runbook Maintenance**:
   - Keep runbooks up-to-date
   - Include actual commands that work
   - Document recent incident learnings
   - Make runbooks easily accessible

3. **SLO Management**:
   - Set realistic SLO targets
   - Monitor error budget trends
   - Use multi-burn-rate alerting
   - Regular SLO reviews

4. **On-Call Health**:
   - Fair rotation schedules
   - Adequate coverage
   - Post-incident reviews
   - On-call handoff procedures

5. **Testing**:
   - Regular fire drills
   - Test all notification channels
   - Verify escalation policies
   - Test runbook procedures

## References

- [Prometheus Alerting](https://prometheus.io/docs/alerting/latest/overview/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [Google SRE Book - Monitoring Distributed Systems](https://sre.google/sre-book/monitoring-distributed-systems/)
- [Multi-Window Multi-Burn-Rate Alerting](https://sre.google/workbook/alerting-on-slos/)
- [PagerDuty Incident Response](https://response.pagerduty.com/)

## Support

For issues or questions:
- Check runbooks first: `kubectl get configmap alert-runbooks -n monitoring`
- Review Alertmanager docs: https://prometheus.io/docs/alerting/
- Contact platform team: #platform-support
- Emergency: Page on-call via PagerDuty
