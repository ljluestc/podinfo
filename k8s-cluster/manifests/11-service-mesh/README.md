# Service Mesh Implementation with Istio

## Overview

This directory contains a production-ready Istio service mesh deployment for the Kubernetes security cluster. The implementation provides:

- **mTLS**: Automatic mutual TLS for all service-to-service communication
- **Traffic Management**: Advanced routing, splitting, mirroring, and canary deployments
- **Observability**: Distributed tracing with Jaeger, metrics with Prometheus, and visualization with Grafana/Kiali
- **Security**: Zero-trust authorization policies and network segmentation
- **Resilience**: Circuit breakers, retries, timeouts, and fault injection

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Istio Control Plane                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                  │
│  │  Istiod  │  │ Ingress  │  │  Egress  │                  │
│  │ (Pilot)  │  │ Gateway  │  │ Gateway  │                  │
│  └──────────┘  └──────────┘  └──────────┘                  │
└─────────────────────────────────────────────────────────────┘
                           │
            ┌──────────────┼──────────────┐
            │              │              │
┌───────────▼──────┐  ┌───▼────────┐  ┌──▼──────────┐
│   Podinfo        │  │ Monitoring │  │ Observability│
│   Namespace      │  │ Namespace  │  │  Namespace   │
│ ┌──────────────┐ │  │            │  │              │
│ │ Pod + Envoy  │ │  │ Prometheus │  │   Jaeger     │
│ │   Sidecar    │ │  │  Grafana   │  │   Kiali      │
│ └──────────────┘ │  │            │  │   OTEL       │
└──────────────────┘  └────────────┘  └──────────────┘
```

### Files

- `00-istio-operator.yaml` - Istio control plane configuration
- `01-mtls-security.yaml` - mTLS and security policies
- `02-traffic-management.yaml` - Traffic routing and circuit breakers
- `03-distributed-tracing.yaml` - Jaeger and OpenTelemetry setup
- `04-observability.yaml` - Monitoring, metrics, and dashboards
- `05-namespace-config.yaml` - Sidecar injection configuration
- `06-test-suite.yaml` - Verification and testing tools
- `README.md` - This file

## Installation

### Prerequisites

- Kubernetes cluster (1.26+)
- kubectl configured
- Helm 3 (for monitoring stack)
- 8 GB+ available cluster memory
- StorageClass for persistent volumes

### Step 1: Install Istio CLI

```bash
# Download Istio
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.20.0 sh -
cd istio-1.20.0
export PATH=$PWD/bin:$PATH

# Verify installation
istioctl version
```

### Step 2: Install Istio Operator

```bash
# Initialize the operator
istioctl operator init

# Verify operator is running
kubectl get pods -n istio-operator
```

### Step 3: Deploy Istio Control Plane

```bash
# Apply the IstioOperator configuration
kubectl create namespace istio-system
kubectl apply -f 00-istio-operator.yaml

# Wait for Istio to be ready (may take 2-3 minutes)
kubectl wait --for=condition=available --timeout=300s deployment/istiod -n istio-system

# Verify installation
istioctl verify-install
kubectl get pods -n istio-system
```

### Step 4: Configure mTLS and Security

```bash
# Apply mTLS and authorization policies
kubectl apply -f 01-mtls-security.yaml

# Verify mTLS is enforced
kubectl get peerauthentication -A
kubectl get authorizationpolicy -A
```

### Step 5: Deploy Observability Stack

```bash
# Create observability namespace
kubectl create namespace observability

# Install Jaeger Operator
kubectl apply -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.51.0/jaeger-operator.yaml -n observability

# Deploy Jaeger and OpenTelemetry
kubectl apply -f 03-distributed-tracing.yaml

# Verify observability components
kubectl get pods -n observability
```

### Step 6: Install Monitoring (if not already installed)

```bash
# Add Prometheus Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus stack
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.retention=30d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi

# Apply service mesh monitoring
kubectl apply -f 04-observability.yaml
```

### Step 7: Enable Sidecar Injection

```bash
# Apply namespace configurations
kubectl apply -f 05-namespace-config.yaml

# Verify injection is enabled
kubectl get namespace -L istio-injection

# Restart pods in injected namespaces to apply sidecars
kubectl rollout restart deployment/podinfo -n podinfo
```

### Step 8: Configure Traffic Management

```bash
# Apply traffic management rules
kubectl apply -f 02-traffic-management.yaml

# Verify configurations
kubectl get virtualservices -A
kubectl get destinationrules -A
kubectl get gateways -A
```

### Step 9: Verification

```bash
# Run the test suite
kubectl apply -f 06-test-suite.yaml

# Check test results
kubectl logs -n istio-system deployment/mesh-test-runner --tail=100

# Verify mTLS is working
istioctl authn tls-check podinfo-<pod-id>.podinfo

