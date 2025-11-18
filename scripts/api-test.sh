#!/bin/bash
set -e

# Harbor ARM64 API Test Script
# This script runs comprehensive API tests against Harbor
# Usage: ./api-test.sh <version> <docker_username> [base_url]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Check arguments
if [ $# -lt 2 ]; then
    log_error "Usage: $0 <version> <docker_username> [base_url]"
    log_info "Example: $0 v2.11.0 myusername http://localhost:8080"
    exit 1
fi

VERSION=$1
DOCKER_USERNAME=$2
BASE_URL=${3:-"http://localhost:8080"}
VERSION_TAG=$(clean_version_tag "$VERSION")

# Remove trailing slash from base URL
BASE_URL=${BASE_URL%/}

start_timer

log_section "Harbor ARM64 API Test"
log_info "Version: $VERSION"
log_info "Docker Username: $DOCKER_USERNAME"
log_info "Base URL: $BASE_URL"

# Check if Harbor is accessible
log_info "Checking if Harbor is accessible at $BASE_URL..."
if ! curl -sf "$BASE_URL/api/v2.0/ping" -o /dev/null; then
    log_error "Harbor is not accessible at $BASE_URL"
    log_info "Please ensure Harbor is running (e.g., via integration-test.sh)"
    exit 1
fi
log_success "Harbor is accessible"

# Initialize report
REPORT_FILE="harbor-api-test-report-${VERSION_TAG}.md"
cat > "$REPORT_FILE" <<EOF
# Harbor ARM64 API Test Report

**Version**: $VERSION
**Date**: $(date)
**Base URL**: $BASE_URL

---

EOF

# Global test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
LOGGED_IN=false

# Cookie file for session management
COOKIE_FILE="/tmp/harbor-api-test-cookies-$$.txt"
trap "rm -f $COOKIE_FILE" EXIT

# API test helper function
test_api() {
    local name=$1
    local method=$2
    local endpoint=$3
    local expected_status=$4
    local body=$5
    local base_url=${6:-$BASE_URL}

    ((TOTAL_TESTS++))

    log_info "Testing: $name"

    response=$(curl -s -w "\n%{http_code}" \
        -X "$method" \
        -H "Content-Type: application/json" \
        ${body:+-d "$body"} \
        "${base_url}${endpoint}")

    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | head -n-1)

    # Handle multiple acceptable status codes
    if echo "$expected_status" | grep -q ","; then
        # Multiple status codes acceptable
        if echo "$expected_status" | grep -q "$http_code"; then
            log_success "✅ $name: PASSED (HTTP $http_code)"
            echo "- ✅ $name: PASSED (HTTP $http_code)" >> "$REPORT_FILE"
            ((PASSED_TESTS++))
            return 0
        fi
    else
        # Single expected status code
        if [ "$http_code" = "$expected_status" ]; then
            log_success "✅ $name: PASSED (HTTP $http_code)"
            echo "- ✅ $name: PASSED" >> "$REPORT_FILE"
            ((PASSED_TESTS++))
            return 0
        fi
    fi

    log_error "❌ $name: FAILED (Expected: $expected_status, Got: $http_code)"
    if [ -n "$response_body" ]; then
        log_error "Response: $response_body"
    fi
    echo "- ❌ $name: FAILED (Expected: $expected_status, Got: $http_code)" >> "$REPORT_FILE"
    ((FAILED_TESTS++))
    return 1
}

# API test with cookie (authenticated)
test_api_with_cookie() {
    local name=$1
    local method=$2
    local endpoint=$3
    local expected_status=$4
    local body=$5
    local base_url=${6:-$BASE_URL}
    local cookie_file=${7:-$COOKIE_FILE}

    ((TOTAL_TESTS++))

    log_info "Testing: $name (authenticated)"

    response=$(curl -s -w "\n%{http_code}" \
        -X "$method" \
        -H "Content-Type: application/json" \
        -b "$cookie_file" \
        ${body:+-d "$body"} \
        "${base_url}${endpoint}")

    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | head -n-1)

    if [ "$http_code" = "$expected_status" ]; then
        log_success "✅ $name: PASSED (HTTP $http_code)"
        echo "- ✅ $name: PASSED" >> "$REPORT_FILE"
        ((PASSED_TESTS++))
        return 0
    else
        log_error "❌ $name: FAILED (Expected: $expected_status, Got: $http_code)"
        if [ -n "$response_body" ]; then
            log_error "Response: $response_body"
        fi
        echo "- ❌ $name: FAILED (Expected: $expected_status, Got: $http_code)" >> "$REPORT_FILE"
        ((FAILED_TESTS++))
        return 1
    fi
}

# Load test modules
source "${SCRIPT_DIR}/api-tests/test-health.sh"
source "${SCRIPT_DIR}/api-tests/test-auth.sh"
source "${SCRIPT_DIR}/api-tests/test-projects.sh"
source "${SCRIPT_DIR}/api-tests/test-registry.sh"

# Run test suites
echo "## Test Results" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Suite 1: Health Checks
test_health_checks "$BASE_URL"
echo "" >> "$REPORT_FILE"

# Suite 2: Authentication
test_authentication "$BASE_URL" "$COOKIE_FILE"
echo "" >> "$REPORT_FILE"

# Suite 3: Project Management
test_project_management "$BASE_URL" "$COOKIE_FILE"
echo "" >> "$REPORT_FILE"

# Suite 4: Registry Operations
test_registry_operations "$BASE_URL" "$COOKIE_FILE" "localhost:8080"
echo "" >> "$REPORT_FILE"

# Final Summary
log_section "API Test Summary"

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
    echo "**Status**: ✅ All API tests passed!" >> "$REPORT_FILE"
    log_success "All API tests passed!"
else
    echo "**Status**: ❌ Some API tests failed" >> "$REPORT_FILE"
    log_error "Some API tests failed"
fi

echo "" >> "$REPORT_FILE"
echo "---" >> "$REPORT_FILE"
echo "*Report generated on $(date)*" >> "$REPORT_FILE"

# Display report
cat "$REPORT_FILE"

log_info "API test report saved to: $REPORT_FILE"

# Cleanup
rm -f "$COOKIE_FILE"

# Exit with appropriate code
if [ $FAILED_TESTS -eq 0 ]; then
    exit 0
else
    exit 1
fi
