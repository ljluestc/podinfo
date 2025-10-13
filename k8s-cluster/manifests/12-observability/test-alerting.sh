#!/bin/bash
# Comprehensive Alerting System Test Script
# Tests alert rules, notification delivery, grouping, and escalation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NAMESPACE="monitoring"
ALERTMANAGER_POD="alertmanager-0"

# Helper functions
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    print_success "kubectl is installed"

    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    print_success "Connected to Kubernetes cluster"

    # Check namespace
    if ! kubectl get namespace $NAMESPACE &> /dev/null; then
        print_error "Namespace $NAMESPACE does not exist"
        exit 1
    fi
    print_success "Namespace $NAMESPACE exists"

    # Check Alertmanager pod
    if ! kubectl get pod -n $NAMESPACE $ALERTMANAGER_POD &> /dev/null; then
        print_error "Alertmanager pod not found"
        exit 1
    fi
    print_success "Alertmanager pod is running"

    # Check if amtool is available
    if ! kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- amtool --version &> /dev/null; then
        print_error "amtool not available in Alertmanager pod"
        exit 1
    fi
    print_success "amtool is available"
}

test_alertmanager_health() {
    print_header "Testing Alertmanager Health"

    # Check Alertmanager status
    if kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- wget -qO- http://localhost:9093/-/healthy | grep -q "Healthy"; then
        print_success "Alertmanager is healthy"
    else
        print_error "Alertmanager health check failed"
        return 1
    fi

    # Check Alertmanager ready
    if kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- wget -qO- http://localhost:9093/-/ready | grep -q "Ready"; then
        print_success "Alertmanager is ready"
    else
        print_error "Alertmanager readiness check failed"
        return 1
    fi

    # Check cluster status
    print_info "Checking Alertmanager cluster status..."
    kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- amtool cluster show
}

test_prometheus_rules() {
    print_header "Testing Prometheus Alert Rules"

    # Check if PrometheusRules exist
    print_info "Checking for PrometheusRule resources..."
    local rules=$(kubectl get prometheusrule -n $NAMESPACE --no-headers | wc -l)
    if [ "$rules" -gt 0 ]; then
        print_success "Found $rules PrometheusRule resources"
        kubectl get prometheusrule -n $NAMESPACE
    else
        print_error "No PrometheusRule resources found"
        return 1
    fi

    # Validate specific rules
    print_info "Validating comprehensive-alert-rules..."
    if kubectl get prometheusrule comprehensive-alert-rules -n $NAMESPACE &> /dev/null; then
        print_success "comprehensive-alert-rules exists"
        local rule_count=$(kubectl get prometheusrule comprehensive-alert-rules -n $NAMESPACE -o json | jq '.spec.groups[].rules | length' | awk '{s+=$1} END {print s}')
        print_info "Total alert rules: $rule_count"
    else
        print_error "comprehensive-alert-rules not found"
        return 1
    fi

    # Check SLO rules
    print_info "Validating SLO alert rules..."
    if kubectl get prometheusrule slo-alert-rules -n $NAMESPACE &> /dev/null; then
        print_success "slo-alert-rules exists"
    else
        print_warning "slo-alert-rules not found"
    fi
}

test_alert_routing() {
    print_header "Testing Alert Routing Configuration"

    # Show current routing configuration
    print_info "Displaying Alertmanager routing tree..."
    kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- amtool config routes show || print_warning "Could not show routes"

    # Show receivers
    print_info "Displaying configured receivers..."
    kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- sh -c "amtool config show | grep -A 2 receivers:" || print_warning "Could not show receivers"
}

send_test_alert() {
    local name=$1
    local severity=$2
    local description=$3

    print_info "Sending test alert: $name (severity: $severity)"

    kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- \
        amtool alert add "$name" \
        severity="$severity" \
        alertname="$name" \
        summary="$description" \
        category="test" \
        --end-time="2m" \
        2>&1

    if [ $? -eq 0 ]; then
        print_success "Test alert sent: $name"
        return 0
    else
        print_error "Failed to send test alert: $name"
        return 1
    fi
}

