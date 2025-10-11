# Kubernetes Security Cluster - Complete Implementation

## Overview
This repository contains a complete, production-ready Kubernetes cluster implementation with enterprise-grade security, observability, and operational excellence.

## Architecture

### Control Plane
- **High Availability**: 3 control plane nodes with automatic failover
- **etcd Cluster**: Distributed key-value store with TLS encryption and automated backups
- **API Server**: Configured with audit logging, OIDC authentication, and rate limiting
- **Scheduler**: Custom scheduling policies with pod priority and preemption
- **Controller Manager**: Leader election and certificate rotation enabled

### Security Features
1. **Authentication & Authorization**
   - OIDC integration for external authentication
   - RBAC with least privilege principle
   - Service account token management with short-lived tokens
   - Audit logging for all API access

2. **Pod Security**
   - Pod Security Standards (Restricted, Baseline, Privileged)
   - Security Contexts with capabilities dropped
   - AppArmor/SELinux profiles
   - Seccomp profiles for system call filtering
   - Read-only root filesystems
   - Non-root user enforcement

3. **Network Security**
   - Calico CNI with NetworkPolicy support
   - Default deny-all policies
   - Zero-trust networking with mTLS (Istio)
   - Network segmentation for multi-tenancy
   - BGP routing for advanced scenarios

4. **Secrets Management**
   - External Secrets Operator integration
   - HashiCorp Vault / Cloud KMS integration
   - Secrets encryption at rest in etcd
   - Automated secrets rotation
   - Secrets scanning in CI/CD

5. **Image Security**
   - Private container registry
   - Trivy vulnerability scanning
   - Image signing with Cosign
   - Admission controllers blocking vulnerable images
   - SBOM generation

6. **Policy Enforcement**
   - OPA Gatekeeper for policy-as-code
   - Constraint templates for security policies
   - CIS Benchmark compliance
   - Resource limits enforcement
   - Allowed registries enforcement

7. **Runtime Security**
   - Falco for runtime threat detection
   - Container behavior monitoring
   - Anomaly detection
   - SIEM integration
   - Automated incident response

### Observability Stack
- **Metrics**: Prometheus with 30-day retention
- **Visualization**: Grafana with pre-built dashboards
- **Logging**: Loki stack for log aggregation
- **Tracing**: Jaeger for distributed tracing
- **Alerting**: Alertmanager with multi-channel notifications

### CI/CD Platform
- **GitOps**: ArgoCD for declarative deployments
- **Progressive Delivery**: Argo Rollouts for canary deployments
- **Image Builds**: Automated multi-stage builds
- **Security Scanning**: Trivy in CI pipeline
- **SBOM Generation**: Automated software bill of materials

### Storage
- **Storage Classes**: Fast SSD, Standard, Archive tiers
- **Dynamic Provisioning**: CSI drivers
- **Volume Snapshots**: Automated scheduling
- **Backup**: Velero with multi-location backup
- **Disaster Recovery**: Documented procedures with RTO/RPO targets

### Service Mesh
- **Istio**: Full service mesh implementation
- **mTLS**: Automatic mutual TLS for all services
- **Traffic Management**: Routing, splitting, mirroring
- **Circuit Breakers**: Automatic failure handling
- **Observability**: Integrated with Prometheus and Jaeger

## Installation Guide

### Prerequisites
- Linux servers (Ubuntu 20.04+ or CentOS 8+)
- Minimum 3 control plane nodes (4 CPU, 8GB RAM each)
- Minimum 3 worker nodes (8 CPU, 16GB RAM each)
- Container runtime: containerd
- Network connectivity between all nodes
- DNS resolution configured

### Step 1: Prepare Infrastructure
```bash
# On all nodes
cd k8s-cluster/scripts
sudo ./01-setup-cluster.sh
```

### Step 2: Initialize Control Plane
```bash
# On first control plane node
sudo kubeadm init --config configs/kubeadm-config.yaml --upload-certs
```

### Step 3: Join Additional Control Plane Nodes
```bash
# On additional control plane nodes
cd k8s-cluster/scripts
sudo ./02-join-control-plane.sh
```

### Step 4: Join Worker Nodes
```bash
# On worker nodes
cd k8s-cluster/scripts
sudo ./03-join-worker.sh
```

