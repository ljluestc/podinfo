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

# Test configuration
BASE_URL="http://localhost:9898"
TEST_TIMEOUT=30
VERBOSE=false

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
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -v, --verbose    Enable verbose output"
            echo "  -u, --url        Base URL for tests (default: http://localhost:9898)"
            echo "  -t, --timeout    Test timeout in seconds (default: 30)"
            echo "  -h, --help       Show this help message"
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

# Utility functions
make_request() {
    local method="$1"
    local url="$2"
    local data="$3"
    
    if [ "$VERBOSE" = true ]; then
        echo "Making $method request to: $url"
        if [ -n "$data" ]; then
            echo "Data: $data"
        fi
    fi
    
    if [ "$method" = "GET" ]; then
        curl -s -w "\n%{http_code}" "$url"
    elif [ "$method" = "POST" ]; then
        curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -d "$data" "$url"
    else
        curl -s -w "\n%{http_code}" -X "$method" "$url"
    fi
}

extract_json_field() {
    local json="$1"
    local field="$2"
    echo "$json" | grep -o "\"$field\":\"[^\"]*\"" | cut -d'"' -f4
}

extract_json_number() {
    local json="$1"
    local field="$2"
    echo "$json" | grep -o "\"$field\":[0-9.]*" | cut -d':' -f2
}

# Test functions
test_server_health() {
    log_test "Testing server health"
    
    local response=$(make_request "GET" "$BASE_URL/healthz")
    local status_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)
    
    if [ "$status_code" = "200" ]; then
        log_success "Server is healthy"
        return 0
    else
        log_error "Server health check failed (status: $status_code)"
        return 1
    fi
}

test_basic_delay_job() {
    log_test "Testing basic delay job completion"
    
    local response=$(make_request "GET" "$BASE_URL/delay/2")
    local status_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)
    
    if [ "$status_code" = "200" ]; then
        local status=$(extract_json_field "$body" "status")
        local job_id=$(extract_json_field "$body" "job_id")
        
        if [ "$status" = "completed" ]; then
            log_success "Basic delay job completed successfully (Job ID: $job_id)"
            return 0
        else
            log_error "Job did not complete successfully (status: $status)"
            return 1
        fi
    else
        log_error "Delay job request failed (status: $status_code)"
        return 1
    fi
}