test_alert_firing() {
    print_header "Testing Alert Firing and Delivery"

    # Send test alerts with different severities
    send_test_alert "TestCriticalAlert" "critical" "Test critical alert for notification delivery"
    sleep 2

    send_test_alert "TestWarningAlert" "warning" "Test warning alert for notification delivery"
    sleep 2

    send_test_alert "TestSecurityAlert" "critical" "Test security alert"
    sleep 2

    # Wait for alerts to be processed
    print_info "Waiting for alerts to be processed (10 seconds)..."
    sleep 10

    # Check active alerts
    print_info "Checking active alerts..."
    kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- amtool alert query --active
}

test_alert_grouping() {
    print_header "Testing Alert Grouping"

    print_info "Sending multiple similar alerts to test grouping..."

    # Send multiple alerts with same alertname but different instances
    for i in {1..5}; do
        kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- \
            amtool alert add "GroupTestAlert" \
            severity="warning" \
            alertname="GroupTestAlert" \
            instance="instance-$i" \
            summary="Test alert $i for grouping" \
            --end-time="2m" \
            2>&1
        sleep 1
    done

    print_success "Sent 5 alerts for grouping test"

    # Wait for grouping
    print_info "Waiting for alert grouping (15 seconds)..."
    sleep 15

    # Check if alerts are grouped
    print_info "Checking grouped alerts..."
    kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- amtool alert query --active alertname="GroupTestAlert"
}

test_inhibition_rules() {
    print_header "Testing Alert Inhibition"

    print_info "Testing inhibition: critical alert should suppress warning alert"

    # Send warning alert first
    send_test_alert "InhibitionTest" "warning" "Warning that should be inhibited"
    sleep 2

    # Send critical alert (should inhibit warning)
    send_test_alert "InhibitionTest" "critical" "Critical alert that inhibits warning"
    sleep 2

    # Wait for inhibition to take effect
    print_info "Waiting for inhibition rules to apply (10 seconds)..."
    sleep 10

    # Check silenced/inhibited alerts
    print_info "Checking for inhibited alerts..."
    kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- amtool alert query alertname="InhibitionTest"

    print_warning "Manual verification required: Check if warning alert is inhibited in Alertmanager UI"
}

test_silence() {
    print_header "Testing Alert Silencing"

    # Create a silence
    print_info "Creating test silence..."
    local silence_id=$(kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- \
        amtool silence add \
        alertname="TestAlert" \
        --duration=5m \
        --comment="Test silence for automated testing" \
        --author="test-script" 2>&1 | grep -o '[a-f0-9-]\{36\}')

    if [ -n "$silence_id" ]; then
        print_success "Created silence: $silence_id"

        # List active silences
        print_info "Listing active silences..."
        kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- amtool silence query

        # Remove silence
        print_info "Removing test silence..."
        kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- amtool silence expire "$silence_id"
        print_success "Removed silence"
    else
        print_error "Failed to create silence"
    fi
}

test_notification_metrics() {
    print_header "Testing Notification Metrics"

    # Port-forward is handled externally, just show commands
    print_info "To check notification metrics, run:"
    echo "  kubectl port-forward -n $NAMESPACE svc/alertmanager 9093:9093"
    echo "  curl http://localhost:9093/metrics | grep alertmanager_notifications"

    # Attempt to get metrics directly
    print_info "Fetching notification metrics..."
    kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- \
        wget -qO- http://localhost:9093/metrics | \
        grep -E "alertmanager_notifications_(total|failed_total)" | \
        head -20 || print_warning "Could not fetch metrics directly"
}

test_webhook_integration() {
    print_header "Testing Webhook Configuration"

    print_info "Checking webhook configuration in Alertmanager..."
    kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- \
        sh -c "amtool config show | grep -A 3 webhook_configs" || \
        print_warning "No webhook configurations found"
}

