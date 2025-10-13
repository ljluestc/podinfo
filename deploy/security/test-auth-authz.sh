#!/bin/bash
# Comprehensive Authentication and Authorization Testing Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
PASSED=0
FAILED=0
TOTAL=0

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

test_passed() {
    ((PASSED++))
    ((TOTAL++))
    log_info "✓ $1"
}

test_failed() {
    ((FAILED++))
    ((TOTAL++))
    log_error "✗ $1"
}

# Test 1: OIDC Provider Accessibility
test_oidc_provider() {
    log_info "Testing OIDC Provider..."

    if kubectl get deployment dex -n auth-system &> /dev/null; then
        test_passed "Dex deployment exists"
    else
        test_failed "Dex deployment not found"
        return
    fi

    if kubectl get pods -n auth-system -l app=dex | grep -q "Running"; then
        test_passed "Dex pods are running"
    else
        test_failed "Dex pods are not running"
    fi

    # Check Dex service
    if kubectl get svc dex -n auth-system &> /dev/null; then
        test_passed "Dex service exists"
    else
        test_failed "Dex service not found"
    fi
}

# Test 2: Service Account Token Configuration
test_service_account_tokens() {
    log_info "Testing Service Account Token Configuration..."

    # Check if projected tokens are configured
    POD_NAME=$(kubectl get pods -n default -o name | head -1 | cut -d'/' -f2)

    if [ -n "$POD_NAME" ]; then
        TOKEN_PATH=$(kubectl get pod "$POD_NAME" -n default -o jsonpath='{.spec.volumes[?(@.projected.sources[0].serviceAccountToken)].projected.sources[0].serviceAccountToken.path}')

        if [ -n "$TOKEN_PATH" ]; then
            test_passed "Projected service account tokens are configured"
        else
            test_warning "No projected tokens found - may be using legacy tokens"
        fi
    else
        log_warning "No pods found to test token projection"
    fi
}

# Test 3: RBAC Roles Existence
test_rbac_roles() {
    log_info "Testing RBAC Roles..."

    # Check ClusterRoles
    EXPECTED_ROLES=(
        "platform-admin"
        "developer"
        "developer-readonly"
        "operator"
        "viewer"
        "security-auditor"
        "monitoring"
        "cicd-deployer"
    )

    for role in "${EXPECTED_ROLES[@]}"; do
        if kubectl get clusterrole "$role" &> /dev/null; then
            test_passed "ClusterRole '$role' exists"
        else
            test_failed "ClusterRole '$role' not found"
        fi
    done
}

# Test 4: RBAC Bindings
test_rbac_bindings() {
    log_info "Testing RBAC Bindings..."

    # Check ClusterRoleBindings
    EXPECTED_BINDINGS=(
        "platform-admins"
        "developers-readonly"
        "viewers"
        "operators"
        "security-auditors"
    )

    for binding in "${EXPECTED_BINDINGS[@]}"; do
        if kubectl get clusterrolebinding "$binding" &> /dev/null; then
            test_passed "ClusterRoleBinding '$binding' exists"
        else
            test_failed "ClusterRoleBinding '$binding' not found"
        fi
    done
}

# Test 5: RBAC Permission Testing
test_rbac_permissions() {
    log_info "Testing RBAC Permissions..."

    # Test viewer role (should not be able to create pods)
    if kubectl auth can-i create pods --as=oidc:viewer@example.com 2>&1 | grep -q "no"; then
        test_passed "Viewer cannot create pods (least privilege working)"
    else
        test_failed "Viewer can create pods (least privilege NOT working)"
    fi

    # Test viewer role (should be able to get pods)
    if kubectl auth can-i get pods --as=oidc:viewer@example.com 2>&1 | grep -q "yes"; then
        test_passed "Viewer can get pods (read access working)"
    else
        test_failed "Viewer cannot get pods (read access NOT working)"
    fi

    # Test developer role (should be able to create deployments)
    if kubectl auth can-i create deployments --as=oidc:developer@example.com -n dev 2>&1 | grep -q "yes"; then
        test_passed "Developer can create deployments in dev namespace"
    else
        test_failed "Developer cannot create deployments in dev namespace"
    fi

    # Test developer cannot access secrets
    if kubectl auth can-i create secrets --as=oidc:developer@example.com -n dev 2>&1 | grep -q "no"; then
        test_passed "Developer cannot create secrets (least privilege working)"
    else
        test_failed "Developer can create secrets (least privilege NOT working)"
    fi
}

# Test 6: Audit Logging Configuration
test_audit_logging() {
    log_info "Testing Audit Logging Configuration..."

    # Check if audit policy configmap exists
    if kubectl get configmap audit-backend-config -n kube-system &> /dev/null; then
        test_passed "Audit backend configuration exists"
    else
        test_failed "Audit backend configuration not found"
    fi

    # Check if audit webhook service exists
    if kubectl get svc audit-webhook-service -n kube-system &> /dev/null; then
        test_passed "Audit webhook service exists"
    else
        test_warning "Audit webhook service not found (optional)"
    fi

    # Try to detect audit logging on API server
    # This requires access to control plane nodes
    log_warning "Audit log verification requires control plane access - checking config only"
}