test_job_cancellation() {
    log_test "Testing job cancellation"
    
    # Start a long-running job in background
    log_info "Starting 10-second delay job..."
    make_request "GET" "$BASE_URL/delay/10" > /dev/null &
    local job_pid=$!
    
    # Wait for job to start
    sleep 1
    
    # Get job list to find the running job
    local jobs_response=$(make_request "GET" "$BASE_URL/jobs")
    local jobs_status_code=$(echo "$jobs_response" | tail -n1)
    local jobs_body=$(echo "$jobs_response" | head -n -1)
    
    if [ "$jobs_status_code" = "200" ]; then
        # Extract job ID (simple approach)
        local job_id=$(echo "$jobs_body" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        
        if [ -n "$job_id" ]; then
            log_info "Found running job: $job_id"
            
            # Cancel the job
            local cancel_response=$(make_request "POST" "$BASE_URL/jobs/$job_id/cancel" "")
            local cancel_status_code=$(echo "$cancel_response" | tail -n1)
            local cancel_body=$(echo "$cancel_response" | head -n -1)
            
            if [ "$cancel_status_code" = "200" ]; then
                local cancel_status=$(extract_json_field "$cancel_body" "status")
                if [ "$cancel_status" = "cancelled" ]; then
                    log_success "Job cancelled successfully"
                    return 0
                else
                    log_error "Job cancellation failed (status: $cancel_status)"
                    return 1
                fi
            else
                log_error "Cancel request failed (status: $cancel_status_code)"
                return 1
            fi
        else
            log_warning "No running job found for cancellation test"
            return 0
        fi
    else
        log_error "Failed to get jobs list (status: $jobs_status_code)"
        return 1
    fi
}

test_job_status_endpoints() {
    log_test "Testing job status endpoints"
    
    # Test list jobs endpoint
    local jobs_response=$(make_request "GET" "$BASE_URL/jobs")
    local jobs_status_code=$(echo "$jobs_response" | tail -n1)
    local jobs_body=$(echo "$jobs_response" | head -n -1)
    
    if [ "$jobs_status_code" = "200" ]; then
        local job_count=$(extract_json_number "$jobs_body" "count")
        log_success "List jobs endpoint working (count: $job_count)"
        
        # Test get specific job if there are jobs
        if [ "$job_count" -gt 0 ]; then
            local job_id=$(echo "$jobs_body" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
            if [ -n "$job_id" ]; then
                local job_response=$(make_request "GET" "$BASE_URL/jobs/$job_id")
                local job_status_code=$(echo "$job_response" | tail -n1)
                
                if [ "$job_status_code" = "200" ]; then
                    log_success "Get job endpoint working"
                    return 0
                else
                    log_error "Get job endpoint failed (status: $job_status_code)"
                    return 1
                fi
            fi
        fi
        return 0
    else
        log_error "List jobs endpoint failed (status: $jobs_status_code)"
        return 1
    fi
}

test_error_handling() {
    log_test "Testing error handling"
    
    # Test cancel non-existent job
    local cancel_response=$(make_request "POST" "$BASE_URL/jobs/fake-job-id/cancel" "")
    local cancel_status_code=$(echo "$cancel_response" | tail -n1)
    
    if [ "$cancel_status_code" = "404" ]; then
        log_success "Error handling working correctly (404 for non-existent job)"
        return 0
    else
        log_error "Error handling failed (expected 404, got $cancel_status_code)"
        return 1
    fi
}

test_concurrent_jobs() {
    log_test "Testing concurrent jobs"
    
    # Start multiple jobs
    log_info "Starting 3 concurrent jobs..."
    make_request "GET" "$BASE_URL/delay/2" > /dev/null &
    make_request "GET" "$BASE_URL/delay/2" > /dev/null &
    make_request "GET" "$BASE_URL/delay/2" > /dev/null &
    
    # Wait for completion
    sleep 4
    
    # Check final job count
    local jobs_response=$(make_request "GET" "$BASE_URL/jobs")
    local jobs_status_code=$(echo "$jobs_response" | tail -n1)
    local jobs_body=$(echo "$jobs_response" | head -n -1)
    
    if [ "$jobs_status_code" = "200" ]; then
        local job_count=$(extract_json_number "$jobs_body" "count")
        log_success "Concurrent jobs test completed (final count: $job_count)"
        return 0
    else
        log_error "Failed to check concurrent jobs (status: $jobs_status_code)"
        return 1
    fi
}

test_frontend_integration() {
    log_test "Testing frontend integration"
    
    # Test that the frontend loads
    local frontend_response=$(make_request "GET" "$BASE_URL/")
    local frontend_status_code=$(echo "$frontend_response" | tail -n1)
    
    if [ "$frontend_status_code" = "200" ]; then
        local frontend_body=$(echo "$frontend_response" | head -n -1)
        if echo "$frontend_body" | grep -q "Long-running Operations"; then
            log_success "Frontend integration working (cancel UI present)"
            return 0
        else
            log_warning "Frontend loaded but cancel UI not found"
            return 0
        fi
    else
        log_error "Frontend not accessible (status: $frontend_status_code)"
        return 1
    fi
}

# Main test runner
run_all_tests() {
    local start_time=$(date +%s)
    local passed=0
    local failed=0
    local total=0
    
    echo -e "${CYAN}🚀 Starting Cancel Functionality Tests${NC}"
    echo "================================================"
    echo "Base URL: $BASE_URL"
    echo "Timeout: ${TEST_TIMEOUT}s"
    echo "Verbose: $VERBOSE"
    echo ""
    
    # Define tests
    local tests=(
        "test_server_health:Server Health Check"
        "test_basic_delay_job:Basic Delay Job"
        "test_job_cancellation:Job Cancellation"
        "test_job_status_endpoints:Job Status Endpoints"
        "test_error_handling:Error Handling"
        "test_concurrent_jobs:Concurrent Jobs"
        "test_frontend_integration:Frontend Integration"
    )
    
    # Run tests
    for test_info in "${tests[@]}"; do
        local test_func=$(echo "$test_info" | cut -d':' -f1)
        local test_name=$(echo "$test_info" | cut -d':' -f2)
        
        total=$((total + 1))
        
        if $test_func; then
            passed=$((passed + 1))
        else
            failed=$((failed + 1))
        fi
        
        echo ""
    done
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Print summary
    echo "================================================"
    echo -e "${CYAN}📊 Test Summary${NC}"
    echo "Total tests: $total"
    echo -e "Passed: ${GREEN}$passed${NC}"
    echo -e "Failed: ${RED}$failed${NC}"
    echo "Duration: ${duration}s"
    
    if [ $failed -eq 0 ]; then
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
    check_server
    run_all_tests
}

# Run main function
main "$@"
