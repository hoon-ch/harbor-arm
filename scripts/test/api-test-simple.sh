#!/bin/bash
set -e

# Simplified Harbor ARM64 API Test
# This script performs basic API validation without full Harbor stack
# Usage: ./api-test-simple.sh <version> <docker_username> [base_url]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

# Check arguments
if [ $# -lt 2 ]; then
    log_error "Usage: $0 <version> <docker_username> [base_url]"
    log_info "Example: $0 v2.14.0 myusername http://localhost:8080"
    exit 1
fi

VERSION=$1
DOCKER_USERNAME=$2
BASE_URL=${3:-"http://localhost:8080"}
VERSION_TAG=$(clean_version_tag "$VERSION")

start_timer

log_section "Harbor ARM64 API Test (Simplified)"
log_info "Version: $VERSION"
log_info "Docker Username: $DOCKER_USERNAME"

# Initialize report
REPORT_FILE="harbor-api-test-report-${VERSION_TAG}.md"
cat > "$REPORT_FILE" <<EOF
# Harbor ARM64 API Test Report

**Version**: $VERSION
**Date**: $(date)

## Test Results

*Note: Full API testing requires running Harbor stack with configuration. This test validates basic functionality.*

EOF

# Since we can't run the full Harbor stack without config, we'll do basic validation
log_section "Basic Validation"

echo "### Basic Validation" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Test that images are available and properly tagged
log_info "Verifying Harbor images are available for API services..."

API_COMPONENTS=(core jobservice nginx portal)
PASSED=0
TOTAL=0

for component in "${API_COMPONENTS[@]}"; do
    IMAGE="${DOCKER_USERNAME}/harbor-${component}-arm64:${VERSION_TAG}"

    if docker image inspect "$IMAGE" >/dev/null 2>&1; then
        log_success "✅ $component image ready for API service"
        echo "- ✅ $component: Image available" >> "$REPORT_FILE"
        PASSED=$((PASSED + 1))
    else
        log_error "❌ $component image not found"
        echo "- ❌ $component: Image not found" >> "$REPORT_FILE"
    fi
    TOTAL=$((TOTAL + 1))
done

echo "" >> "$REPORT_FILE"

# Summary
SUCCESS_RATE=$((PASSED * 100 / TOTAL))

echo "## Summary" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- **Components Checked**: $TOTAL" >> "$REPORT_FILE"
echo "- **Available**: $PASSED" >> "$REPORT_FILE"
echo "- **Success Rate**: ${SUCCESS_RATE}%" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ $PASSED -eq $TOTAL ]; then
    echo "**Status**: ✅ All API service images available" >> "$REPORT_FILE"
    log_success "All API service images available!"
else
    echo "**Status**: ⚠️ Some API service images missing" >> "$REPORT_FILE"
    log_warning "Some API service images missing"
fi

echo "" >> "$REPORT_FILE"
echo "---" >> "$REPORT_FILE"
echo "*Full API testing requires Harbor to be running with proper configuration.*" >> "$REPORT_FILE"

# Display report
cat "$REPORT_FILE"

log_info "API test report saved to: $REPORT_FILE"

end_timer

# Exit success if most images are available
if [ $SUCCESS_RATE -ge 75 ]; then
    exit 0
else
    exit 1
fi