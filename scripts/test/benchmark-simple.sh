#!/bin/bash
set -e

# Simplified Harbor ARM64 Benchmark Script
# This script performs basic performance measurements without full Harbor stack
# Usage: ./benchmark-simple.sh <version> <docker_username> [base_url]

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

log_section "Harbor ARM64 Benchmark (Simplified)"
log_info "Version: $VERSION"
log_info "Docker Username: $DOCKER_USERNAME"

# Initialize report
REPORT_FILE="harbor-benchmark-report-${VERSION_TAG}.md"
cat > "$REPORT_FILE" <<EOF
# Harbor ARM64 Benchmark Report

**Version**: $VERSION
**Date**: $(date)
**Architecture**: $(uname -m)

## Benchmark Results

*Note: Full benchmarking requires running Harbor stack. This test measures basic image performance.*

EOF

# Benchmark 1: Image Pull Performance
log_section "Benchmark 1: Image Pull Performance"

echo "### Image Pull Performance" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "| Component | Size (MB) | Pull Time (s) |" >> "$REPORT_FILE"
echo "|-----------|-----------|---------------|" >> "$REPORT_FILE"

COMPONENTS=(core db nginx portal redis registry)

for component in "${COMPONENTS[@]}"; do
    IMAGE="${DOCKER_USERNAME}/harbor-${component}-arm64:${VERSION_TAG}"

    # Remove image if exists to measure pull time
    docker rmi "$IMAGE" >/dev/null 2>&1 || true

    log_info "Pulling $component image..."
    START=$(date +%s.%N)
    if docker pull "$IMAGE" >/dev/null 2>&1; then
        END=$(date +%s.%N)
        DURATION=$(echo "$END - $START" | bc)

        SIZE=$(docker image inspect "$IMAGE" --format '{{.Size}}' 2>/dev/null || echo "0")
        SIZE_MB=$((SIZE / 1024 / 1024))

        echo "| $component | $SIZE_MB | $DURATION |" >> "$REPORT_FILE"
        log_success "$component: ${SIZE_MB}MB in ${DURATION}s"
    else
        echo "| $component | - | Failed |" >> "$REPORT_FILE"
        log_error "$component: Failed to pull"
    fi
done

echo "" >> "$REPORT_FILE"

# Benchmark 2: Container Startup Time (Redis only)
log_section "Benchmark 2: Container Startup Time"

echo "### Container Startup Time" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

REDIS_IMAGE="${DOCKER_USERNAME}/redis-photon:${VERSION_TAG}"
log_info "Testing Redis container startup time..."

START=$(date +%s.%N)
if docker run -d --name redis-bench --rm "$REDIS_IMAGE" redis-server >/dev/null 2>&1; then
    # Wait for Redis to be ready
    for i in {1..10}; do
        if docker exec redis-bench redis-cli ping 2>&1 | grep -q "PONG"; then
            END=$(date +%s.%N)
            STARTUP_TIME=$(echo "$END - $START" | bc)
            echo "- Redis startup time: ${STARTUP_TIME}s" >> "$REPORT_FILE"
            log_success "Redis started in ${STARTUP_TIME}s"
            break
        fi
        sleep 0.5
    done
    docker stop redis-bench >/dev/null 2>&1 || true
else
    echo "- Redis startup: Failed" >> "$REPORT_FILE"
    log_error "Redis failed to start"
fi

echo "" >> "$REPORT_FILE"

# Benchmark 3: Memory Usage
log_section "Benchmark 3: Memory Usage"

echo "### Memory Usage (Idle)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Start Redis container for memory measurement
if docker run -d --name redis-mem --rm "$REDIS_IMAGE" redis-server >/dev/null 2>&1; then
    sleep 2
    STATS=$(docker stats --no-stream --format "{{.MemUsage}}" redis-mem 2>/dev/null || echo "N/A")
    echo "- Redis memory usage: $STATS" >> "$REPORT_FILE"
    log_info "Redis memory: $STATS"
    docker stop redis-mem >/dev/null 2>&1 || true
fi

echo "" >> "$REPORT_FILE"

# Summary
log_section "Benchmark Summary"

end_timer

echo "## Summary" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- **Architecture**: $(uname -m)" >> "$REPORT_FILE"
echo "- **Total Images**: ${#COMPONENTS[@]}" >> "$REPORT_FILE"
echo "- **Benchmark Duration**: Check execution time above" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "**Status**: ✅ Basic benchmarks completed" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "---" >> "$REPORT_FILE"
echo "*Full performance benchmarking requires Harbor stack with configuration.*" >> "$REPORT_FILE"

# Display report
cat "$REPORT_FILE"

log_info "Benchmark report saved to: $REPORT_FILE"
log_success "Basic benchmark completed successfully"

exit 0