# Check traffic routing
kubectl exec -n podinfo deploy/podinfo -c podinfo -- curl -s http://podinfo-stable:9898/
```

## Configuration

### mTLS Configuration

The mesh is configured with STRICT mTLS mode cluster-wide. All service-to-service communication is automatically encrypted and authenticated.

**Certificate Rotation:**
- Workload certificates: 24 hours
- Rotation starts at: 75% of lifetime (18 hours)
- CA certificate: 10 years

**To verify mTLS:**
```bash
# Check mTLS status for a service
istioctl authn tls-check podinfo-<pod>.podinfo podinfo-stable.podinfo.svc.cluster.local

# View certificate details
istioctl proxy-config secret deploy/podinfo -n podinfo
```

### Traffic Management

**Canary Deployments:**
- 90% traffic to stable
- 10% traffic to canary
- Header-based routing with `X-Canary: true`
- User-based A/B testing

**Circuit Breaker Settings:**
- Consecutive errors: 5
- Ejection time: 30s
- Max ejection: 50%
- Health check interval: 30s

**Retry Policy:**
- Max attempts: 3
- Per-try timeout: 2s
- Retry on: 5xx, connection failures, resets

**Example traffic split modification:**
```bash
# Edit virtual service to change traffic split
kubectl edit virtualservice podinfo-routes -n podinfo

# Change weights:
#   - stable: weight: 75
#   - canary: weight: 25
```

### Distributed Tracing

**Sampling Configuration:**
- Default: 100% (for development)
- Health checks: 10%
- Metrics endpoints: 1%

**Accessing Jaeger UI:**
```bash
# Port-forward Jaeger query service
kubectl port-forward -n observability svc/jaeger-query 16686:16686

# Open browser to http://localhost:16686
```

**Custom span tags:**
- environment: production
- cluster_name: kubernetes-security-cluster
- pod_name: from environment
- namespace: from environment

### Observability Dashboards

**Grafana Dashboards:**
1. Istio Service Mesh Overview
2. Podinfo Service Metrics
3. Distributed Tracing Dashboard

**Kiali:**
```bash
# Access Kiali UI
kubectl port-forward -n istio-system svc/kiali 20001:20001

# Open browser to http://localhost:20001/kiali
```

**Prometheus Queries:**
```promql
# Request rate by service
sum(rate(istio_requests_total[5m])) by (destination_service_name)

# P95 latency
histogram_quantile(0.95, sum(rate(istio_request_duration_milliseconds_bucket[5m])) by (le, destination_service_name))

# Error rate
sum(rate(istio_requests_total{response_code=~"5.."}[5m])) / sum(rate(istio_requests_total[5m]))
```

## Security

### Authorization Policies

The mesh implements defense-in-depth with multiple authorization layers:

1. **Default Deny-All**: All traffic denied by default
2. **Health Check Allow**: Health endpoints accessible
3. **Service-to-Service**: Explicit allow rules for service communication
4. **Ingress Gateway**: External traffic through gateway only
5. **Metrics Scraping**: Prometheus access for monitoring

**To add a new service:**
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-myservice
  namespace: mynamespace
spec:
  selector:
    matchLabels:
      app: myservice
  action: ALLOW
  rules:
  - from:
    - source:
        namespaces: ["mynamespace"]
```

### Security Best Practices

1. **Never disable mTLS** in production
2. **Use STRICT mode** for all production workloads
3. **Review authorization policies** regularly
4. **Monitor certificate expiration** alerts
5. **Audit access logs** for security events
6. **Limit egress** to known external services
7. **Use ServiceEntry** for external API access

## Troubleshooting

### Common Issues

#### 1. Pods not receiving sidecars

**Symptoms:** Pods don't have istio-proxy container

**Solutions:**
```bash
# Check namespace label
kubectl get namespace podinfo -o yaml | grep istio-injection

# If missing, add label
kubectl label namespace podinfo istio-injection=enabled

# Restart pods
kubectl rollout restart deployment/podinfo -n podinfo
```

#### 2. mTLS connection failures

**Symptoms:** Services can't communicate, 503 errors

**Solutions:**
```bash
# Check mTLS status
istioctl authn tls-check podinfo-<pod>.podinfo

# Verify PeerAuthentication
kubectl get peerauthentication -A

# Check authorization policies
kubectl get authorizationpolicy -A

# View proxy logs
kubectl logs -n podinfo podinfo-<pod> -c istio-proxy
```

#### 3. High latency after mesh deployment

**Symptoms:** Increased request latency

**Solutions:**
```bash
# Check sidecar resource usage
kubectl top pods -n podinfo --containers

# Increase sidecar resources via annotation:
# sidecar.istio.io/proxyCPU: "500m"
# sidecar.istio.io/proxyMemory: "512Mi"

# Check connection pool settings
kubectl get destinationrule -n podinfo -o yaml
```

#### 4. Traffic routing not working

**Symptoms:** Traffic not splitting as expected

**Solutions:**
```bash
# Verify virtual service configuration
kubectl get virtualservice -n podinfo -o yaml

# Check destination rules
kubectl get destinationrule -n podinfo -o yaml

# Validate configuration
istioctl analyze -n podinfo

# Check routing with test request
kubectl exec -n podinfo deploy/podinfo -c podinfo -- \
  curl -H "X-Canary: true" http://podinfo:9898/
```

