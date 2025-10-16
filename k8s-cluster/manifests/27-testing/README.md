# Comprehensive Testing Framework

This directory contains a complete testing framework for Kubernetes cluster validation, security testing, performance benchmarking, and continuous validation.

## Table of Contents

1. [Overview](#overview)
2. [Testing Categories](#testing-categories)
3. [Quick Start](#quick-start)
4. [Testing Schedule](#testing-schedule)
5. [Test Execution](#test-execution)
6. [CI/CD Integration](#cicd-integration)
7. [Troubleshooting](#troubleshooting)

## Overview

The testing framework includes:

- **Conformance Testing**: Kubernetes conformance with Sonobuoy
- **Chaos Engineering**: Fault injection with Chaos Mesh
- **Load Testing**: Performance testing with k6 and Locust
- **Security Testing**: Vulnerability scanning with kube-bench, kube-hunter, and Trivy
- **Disaster Recovery**: Backup/restore and failover testing
- **Integration Testing**: Smoke tests and E2E tests
- **Continuous Validation**: Policy and configuration validation
- **Regression Testing**: Automated regression test suite

## Testing Categories

### 1. Conformance Testing

**Location**: `01-conformance-testing.yaml`

Tests Kubernetes cluster conformance against CNCF standards using Sonobuoy.

**Run manually**:
```bash
# Quick conformance test
kubectl apply -f 01-conformance-testing.yaml

# Or using Sonobuoy CLI
sonobuoy run --mode=quick --wait
sonobuoy status
sonobuoy retrieve
```

**Scheduled**: Weekly on Sunday at 2 AM

### 2. Chaos Engineering

**Location**: `chaos-mesh/`

Tests cluster resilience with Chaos Mesh experiments:

- Pod failures and kills
- Network delays, loss, and partitions
- CPU and memory stress
- I/O performance degradation

**Install Chaos Mesh**:
```bash
# Add Helm repo
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm repo update

# Install using custom values
kubectl apply -f chaos-mesh/01-namespace.yaml
kubectl apply -f chaos-mesh/02-helm-install.yaml

# Install with Helm
helm install chaos-mesh chaos-mesh/chaos-mesh \
  --namespace=chaos-testing \
  --values=chaos-mesh/02-helm-install.yaml
```

**Run chaos experiments**:
```bash
# Deploy chaos experiments
kubectl apply -f chaos-mesh/03-pod-chaos.yaml
kubectl apply -f chaos-mesh/04-network-chaos.yaml
kubectl apply -f chaos-mesh/05-stress-chaos.yaml
kubectl apply -f chaos-mesh/06-io-chaos.yaml

# View Chaos Dashboard
kubectl port-forward -n chaos-testing svc/chaos-dashboard 2333:2333
# Access at http://localhost:2333
```

### 3. Load Testing

**Location**: `load-testing/`

Performance testing with k6 and Locust.

**k6 Load Testing**:
```bash
# Deploy k6 tests
kubectl apply -f load-testing/01-namespace.yaml
kubectl apply -f load-testing/02-k6-tests.yaml

# Run basic load test
kubectl create job --from=cronjob/k6-scheduled-load-test k6-manual-test -n load-testing

# View results
kubectl logs -n load-testing job/k6-manual-test
```

**Locust Load Testing**:
```bash
# Deploy Locust
kubectl apply -f load-testing/03-locust-tests.yaml

# Access Locust UI
kubectl port-forward -n load-testing svc/locust-master 8089:8089
# Access at http://localhost:8089
```

**Scheduled**: Daily at 4 AM

### 4. Security Testing

**Location**: `security-testing/`

Comprehensive security scanning with multiple tools.

**kube-bench (CIS Benchmarks)**:
```bash
# Deploy kube-bench
kubectl apply -f security-testing/01-namespace.yaml
kubectl apply -f security-testing/02-kube-bench.yaml

# Run scan
kubectl create job --from=cronjob/kube-bench-scheduled kube-bench-manual -n security-testing

# View results
kubectl logs -n security-testing job/kube-bench-manual
```

**kube-hunter (Penetration Testing)**:
```bash
# Deploy kube-hunter
kubectl apply -f security-testing/03-kube-hunter.yaml

# Run internal scan
kubectl create job --from=cronjob/kube-hunter-scheduled kube-hunter-manual -n security-testing

# View results
kubectl logs -n security-testing job/kube-hunter-manual
```

**Trivy (Vulnerability Scanning)**:
```bash
# Deploy Trivy
kubectl apply -f security-testing/04-trivy-scanner.yaml

# Run cluster scan
kubectl create job --from=cronjob/trivy-scheduled-scan trivy-manual -n security-testing

# View results
kubectl logs -n security-testing job/trivy-manual
```

**Scheduled**:
- kube-bench: Weekly on Monday at 3 AM
- kube-hunter: Weekly on Monday at 2 AM
- Trivy: Daily at 1 AM

### 5. Disaster Recovery Testing

**Location**: `dr-testing/`

Tests backup, restore, and failover procedures.

**Run DR tests**:
```bash
# Deploy DR testing framework
kubectl apply -f dr-testing/01-backup-restore-tests.yaml

# Run full DR test suite
kubectl create job --from=job/dr-full-test dr-test-$(date +%s) -n dr-testing

# View results
kubectl logs -n dr-testing job/dr-test-*
```

**Scheduled**: Weekly on Sunday at 5 AM

### 6. Integration Testing

**Location**: `integration-tests/`

Smoke tests and E2E tests for cluster and application functionality.

**Run smoke tests**:
```bash
# Deploy smoke tests
kubectl apply -f integration-tests/01-smoke-tests.yaml

# Run cluster smoke tests
kubectl create job --from=job/cluster-smoke-test cluster-test-$(date +%s) -n integration-testing

# Run application smoke tests
kubectl create job --from=job/app-smoke-test app-test-$(date +%s) -n integration-testing
```

**Run E2E tests**:
```bash
# Deploy E2E tests
kubectl apply -f integration-tests/02-e2e-tests.yaml

# Run E2E test suite
kubectl create job --from=job/e2e-test e2e-test-$(date +%s) -n integration-testing
```

**Scheduled**:
- Smoke tests: Every 30 minutes
- E2E tests: Every 6 hours

### 7. Continuous Validation

**Location**: `validation/`

Continuous validation of configurations, policies, and security standards.

**Deploy validation**:
```bash
kubectl apply -f validation/01-config-validation.yaml
```

**Run validation manually**:
```bash
# Manifest validation
kubectl create job --from=cronjob/validate-manifests manifest-check -n validation-testing

# Policy validation
kubectl create job --from=cronjob/validate-policies policy-check -n validation-testing

# Security validation
kubectl create job --from=cronjob/validate-security security-check -n validation-testing
```

**Scheduled**:
- Manifest validation: Every 4 hours
- Policy validation: Every 15 minutes
- Security validation: Every 6 hours

### 8. Regression Testing

**Location**: `regression/`

Automated regression test suite for cluster functionality.

**Run regression tests**:
```bash
# Deploy regression tests
kubectl apply -f regression/01-regression-tests.yaml

# Run regression suite
kubectl create job --from=job/regression-test-manual regression-$(date +%s) -n regression-testing

# View results
kubectl logs -n regression-testing job/regression-*
```

**Scheduled**: Daily at 6 AM

## Quick Start

### Deploy All Testing Components

```bash
#!/bin/bash

# Navigate to testing directory
cd k8s-cluster/manifests/27-testing

# Deploy conformance testing
kubectl apply -f 01-conformance-testing.yaml

# Deploy chaos mesh (requires Helm installation separately)
kubectl apply -f chaos-mesh/01-namespace.yaml

# Deploy load testing
kubectl apply -f load-testing/

# Deploy security testing
kubectl apply -f security-testing/

# Deploy DR testing
kubectl apply -f dr-testing/

# Deploy integration testing
kubectl apply -f integration-tests/

# Deploy validation
kubectl apply -f validation/

# Deploy regression testing
kubectl apply -f regression/

echo "All testing components deployed!"
```

### Run Quick Test Suite

```bash
#!/bin/bash

# Run smoke tests
kubectl create job --from=job/cluster-smoke-test quick-smoke -n integration-testing
kubectl wait --for=condition=complete job/quick-smoke -n integration-testing --timeout=300s

# Run basic security scan
kubectl create job --from=job/kube-bench-node quick-bench -n security-testing
kubectl wait --for=condition=complete job/quick-bench -n security-testing --timeout=300s

# Run regression tests
kubectl create job --from=job/regression-test-manual quick-regression -n regression-testing
kubectl wait --for=condition=complete job/quick-regression -n regression-testing --timeout=300s

echo "Quick test suite completed!"
```

## Testing Schedule

| Test Type | Frequency | Schedule | Duration |
|-----------|-----------|----------|----------|
| Smoke Tests | Every 30 min | */30 * * * * | ~2 min |
| Policy Validation | Every 15 min | */15 * * * * | ~1 min |
| Trivy Scan | Daily | 0 1 * * * | ~15 min |
| kube-hunter | Weekly (Mon) | 0 2 * * 1 | ~10 min |
| kube-bench | Weekly (Mon) | 0 3 * * 1 | ~5 min |
| Load Tests | Daily | 0 4 * * * | ~30 min |
| DR Tests | Weekly (Sun) | 0 5 * * 0 | ~20 min |
| Regression Tests | Daily | 0 6 * * * | ~10 min |
| E2E Tests | Every 6 hours | 0 */6 * * * | ~15 min |
| Conformance | Weekly (Sun) | 0 2 * * 0 | ~60 min |

## Test Execution

### Master Test Script

Create `run-all-tests.sh`:

```bash
#!/bin/bash
set -e

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="./test-results-$TIMESTAMP"
mkdir -p "$RESULTS_DIR"

echo "=== Comprehensive Testing Suite ==="
echo "Timestamp: $TIMESTAMP"
echo "Results directory: $RESULTS_DIR"
echo ""

# Function to run test and capture results
run_test() {
  TEST_NAME=$1
  TEST_NAMESPACE=$2
  TEST_JOB=$3

  echo "Running: $TEST_NAME"
  kubectl create job --from=$TEST_JOB test-$RANDOM -n $TEST_NAMESPACE
  kubectl wait --for=condition=complete job/test-* -n $TEST_NAMESPACE --timeout=600s
  kubectl logs -n $TEST_NAMESPACE job/test-* > "$RESULTS_DIR/$TEST_NAME.log"
  kubectl delete job/test-* -n $TEST_NAMESPACE
  echo "✓ $TEST_NAME completed"
}

# Run all tests
run_test "smoke-tests" "integration-testing" "job/cluster-smoke-test"
run_test "security-kube-bench" "security-testing" "job/kube-bench-node"
run_test "security-kube-hunter" "security-testing" "job/kube-hunter-internal"
run_test "regression-suite" "regression-testing" "job/regression-test-manual"
run_test "e2e-tests" "integration-testing" "job/e2e-test"

echo ""
echo "=== Test Suite Complete ==="
echo "Results saved to: $RESULTS_DIR"
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Cluster Testing

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Configure kubectl
        run: |
          echo "${{ secrets.KUBECONFIG }}" > kubeconfig
          export KUBECONFIG=kubeconfig

      - name: Run smoke tests
        run: |
          kubectl create job --from=job/cluster-smoke-test smoke-ci -n integration-testing
          kubectl wait --for=condition=complete job/smoke-ci -n integration-testing --timeout=300s
          kubectl logs -n integration-testing job/smoke-ci

      - name: Run security scan
        run: |
          kubectl create job --from=job/kube-bench-node bench-ci -n security-testing
          kubectl wait --for=condition=complete job/bench-ci -n security-testing --timeout=300s
          kubectl logs -n security-testing job/bench-ci
```

## Troubleshooting

### Common Issues

**Issue**: Tests fail with timeout
**Solution**: Increase timeout values in job specifications or check cluster resources

**Issue**: Chaos experiments breaking cluster
**Solution**: Start with lower intensity chaos experiments, use `duration` fields to limit impact

**Issue**: Load tests overwhelming cluster
**Solution**: Reduce concurrent users in k6/Locust configurations

**Issue**: Security scans finding too many issues
**Solution**: Review and prioritize findings, use `severity` filters

### Viewing Test Results

```bash
# View all test job status
kubectl get jobs -A -l app=smoke-test,app=regression-test,app=e2e-test

# View logs from latest test
kubectl logs -n integration-testing -l app=smoke-test --tail=100

# View failed test logs
kubectl get pods -A --field-selector=status.phase=Failed
kubectl logs -n <namespace> <failed-pod-name>
```

### Cleanup

```bash
# Delete all test jobs
kubectl delete jobs -n integration-testing --all
kubectl delete jobs -n security-testing --all
kubectl delete jobs -n regression-testing --all

# Delete test namespaces (WARNING: removes all tests)
kubectl delete namespace sonobuoy
kubectl delete namespace chaos-testing
kubectl delete namespace load-testing
kubectl delete namespace security-testing
kubectl delete namespace dr-testing
kubectl delete namespace integration-testing
kubectl delete namespace validation-testing
kubectl delete namespace regression-testing
```

## Best Practices

1. **Start Small**: Begin with smoke tests, then add more comprehensive testing
2. **Monitor Impact**: Watch cluster resources during load and chaos tests
3. **Review Results**: Regularly review test results and address failures
4. **Tune Schedules**: Adjust test frequency based on cluster usage patterns
5. **Integrate CI/CD**: Automate tests in your deployment pipeline
6. **Document Failures**: Keep track of test failures and resolutions
7. **Update Tests**: Keep test scenarios up-to-date with cluster changes
8. **Security First**: Prioritize security test findings
9. **Performance Baselines**: Establish performance baselines and track trends
10. **Disaster Recovery**: Test DR procedures regularly

## Additional Resources

- [Sonobuoy Documentation](https://sonobuoy.io/)
- [Chaos Mesh Documentation](https://chaos-mesh.org/)
- [k6 Documentation](https://k6.io/docs/)
- [Locust Documentation](https://docs.locust.io/)
- [kube-bench GitHub](https://github.com/aquasecurity/kube-bench)
- [kube-hunter GitHub](https://github.com/aquasecurity/kube-hunter)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)

## Support

For issues or questions about the testing framework:
1. Check logs: `kubectl logs -n <namespace> <pod-name>`
2. Review test configurations in respective YAML files
3. Check cluster resources: `kubectl top nodes && kubectl top pods -A`
4. Review documentation in this README