test_slo_alerts() {
    print_header "Testing SLO Alert Rules"

    print_info "Checking SLO recording rules..."

    # Port-forward command
    print_info "To verify SLO metrics in Prometheus:"
    echo "  kubectl port-forward -n $NAMESPACE svc/prometheus-operated 9090:9090"
    echo "  # Then query: apiserver:availability:ratio_rate5m"

    # Check if SLO PrometheusRules exist
    if kubectl get prometheusrule slo-recording-rules -n $NAMESPACE &> /dev/null; then
        print_success "SLO recording rules configured"
        local slo_rules=$(kubectl get prometheusrule slo-recording-rules -n $NAMESPACE -o json | jq '.spec.groups[].rules | length' | awk '{s+=$1} END {print s}')
        print_info "SLO recording rules count: $slo_rules"
    else
        print_warning "SLO recording rules not found"
    fi

    if kubectl get prometheusrule slo-alert-rules -n $NAMESPACE &> /dev/null; then
        print_success "SLO alert rules configured"
        local slo_alerts=$(kubectl get prometheusrule slo-alert-rules -n $NAMESPACE -o json | jq '.spec.groups[].rules | length' | awk '{s+=$1} END {print s}')
        print_info "SLO alert rules count: $slo_alerts"
    else
        print_warning "SLO alert rules not found"
    fi
}

test_configuration_validity() {
    print_header "Testing Configuration Validity"

    # Check Alertmanager config
    print_info "Validating Alertmanager configuration..."
    if kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- amtool check-config /etc/alertmanager/alertmanager.yaml; then
        print_success "Alertmanager configuration is valid"
    else
        print_error "Alertmanager configuration is invalid"
        return 1
    fi

    # Check secrets exist
    print_info "Checking required secrets..."
    if kubectl get secret alertmanager-secrets -n $NAMESPACE &> /dev/null; then
        print_success "alertmanager-secrets exists"
    else
        print_error "alertmanager-secrets not found"
        return 1
    fi
}

cleanup_test_alerts() {
    print_header "Cleaning Up Test Alerts"

    print_info "Removing test alerts..."

    # Expire all test alerts
    local alert_ids=$(kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- \
        amtool alert query --active category="test" -o json 2>/dev/null | \
        jq -r '.[].labels.alertname' 2>/dev/null || echo "")

    if [ -n "$alert_ids" ]; then
        print_info "Found test alerts to clean up"
        # Test alerts will auto-expire based on end-time
        print_success "Test alerts will auto-expire"
    else
        print_info "No test alerts to clean up"
    fi

    # Clean up any test silences
    local test_silences=$(kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- \
        amtool silence query --expired=false 2>/dev/null | \
        grep "test-script" | \
        awk '{print $1}' || echo "")

    if [ -n "$test_silences" ]; then
        for silence in $test_silences; do
            kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- amtool silence expire "$silence"
            print_info "Expired silence: $silence"
        done
    fi
}

generate_test_report() {
    print_header "Test Summary Report"

    echo -e "${GREEN}Alerting System Test Report${NC}"
    echo -e "Generated: $(date)"
    echo ""

    print_info "Alertmanager Status:"
    kubectl get pods -n $NAMESPACE -l app=alertmanager -o wide
    echo ""

    print_info "PrometheusRules:"
    kubectl get prometheusrule -n $NAMESPACE
    echo ""

    print_info "Current Active Alerts:"
    kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- amtool alert query --active 2>/dev/null || echo "No active alerts"
    echo ""

    print_info "Active Silences:"
    kubectl exec -n $NAMESPACE $ALERTMANAGER_POD -- amtool silence query 2>/dev/null || echo "No active silences"
    echo ""

    print_success "Test execution completed!"
    echo ""

    print_warning "Manual Verification Checklist:"
    echo "  □ Check Slack channels for test notifications"
    echo "  □ Check PagerDuty for test incidents"
    echo "  □ Verify email notifications received"
    echo "  □ Review Alertmanager UI at http://alertmanager.cluster.local"
    echo "  □ Review Prometheus alerts at http://prometheus.cluster.local/alerts"
    echo "  □ Test escalation policies by not acknowledging alerts"
    echo "  □ Verify runbooks are accessible"
    echo ""
}

# Main execution
main() {
    print_header "Alerting System Test Suite"
    echo "Testing alerting and incident management configuration"
    echo ""

    # Run all tests
    check_prerequisites
    test_alertmanager_health
    test_prometheus_rules
    test_alert_routing
    test_configuration_validity
    test_alert_firing
    test_alert_grouping
    test_inhibition_rules
    test_silence
    test_notification_metrics
    test_webhook_integration
    test_slo_alerts

    # Cleanup
    sleep 5
    cleanup_test_alerts

    # Generate report
    generate_test_report
}

# Run main function
main "$@"