#### 5. Control plane issues

**Symptoms:** Istiod not ready, sidecars failing

**Solutions:**
```bash
# Check istiod logs
kubectl logs -n istio-system deployment/istiod

# Verify istiod is running
kubectl get pods -n istio-system

# Check webhook configuration
kubectl get mutatingwebhookconfigurations

# Restart istiod if needed
kubectl rollout restart deployment/istiod -n istio-system
```

### Debug Commands

```bash
# Analyze mesh configuration
istioctl analyze -A

# Check proxy status
istioctl proxy-status

# View proxy configuration
istioctl proxy-config <config-type> <pod-name> -n <namespace>
# config-type: cluster, route, listener, endpoint, secret

# Get detailed metrics
kubectl exec -n podinfo podinfo-<pod> -c istio-proxy -- curl localhost:15000/stats

# View access logs
kubectl logs -n podinfo podinfo-<pod> -c istio-proxy --tail=100

# Debug mode (temporarily)
kubectl exec -n podinfo podinfo-<pod> -c istio-proxy -- \
  curl -X POST localhost:15000/logging?level=debug
```

## Performance Tuning

### Resource Optimization

**Default sidecar resources:**
- CPU request: 100m
- Memory request: 128Mi
- CPU limit: 2000m
- Memory limit: 1024Mi

**For high-throughput services:**
```yaml
annotations:
  sidecar.istio.io/proxyCPU: "500m"
  sidecar.istio.io/proxyMemory: "512Mi"
  sidecar.istio.io/proxyCPULimit: "4000m"
  sidecar.istio.io/proxyMemoryLimit: "2048Mi"
```

### Connection Pool Tuning

**Default settings:**
- Max connections: 100
- Max pending requests: 50
- Max requests per connection: 2

**For high-load scenarios:**
```yaml
spec:
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 200
      http:
        http1MaxPendingRequests: 100
        http2MaxRequests: 200
        maxRequestsPerConnection: 5
```

## Monitoring

### Key Metrics

1. **Request Rate**: `istio_requests_total`
2. **Latency**: `istio_request_duration_milliseconds`
3. **Error Rate**: `istio_requests_total{response_code=~"5.."}`
4. **Connection Pool**: `envoy_cluster_upstream_cx_active`
5. **Circuit Breaker**: `envoy_cluster_upstream_rq_pending_overflow`

### Alerts

Configured alerts (see `04-observability.yaml`):
- High 5xx error rate (>5%)
- High request latency (P99 > 1s)
- Certificate expiring soon (<30 days)
- Pilot push errors
- Control plane unavailable
- High proxy resource usage
- Circuit breaker triggered
- Gateway unhealthy

## Maintenance

### Certificate Rotation

Certificates are automatically rotated by Istio:
- Workload certs rotate every 24h
- Rotation starts at 18h (75% of lifetime)
- No manual intervention required

**To force rotation:**
```bash
# Restart pods to get new certificates
kubectl rollout restart deployment/podinfo -n podinfo
```

### Upgrade Procedure

```bash
# 1. Download new Istio version
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.21.0 sh -

# 2. Check upgrade compatibility
istioctl x precheck

# 3. Upgrade control plane (canary)
istioctl install --set revision=1-21-0

# 4. Label namespace for new revision
kubectl label namespace podinfo istio.io/rev=1-21-0 --overwrite

# 5. Restart workloads
kubectl rollout restart deployment/podinfo -n podinfo

# 6. Verify new version
istioctl proxy-status

# 7. Remove old revision
istioctl uninstall --revision=default
```

### Backup and Recovery

```bash
# Backup Istio configuration
kubectl get istiooperator -n istio-system -o yaml > istio-backup.yaml
kubectl get peerauthentication -A -o yaml > mtls-backup.yaml
kubectl get authorizationpolicy -A -o yaml > authz-backup.yaml
kubectl get virtualservice -A -o yaml > vs-backup.yaml
kubectl get destinationrule -A -o yaml > dr-backup.yaml

# Restore
kubectl apply -f istio-backup.yaml
kubectl apply -f mtls-backup.yaml
kubectl apply -f authz-backup.yaml
kubectl apply -f vs-backup.yaml
kubectl apply -f dr-backup.yaml
```

## References

- [Istio Documentation](https://istio.io/latest/docs/)
- [Istio Security](https://istio.io/latest/docs/concepts/security/)
- [Istio Traffic Management](https://istio.io/latest/docs/concepts/traffic-management/)
- [Istio Observability](https://istio.io/latest/docs/tasks/observability/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [Kiali Documentation](https://kiali.io/docs/)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Istio logs: `kubectl logs -n istio-system deployment/istiod`
3. Run mesh analysis: `istioctl analyze -A`
4. Check proxy status: `istioctl proxy-status`
5. Consult [Istio Discuss](https://discuss.istio.io/)
