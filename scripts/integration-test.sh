#!/bin/bash
set -e

# Harbor ARM64 Integration Test Script
# This script runs full stack integration tests using Docker Compose
# Usage: ./integration-test.sh <version> <docker_username>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Check arguments
if [ $# -lt 2 ]; then
    log_error "Usage: $0 <version> <docker_username>"
    log_info "Example: $0 v2.11.0 myusername"
    exit 1
fi

VERSION=$1
DOCKER_USERNAME=$2
VERSION_TAG=$(clean_version_tag "$VERSION")

# Test configuration
COMPOSE_FILE="docker-compose.test.yml"
TIMEOUT=300  # 5 minutes timeout for stack to be ready
HEALTH_CHECK_INTERVAL=5

start_timer

log_section "Harbor ARM64 Integration Test"
log_info "Version: $VERSION"
log_info "Version Tag: $VERSION_TAG"
log_info "Docker Username: $DOCKER_USERNAME"
log_info "Compose File: $COMPOSE_FILE"

# Verify compose file exists
verify_file "$COMPOSE_FILE"

# Initialize report
REPORT_FILE="harbor-integration-test-report-${VERSION_TAG}.md"
cat > "$REPORT_FILE" <<EOF
# Harbor ARM64 Integration Test Report

**Version**: $VERSION
**Date**: $(date)
**Test Duration**: (calculating...)

---

## Test Configuration

- Docker Compose File: $COMPOSE_FILE
- Timeout: ${TIMEOUT}s
- Health Check Interval: ${HEALTH_CHECK_INTERVAL}s

---

EOF

# Cleanup function
cleanup() {
    log_section "Cleaning Up Test Environment"

    if [ -f "$COMPOSE_FILE" ]; then
        log_info "Stopping and removing containers..."
        DOCKER_USERNAME=$DOCKER_USERNAME VERSION_TAG=$VERSION_TAG \
            docker compose -f "$COMPOSE_FILE" down -v --remove-orphans 2>/dev/null || true
    fi

    # Remove test network if exists
    docker network rm harbor-test 2>/dev/null || true

    log_success "Cleanup completed"
}

# Set trap for cleanup on exit
trap cleanup EXIT

# Clean up any previous test runs
cleanup

# Test Results Tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

run_test() {
    local test_name=$1
    local test_command=$2

    ((TOTAL_TESTS++))

    log_info "Running: $test_name"

    if eval "$test_command"; then
        log_success "✅ $test_name: PASSED"
        echo "- ✅ $test_name: PASSED" >> "$REPORT_FILE"
        ((PASSED_TESTS++))
        return 0
    else
        log_error "❌ $test_name: FAILED"
        echo "- ❌ $test_name: FAILED" >> "$REPORT_FILE"
        ((FAILED_TESTS++))
        return 1
    fi
}

# Test 1: Start Harbor Stack
log_section "Test 1: Starting Harbor Stack"

log_info "Pulling latest images..."
export DOCKER_USERNAME=$DOCKER_USERNAME
export VERSION_TAG=$VERSION_TAG

# Start the stack
log_info "Starting Harbor stack with docker compose..."
docker compose -f "$COMPOSE_FILE" up -d

if [ $? -ne 0 ]; then
    log_error "Failed to start Harbor stack"
    echo "## ❌ FAILED: Unable to start stack" >> "$REPORT_FILE"
    exit 1
fi

log_success "Stack started successfully"
echo "## Stack Startup" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- ✅ Docker Compose up successful" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Test 2: Wait for Services to be Healthy
log_section "Test 2: Waiting for Services to be Healthy"

echo "## Health Checks" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

SERVICES=(log redis postgresql registry registryctl core portal jobservice proxy trivy-adapter)
START_TIME=$(date +%s)

for service in "${SERVICES[@]}"; do
    log_info "Waiting for $service to be healthy..."

    elapsed=0
    while [ $elapsed -lt $TIMEOUT ]; do
        health_status=$(docker compose -f "$COMPOSE_FILE" ps --format json | \
            jq -r ".[] | select(.Service == \"$service\") | .Health" 2>/dev/null || echo "")

        if [ "$health_status" = "healthy" ]; then
            service_start_time=$(($(date +%s) - START_TIME))
            log_success "$service is healthy (${service_start_time}s)"
            echo "- ✅ $service: healthy (${service_start_time}s)" >> "$REPORT_FILE"
            break
        fi

        sleep $HEALTH_CHECK_INTERVAL
        elapsed=$((elapsed + HEALTH_CHECK_INTERVAL))

        if [ $elapsed -ge $TIMEOUT ]; then
            log_error "$service failed to become healthy within ${TIMEOUT}s"
            echo "- ❌ $service: timeout (${TIMEOUT}s)" >> "$REPORT_FILE"

            # Capture logs for debugging
            log_warning "Capturing logs for $service..."
            docker compose -f "$COMPOSE_FILE" logs --tail=50 "$service" > "${service}-failure.log"
            echo "  - Logs saved to ${service}-failure.log" >> "$REPORT_FILE"
        fi
    done
done

TOTAL_START_TIME=$(($(date +%s) - START_TIME))
log_success "All services health check completed in ${TOTAL_START_TIME}s"
echo "" >> "$REPORT_FILE"
echo "**Total startup time**: ${TOTAL_START_TIME}s" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Test 3: Container Status Verification
log_section "Test 3: Container Status Verification"

echo "## Container Status" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

for service in "${SERVICES[@]}"; do
    container_status=$(docker compose -f "$COMPOSE_FILE" ps --format json | \
        jq -r ".[] | select(.Service == \"$service\") | .State" 2>/dev/null || echo "missing")

    if [ "$container_status" = "running" ]; then
        run_test "Container $service is running" "true"
    else
        run_test "Container $service is running" "false"
        echo "  - Status: $container_status" >> "$REPORT_FILE"
    fi
done

echo "" >> "$REPORT_FILE"

# Test 4: Log Error Analysis
log_section "Test 4: Log Error Analysis"

echo "## Log Analysis" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

for service in "${SERVICES[@]}"; do
    log_info "Analyzing logs for $service..."

    # Get logs
    logs=$(docker compose -f "$COMPOSE_FILE" logs --tail=100 "$service" 2>/dev/null || echo "")

    # Count errors
    fatal_count=$(echo "$logs" | grep -i "FATAL" | wc -l | tr -d ' ')
    error_count=$(echo "$logs" | grep -i "ERROR" | wc -l | tr -d ' ')
    warning_count=$(echo "$logs" | grep -i "WARNING\|WARN" | wc -l | tr -d ' ')

    echo "### $service" >> "$REPORT_FILE"
    echo "- FATAL: $fatal_count" >> "$REPORT_FILE"
    echo "- ERROR: $error_count" >> "$REPORT_FILE"
    echo "- WARNING: $warning_count" >> "$REPORT_FILE"

    if [ "$fatal_count" -gt 0 ]; then
        log_error "$service has $fatal_count FATAL errors"
        echo "  - ❌ Has FATAL errors!" >> "$REPORT_FILE"
        ((FAILED_TESTS++))
    elif [ "$error_count" -gt 5 ]; then
        log_warning "$service has $error_count ERROR messages"
        echo "  - ⚠️  High error count" >> "$REPORT_FILE"
    else
        log_success "$service logs look clean"
        echo "  - ✅ Logs OK" >> "$REPORT_FILE"
        ((PASSED_TESTS++))
    fi

    echo "" >> "$REPORT_FILE"
    ((TOTAL_TESTS++))
done

# Test 5: Service Connectivity
log_section "Test 5: Service Connectivity Tests"

echo "## Service Connectivity" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Test Core -> PostgreSQL
run_test "Core can connect to PostgreSQL" \
    "docker compose -f $COMPOSE_FILE exec -T core sh -c 'timeout 5 nc -zv postgresql 5432' 2>&1 | grep -q 'succeeded\|open'"

# Test Core -> Redis
run_test "Core can connect to Redis" \
    "docker compose -f $COMPOSE_FILE exec -T core sh -c 'timeout 5 nc -zv redis 6379' 2>&1 | grep -q 'succeeded\|open'"

# Test Core -> Registry
run_test "Core can connect to Registry" \
    "docker compose -f $COMPOSE_FILE exec -T core sh -c 'timeout 5 nc -zv registry 5000' 2>&1 | grep -q 'succeeded\|open'"

# Test Jobservice -> Core
run_test "Jobservice can connect to Core" \
    "docker compose -f $COMPOSE_FILE exec -T jobservice sh -c 'timeout 5 nc -zv core 8080' 2>&1 | grep -q 'succeeded\|open'"

echo "" >> "$REPORT_FILE"

# Test 6: HTTP Endpoint Tests
log_section "Test 6: HTTP Endpoint Tests"

echo "## HTTP Endpoints" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Wait a bit for services to fully initialize
sleep 10

# Test Nginx proxy
run_test "Nginx proxy responds on port 8080" \
    "curl -sf -o /dev/null -w '%{http_code}' http://localhost:8080/ | grep -q '200\|302'"

# Test Harbor API health endpoint (through nginx)
run_test "Harbor API health endpoint accessible" \
    "curl -sf http://localhost:8080/api/v2.0/ping -o /dev/null"

# Test Harbor Portal
run_test "Harbor Portal accessible" \
    "curl -sf http://localhost:8080/ -o /dev/null"

# Test Registry v2 API
run_test "Docker Registry v2 API responds" \
    "curl -sf http://localhost:8080/v2/ -o /dev/null"

echo "" >> "$REPORT_FILE"

# Test 7: Resource Usage
log_section "Test 7: Resource Usage Analysis"

echo "## Resource Usage" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "| Container | CPU % | Memory |" >> "$REPORT_FILE"
echo "|-----------|-------|--------|" >> "$REPORT_FILE"

docker compose -f "$COMPOSE_FILE" ps --format json | jq -r '.[].Service' | while read service; do
    container_name=$(docker compose -f "$COMPOSE_FILE" ps --format json | \
        jq -r ".[] | select(.Service == \"$service\") | .Name")

    if [ -n "$container_name" ]; then
        stats=$(docker stats --no-stream --format "{{.CPUPerc}}\t{{.MemUsage}}" "$container_name" 2>/dev/null || echo "N/A\tN/A")
        cpu=$(echo "$stats" | cut -f1)
        mem=$(echo "$stats" | cut -f2 | cut -d'/' -f1 | tr -d ' ')

        echo "| $service | $cpu | $mem |" >> "$REPORT_FILE"
        log_info "$service: CPU=$cpu, Memory=$mem"
    fi
done

echo "" >> "$REPORT_FILE"

# Final Summary
log_section "Integration Test Summary"

end_timer

# Calculate success rate
SUCCESS_RATE=0
if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
fi

echo "## Summary" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- **Total Tests**: $TOTAL_TESTS" >> "$REPORT_FILE"
echo "- **Passed**: $PASSED_TESTS" >> "$REPORT_FILE"
echo "- **Failed**: $FAILED_TESTS" >> "$REPORT_FILE"
echo "- **Success Rate**: ${SUCCESS_RATE}%" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ $FAILED_TESTS -eq 0 ]; then
    echo "**Status**: ✅ All integration tests passed!" >> "$REPORT_FILE"
    log_success "All integration tests passed!"
else
    echo "**Status**: ❌ Some integration tests failed" >> "$REPORT_FILE"
    log_error "Some integration tests failed"
fi

echo "" >> "$REPORT_FILE"
echo "---" >> "$REPORT_FILE"
echo "*Report generated on $(date)*" >> "$REPORT_FILE"

# Display report
cat "$REPORT_FILE"

log_info "Integration test report saved to: $REPORT_FILE"

# Exit with appropriate code
if [ $FAILED_TESTS -eq 0 ]; then
    exit 0
else
    exit 1
fi
