#!/bin/bash
set -e

# Validate Harbor ARM64 images
# This script validates built Harbor images for ARM64 architecture
# Usage: ./validate-images.sh <version> <docker_username> [--full]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Check arguments
if [ $# -lt 2 ]; then
    log_error "Usage: $0 <version> <docker_username> [--full]"
    log_info "Example: $0 v2.11.0 myusername"
    log_info "Add --full flag to run comprehensive tests (slower)"
    exit 1
fi

VERSION=$1
DOCKER_USERNAME=$2
FULL_TEST=${3:-""}
VERSION_TAG=$(clean_version_tag "$VERSION")

start_timer

log_section "Harbor ARM64 Image Validation"
log_info "Version: $VERSION"
log_info "Version Tag: $VERSION_TAG"
log_info "Docker Username: $DOCKER_USERNAME"
log_info "Full Test Mode: $([ "$FULL_TEST" = "--full" ] && echo "Yes" || echo "No")"

# Component list
COMPONENTS=(prepare core db jobservice log nginx portal redis registry registryctl exporter)

# Track validation results
PASSED_TESTS=0
FAILED_TESTS=0
VALIDATION_REPORT="/tmp/harbor-validation-report-$$.md"

# Initialize report
cat > "$VALIDATION_REPORT" <<EOF
# Harbor ARM64 Image Validation Report

**Version**: $VERSION
**Date**: $(date)
**Architecture**: $(uname -m)

## Test Results

EOF

# Test 1: Image Existence
log_section "Test 1: Image Existence Check"

declare -A IMAGE_NAMES=(
    ["prepare"]="prepare"
    ["core"]="harbor-core"
    ["db"]="harbor-db"
    ["jobservice"]="harbor-jobservice"
    ["log"]="harbor-log"
    ["nginx"]="nginx-photon"
    ["portal"]="harbor-portal"
    ["redis"]="redis-photon"
    ["registry"]="registry-photon"
    ["registryctl"]="harbor-registryctl"
    ["exporter"]="harbor-exporter"
)

MISSING_IMAGES=()

for component in "${COMPONENTS[@]}"; do
    IMAGE_NAME="${IMAGE_NAMES[$component]}"
    IMAGE="${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION_TAG}"

    if verify_image "$IMAGE"; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        MISSING_IMAGES+=("$component")
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
done

echo "### Image Existence" >> "$VALIDATION_REPORT"
echo "- **Passed**: $PASSED_TESTS/${#COMPONENTS[@]}" >> "$VALIDATION_REPORT"
if [ ${#MISSING_IMAGES[@]} -gt 0 ]; then
    echo "- **Missing**: ${MISSING_IMAGES[*]}" >> "$VALIDATION_REPORT"
fi
echo "" >> "$VALIDATION_REPORT"

# Test 2: Architecture Verification
log_section "Test 2: Architecture Verification"

ARCH_FAILED=()

for component in "${COMPONENTS[@]}"; do
    IMAGE_NAME="${IMAGE_NAMES[$component]}"
    IMAGE="${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION_TAG}"

    if docker image inspect "$IMAGE" >/dev/null 2>&1; then
        if verify_image_arch "$IMAGE" "arm64"; then
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            ARCH_FAILED+=("$component")
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
done

echo "### Architecture Verification" >> "$VALIDATION_REPORT"
echo "- **Passed**: $(( ${#COMPONENTS[@]} - ${#ARCH_FAILED[@]} ))/${#COMPONENTS[@]}" >> "$VALIDATION_REPORT"
if [ ${#ARCH_FAILED[@]} -gt 0 ]; then
    echo "- **Failed**: ${ARCH_FAILED[*]}" >> "$VALIDATION_REPORT"
fi
echo "" >> "$VALIDATION_REPORT"

# Test 3: Image Size Analysis
log_section "Test 3: Image Size Analysis"

echo "### Image Sizes" >> "$VALIDATION_REPORT"
echo "" >> "$VALIDATION_REPORT"
echo "| Component | Size |" >> "$VALIDATION_REPORT"
echo "|-----------|------|" >> "$VALIDATION_REPORT"

TOTAL_SIZE=0

for component in "${COMPONENTS[@]}"; do
    IMAGE_NAME="${IMAGE_NAMES[$component]}"
    IMAGE="${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION_TAG}"

    if docker image inspect "$IMAGE" >/dev/null 2>&1; then
        SIZE=$(docker image inspect "$IMAGE" --format '{{.Size}}')
        SIZE_MB=$((SIZE / 1024 / 1024))
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        log_info "$component: ${SIZE_MB}MB"
        echo "| $component | ${SIZE_MB}MB |" >> "$VALIDATION_REPORT"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    fi
done

TOTAL_SIZE_MB=$((TOTAL_SIZE / 1024 / 1024))
echo "| **Total** | **${TOTAL_SIZE_MB}MB** |" >> "$VALIDATION_REPORT"
echo "" >> "$VALIDATION_REPORT"

log_info "Total size: ${TOTAL_SIZE_MB}MB"

# Test 4: Basic Smoke Tests (Container Start)
log_section "Test 4: Smoke Tests (Container Startup)"

echo "### Smoke Tests" >> "$VALIDATION_REPORT"
echo "" >> "$VALIDATION_REPORT"

SMOKE_FAILED=()

# Test components that can start standalone
TESTABLE_COMPONENTS=(redis db)

for component in "${TESTABLE_COMPONENTS[@]}"; do
    IMAGE_NAME="${IMAGE_NAMES[$component]}"
    IMAGE="${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION_TAG}"

    if docker image inspect "$IMAGE" >/dev/null 2>&1; then
        log_info "Testing $component startup..."

        CONTAINER_ID=$(docker run -d --rm "$IMAGE" 2>&1)

        if [ $? -eq 0 ]; then
            sleep 3

            # Check if container is still running
            if docker ps | grep -q "$CONTAINER_ID"; then
                log_success "$component started successfully"
                docker stop "$CONTAINER_ID" >/dev/null 2>&1
                echo "- ✅ $component: Started successfully" >> "$VALIDATION_REPORT"
                PASSED_TESTS=$((PASSED_TESTS + 1))
            else
                log_error "$component exited unexpectedly"
                SMOKE_FAILED+=("$component")
                echo "- ❌ $component: Exited unexpectedly" >> "$VALIDATION_REPORT"
                FAILED_TESTS=$((FAILED_TESTS + 1))
            fi
        else
            log_error "$component failed to start"
            SMOKE_FAILED+=("$component")
            echo "- ❌ $component: Failed to start" >> "$VALIDATION_REPORT"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    fi
done

echo "" >> "$VALIDATION_REPORT"

# Test 5: Security Scan (if --full flag is set)
if [ "$FULL_TEST" = "--full" ]; then
    log_section "Test 5: Security Scanning with Trivy"

    # Check if Trivy is installed
    if command -v trivy &> /dev/null; then
        echo "### Security Scan Results" >> "$VALIDATION_REPORT"
        echo "" >> "$VALIDATION_REPORT"

        # Scan core components only (to save time)
        SCAN_COMPONENTS=(core portal registry)

        for component in "${SCAN_COMPONENTS[@]}"; do
            IMAGE_NAME="${IMAGE_NAMES[$component]}"
            IMAGE="${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION_TAG}"

            if docker image inspect "$IMAGE" >/dev/null 2>&1; then
                log_info "Scanning $component for vulnerabilities..."

                SCAN_OUTPUT="/tmp/trivy-scan-$component-$$.txt"
                trivy image --severity HIGH,CRITICAL --quiet "$IMAGE" > "$SCAN_OUTPUT" 2>&1

                VULN_COUNT=$(grep -c "Total:" "$SCAN_OUTPUT" 2>/dev/null || echo "0")

                if [ -s "$SCAN_OUTPUT" ]; then
                    log_warning "$component has vulnerabilities (see report)"
                    echo "- ⚠️ $component: Vulnerabilities found" >> "$VALIDATION_REPORT"
                else
                    log_success "$component: No HIGH/CRITICAL vulnerabilities"
                    echo "- ✅ $component: No HIGH/CRITICAL vulnerabilities" >> "$VALIDATION_REPORT"
                    PASSED_TESTS=$((PASSED_TESTS + 1))
                fi
                TOTAL_TESTS=$((TOTAL_TESTS + 1))

                rm -f "$SCAN_OUTPUT"
            fi
        done

        echo "" >> "$VALIDATION_REPORT"
    else
        log_warning "Trivy not installed, skipping security scan"
        log_info "Install Trivy: https://aquasecurity.github.io/trivy/"
        echo "⚠️ Security scan skipped (Trivy not installed)" >> "$VALIDATION_REPORT"
        echo "" >> "$VALIDATION_REPORT"
    fi
fi

# Final Summary
log_section "Validation Summary"

echo "## Summary" >> "$VALIDATION_REPORT"
echo "" >> "$VALIDATION_REPORT"
echo "- **Total Tests**: $((PASSED_TESTS + FAILED_TESTS))" >> "$VALIDATION_REPORT"
echo "- **Passed**: $PASSED_TESTS" >> "$VALIDATION_REPORT"
echo "- **Failed**: $FAILED_TESTS" >> "$VALIDATION_REPORT"
echo "" >> "$VALIDATION_REPORT"

if [ $FAILED_TESTS -eq 0 ]; then
    echo "**Status**: ✅ All validation tests passed!" >> "$VALIDATION_REPORT"
    log_success "All validation tests passed!"
else
    echo "**Status**: ❌ Some validation tests failed" >> "$VALIDATION_REPORT"
    log_error "Some validation tests failed"
fi

# Display report
cat "$VALIDATION_REPORT"

# Save report to current directory
FINAL_REPORT="harbor-validation-report-${VERSION_TAG}.md"
cp "$VALIDATION_REPORT" "$FINAL_REPORT"
rm -f "$VALIDATION_REPORT"

log_info "Validation report saved to: $FINAL_REPORT"

end_timer

# Exit with appropriate code
if [ $FAILED_TESTS -eq 0 ]; then
    exit 0
else
    exit 1
fi
