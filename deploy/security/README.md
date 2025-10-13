# Kubernetes Authentication and Authorization Implementation

This directory contains comprehensive authentication and authorization configurations for a secure Kubernetes cluster.

## Overview

This implementation provides:
- **OIDC Authentication**: Federated authentication via Dex
- **Short-lived Service Account Tokens**: Projected tokens with automatic rotation
- **RBAC with Least Privilege**: Role-based access control with minimal permissions
- **Comprehensive Audit Logging**: Complete API access audit trail
- **Webhook Authentication**: External authentication system integration
- **Admission Webhooks**: Policy enforcement via validating and mutating webhooks

## Directory Structure

```
deploy/security/
├── oidc/                    # OIDC authentication configuration
│   ├── dex-deployment.yaml           # Dex OIDC provider
│   ├── apiserver-oidc-config.yaml    # API server OIDC flags
│   └── kubelogin-helper.yaml         # kubectl OIDC login helper
├── rbac/                    # RBAC roles and bindings
│   ├── cluster-roles.yaml            # ClusterRoles for personas
│   ├── namespace-roles.yaml          # Namespace-scoped Roles
│   └── role-bindings.yaml            # RoleBindings and ClusterRoleBindings
├── service-accounts/        # Service account token configuration
│   └── bound-sa-token-config.yaml    # Short-lived token configuration
├── audit/                   # Audit logging configuration
│   ├── audit-policy.yaml             # Comprehensive audit policy
│   └── audit-backend-config.yaml     # Audit backend setup
├── webhooks/                # Webhook configurations
│   ├── webhook-token-auth.yaml       # Webhook authentication
│   └── admission-webhooks.yaml       # Admission webhooks
├── test-auth-authz.sh      # Testing and validation script
└── README.md               # This file
```

## Components

### 1. OIDC Authentication (oidc/)

**Purpose**: Provides federated authentication using OpenID Connect.

**Key Features**:
- Dex as OIDC provider (supports LDAP, SAML, OAuth2)
- Static users for testing (admin, developer, viewer)
- kubelogin integration for kubectl
- Group-based authorization

**Deployment**:
```bash
# Deploy Dex OIDC provider
kubectl apply -f oidc/dex-deployment.yaml

# Configure API server (see apiserver-oidc-config.yaml for instructions)
# This requires editing kube-apiserver manifest
```

**Testing**:
```bash
# Setup kubeconfig for OIDC
kubectl apply -f oidc/kubelogin-helper.yaml
kubectl exec -it -n auth-system deploy/dex -- cat /scripts/setup-kubeconfig.sh | bash
```

### 2. Service Account Tokens (service-accounts/)

**Purpose**: Implements short-lived, bound service account tokens.

**Key Features**:
- Projected service account tokens
- 1-hour token expiration
- Automatic token rotation
- Audience-bound tokens

**Deployment**:
```bash
# Apply configuration
kubectl apply -f service-accounts/bound-sa-token-config.yaml

# Configure API server (see instructions in the file)
# Add flags to kube-apiserver:
# --service-account-issuer=https://kubernetes.default.svc.cluster.local
# --service-account-max-token-expiration=3600s
```

### 3. RBAC Configuration (rbac/)

**Purpose**: Implements role-based access control with least privilege.

**Personas**:
- **Cluster Admin**: Full cluster access
- **Platform Admin**: Cluster management (limited security access)
- **Developer**: Namespace-scoped deployment
- **Operator**: Operational tasks (restart pods, scale)
- **Viewer**: Read-only cluster access
- **Security Auditor**: Security configuration review
- **CI/CD Deployer**: Automated deployment access

**Deployment**:
```bash
# Deploy ClusterRoles
kubectl apply -f rbac/cluster-roles.yaml

# Deploy namespace-specific Roles
kubectl apply -f rbac/namespace-roles.yaml

# Deploy RoleBindings and ClusterRoleBindings
kubectl apply -f rbac/role-bindings.yaml

# Create namespaces if needed
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace production
```

