# DNS and Service Discovery Configuration

This directory contains Kubernetes manifests for configuring DNS and service discovery in the cluster.

## Architecture Overview

### Components

1. **CoreDNS** - Cluster DNS server with custom configurations
2. **External DNS** - Automatic DNS record management
3. **Service Discovery** - Kubernetes-native service discovery mechanisms
4. **Split-Horizon DNS** - Different DNS responses for internal/external clients
5. **DNS Load Balancing** - Traffic distribution via DNS
6. **Monitoring & Troubleshooting** - DNS health monitoring and debugging tools

### DNS Flow

```
┌─────────────┐
│   Client    │
│   (Pod)     │
└──────┬──────┘
       │ DNS Query
       ▼
┌─────────────────────────────────────┐
│          CoreDNS                    │
│  ┌──────────────────────────────┐  │
│  │  Custom Zones & Upstreams    │  │
│  │  - app.local                 │  │
│  │  - db.local                  │  │
│  │  - Custom resolvers          │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  Caching Layer               │  │
│  │  - 30s success cache         │  │
│  │  - 5s denial cache           │  │
│  │  - Prefetch enabled          │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  Split-Horizon Logic         │  │
│  │  - Internal: ClusterIP       │  │
│  │  - External: LoadBalancer IP │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  Load Balancing              │  │
│  │  - Round-robin               │  │
│  │  - Weighted distribution     │  │
│  └──────────────────────────────┘  │
└─────────────────────────────────────┘
       │
       ▼
┌─────────────────┐
│  Service/Pod    │
└─────────────────┘

External Services ◄──► External DNS ◄──► K8s API
                         (Auto-sync)
```

## Files Description

### 1. coredns-custom-configmap.yaml

CoreDNS customization for additional DNS functionality:

- **Custom zones**: app.local, db.local
- **Upstream resolvers**: Google DNS (8.8.8.8), Cloudflare (1.1.1.1)
- **Caching configuration**: Enhanced with prefetch and custom TTLs
- **Performance tuning**: Connection pooling, health checks
- **Custom zone files**: Static DNS records for specific domains

**Key Features:**
- Custom domain support
- Upstream DNS with failover
- DNS caching with 30s TTL for success, 5s for denial
- Prefetch for popular queries
- Response size limiting (1232 bytes)

### 2. external-dns-deployment.yaml

Automatic DNS record creation and synchronization:

- **RBAC**: ServiceAccount, ClusterRole, ClusterRoleBinding
- **Deployment**: External DNS controller
- **Configuration**:
  - Sources: Service, Ingress
  - Provider: CoreDNS (can be changed to AWS, Cloudflare, etc.)
  - Domain filters: podinfo.local, app.local
  - Registry: TXT records for ownership tracking

**Key Features:**
- Automatic DNS record creation from Kubernetes resources
- TXT registry for managing record ownership
- Metrics endpoint for Prometheus
- Health checks and probes
- Security: Non-root user, read-only filesystem

### 3. service-discovery-examples.yaml

Various service discovery patterns:

- **Headless Service**: Direct pod DNS records
  - DNS: `<pod-name>.<service-name>.<namespace>.svc.cluster.local`

- **ClusterIP Service**: Standard load-balanced service
  - DNS: `<service-name>.<namespace>.svc.cluster.local`

- **ExternalName Service**: Map to external DNS
  - Redirects internal DNS to external hostname

- **Topology-Aware Service**: Zone-local routing
  - Routes traffic to pods in same zone first

- **Manual Endpoints**: Custom endpoint management
  - Full control over backend IPs

**DNS Patterns:**
```
# Full FQDN
podinfo-internal.default.svc.cluster.local

# Short names (same namespace)
podinfo-internal

# Cross-namespace
podinfo-internal.production

# Headless service pod
podinfo-0.podinfo-headless.default.svc.cluster.local

# SRV records (port discovery)
_http._tcp.podinfo-internal.default.svc.cluster.local
```

### 4. split-horizon-dns.yaml

Different DNS responses based on query source:

- **Internal Zone**: Returns ClusterIP addresses for internal clients
- **External Zone**: Returns LoadBalancer/public IPs for external clients
- **ACL-based routing**: Different responses based on source IP
- **Zone files**: Separate zone definitions for internal/external

**Use Cases:**
- Internal clients access via ClusterIP (faster, no external hop)
- External clients access via LoadBalancer IP
- Security: Internal services only resolvable from inside cluster
- Cost optimization: Avoid external traffic charges for internal calls

### 5. dns-monitoring.yaml

DNS health monitoring and alerting:

- **ServiceMonitors**: Prometheus scraping for CoreDNS and External DNS
- **PrometheusRules**: Alerts and recording rules
  - HighDNSErrorRate: > 5% error rate
  - CoreDNSDown: CoreDNS unavailable
  - HighDNSLatency: P99 > 1s
  - LowDNSCacheHitRatio: < 80%
  - ExternalDNSSyncFailure: External DNS errors

- **DNS Debug Tools Pod**: Contains network diagnostic tools
  - nslookup, dig, host, curl, tcpdump, etc.