# Test 7: Webhook Authentication
test_webhook_authentication() {
    log_info "Testing Webhook Authentication..."

    # Check webhook token auth deployment
    if kubectl get deployment webhook-token-auth -n auth-system &> /dev/null; then
        test_passed "Webhook token auth deployment exists"

        if kubectl get pods -n auth-system -l app=webhook-token-auth | grep -q "Running"; then
            test_passed "Webhook token auth pods are running"
        else
            test_failed "Webhook token auth pods are not running"
        fi
    else
        test_warning "Webhook token auth not deployed (optional)"
    fi
}

# Test 8: Admission Webhooks
test_admission_webhooks() {
    log_info "Testing Admission Webhooks..."

    # Check ValidatingWebhookConfiguration
    if kubectl get validatingwebhookconfiguration security-policy-validator &> /dev/null; then
        test_passed "Validating webhook configuration exists"
    else
        test_failed "Validating webhook configuration not found"
    fi

    # Check MutatingWebhookConfiguration
    if kubectl get mutatingwebhookconfiguration security-policy-mutator &> /dev/null; then
        test_passed "Mutating webhook configuration exists"
    else
        test_failed "Mutating webhook configuration not found"
    fi

    # Check webhook deployments
    if kubectl get deployment validating-webhook -n auth-system &> /dev/null; then
        test_passed "Validating webhook deployment exists"
    else
        test_warning "Validating webhook deployment not found"
    fi

    if kubectl get deployment mutating-webhook -n auth-system &> /dev/null; then
        test_passed "Mutating webhook deployment exists"
    else
        test_warning "Mutating webhook deployment not found"
    fi
}

# Test 9: Namespace Isolation
test_namespace_isolation() {
    log_info "Testing Namespace Isolation..."

    # Check if dev namespace exists
    if kubectl get namespace dev &> /dev/null; then
        test_passed "Dev namespace exists"
    else
        test_warning "Dev namespace not found"
    fi

    # Check if staging namespace exists
    if kubectl get namespace staging &> /dev/null; then
        test_passed "Staging namespace exists"
    else
        test_warning "Staging namespace not found"
    fi

    # Check if production namespace exists
    if kubectl get namespace production &> /dev/null; then
        test_passed "Production namespace exists"
    else
        test_warning "Production namespace not found"
    fi
}

# Test 10: Security Context Defaults
test_security_contexts() {
    log_info "Testing Security Contexts..."

    # Check a sample pod for security context
    POD_NAME=$(kubectl get pods -n default -o name | head -1)

    if [ -n "$POD_NAME" ]; then
        RUN_AS_NON_ROOT=$(kubectl get "$POD_NAME" -n default -o jsonpath='{.spec.securityContext.runAsNonRoot}')

        if [ "$RUN_AS_NON_ROOT" = "true" ]; then
            test_passed "Pods are configured to run as non-root"
        else
            test_warning "Some pods may be running as root"
        fi
    fi
}

# Test 11: Certificate Rotation
test_certificate_management() {
    log_info "Testing Certificate Management..."

    # Check if cert-manager is installed (common for certificate management)
    if kubectl get namespace cert-manager &> /dev/null; then
        test_passed "Cert-manager namespace exists"
    else
        test_warning "Cert-manager not found - manual certificate management may be required"
    fi
}

# Test 12: Emergency Access
test_emergency_access() {
    log_info "Testing Emergency Access Configuration..."

    # Check emergency admin cluster role binding
    if kubectl get clusterrolebinding emergency-admin-binding &> /dev/null; then
        # Check if it has no subjects (should be empty until emergency)
        SUBJECTS=$(kubectl get clusterrolebinding emergency-admin-binding -o jsonpath='{.subjects}')

        if [ "$SUBJECTS" = "[]" ] || [ -z "$SUBJECTS" ]; then
            test_passed "Emergency admin binding exists and is empty (correct)"
        else
            test_warning "Emergency admin binding has active subjects - review needed"
        fi
    else
        test_failed "Emergency admin binding not found"
    fi
}

# Main execution
main() {
    echo "======================================"
    echo "Authentication & Authorization Tests"
    echo "======================================"
    echo ""

    test_oidc_provider
    echo ""

    test_service_account_tokens
    echo ""

    test_rbac_roles
    echo ""

    test_rbac_bindings
    echo ""

    test_rbac_permissions
    echo ""

    test_audit_logging
    echo ""

    test_webhook_authentication
    echo ""

    test_admission_webhooks
    echo ""

    test_namespace_isolation
    echo ""

    test_security_contexts
    echo ""

    test_certificate_management
    echo ""

    test_emergency_access
    echo ""

    # Summary
    echo "======================================"
    echo "Test Summary"
    echo "======================================"
    echo "Total Tests: $TOTAL"
    echo -e "${GREEN}Passed: $PASSED${NC}"
    echo -e "${RED}Failed: $FAILED${NC}"
    echo ""

    if [ $FAILED -eq 0 ]; then
        log_info "All tests passed! ✓"
        exit 0
    else
        log_error "Some tests failed. Please review the output above."
        exit 1
    fi
}

# Run tests
main