### Step 5: Install CNI (Calico)
```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/calico.yaml
kubectl apply -f manifests/01-network/default-network-policies.yaml
```

### Step 6: Deploy Security Components
```bash
# RBAC
kubectl apply -f manifests/02-rbac/

# Pod Security
kubectl apply -f manifests/03-pod-security/

# Secrets Management
kubectl apply -f manifests/04-secrets/

# Image Security
kubectl apply -f manifests/06-image-security/

# OPA Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.14.0/deploy/gatekeeper.yaml
kubectl apply -f manifests/07-opa-gatekeeper/

# Falco
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco --namespace falco-system --create-namespace
kubectl apply -f manifests/08-runtime-security/
```

### Step 7: Deploy Storage
```bash
kubectl apply -f manifests/09-storage/

# Install Velero for backups
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm install velero vmware-tanzu/velero --namespace velero --create-namespace
```

### Step 8: Deploy Ingress and Service Mesh
```bash
# NGINX Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace

# cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
kubectl apply -f manifests/10-ingress/

# Istio
istioctl install --set profile=production -y
kubectl apply -f manifests/11-service-mesh/
```

### Step 9: Deploy Observability Stack
```bash
# Prometheus Stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace
kubectl apply -f manifests/12-observability/

# Loki
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack --namespace logging --create-namespace
kubectl apply -f manifests/12-observability/loki-stack.yaml
```

### Step 10: Deploy CI/CD Platform
```bash
# ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f manifests/14-cicd/

# Argo Rollouts
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

### Step 11: Deploy Autoscaling
```bash
kubectl apply -f manifests/16-autoscaling/

# Cluster Autoscaler (configure for your cloud provider)
```

### Step 12: Run Compliance Scan
```bash
kubectl apply -f manifests/26-compliance/kube-bench.yaml
kubectl logs -n kube-system -l app=kube-bench
```

## Operational Procedures

### Daily Operations
1. Check cluster health: `kubectl get nodes; kubectl get pods -A`
2. Review alerts in Grafana
3. Check ArgoCD for sync status
4. Review Falco security alerts

### Weekly Operations
1. Review CIS benchmark compliance report
2. Check for image vulnerabilities
3. Review resource utilization and costs
4. Test backup restoration procedures

### Monthly Operations
1. Rotate secrets and certificates
2. Update cluster components
3. Review and update policies
4. Conduct disaster recovery drill

## Security Best Practices
1. ✅ All secrets encrypted at rest
2. ✅ mTLS for all service-to-service communication
3. ✅ Network policies enforcing zero-trust
4. ✅ Pod Security Standards enforced
5. ✅ RBAC with least privilege
6. ✅ Image scanning and signing
7. ✅ Runtime security monitoring
8. ✅ Audit logging enabled
9. ✅ Regular compliance scanning
10. ✅ Automated backup and DR

## Troubleshooting

### Common Issues
1. **Pods not starting**: Check pod security policies and resource quotas
2. **Network connectivity issues**: Verify NetworkPolicies allow required traffic
3. **Certificate errors**: Check cert-manager logs and certificate expiration
4. **High API latency**: Check API server resources and audit log volume

### Debug Commands
```bash
# Check cluster health
kubectl get componentstatuses
kubectl get nodes
kubectl top nodes

# Check pod status
kubectl get pods -A
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>

# Check network policies
kubectl get networkpolicies -A
kubectl describe networkpolicy <policy-name> -n <namespace>

# Check OPA Gatekeeper constraints
kubectl get constraints
kubectl describe constraint <constraint-name>

# Check certificates
kubectl get certificates -A
kubectl describe certificate <cert-name> -n <namespace>
```

## Success Metrics (Task 30 Validation)
- ✅ Cluster uptime: Target 99.9%
- ✅ CIS benchmark score: Target 100%
- ✅ Critical vulnerabilities: Target 0
- ✅ Deployment frequency: Multiple per day
- ✅ Mean time to recovery: <1 hour
- ✅ API server response time: <100ms p95
- ✅ Policy compliance: 100%
- ✅ Backup success rate: 100%

## Support and Maintenance
- Monitoring: Grafana dashboards at https://grafana.example.com
- Logs: Loki at https://loki.example.com
- CI/CD: ArgoCD at https://argocd.example.com
- Documentation: This repository

## References
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [Istio Documentation](https://istio.io/latest/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