- **Troubleshooting Scripts**:
  - `check-dns-health.sh`: Overall DNS health check
  - `test-dns-resolution.sh`: Comprehensive resolution tests
  - `analyze-dns-performance.sh`: Performance metrics analysis
  - `trace-dns-query.sh`: Detailed query tracing

### 6. dns-load-balancing.yaml

DNS-based load balancing configurations:

- **Round-Robin**: Rotate through multiple IPs
- **Weighted**: Percentage-based traffic distribution
- **Geographic**: Location-based routing (requires GeoIP plugin)
- **Health-Based**: Remove unhealthy endpoints

**Strategies:**
1. Multiple A records with round-robin
2. Weighted records (more IPs = more weight)
3. Low TTL for dynamic balance (60s)
4. Manual endpoints for fine control

**Testing Scripts:**
- `test-dns-lb.sh`: Verify load distribution
- `benchmark-dns-lb.sh`: Performance testing with statistics

## Deployment Instructions

### 1. Apply CoreDNS Customizations

```bash
# Apply custom CoreDNS configuration
kubectl apply -f coredns-custom-configmap.yaml

# Restart CoreDNS to apply changes
kubectl rollout restart -n kube-system deployment/coredns
```

### 2. Deploy External DNS

```bash
# Deploy External DNS
kubectl apply -f external-dns-deployment.yaml

# Verify deployment
kubectl get pods -n kube-system -l app.kubernetes.io/name=external-dns
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns
```

**Note**: For production, update the `--provider` argument to your DNS provider (aws, cloudflare, azure, etc.) and configure appropriate credentials.

### 3. Configure Service Discovery

```bash
# Apply service discovery examples
kubectl apply -f service-discovery-examples.yaml

# Test DNS resolution
kubectl run -it --rm debug --image=busybox:1.28 --restart=Never -- sh
# Inside the pod:
nslookup podinfo-internal
nslookup podinfo-headless
```

### 4. Set Up Split-Horizon DNS

```bash
# Apply split-horizon configuration
kubectl apply -f split-horizon-dns.yaml

# Verify zones are mounted
kubectl get configmap -n kube-system | grep coredns
```

### 5. Enable DNS Monitoring

```bash
# Apply monitoring configuration (requires Prometheus Operator)
kubectl apply -f dns-monitoring.yaml

# Deploy debug tools pod
kubectl get pod -n kube-system -l app=dns-debug-tools

# Run health check
kubectl exec -n kube-system deploy/dns-debug-tools -- /bin/bash -c "$(kubectl get cm -n kube-system dns-troubleshooting-scripts -o jsonpath='{.data.check-dns-health\.sh}')"
```

### 6. Configure DNS Load Balancing

```bash
# Apply load balancing configuration
kubectl apply -f dns-load-balancing.yaml

# Test load balancing
kubectl run -it --rm lb-test --image=busybox:1.28 --restart=Never -- sh
# Inside the pod:
for i in {1..10}; do nslookup lb.podinfo.local; done
```

## Testing and Validation

### 1. Test DNS Resolution

```bash
# Deploy test pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: dns-test
  namespace: default
spec:
  containers:
  - name: test
    image: busybox:1.28
    command: ['sh', '-c', 'sleep 3600']
EOF

# Test internal service discovery
kubectl exec dns-test -- nslookup kubernetes.default
kubectl exec dns-test -- nslookup podinfo-internal.default.svc.cluster.local

# Test external resolution
kubectl exec dns-test -- nslookup google.com

# Test SRV records
kubectl exec dns-test -- nslookup -type=srv _http._tcp.podinfo-internal.default.svc.cluster.local
```

### 2. Verify External DNS

```bash
# Check External DNS logs
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns

# Check for DNS records created
# (depends on DNS provider)

# Test external DNS hostname
kubectl exec dns-test -- nslookup podinfo.app.local
```

### 3. Test Split-Horizon DNS

```bash
# From inside cluster (should get internal IP)
kubectl exec dns-test -- nslookup podinfo.local

# From outside cluster (should get external IP)
# Run from your local machine
nslookup podinfo.local
```

### 4. Validate Service Discovery

```bash
# Test headless service (individual pod DNS)
kubectl exec dns-test -- nslookup podinfo-0.podinfo-headless.default.svc.cluster.local

# Test standard service (load-balanced)
kubectl exec dns-test -- nslookup podinfo-internal.default.svc.cluster.local

# Test short names
kubectl exec dns-test -- nslookup podinfo-internal
```

### 5. Check DNS Performance

```bash
# View CoreDNS metrics
kubectl port-forward -n kube-system svc/kube-dns 9153:9153
curl localhost:9153/metrics | grep coredns_dns

# Check cache hit ratio
kubectl exec -n kube-system deploy/coredns -- wget -qO- http://localhost:9153/metrics | grep coredns_cache
```

## Troubleshooting

### DNS Resolution Failures

```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Verify CoreDNS configuration
kubectl get configmap -n kube-system coredns -o yaml

# Test DNS from debug pod
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash
# Run: nslookup kubernetes.default
```

### External DNS Issues