**Permission Testing**:
```bash
# Test viewer permissions
kubectl auth can-i create pods --as=oidc:viewer@example.com
# Expected: no

kubectl auth can-i get pods --as=oidc:viewer@example.com
# Expected: yes

# Test developer permissions
kubectl auth can-i create deployments --as=oidc:developer@example.com -n dev
# Expected: yes

kubectl auth can-i delete secrets --as=oidc:developer@example.com -n dev
# Expected: no
```

### 4. Audit Logging (audit/)

**Purpose**: Comprehensive audit trail of all API access.

**Audit Levels**:
- **None**: No logging
- **Metadata**: Log request metadata only
- **Request**: Log metadata and request body
- **RequestResponse**: Log metadata, request, and response

**Key Policies**:
- All secret access logged
- RBAC changes logged at RequestResponse level
- Pod exec/attach/portforward logged
- Failed requests logged for security analysis

**Deployment**:
```bash
# Apply audit policy
kubectl apply -f audit/audit-policy.yaml

# Configure API server (see audit-backend-config.yaml)
# Add flags to kube-apiserver:
# --audit-policy-file=/etc/kubernetes/audit/audit-policy.yaml
# --audit-log-path=/var/log/kubernetes/audit/audit.log

# Optional: Deploy audit webhook for real-time log shipping
kubectl apply -f audit/audit-backend-config.yaml
```

**Log Analysis**:
```bash
# View audit logs (on control plane node)
sudo tail -f /var/log/kubernetes/audit/audit.log

# Search for specific user activity
sudo cat /var/log/kubernetes/audit/audit.log | jq '. | select(.user.username == "oidc:viewer@example.com")'

# Search for secret access
sudo cat /var/log/kubernetes/audit/audit.log | jq '. | select(.objectRef.resource == "secrets")'
```

### 5. Webhook Authentication (webhooks/)

**Purpose**: Validate bearer tokens using external authentication systems.

**Use Cases**:
- Integration with existing identity providers
- Custom token validation logic
- API key authentication
- Service-to-service authentication

**Deployment**:
```bash
# Deploy webhook authentication service
kubectl apply -f webhooks/webhook-token-auth.yaml

# Generate TLS certificates (see instructions in file)

# Configure API server
# --authentication-token-webhook-config-file=/etc/kubernetes/auth/webhook-config.yaml
```

### 6. Admission Webhooks (webhooks/)

**Purpose**: Policy enforcement via validating and mutating webhooks.

**Validating Webhooks**:
- Pod security policy enforcement
- Image registry validation
- Resource limit requirements
- Secret access control

**Mutating Webhooks**:
- Auto-inject security contexts
- Auto-inject projected service account tokens
- Add security labels
- Set resource defaults

**Deployment**:
```bash
# Deploy webhook services
kubectl apply -f webhooks/admission-webhooks.yaml

# Generate TLS certificates (see instructions)

# Webhooks will automatically intercept pod creation/updates
```

**Testing**:
```bash
# Test validating webhook (should fail without resource limits)
kubectl run test-pod --image=nginx:latest

# Test mutating webhook (should auto-inject security context)
kubectl run test-pod --image=nginx:latest
kubectl get pod test-pod -o yaml | grep -A 5 securityContext
```

## Deployment Order

Follow this order for initial setup:

1. **OIDC Provider** (if using federated auth)
   ```bash
   kubectl apply -f oidc/dex-deployment.yaml
   ```

2. **RBAC Configuration**
   ```bash
   kubectl apply -f rbac/cluster-roles.yaml
   kubectl apply -f rbac/namespace-roles.yaml
   kubectl apply -f rbac/role-bindings.yaml
   ```

3. **Service Account Tokens**
   ```bash
   kubectl apply -f service-accounts/bound-sa-token-config.yaml
   # Configure API server flags
   ```

4. **Audit Logging**
   ```bash
   kubectl apply -f audit/audit-policy.yaml
   kubectl apply -f audit/audit-backend-config.yaml
   # Configure API server flags
   ```

5. **Webhook Authentication** (optional)
   ```bash
   kubectl apply -f webhooks/webhook-token-auth.yaml
   # Configure API server flags
   ```

6. **Admission Webhooks**
   ```bash
   kubectl apply -f webhooks/admission-webhooks.yaml
   ```

