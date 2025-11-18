#!/bin/bash
set -e

# Harbor ARM64 Performance Benchmark Script
# This script measures performance and resource usage of Harbor
# Usage: ./benchmark.sh <version> <docker_username> [base_url]

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
COMPOSE_FILE="docker-compose.test.yml"

# Remove trailing slash
BASE_URL=${BASE_URL%/}

start_timer

log_section "Harbor ARM64 Performance Benchmark"
log_info "Version: $VERSION"
log_info "Docker Username: $DOCKER_USERNAME"
log_info "Base URL: $BASE_URL"

# Check if Harbor is running
if ! curl -sf "$BASE_URL/api/v2.0/ping" -o /dev/null 2>&1; then
    log_error "Harbor is not accessible at $BASE_URL"
    log_info "Please start Harbor first (e.g., via integration-test.sh)"
    exit 1
fi

# Initialize report
REPORT_FILE="harbor-benchmark-report-${VERSION_TAG}.md"
cat > "$REPORT_FILE" <<EOF
# Harbor ARM64 Performance Benchmark Report

**Version**: $VERSION
**Date**: $(date)
**Architecture**: $(uname -m)
**Base URL**: $BASE_URL

---

EOF

# Benchmark 1: Container Startup Times
log_section "Benchmark 1: Container Startup Times"

echo "## Container Startup Times" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ -f "$COMPOSE_FILE" ]; then
    log_info "Reading container startup times from docker compose..."

    # Get container creation times and current time
    echo "| Container | Status | Uptime |" >> "$REPORT_FILE"
    echo "|-----------|--------|--------|" >> "$REPORT_FILE"

    SERVICES=(log redis postgresql registry registryctl core portal jobservice proxy trivy-adapter)

    for service in "${SERVICES[@]}"; do
        container_info=$(docker compose -f "$COMPOSE_FILE" ps --format json 2>/dev/null | \
            jq -r ".[] | select(.Service == \"$service\") | .Name + \" \" + .Status" 2>/dev/null || echo "")

        if [ -n "$container_info" ]; then
            container_name=$(echo "$container_info" | awk '{print $1}')
            status=$(echo "$container_info" | cut -d' ' -f2-)

            # Get uptime
            uptime=$(docker inspect "$container_name" --format='{{.State.StartedAt}}' 2>/dev/null || echo "N/A")

            if [ "$uptime" != "N/A" ]; then
                start_epoch=$(date -d "$uptime" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${uptime:0:19}" +%s 2>/dev/null || echo "0")
                current_epoch=$(date +%s)
                uptime_seconds=$((current_epoch - start_epoch))
                uptime_display="${uptime_seconds}s"
            else
                uptime_display="N/A"
            fi

            echo "| $service | $status | $uptime_display |" >> "$REPORT_FILE"
            log_info "$service: $uptime_display"
        fi
    done

    echo "" >> "$REPORT_FILE"
fi

# Benchmark 2: Resource Usage (Idle State)
log_section "Benchmark 2: Resource Usage (Idle State)"

echo "## Resource Usage (Idle State)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "| Container | CPU % | Memory Usage | Memory Limit |" >> "$REPORT_FILE"
echo "|-----------|-------|--------------|--------------|" >> "$REPORT_FILE"

TOTAL_MEM=0

if [ -f "$COMPOSE_FILE" ]; then
    for service in "${SERVICES[@]}"; do
        container_name=$(docker compose -f "$COMPOSE_FILE" ps --format json 2>/dev/null | \
            jq -r ".[] | select(.Service == \"$service\") | .Name" 2>/dev/null || echo "")

        if [ -n "$container_name" ] && docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
            stats=$(docker stats --no-stream --format "{{.CPUPerc}}\t{{.MemUsage}}" "$container_name" 2>/dev/null || echo "N/A\tN/A")

            cpu=$(echo "$stats" | cut -f1)
            mem_usage=$(echo "$stats" | cut -f2)

            echo "| $service | $cpu | $mem_usage |" >> "$REPORT_FILE"
            log_info "$service: CPU=$cpu, Memory=$mem_usage"

            # Extract memory number for total calculation
            mem_mb=$(echo "$mem_usage" | cut -d'/' -f1 | grep -o '[0-9.]*' | head -1 || echo "0")
            TOTAL_MEM=$(echo "$TOTAL_MEM + $mem_mb" | bc 2>/dev/null || echo "$TOTAL_MEM")
        fi
    done

    echo "| **Total** | - | **${TOTAL_MEM}MiB** | - |" >> "$REPORT_FILE"
    log_info "Total Memory Usage: ${TOTAL_MEM}MiB"
fi

echo "" >> "$REPORT_FILE"

# Benchmark 3: API Response Times
log_section "Benchmark 3: API Response Times"

echo "## API Response Times" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "| Endpoint | Avg (ms) | Min (ms) | Max (ms) |" >> "$REPORT_FILE"
echo "|----------|----------|----------|----------|" >> "$REPORT_FILE"

# Test endpoints
ENDPOINTS=(
    "/api/v2.0/ping"
    "/api/v2.0/health"
    "/api/v2.0/systeminfo"
)

for endpoint in "${ENDPOINTS[@]}"; do
    log_info "Testing endpoint: $endpoint"

    # Run 10 requests and measure response time
    times=()
    for i in {1..10}; do
        response_time=$(curl -o /dev/null -s -w '%{time_total}\n' "${BASE_URL}${endpoint}" 2>/dev/null || echo "0")
        # Convert to milliseconds
        time_ms=$(echo "$response_time * 1000" | bc 2>/dev/null || echo "0")
        times+=("$time_ms")
    done

    # Calculate statistics
    min=$(printf '%s\n' "${times[@]}" | sort -n | head -1)
    max=$(printf '%s\n' "${times[@]}" | sort -n | tail -1)

    # Calculate average
    sum=0
    for t in "${times[@]}"; do
        sum=$(echo "$sum + $t" | bc)
    done
    avg=$(echo "scale=2; $sum / ${#times[@]}" | bc)

    echo "| $endpoint | $avg | $min | $max |" >> "$REPORT_FILE"
    log_info "$endpoint: avg=${avg}ms, min=${min}ms, max=${max}ms"
done

echo "" >> "$REPORT_FILE"

# Benchmark 4: Image Push/Pull Performance
log_section "Benchmark 4: Image Push/Pull Performance"

echo "## Image Push/Pull Performance" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Login to registry
log_info "Logging into Harbor registry..."
echo "Harbor12345" | docker login localhost:8080 -u admin --password-stdin > /dev/null 2>&1 || true

# Create test project
log_info "Creating benchmark test project..."
curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"project_name":"benchmark-test","public":true}' \
    "${BASE_URL}/c/login" > /dev/null 2>&1 || true

