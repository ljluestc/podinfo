# Cost Management - Quick Start Guide

This guide provides the essential commands to get started with cost management quickly.

## Quick Deploy

```bash
cd k8s-cluster/manifests/24-cost-management
./deploy.sh
```

## Quick Access

### OpenCost UI
```bash
kubectl port-forward -n opencost svc/opencost 9003:9003
# Access: http://localhost:9003
```

### Grafana Dashboards
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Access: http://localhost:3000
# Look for "Cost Management" dashboards
```

## Quick Queries

### Get Total Cluster Cost
```bash
kubectl port-forward -n opencost svc/opencost 9003:9003 &
curl "http://localhost:9003/allocation/compute?window=1d"
```

### Get Cost by Namespace
```bash
curl "http://localhost:9003/allocation/compute?window=7d&aggregate=namespace" | jq .
```

### Get Cost by Team
```bash
curl "http://localhost:9003/allocation/compute?window=7d&aggregate=label:team" | jq .
```

## Quick Labeling

### Add Cost Labels to a Deployment
```bash
kubectl label deployment <deployment-name> \
  team=platform-team \
  application=my-app \
  environment=production \
  cost-center=CC-1001

kubectl annotate deployment <deployment-name> \
  cost-allocation/team="platform-team" \
  cost-allocation/owner="team@example.com" \
  cost-allocation/monthly-budget="200"
```

### Set Budget on a Namespace
```bash
kubectl annotate namespace <namespace> \
  cost-allocation/monthly-budget="1000" \
  cost-allocation/team="platform-team"
```

## Quick Testing

### Deploy Test Resources
```bash
kubectl apply -f 07-testing.yaml
```

### Run Validation
```bash
kubectl logs -n cost-test job/cost-validation-test -f
```

### Check Right-Sizing Recommendations
```bash
kubectl logs -n opencost -l app=rightsizing --tail=50
```

### Check Idle Resources
```bash
kubectl logs -n opencost -l app=idle-cleanup --tail=50
```

## Quick Troubleshooting

### Check OpenCost Status
```bash
kubectl get pods -n opencost
kubectl logs -n opencost -l app=opencost --tail=50
```

### Verify Prometheus Integration
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit: http://localhost:9090/targets
# Look for: opencost/opencost/0
```

### Check Alerts
```bash
kubectl get prometheusrule -n opencost cost-alerts
# Visit Prometheus alerts: http://localhost:9090/alerts
```

### View Dashboard ConfigMaps
```bash
kubectl get configmap -n opencost cost-dashboards -o yaml
```

## Quick Commands Reference

| Task | Command |
|------|---------|
| Deploy all | `./deploy.sh` |
| View costs | `curl localhost:9003/allocation/compute?window=1d` |
| Check status | `kubectl get all -n opencost` |
| View logs | `kubectl logs -n opencost -l app=opencost` |
| Run tests | `kubectl apply -f 07-testing.yaml` |
| Access UI | `kubectl port-forward -n opencost svc/opencost 9003:9003` |
| View dashboards | `kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80` |
| Manual right-size | `kubectl create job --from=cronjob/rightsizing-analyzer manual-run -n opencost` |
| Manual idle check | `kubectl create job --from=cronjob/idle-resource-detector manual-check -n opencost` |

## Cost Allocation Labels (Required)

```yaml
labels:
  team: "platform-team"          # Required
  application: "my-app"          # Required
  environment: "production"      # Required
  cost-center: "CC-1001"        # Optional

annotations:
  cost-allocation/team: "platform-team"
  cost-allocation/owner: "team@example.com"
  cost-allocation/monthly-budget: "200"
```

## Key Metrics

- **Total Cluster Cost**: Sum of all resource costs
- **Cost by Namespace**: Breakdown by Kubernetes namespace
- **Cost by Team**: Aggregated by team label
- **Cost Efficiency**: Actual usage vs requested resources
- **Potential Savings**: Identified optimization opportunities

## Next Steps

1. Label all existing workloads with cost tracking labels
2. Set budgets on namespaces
3. Configure alert notifications (update secrets)
4. Review dashboards daily
5. Implement right-sizing recommendations weekly
6. Generate monthly showback/chargeback reports

## Support

For detailed documentation, see [README.md](README.md)

For OpenCost documentation: https://www.opencost.io/docs/