```bash
# Check External DNS logs
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns -f

# Verify RBAC permissions
kubectl auth can-i get services --as=system:serviceaccount:kube-system:external-dns
kubectl auth can-i get ingresses --as=system:serviceaccount:kube-system:external-dns

# Check External DNS metrics
kubectl port-forward -n kube-system svc/external-dns 7979:7979
curl localhost:7979/metrics
```

### High DNS Latency

```bash
# Check CoreDNS resource usage
kubectl top pod -n kube-system -l k8s-app=kube-dns

# Analyze DNS query latency
kubectl exec -n kube-system deploy/coredns -- wget -qO- http://localhost:9153/metrics | grep coredns_dns_request_duration

# Check cache performance
kubectl exec -n kube-system deploy/coredns -- wget -qO- http://localhost:9153/metrics | grep coredns_cache_hits

# Scale CoreDNS if needed
kubectl scale -n kube-system deployment/coredns --replicas=3
```

### Service Discovery Not Working

```bash
# Verify service exists
kubectl get svc podinfo-internal

# Check endpoints
kubectl get endpoints podinfo-internal

# Verify DNS entry
kubectl run -it --rm debug --image=busybox:1.28 --restart=Never -- nslookup podinfo-internal

# Check kube-proxy
kubectl logs -n kube-system -l k8s-app=kube-proxy
```

### Using Troubleshooting Scripts

```bash
# Run comprehensive DNS health check
kubectl exec -n kube-system deploy/dns-debug-tools -- bash <<'EOF'
$(cat <<'SCRIPT'
#!/bin/bash
echo "DNS Health Check"
nslookup kubernetes.default
nslookup google.com
dig podinfo-internal.default.svc.cluster.local
SCRIPT
)
EOF

# Or copy script to pod and execute
kubectl cp check-dns-health.sh kube-system/dns-debug-tools:/tmp/
kubectl exec -n kube-system deploy/dns-debug-tools -- bash /tmp/check-dns-health.sh
```

## Performance Tuning

### CoreDNS Optimization

1. **Increase cache size and TTL**:
   ```yaml
   cache {
       success 10000 60    # Cache 10k successful queries for 60s
       denial 5000 10      # Cache 5k failures for 10s
       prefetch 10 60m 10% # Prefetch queries in last 60m with >10% frequency
   }
   ```

2. **Tune forward plugin**:
   ```yaml
   forward . 8.8.8.8 8.8.4.4 1.1.1.1 {
       max_concurrent 1000
       policy sequential
       health_check 5s
   }
   ```

3. **Enable connection pooling**:
   ```yaml
   bufsize 1232  # Optimal UDP buffer size
   ```

4. **Scale CoreDNS horizontally**:
   ```bash
   kubectl scale -n kube-system deployment/coredns --replicas=3
   ```

### External DNS Optimization

1. **Adjust sync interval**:
   ```yaml
   --interval=5m  # Increase from 1m to 5m for less frequent updates
   ```

2. **Use filtering**:
   ```yaml
   --domain-filter=example.com  # Only process specific domains
   ```

## Security Considerations

1. **CoreDNS**:
   - Use ACLs to restrict query sources
   - Implement rate limiting
   - Enable DNSSEC validation
   - Use split-horizon to hide internal services

2. **External DNS**:
   - Use least-privilege RBAC
   - Filter domains to prevent unauthorized records
   - Use TXT registry for ownership verification
   - Run as non-root user

3. **Network Policies**:
   ```yaml
   # Restrict access to CoreDNS
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: coredns-policy
     namespace: kube-system
   spec:
     podSelector:
       matchLabels:
         k8s-app: kube-dns
     policyTypes:
     - Ingress
     ingress:
     - from:
       - namespaceSelector: {}
       ports:
       - protocol: UDP
         port: 53
       - protocol: TCP
         port: 53
   ```

## Best Practices

1. **Use appropriate TTLs**:
   - Internal services: 30-60s
   - External services: 300-600s
   - Load-balanced endpoints: 60s

2. **Implement health checks**:
   - Monitor DNS query rates
   - Alert on high error rates
   - Track cache hit ratios

3. **Use headless services for StatefulSets**:
   - Enables direct pod addressing
   - Required for clustered applications

4. **Leverage service discovery patterns**:
   - Use short names within namespace
   - Use FQDNs for cross-namespace
   - Use SRV records for port discovery

5. **Test DNS changes**:
   - Always test in non-production first
   - Use dry-run mode for External DNS
   - Verify with multiple query tools

## Monitoring Metrics

Key metrics to monitor:

- `coredns_dns_requests_total`: Total DNS queries
- `coredns_dns_responses_total`: Total responses by code
- `coredns_dns_request_duration_seconds`: Query latency
- `coredns_cache_hits_total`: Cache hits
- `coredns_cache_misses_total`: Cache misses
- `external_dns_source_errors_total`: External DNS sync errors
- `external_dns_registry_errors_total`: Registry errors

## References

- [CoreDNS Documentation](https://coredns.io/)
- [External DNS Documentation](https://github.com/kubernetes-sigs/external-dns)
- [Kubernetes DNS Specification](https://github.com/kubernetes/dns/blob/master/docs/specification.md)
- [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