curl -s -X POST \
    -H "Content-Type: application/json" \
    -u admin:Harbor12345 \
    -d '{"project_name":"benchmark-test","public":true}' \
    "${BASE_URL}/api/v2.0/projects" > /dev/null 2>&1 || true

sleep 2

# Test images of different sizes
TEST_IMAGES=(
    "alpine:latest:7MB"
    "nginx:alpine:40MB"
)

echo "| Image | Size | Push Time (s) | Pull Time (s) | Throughput (MB/s) |" >> "$REPORT_FILE"
echo "|-------|------|---------------|---------------|-------------------|" >> "$REPORT_FILE"

for test_image in "${TEST_IMAGES[@]}"; do
    image=$(echo "$test_image" | cut -d':' -f1,2)
    size_label=$(echo "$test_image" | cut -d':' -f3)

    log_info "Testing with image: $image ($size_label)"

    # Pull original image
    docker pull "$image" > /dev/null 2>&1 || continue

    # Get actual size
    size_bytes=$(docker image inspect "$image" --format='{{.Size}}' 2>/dev/null || echo "0")
    size_mb=$(echo "scale=2; $size_bytes / 1024 / 1024" | bc)

    # Tag for Harbor
    harbor_image="localhost:8080/benchmark-test/$(echo $image | tr ':' '-'):bench"
    docker tag "$image" "$harbor_image" 2>/dev/null || continue

    # Measure push time
    push_start=$(date +%s.%N)
    docker push "$harbor_image" > /dev/null 2>&1
    push_end=$(date +%s.%N)
    push_time=$(echo "$push_end - $push_start" | bc)

    # Remove local image
    docker rmi "$harbor_image" > /dev/null 2>&1 || true

    # Measure pull time
    pull_start=$(date +%s.%N)
    docker pull "$harbor_image" > /dev/null 2>&1
    pull_end=$(date +%s.%N)
    pull_time=$(echo "$pull_end - $pull_start" | bc)

    # Calculate throughput
    throughput=$(echo "scale=2; $size_mb / $pull_time" | bc)

    echo "| $image | ${size_mb}MB | $push_time | $pull_time | $throughput |" >> "$REPORT_FILE"
    log_info "$image: push=${push_time}s, pull=${pull_time}s, throughput=${throughput}MB/s"

    # Cleanup
    docker rmi "$harbor_image" "$image" > /dev/null 2>&1 || true
done

echo "" >> "$REPORT_FILE"

# Cleanup benchmark project
curl -s -X DELETE \
    -u admin:Harbor12345 \
    "${BASE_URL}/api/v2.0/projects/benchmark-test" > /dev/null 2>&1 || true

docker logout localhost:8080 > /dev/null 2>&1 || true

# Final Summary
log_section "Benchmark Summary"

end_timer

echo "## Summary" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- **Total Memory Usage**: ${TOTAL_MEM}MiB" >> "$REPORT_FILE"
echo "- **Architecture**: $(uname -m)" >> "$REPORT_FILE"
echo "- **Benchmark Duration**: Check execution time above" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "---" >> "$REPORT_FILE"
echo "*Report generated on $(date)*" >> "$REPORT_FILE"

# Display report
cat "$REPORT_FILE"

log_info "Benchmark report saved to: $REPORT_FILE"
log_success "Benchmark completed successfully"

exit 0
