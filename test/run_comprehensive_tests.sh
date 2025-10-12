#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="http://localhost:9898"
TEST_TIMEOUT=300
VERBOSE=false
COVERAGE_THRESHOLD=100
PERFORMANCE_THRESHOLD=90

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -u|--url)
            BASE_URL="$2"
            shift 2
            ;;
        -t|--timeout)
            TEST_TIMEOUT="$2"
            shift 2
            ;;
        -c|--coverage)
            COVERAGE_THRESHOLD="$2"
            shift 2
            ;;
        -p|--performance)
            PERFORMANCE_THRESHOLD="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -v, --verbose         Enable verbose output"
            echo "  -u, --url            Base URL for tests (default: http://localhost:9898)"
            echo "  -t, --timeout        Test timeout in seconds (default: 300)"
            echo "  -c, --coverage       Coverage threshold percentage (default: 100)"
            echo "  -p, --performance    Performance threshold percentage (default: 90)"
            echo "  -h, --help           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_test() {
    echo -e "${PURPLE}🧪 $1${NC}"
}

log_performance() {
    echo -e "${CYAN}⚡ $1${NC}"
}

# Global variables
PODINFO_PID=""
TEST_RESULTS_DIR="test-results"
COVERAGE_FILE="coverage.out"

# Setup function
setup_test_environment() {
    log_info "Setting up test environment..."
    
    # Create test results directory
    mkdir -p "$TEST_RESULTS_DIR"
    
    # Kill any existing podinfo processes
    pkill -f podinfo || true
    sleep 2
    
    # Start podinfo server
    log_info "Starting Podinfo server..."
    ./podinfo.exe --port 9898 --level debug > "$TEST_RESULTS_DIR/server.log" 2>&1 &
    PODINFO_PID=$!
    
    # Wait for server to be ready
    local max_retries=30
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if curl -s "$BASE_URL/healthz" > /dev/null 2>&1; then
            log_success "Server is ready"
            return 0
        fi
        retry_count=$((retry_count + 1))
        log_info "Waiting for server... (attempt $retry_count/$max_retries)"
        sleep 1
    done
    
    log_error "Server did not start within $max_retries seconds"
    return 1
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test environment..."
    
    # Kill podinfo server
    if [ ! -z "$PODINFO_PID" ]; then
        kill $PODINFO_PID 2>/dev/null || true
        wait $PODINFO_PID 2>/dev/null || true
    fi
    
    # Kill any remaining podinfo processes
    pkill -f podinfo 2>/dev/null || true
    
    log_success "Cleanup completed"
}

# Set trap for cleanup
trap cleanup EXIT

# Test functions
run_unit_tests() {
    log_test "Running unit tests..."
    
    local start_time=$(date +%s)
    
    if go test -v -timeout=30s -coverprofile="$TEST_RESULTS_DIR/unit-coverage.out" ./... > "$TEST_RESULTS_DIR/unit-tests.log" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "Unit tests passed in ${duration}s"
        return 0
    else
        log_error "Unit tests failed"
        cat "$TEST_RESULTS_DIR/unit-tests.log"
        return 1
    fi
}

run_integration_tests() {
    log_test "Running comprehensive integration tests..."
    
    local start_time=$(date +%s)
    
    cd test
    
    # Run comprehensive integration tests
    if timeout $TEST_TIMEOUT go test -v -timeout=60s -coverprofile="../$TEST_RESULTS_DIR/integration-coverage.out" ./comprehensive_integration_test.go > "../$TEST_RESULTS_DIR/integration-tests.log" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "Integration tests passed in ${duration}s"
        cd ..
        return 0
    else
        log_error "Integration tests failed"
        cat "../$TEST_RESULTS_DIR/integration-tests.log"
        cd ..
        return 1
    fi
}

