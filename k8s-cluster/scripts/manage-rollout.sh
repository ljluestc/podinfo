#!/bin/bash
# manage-rollout.sh
# Script to manage canary rollouts for podinfo

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }

NAMESPACE="${NAMESPACE:-podinfo}"
ROLLOUT_NAME="${ROLLOUT_NAME:-podinfo}"

# Show rollout status
status() {
    print_info "Getting rollout status..."
    kubectl argo rollouts status $ROLLOUT_NAME -n $NAMESPACE
    echo ""
    kubectl get rollout $ROLLOUT_NAME -n $NAMESPACE
}

# Promote canary to next step
promote() {
    print_info "Promoting canary to next step..."
    kubectl argo rollouts promote $ROLLOUT_NAME -n $NAMESPACE
    print_success "Canary promoted"
    status
}

# Promote canary all the way (skip all analysis)
promote_full() {
    print_warning "Promoting canary to 100% (skipping all analysis steps)..."
    kubectl argo rollouts promote $ROLLOUT_NAME --full -n $NAMESPACE
    print_success "Canary fully promoted"
    status
}

# Abort rollout and rollback
abort() {
    print_warning "Aborting rollout and rolling back..."
    kubectl argo rollouts abort $ROLLOUT_NAME -n $NAMESPACE
    print_success "Rollout aborted, rolling back to stable"
    status
}

# Restart rollout
restart() {
    print_info "Restarting rollout..."
    kubectl argo rollouts restart $ROLLOUT_NAME -n $NAMESPACE
    print_success "Rollout restarted"
    status
}

# Pause rollout
pause() {
    print_info "Pausing rollout..."
    kubectl argo rollouts pause $ROLLOUT_NAME -n $NAMESPACE
    print_success "Rollout paused"
    status
}

# Resume rollout
resume() {
    print_info "Resuming rollout..."
    kubectl argo rollouts resume $ROLLOUT_NAME -n $NAMESPACE
    print_success "Rollout resumed"
    status
}

# Update image
update_image() {
    local NEW_IMAGE=$1
    if [ -z "$NEW_IMAGE" ]; then
        print_error "Please provide new image tag"
        echo "Usage: $0 update-image <image:tag>"
        exit 1
    fi

    print_info "Updating image to: $NEW_IMAGE..."
    kubectl argo rollouts set image $ROLLOUT_NAME podinfo=$NEW_IMAGE -n $NAMESPACE
    print_success "Image updated, canary rollout started"
    status
}

# Watch rollout live
watch_rollout() {
    print_info "Watching rollout (press Ctrl+C to exit)..."
    kubectl argo rollouts get rollout $ROLLOUT_NAME -n $NAMESPACE --watch
}

# Get rollout history
history() {
    print_info "Rollout history..."
    kubectl rollout history rollout/$ROLLOUT_NAME -n $NAMESPACE
}

# Rollback to specific revision
rollback() {
    local REVISION=$1
    if [ -z "$REVISION" ]; then
        print_error "Please provide revision number"
        echo "Usage: $0 rollback <revision>"
        exit 1
    fi

    print_warning "Rolling back to revision $REVISION..."
    kubectl rollout undo rollout/$ROLLOUT_NAME --to-revision=$REVISION -n $NAMESPACE
    print_success "Rolled back to revision $REVISION"
    status
}

# Get analysis runs
analysis() {
    print_info "Analysis runs for $ROLLOUT_NAME..."
    kubectl get analysisrun -n $NAMESPACE -l rollouts-pod-template-hash
    echo ""
    print_info "Latest analysis run details:"
    kubectl describe analysisrun -n $NAMESPACE -l rollouts-pod-template-hash | tail -50
}

# View metrics
metrics() {
    print_info "Querying Prometheus for podinfo metrics..."

    # Check if port-forward to Prometheus is active
    if ! nc -z localhost 9090 2>/dev/null; then
        print_warning "Prometheus not accessible on localhost:9090"
        print_info "Run: kubectl port-forward -n monitoring svc/prometheus 9090:9090"
        return 1
    fi

    # Query success rate
    echo -e "\n${BLUE}Success Rate (Stable vs Canary):${NC}"
    curl -s "http://localhost:9090/api/v1/query?query=sum(rate(http_request_duration_seconds_count{job=\"podinfo-stable\",status=~\"2..\"}[5m]))/sum(rate(http_request_duration_seconds_count{job=\"podinfo-stable\"}[5m]))" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A"
    curl -s "http://localhost:9090/api/v1/query?query=sum(rate(http_request_duration_seconds_count{job=\"podinfo-canary\",status=~\"2..\"}[5m]))/sum(rate(http_request_duration_seconds_count{job=\"podinfo-canary\"}[5m]))" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A"

    # Query latency
    echo -e "\n${BLUE}P95 Latency (Stable vs Canary):${NC}"
    curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,sum(rate(http_request_duration_seconds_bucket{job=\"podinfo-stable\"}[5m]))by(le))" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A"
    curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,sum(rate(http_request_duration_seconds_bucket{job=\"podinfo-canary\"}[5m]))by(le))" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A"
}

# Dashboard
dashboard() {
    print_info "Opening Argo Rollouts dashboard..."
    kubectl argo rollouts dashboard -n $NAMESPACE
}

# Test canary with header
test_canary() {
    local INGRESS_URL=$1
    if [ -z "$INGRESS_URL" ]; then
        print_error "Please provide ingress URL"
        echo "Usage: $0 test-canary <ingress-url>"
        exit 1
    fi

    print_info "Testing canary deployment with X-Canary header..."
    echo -e "\n${BLUE}Stable version:${NC}"
    curl -s "$INGRESS_URL" | grep -o "version.*" | head -1

    echo -e "\n${BLUE}Canary version (with header):${NC}"
    curl -s -H "X-Canary: true" "$INGRESS_URL" | grep -o "version.*" | head -1
}

# Show help
show_help() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  status              - Show rollout status"
    echo "  promote             - Promote canary to next step"
    echo "  promote-full        - Promote canary to 100% (skip analysis)"
    echo "  abort               - Abort rollout and rollback"
    echo "  restart             - Restart rollout"
    echo "  pause               - Pause rollout"
    echo "  resume              - Resume rollout"
    echo "  update-image <img>  - Update to new image and start canary"
    echo "  watch               - Watch rollout live"
    echo "  history             - Show rollout history"
    echo "  rollback <rev>      - Rollback to specific revision"
    echo "  analysis            - Show analysis runs"
    echo "  metrics             - Query Prometheus metrics"
    echo "  dashboard           - Open Argo Rollouts dashboard"
    echo "  test-canary <url>   - Test canary with header"
    echo ""
    echo "Environment Variables:"
    echo "  NAMESPACE           - Kubernetes namespace (default: podinfo)"
    echo "  ROLLOUT_NAME        - Rollout name (default: podinfo)"
}

# Main
case "${1:-}" in
    status)
        status
        ;;
    promote)
        promote
        ;;
    promote-full)
        promote_full
        ;;
    abort)
        abort
        ;;
    restart)
        restart
        ;;
    pause)
        pause
        ;;
    resume)
        resume
        ;;
    update-image)
        update_image "$2"
        ;;
    watch)
        watch_rollout
        ;;
    history)
        history
        ;;
    rollback)
        rollback "$2"
        ;;
    analysis)
        analysis
        ;;
    metrics)
        metrics
        ;;
    dashboard)
        dashboard
        ;;
    test-canary)
        test_canary "$2"
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
