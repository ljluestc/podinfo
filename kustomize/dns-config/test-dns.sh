#!/bin/bash
set -euo pipefail

# Comprehensive DNS Testing Script
# Tests all aspects of DNS configuration

echo "=================================================="
echo "DNS Configuration Test Suite"
echo "=================================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

test_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAILED${NC}"
        ((FAILED++))
    fi
    echo ""
}

# Test 1: CoreDNS pods are running
echo "Test 1: CoreDNS Pods Status"
echo "----------------------------"
if kubectl get pods -n kube-system -l k8s-app=kube-dns | grep -q "Running"; then
    kubectl get pods -n kube-system -l k8s-app=kube-dns
    test_result 0
else
    echo "CoreDNS pods are not running"
    test_result 1
fi

# Test 2: External DNS is running
echo "Test 2: External DNS Status"
echo "----------------------------"
if kubectl get pods -n kube-system -l app.kubernetes.io/name=external-dns 2>/dev/null | grep -q "Running"; then
    kubectl get pods -n kube-system -l app.kubernetes.io/name=external-dns
    test_result 0
else
    echo "External DNS pod not found or not running"
    test_result 1
fi

# Test 3: CoreDNS service is accessible
echo "Test 3: CoreDNS Service"
echo "-----------------------"
if kubectl get svc -n kube-system kube-dns &>/dev/null; then
    kubectl get svc -n kube-system kube-dns
    test_result 0
else
    echo "CoreDNS service not found"
    test_result 1
fi

# Test 4: DNS resolution of kubernetes.default
echo "Test 4: Kubernetes DNS Resolution"
echo "----------------------------------"
if kubectl run dns-test-1 --image=busybox:1.28 --rm -i --restart=Never --timeout=30s \
    --command -- nslookup kubernetes.default 2>/dev/null | grep -q "Address"; then
    echo "Successfully resolved kubernetes.default"
    test_result 0
else
    echo "Failed to resolve kubernetes.default"
    test_result 1
fi

# Test 5: External DNS resolution
echo "Test 5: External DNS Resolution"
echo "--------------------------------"
if kubectl run dns-test-2 --image=busybox:1.28 --rm -i --restart=Never --timeout=30s \
    --command -- nslookup google.com 2>/dev/null | grep -q "Address"; then
    echo "Successfully resolved google.com"
    test_result 0
else
    echo "Failed to resolve google.com"
    test_result 1
fi

# Test 6: Service discovery
echo "Test 6: Service Discovery"
echo "-------------------------"
if kubectl get svc podinfo-internal -n default &>/dev/null; then
    if kubectl run dns-test-3 --image=busybox:1.28 --rm -i --restart=Never --timeout=30s \
        --command -- nslookup podinfo-internal.default.svc.cluster.local 2>/dev/null | grep -q "Address"; then
        echo "Successfully resolved podinfo-internal service"
        test_result 0
    else
        echo "Failed to resolve podinfo-internal service"
        test_result 1
    fi
else
    echo "podinfo-internal service not found (skipping)"
    test_result 0
fi

# Test 7: Headless service resolution
echo "Test 7: Headless Service"
echo "------------------------"
if kubectl get svc podinfo-headless -n default &>/dev/null; then
    if kubectl run dns-test-4 --image=busybox:1.28 --rm -i --restart=Never --timeout=30s \
        --command -- nslookup podinfo-headless.default.svc.cluster.local 2>/dev/null | grep -q "Address"; then
        echo "Successfully resolved podinfo-headless service"
        test_result 0
    else
        echo "Failed to resolve podinfo-headless service"
        test_result 1
    fi
else
    echo "podinfo-headless service not found (skipping)"
    test_result 0
fi

# Test 8: CoreDNS metrics endpoint
echo "Test 8: CoreDNS Metrics"
echo "-----------------------"
COREDNS_POD=$(kubectl get pod -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$COREDNS_POD" ]; then
    if kubectl exec -n kube-system "$COREDNS_POD" -- wget -qO- http://localhost:9153/metrics 2>/dev/null | grep -q "coredns_dns_requests_total"; then
        echo "CoreDNS metrics endpoint is accessible"
        test_result 0
    else
        echo "CoreDNS metrics endpoint not accessible"
        test_result 1
    fi
else
    echo "CoreDNS pod not found"
    test_result 1
fi

# Test 9: External DNS metrics
echo "Test 9: External DNS Metrics"
echo "----------------------------"
EXTERNAL_DNS_POD=$(kubectl get pod -n kube-system -l app.kubernetes.io/name=external-dns -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$EXTERNAL_DNS_POD" ]; then
    if kubectl exec -n kube-system "$EXTERNAL_DNS_POD" -- wget -qO- http://localhost:7979/healthz 2>/dev/null | grep -q "OK\|Healthy"; then
        echo "External DNS health endpoint is accessible"
        test_result 0
    else
        # External DNS might not have OK/Healthy in response, check if endpoint responds
        if kubectl exec -n kube-system "$EXTERNAL_DNS_POD" -- wget -qO- http://localhost:7979/metrics 2>/dev/null | grep -q "external_dns"; then
            echo "External DNS metrics endpoint is accessible"
            test_result 0
        else
            echo "External DNS endpoints not accessible"
            test_result 1
        fi
    fi
else
    echo "External DNS pod not found (skipping)"
    test_result 0
fi

# Test 10: DNS cache performance
echo "Test 10: DNS Cache Hit Ratio"
echo "-----------------------------"
if [ -n "$COREDNS_POD" ]; then
    CACHE_METRICS=$(kubectl exec -n kube-system "$COREDNS_POD" -- wget -qO- http://localhost:9153/metrics 2>/dev/null | grep "coredns_cache_hits_total\|coredns_cache_misses_total" | grep -v "^#")
    if [ -n "$CACHE_METRICS" ]; then
        echo "Cache metrics available:"
        echo "$CACHE_METRICS"
        test_result 0
    else
        echo "No cache metrics found (may be new deployment)"
        test_result 0
    fi
else
    echo "CoreDNS pod not found"
    test_result 1
fi

# Test 11: DNS debug tools pod
echo "Test 11: DNS Debug Tools"
echo "------------------------"
if kubectl get pod -n kube-system -l app=dns-debug-tools 2>/dev/null | grep -q "Running"; then
    echo "DNS debug tools pod is running"
    test_result 0
else
    echo "DNS debug tools pod not found or not running"
    test_result 1
fi

# Test 12: ConfigMaps exist
echo "Test 12: DNS ConfigMaps"
echo "-----------------------"
EXPECTED_CMS=("coredns-custom" "coredns-custom-zones" "coredns-split-horizon" "service-discovery-examples")
CM_FOUND=0
CM_TOTAL=${#EXPECTED_CMS[@]}

for cm in "${EXPECTED_CMS[@]}"; do
    if kubectl get configmap -n kube-system "$cm" &>/dev/null 2>&1 || kubectl get configmap -n default "$cm" &>/dev/null 2>&1; then
        ((CM_FOUND++))
    fi
done

echo "Found $CM_FOUND/$CM_TOTAL expected ConfigMaps"
if [ $CM_FOUND -ge 2 ]; then
    test_result 0
else
    test_result 1
fi

# Summary
echo "=================================================="
echo "Test Summary"
echo "=================================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo "Total: $((PASSED + FAILED))"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}Some tests failed. Review the output above.${NC}"
    exit 1
fi