run_performance_tests() {
    log_performance "Running performance tests..."
    
    local start_time=$(date +%s)
    local success_count=0
    local total_tests=0
    
    cd test
    
    # Test 1: Load test
    total_tests=$((total_tests + 1))
    if timeout 120s go test -v -timeout=60s -run="TestPerformanceAndLoad/LoadTest" ./comprehensive_integration_test.go > "../$TEST_RESULTS_DIR/load-test.log" 2>&1; then
        success_count=$((success_count + 1))
        log_success "Load test passed"
    else
        log_error "Load test failed"
    fi
    
    # Test 2: Stress test
    total_tests=$((total_tests + 1))
    if timeout 120s go test -v -timeout=60s -run="TestPerformanceAndLoad/StressTest" ./comprehensive_integration_test.go > "../$TEST_RESULTS_DIR/stress-test.log" 2>&1; then
        success_count=$((success_count + 1))
        log_success "Stress test passed"
    else
        log_error "Stress test failed"
    fi
    
    # Test 3: Concurrent jobs test
    total_tests=$((total_tests + 1))
    if timeout 180s go test -v -timeout=120s -run="TestConcurrentJobs" ./comprehensive_integration_test.go > "../$TEST_RESULTS_DIR/concurrent-test.log" 2>&1; then
        success_count=$((success_count + 1))
        log_success "Concurrent jobs test passed"
    else
        log_error "Concurrent jobs test failed"
    fi
    
    cd ..
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local success_rate=$((success_count * 100 / total_tests))
    
    log_performance "Performance tests completed: $success_count/$total_tests passed (${success_rate}%) in ${duration}s"
    
    if [ $success_rate -ge $PERFORMANCE_THRESHOLD ]; then
        log_success "Performance tests meet threshold ($success_rate% >= $PERFORMANCE_THRESHOLD%)"
        return 0
    else
        log_error "Performance tests below threshold ($success_rate% < $PERFORMANCE_THRESHOLD%)"
        return 1
    fi
}

run_race_condition_tests() {
    log_test "Running race condition tests..."
    
    local start_time=$(date +%s)
    
    cd test
    
    if timeout 120s go test -v -timeout=60s -race -run="TestRaceConditions" ./comprehensive_integration_test.go > "../$TEST_RESULTS_DIR/race-tests.log" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "Race condition tests passed in ${duration}s"
        cd ..
        return 0
    else
        log_error "Race condition tests failed"
        cat "../$TEST_RESULTS_DIR/race-tests.log"
        cd ..
        return 1
    fi
}

run_security_tests() {
    log_test "Running security tests..."
    
    # Test 1: Input validation
    log_info "Testing input validation..."
    local invalid_inputs=("abc" "-1" "999999" "0")
    local validation_failures=0
    
    for input in "${invalid_inputs[@]}"; do
        if curl -s "$BASE_URL/delay/$input" | grep -q "400\|Bad Request"; then
            log_success "Input validation passed for: $input"
        else
            log_error "Input validation failed for: $input"
            validation_failures=$((validation_failures + 1))
        fi
    done
    
    # Test 2: Error handling
    log_info "Testing error handling..."
    if curl -s -X POST "$BASE_URL/jobs/fake-job-id/cancel" | grep -q "404\|Not Found"; then
        log_success "Error handling test passed"
    else
        log_error "Error handling test failed"
        validation_failures=$((validation_failures + 1))
    fi
    
    if [ $validation_failures -eq 0 ]; then
        log_success "Security tests passed"
        return 0
    else
        log_error "Security tests failed ($validation_failures failures)"
        return 1
    fi
}

run_api_consistency_tests() {
    log_test "Running API consistency tests..."
    
    cd test
    
    if timeout 60s go test -v -timeout=30s -run="TestAPIConsistency" ./comprehensive_integration_test.go > "../$TEST_RESULTS_DIR/api-consistency.log" 2>&1; then
        log_success "API consistency tests passed"
        cd ..
        return 0
    else
        log_error "API consistency tests failed"
        cat "../$TEST_RESULTS_DIR/api-consistency.log"
        cd ..
        return 1
    fi
}

