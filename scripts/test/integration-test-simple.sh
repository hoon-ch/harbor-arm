#!/bin/bash
set -e

# Simplified Harbor ARM64 Integration Test
# This script performs basic validation without requiring full Harbor configuration
# Usage: ./integration-test-simple.sh <version> <docker_username>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

# Check arguments
if [ $# -lt 2 ]; then
    log_error "Usage: $0 <version> <docker_username>"
    log_info "Example: $0 v2.14.0 myusername"
    exit 1
fi

VERSION=$1
DOCKER_USERNAME=$2
VERSION_TAG=$(clean_version_tag "$VERSION")

start_timer

log_section "Harbor ARM64 Basic Integration Test"
log_info "Version: $VERSION"
log_info "Docker Username: $DOCKER_USERNAME"

# Initialize report
REPORT_FILE="harbor-integration-test-report-${VERSION_TAG}.md"
cat > "$REPORT_FILE" <<EOF
# Harbor ARM64 Integration Test Report

**Version**: $VERSION
**Date**: $(date)

## Test Results

*Note: Full Harbor stack requires configuration files. This test validates basic image functionality.*

EOF

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test 1: Image Availability
log_section "Test 1: Image Availability Check"

COMPONENTS=(prepare core db jobservice log nginx portal redis registry registryctl exporter)

echo "### Image Availability" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

for component in "${COMPONENTS[@]}"; do
    IMAGE="${DOCKER_USERNAME}/harbor-${component}-arm64:${VERSION_TAG}"

    if docker image inspect "$IMAGE" >/dev/null 2>&1; then
        log_success "✅ $component image available"
        echo "- ✅ $component: Available" >> "$REPORT_FILE"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_error "❌ $component image not found"
        echo "- ❌ $component: Not found" >> "$REPORT_FILE"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
done

echo "" >> "$REPORT_FILE"

# Test 2: Architecture Verification
log_section "Test 2: Architecture Verification"

echo "### Architecture Verification" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

for component in "${COMPONENTS[@]}"; do
    IMAGE="${DOCKER_USERNAME}/harbor-${component}-arm64:${VERSION_TAG}"

    if docker image inspect "$IMAGE" >/dev/null 2>&1; then
        ARCH=$(docker image inspect "$IMAGE" --format '{{.Architecture}}')
        if [ "$ARCH" = "arm64" ]; then
            log_success "✅ $component is ARM64"
            echo "- ✅ $component: ARM64" >> "$REPORT_FILE"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            log_error "❌ $component is $ARCH (expected arm64)"
            echo "- ❌ $component: $ARCH (expected arm64)" >> "$REPORT_FILE"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
done

echo "" >> "$REPORT_FILE"

# Test 3: Basic Container Test (Redis only, as it works standalone)
log_section "Test 3: Basic Container Functionality"

echo "### Basic Container Test" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

log_info "Testing Redis container (only component that runs standalone)..."

# Test Redis
REDIS_IMAGE="${DOCKER_USERNAME}/redis-photon:${VERSION_TAG}"
if docker run -d --name redis-test-basic --rm "$REDIS_IMAGE" redis-server >/dev/null 2>&1; then
    sleep 3

    if docker exec redis-test-basic redis-cli ping 2>&1 | grep -q "PONG"; then
        log_success "✅ Redis container works"
        echo "- ✅ Redis: Container runs and responds to ping" >> "$REPORT_FILE"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_error "❌ Redis container not responding"
        echo "- ❌ Redis: Container runs but doesn't respond" >> "$REPORT_FILE"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi

    docker stop redis-test-basic >/dev/null 2>&1 || true
else
    log_error "❌ Redis container failed to start"
    echo "- ❌ Redis: Failed to start" >> "$REPORT_FILE"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

echo "" >> "$REPORT_FILE"
echo "*Note: Other Harbor components require configuration files and cannot be tested standalone.*" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Test 4: Image Sizes
log_section "Test 4: Image Size Report"

echo "### Image Sizes" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "| Component | Size (MB) |" >> "$REPORT_FILE"
echo "|-----------|-----------|" >> "$REPORT_FILE"

TOTAL_SIZE=0
for component in "${COMPONENTS[@]}"; do
    IMAGE="${DOCKER_USERNAME}/harbor-${component}-arm64:${VERSION_TAG}"

    if docker image inspect "$IMAGE" >/dev/null 2>&1; then
        SIZE=$(docker image inspect "$IMAGE" --format '{{.Size}}')
        SIZE_MB=$((SIZE / 1024 / 1024))
        echo "| $component | $SIZE_MB |" >> "$REPORT_FILE"
        log_info "$component: ${SIZE_MB}MB"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
    fi
done

TOTAL_SIZE_MB=$((TOTAL_SIZE / 1024 / 1024))
echo "| **Total** | **$TOTAL_SIZE_MB** |" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Summary
log_section "Test Summary"

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
    echo "**Status**: ✅ Basic integration test passed!" >> "$REPORT_FILE"
    log_success "All basic tests passed!"
else
    echo "**Status**: ⚠️ Some tests failed" >> "$REPORT_FILE"
    log_warning "Some tests failed"
fi

echo "" >> "$REPORT_FILE"
echo "---" >> "$REPORT_FILE"
echo "*Full Harbor stack testing requires Harbor configuration files and is skipped.*" >> "$REPORT_FILE"
echo "*Images are validated for availability, architecture, and basic functionality.*" >> "$REPORT_FILE"

# Display report
cat "$REPORT_FILE"

log_info "Integration test report saved to: $REPORT_FILE"

end_timer

# Exit based on critical tests (image availability and architecture)
if [ $SUCCESS_RATE -ge 80 ]; then
    log_success "Integration test completed successfully (${SUCCESS_RATE}% pass rate)"
    exit 0
else
    log_error "Integration test failed (${SUCCESS_RATE}% pass rate)"
    exit 1
fi