## Testing and Validation

Run the comprehensive test script:

```bash
chmod +x test-auth-authz.sh
./test-auth-authz.sh
```

### Manual Testing

**Test OIDC Login**:
```bash
# Setup kubeconfig for OIDC
export DEX_URL=https://dex.example.com
export CLIENT_ID=kubernetes
./oidc/kubelogin-helper.yaml

# Test authentication
kubectl get pods
```

**Test RBAC Permissions**:
```bash
# Test as different users
kubectl auth can-i create pods --as=oidc:developer@example.com -n dev
kubectl auth can-i delete secrets --as=oidc:viewer@example.com
kubectl auth can-i update nodes --as=oidc:operator@example.com
```

**Test Service Account Tokens**:
```bash
# Deploy test pod with projected tokens
kubectl apply -f service-accounts/bound-sa-token-config.yaml

# Verify token expiration
kubectl exec -it <pod-name> -- cat /var/run/secrets/tokens/api-token
kubectl exec -it <pod-name> -- jwt decode /var/run/secrets/tokens/api-token
```

**Test Audit Logging**:
```bash
# Perform some API operations
kubectl create deployment test --image=nginx
kubectl delete deployment test

# Check audit logs
sudo tail -f /var/log/kubernetes/audit/audit.log | jq .
```

**Test Admission Webhooks**:
```bash
# Try to create pod without resource limits (should fail)
kubectl run test --image=nginx

# Try to use untrusted image registry (should fail)
kubectl run test --image=docker.io/nginx
```

## Security Best Practices

### 1. Regular Audits
- Review audit logs daily
- Monitor failed authentication attempts
- Review RBAC changes

### 2. Least Privilege
- Grant minimum necessary permissions
- Use namespace-scoped roles when possible
- Regularly review and prune unused permissions

### 3. Token Management
- Use short-lived tokens (1 hour max)
- Rotate service account keys regularly
- Disable legacy service account tokens

### 4. Emergency Access
- Keep emergency break-glass access empty
- Document emergency access procedures
- Audit all emergency access usage

### 5. Certificate Management
- Rotate certificates regularly (90 days)
- Use automated certificate management (cert-manager)
- Monitor certificate expiration

## Troubleshooting

### OIDC Login Fails
```bash
# Check Dex pods
kubectl get pods -n auth-system -l app=dex

# Check Dex logs
kubectl logs -n auth-system -l app=dex

# Verify API server OIDC configuration
kubectl -n kube-system get pod -l component=kube-apiserver -o yaml | grep oidc
```

### RBAC Permission Denied
```bash
# Check user's effective permissions
kubectl auth can-i --list --as=oidc:user@example.com

# Check role bindings for user
kubectl get rolebindings,clusterrolebindings --all-namespaces -o json | \
  jq '.items[] | select(.subjects[]?.name == "oidc:user@example.com")'
```

### Admission Webhook Blocking Requests
```bash
# Check webhook status
kubectl get validatingwebhookconfiguration
kubectl get mutatingwebhookconfiguration

# Check webhook pod logs
kubectl logs -n auth-system -l app=validating-webhook

# Temporarily disable webhook (emergency only)
kubectl delete validatingwebhookconfiguration security-policy-validator
```

### Audit Logs Not Appearing
```bash
# Verify API server configuration
ps aux | grep kube-apiserver | grep audit

# Check audit log file permissions
sudo ls -la /var/log/kubernetes/audit/

# Verify audit policy is loaded
sudo cat /etc/kubernetes/audit/audit-policy.yaml
```

## References

- [Kubernetes Authentication](https://kubernetes.io/docs/reference/access-authn-authz/authentication/)
- [Kubernetes Authorization](https://kubernetes.io/docs/reference/access-authn-authz/authorization/)
- [RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Audit Logging](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)
- [Admission Controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)
- [Dex OIDC Provider](https://dexidp.io/)

## Support

For issues or questions:
1. Check troubleshooting section
2. Review audit logs
3. Verify component status
4. Check API server logs

## License

This configuration is part of the podinfo security implementation.