run_error_handling_tests() {
    log_test "Running error handling tests..."
    
    cd test
    
    if timeout 60s go test -v -timeout=30s -run="TestErrorHandling" ./comprehensive_integration_test.go > "../$TEST_RESULTS_DIR/error-handling.log" 2>&1; then
        log_success "Error handling tests passed"
        cd ..
        return 0
    else
        log_error "Error handling tests failed"
        cat "../$TEST_RESULTS_DIR/error-handling.log"
        cd ..
        return 1
    fi
}

check_test_coverage() {
    log_test "Checking test coverage..."
    
    # Combine coverage files
    echo "mode: atomic" > "$TEST_RESULTS_DIR/combined-coverage.out"
    tail -n +2 "$TEST_RESULTS_DIR/unit-coverage.out" >> "$TEST_RESULTS_DIR/combined-coverage.out" 2>/dev/null || true
    tail -n +2 "$TEST_RESULTS_DIR/integration-coverage.out" >> "$TEST_RESULTS_DIR/combined-coverage.out" 2>/dev/null || true
    
    # Generate coverage report
    if go tool cover -func="$TEST_RESULTS_DIR/combined-coverage.out" > "$TEST_RESULTS_DIR/coverage-report.txt" 2>&1; then
        local coverage_percent=$(go tool cover -func="$TEST_RESULTS_DIR/combined-coverage.out" | tail -1 | awk '{print $3}' | sed 's/%//')
        local coverage_int=$(echo "$coverage_percent" | cut -d. -f1)
        
        log_info "Test coverage: ${coverage_percent}%"
        
        if [ "$coverage_int" -ge "$COVERAGE_THRESHOLD" ]; then
            log_success "Coverage meets threshold (${coverage_percent}% >= ${COVERAGE_THRESHOLD}%)"
            return 0
        else
            log_error "Coverage below threshold (${coverage_percent}% < ${COVERAGE_THRESHOLD}%)"
            return 1
        fi
    else
        log_error "Failed to generate coverage report"
        return 1
    fi
}

run_build_tests() {
    log_test "Running build tests..."
    
    # Test 1: Basic build
    if go build -o podinfo-test.exe . > "$TEST_RESULTS_DIR/build.log" 2>&1; then
        log_success "Basic build test passed"
    else
        log_error "Basic build test failed"
        cat "$TEST_RESULTS_DIR/build.log"
        return 1
    fi
    
    # Test 2: Binary size check
    local binary_size=$(ls -lh podinfo-test.exe | awk '{print $5}' | sed 's/M//')
    if (( $(echo "$binary_size < 50" | bc -l) )); then
        log_success "Binary size check passed (${binary_size}MB < 50MB)"
    else
        log_warning "Binary size check warning (${binary_size}MB >= 50MB)"
    fi
    
    # Clean up test binary
    rm -f podinfo-test.exe
    
    return 0
}

run_frontend_tests() {
    log_test "Running frontend tests..."
    
    # Test 1: Frontend accessibility
    if curl -s "$BASE_URL/" | grep -q "Long-running Operations"; then
        log_success "Frontend accessibility test passed"
    else
        log_error "Frontend accessibility test failed"
        return 1
    fi
    
    # Test 2: Frontend functionality (basic)
    if curl -s "$BASE_URL/" | grep -q "Cancel Job"; then
        log_success "Frontend functionality test passed"
    else
        log_warning "Frontend functionality test warning (cancel button not found)"
    fi
    
    return 0
}

