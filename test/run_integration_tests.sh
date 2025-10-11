#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Podinfo Integration Tests${NC}"
echo "================================================"

# Check if podinfo is running
check_server() {
    echo -e "${YELLOW}📡 Checking if podinfo server is running...${NC}"
    for i in {1..30}; do
        if curl -s http://localhost:9898/healthz > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Server is running${NC}"
            return 0
        fi
        echo -e "${YELLOW}⏳ Waiting for server... (attempt $i/30)${NC}"
        sleep 1
    done
    echo -e "${RED}❌ Server is not responding after 30 seconds${NC}"
    return 1
}

# Start podinfo server if not running
start_server() {
    if ! check_server; then
        echo -e "${YELLOW}🔧 Starting podinfo server...${NC}"
        cd "$(dirname "$0")/.."
        
        # Kill any existing podinfo processes
        pkill -f podinfo || true
        sleep 2
        
        # Start podinfo in background
        ./podinfo.exe --port 9898 --level debug &
        PODINFO_PID=$!
        
        # Wait for server to start
        check_server
        echo -e "${GREEN}✅ Server started with PID: $PODINFO_PID${NC}"
    fi
}

# Run integration tests
run_tests() {
    echo -e "${BLUE}🧪 Running integration tests...${NC}"
    cd "$(dirname "$0")"
    
    # Run Go tests
    if command -v go >/dev/null 2>&1; then
        echo -e "${YELLOW}📋 Running Go integration tests...${NC}"
        go test -v -timeout 60s ./integration_test.go
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Go integration tests passed${NC}"
        else
            echo -e "${RED}❌ Go integration tests failed${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  Go not found, skipping Go tests${NC}"
    fi
    
    # Run manual API tests
    echo -e "${YELLOW}📋 Running manual API tests...${NC}"
    
    # Test 1: Basic delay job
    echo -e "${BLUE}Test 1: Basic delay job${NC}"
    JOB_RESPONSE=$(curl -s "http://localhost:9898/delay/2")
    echo "Response: $JOB_RESPONSE"
    if echo "$JOB_RESPONSE" | grep -q '"status":"completed"'; then
        echo -e "${GREEN}✅ Basic delay job test passed${NC}"
    else
        echo -e "${RED}❌ Basic delay job test failed${NC}"
        return 1
    fi
    
    # Test 2: Job cancellation
    echo -e "${BLUE}Test 2: Job cancellation${NC}"
    # Start a long job in background
    curl -s "http://localhost:9898/delay/10" &
    LONG_JOB_PID=$!
    
    # Wait a bit for job to start
    sleep 1
    
    # Get job ID
    JOBS_RESPONSE=$(curl -s "http://localhost:9898/jobs")
    echo "Jobs: $JOBS_RESPONSE"
    
    # Extract job ID (simple extraction)
    JOB_ID=$(echo "$JOBS_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ -n "$JOB_ID" ]; then
        echo "Found job ID: $JOB_ID"
        
        # Cancel the job
        CANCEL_RESPONSE=$(curl -s -X POST "http://localhost:9898/jobs/$JOB_ID/cancel")
        echo "Cancel response: $CANCEL_RESPONSE"
        
        if echo "$CANCEL_RESPONSE" | grep -q '"status":"cancelled"'; then
            echo -e "${GREEN}✅ Job cancellation test passed${NC}"
        else
            echo -e "${RED}❌ Job cancellation test failed${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  No running job found for cancellation test${NC}"
    fi
    
    # Test 3: Job status endpoints
    echo -e "${BLUE}Test 3: Job status endpoints${NC}"
    
    # Test list jobs
    JOBS_RESPONSE=$(curl -s "http://localhost:9898/jobs")
    if echo "$JOBS_RESPONSE" | grep -q '"jobs"'; then
        echo -e "${GREEN}✅ List jobs endpoint working${NC}"
    else
        echo -e "${RED}❌ List jobs endpoint failed${NC}"
        return 1
    fi
    
    # Test 4: Error handling
    echo -e "${BLUE}Test 4: Error handling${NC}"
    
    # Test cancel non-existent job
    CANCEL_404=$(curl -s -w "%{http_code}" -X POST "http://localhost:9898/jobs/fake-job-id/cancel" -o /dev/null)
    if [ "$CANCEL_404" = "404" ]; then
        echo -e "${GREEN}✅ Error handling test passed${NC}"
    else
        echo -e "${RED}❌ Error handling test failed (expected 404, got $CANCEL_404)${NC}"
        return 1
    fi
    
    # Test 5: Concurrent jobs
    echo -e "${BLUE}Test 5: Concurrent jobs${NC}"
    # Start multiple jobs
    curl -s "http://localhost:9898/delay/1" &
    curl -s "http://localhost:9898/delay/1" &
    curl -s "http://localhost:9898/delay/1" &
    
    # Wait for completion
    sleep 3
    
    # Check final job count
    FINAL_JOBS=$(curl -s "http://localhost:9898/jobs" | grep -o '"count":[0-9]*' | cut -d':' -f2)
    echo "Final job count: $FINAL_JOBS"
    echo -e "${GREEN}✅ Concurrent jobs test completed${NC}"
    
    echo -e "${GREEN}🎉 All integration tests passed!${NC}"
    return 0
}

# Cleanup function
cleanup() {
    echo -e "${YELLOW}🧹 Cleaning up...${NC}"
    # Kill podinfo if we started it
    if [ ! -z "$PODINFO_PID" ]; then
        kill $PODINFO_PID 2>/dev/null || true
    fi
    # Kill any remaining podinfo processes
    pkill -f podinfo 2>/dev/null || true
}

# Set trap for cleanup
trap cleanup EXIT

# Main execution
main() {
    start_server
    run_tests
    TEST_RESULT=$?
    
    if [ $TEST_RESULT -eq 0 ]; then
        echo -e "${GREEN}🎉 All tests passed successfully!${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some tests failed${NC}"
        exit 1
    fi
}

# Run main function
main "$@"