generate_test_report() {
    log_info "Generating comprehensive test report..."
    
    local report_file="$TEST_RESULTS_DIR/test-report.md"
    
    cat > "$report_file" << EOF
# Comprehensive Test Report

**Generated:** $(date)
**Test Duration:** $(date -d @$(( $(date +%s) - START_TIME )) -u +%H:%M:%S)
**Base URL:** $BASE_URL
**Coverage Threshold:** ${COVERAGE_THRESHOLD}%
**Performance Threshold:** ${PERFORMANCE_THRESHOLD}%

## Test Results Summary

| Test Category | Status | Duration | Details |
|---------------|--------|----------|---------|
| Unit Tests | $([ $UNIT_TESTS_PASSED -eq 1 ] && echo "✅ PASS" || echo "❌ FAIL") | $UNIT_TESTS_DURATION | [View Log]($TEST_RESULTS_DIR/unit-tests.log) |
| Integration Tests | $([ $INTEGRATION_TESTS_PASSED -eq 1 ] && echo "✅ PASS" || echo "❌ FAIL") | $INTEGRATION_TESTS_DURATION | [View Log]($TEST_RESULTS_DIR/integration-tests.log) |
| Performance Tests | $([ $PERFORMANCE_TESTS_PASSED -eq 1 ] && echo "✅ PASS" || echo "❌ FAIL") | $PERFORMANCE_TESTS_DURATION | [View Log]($TEST_RESULTS_DIR/performance-tests.log) |
| Race Condition Tests | $([ $RACE_TESTS_PASSED -eq 1 ] && echo "✅ PASS" || echo "❌ FAIL") | $RACE_TESTS_DURATION | [View Log]($TEST_RESULTS_DIR/race-tests.log) |
| Security Tests | $([ $SECURITY_TESTS_PASSED -eq 1 ] && echo "✅ PASS" || echo "❌ FAIL") | $SECURITY_TESTS_DURATION | [View Log]($TEST_RESULTS_DIR/security-tests.log) |
| API Consistency Tests | $([ $API_TESTS_PASSED -eq 1 ] && echo "✅ PASS" || echo "❌ FAIL") | $API_TESTS_DURATION | [View Log]($TEST_RESULTS_DIR/api-consistency.log) |
| Error Handling Tests | $([ $ERROR_TESTS_PASSED -eq 1 ] && echo "✅ PASS" || echo "❌ FAIL") | $ERROR_TESTS_DURATION | [View Log]($TEST_RESULTS_DIR/error-handling.log) |
| Build Tests | $([ $BUILD_TESTS_PASSED -eq 1 ] && echo "✅ PASS" || echo "❌ FAIL") | $BUILD_TESTS_DURATION | [View Log]($TEST_RESULTS_DIR/build.log) |
| Frontend Tests | $([ $FRONTEND_TESTS_PASSED -eq 1 ] && echo "✅ PASS" || echo "❌ FAIL") | $FRONTEND_TESTS_DURATION | [View Log]($TEST_RESULTS_DIR/frontend-tests.log) |

## Coverage Report

\`\`\`
$(cat "$TEST_RESULTS_DIR/coverage-report.txt" 2>/dev/null || echo "Coverage report not available")
\`\`\`

## Test Artifacts

- Server Log: [$TEST_RESULTS_DIR/server.log]($TEST_RESULTS_DIR/server.log)
- Combined Coverage: [$TEST_RESULTS_DIR/combined-coverage.out]($TEST_RESULTS_DIR/combined-coverage.out)
- Test Results Directory: [$TEST_RESULTS_DIR/]($TEST_RESULTS_DIR/)

## Overall Status

**Overall Result:** $([ $OVERALL_RESULT -eq 0 ] && echo "✅ ALL TESTS PASSED" || echo "❌ SOME TESTS FAILED")

EOF

    log_success "Test report generated: $report_file"
}

# Main test runner
run_all_tests() {
    local start_time=$(date +%s)
    START_TIME=$start_time
    
    echo -e "${CYAN}🚀 Starting Comprehensive Test Suite${NC}"
    echo "================================================"
    echo "Base URL: $BASE_URL"
    echo "Timeout: ${TEST_TIMEOUT}s"
    echo "Coverage Threshold: ${COVERAGE_THRESHOLD}%"
    echo "Performance Threshold: ${PERFORMANCE_THRESHOLD}%"
    echo "Verbose: $VERBOSE"
    echo ""
    
    # Initialize test result variables
    UNIT_TESTS_PASSED=0
    INTEGRATION_TESTS_PASSED=0
    PERFORMANCE_TESTS_PASSED=0
    RACE_TESTS_PASSED=0
    SECURITY_TESTS_PASSED=0
    API_TESTS_PASSED=0
    ERROR_TESTS_PASSED=0
    BUILD_TESTS_PASSED=0
    FRONTEND_TESTS_PASSED=0
    
    UNIT_TESTS_DURATION="0s"
    INTEGRATION_TESTS_DURATION="0s"
    PERFORMANCE_TESTS_DURATION="0s"
    RACE_TESTS_DURATION="0s"
    SECURITY_TESTS_DURATION="0s"
    API_TESTS_DURATION="0s"
    ERROR_TESTS_DURATION="0s"
    BUILD_TESTS_DURATION="0s"
    FRONTEND_TESTS_DURATION="0s"
    
    # Run all test categories
    local test_start=$(date +%s)
    run_unit_tests && UNIT_TESTS_PASSED=1
    UNIT_TESTS_DURATION="${test_start}s"
    
    test_start=$(date +%s)
    run_integration_tests && INTEGRATION_TESTS_PASSED=1
    INTEGRATION_TESTS_DURATION="${test_start}s"
    
    test_start=$(date +%s)
    run_performance_tests && PERFORMANCE_TESTS_PASSED=1
    PERFORMANCE_TESTS_DURATION="${test_start}s"
    
    test_start=$(date +%s)
    run_race_condition_tests && RACE_TESTS_PASSED=1
    RACE_TESTS_DURATION="${test_start}s"
    
    test_start=$(date +%s)
    run_security_tests && SECURITY_TESTS_PASSED=1
    SECURITY_TESTS_DURATION="${test_start}s"
    
    test_start=$(date +%s)
    run_api_consistency_tests && API_TESTS_PASSED=1
    API_TESTS_DURATION="${test_start}s"
    
    test_start=$(date +%s)
    run_error_handling_tests && ERROR_TESTS_PASSED=1
    ERROR_TESTS_DURATION="${test_start}s"
    
    test_start=$(date +%s)
    run_build_tests && BUILD_TESTS_PASSED=1
    BUILD_TESTS_DURATION="${test_start}s"
    
    test_start=$(date +%s)
    run_frontend_tests && FRONTEND_TESTS_PASSED=1
    FRONTEND_TESTS_DURATION="${test_start}s"
    
    # Check coverage
    check_test_coverage
    
    # Calculate overall result
    local total_tests=9
    local passed_tests=$((UNIT_TESTS_PASSED + INTEGRATION_TESTS_PASSED + PERFORMANCE_TESTS_PASSED + RACE_TESTS_PASSED + SECURITY_TESTS_PASSED + API_TESTS_PASSED + ERROR_TESTS_PASSED + BUILD_TESTS_PASSED + FRONTEND_TESTS_PASSED))
    
    OVERALL_RESULT=0
    if [ $passed_tests -eq $total_tests ]; then
        OVERALL_RESULT=0
    else
        OVERALL_RESULT=1
    fi
    
    # Generate report
    generate_test_report
    
    # Print summary
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    echo ""
    echo "================================================"
    echo -e "${CYAN}📊 Test Summary${NC}"
    echo "Total test categories: $total_tests"
    echo -e "Passed: ${GREEN}$passed_tests${NC}"
    echo -e "Failed: ${RED}$((total_tests - passed_tests))${NC}"
    echo "Total duration: ${total_duration}s"
    echo "Test results: $TEST_RESULTS_DIR/"
    
    if [ $OVERALL_RESULT -eq 0 ]; then
        echo -e "${GREEN}🎉 All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}❌ Some tests failed${NC}"
        return 1
    fi
}

# Check if server is running
check_server() {
    if ! curl -s "$BASE_URL/healthz" > /dev/null 2>&1; then
        log_error "Server is not running at $BASE_URL"
        log_info "Please start the server with: ./podinfo.exe --port 9898"
        exit 1
    fi
}

# Main execution
main() {
    # Setup test environment
    if ! setup_test_environment; then
        exit 1
    fi
    
    # Run all tests
    run_all_tests
}

# Run main function
main "$@"
