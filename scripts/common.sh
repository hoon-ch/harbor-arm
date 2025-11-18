#!/bin/bash

# Common utility functions for Harbor ARM64 build scripts

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

# Error handling
exit_on_error() {
    log_error "$1"
    exit 1
}

# Check if command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        exit_on_error "Required command not found: $1"
    fi
}

# Verify Docker image exists
verify_image() {
    local image=$1
    if docker image inspect "$image" >/dev/null 2>&1; then
        log_success "Image verified: $image"
        return 0
    else
        log_error "Image not found: $image"
        return 1
    fi
}

# Verify Docker image architecture
verify_image_arch() {
    local image=$1
    local expected_arch=$2

    local arch=$(docker image inspect "$image" --format '{{.Architecture}}' 2>/dev/null)

    if [ "$arch" = "$expected_arch" ]; then
        log_success "Image architecture verified: $image ($arch)"
        return 0
    else
        log_error "Image architecture mismatch: $image (expected: $expected_arch, got: $arch)"
        return 1
    fi
}

# List images with filter
list_images() {
    local filter=$1
    log_section "Docker Images (filter: $filter)"
    docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | grep -E "$filter|REPOSITORY" | head -20
}

# Clean version tag (remove 'v' prefix)
clean_version_tag() {
    local version=$1
    echo "${version#v}"
}

# Verify file exists
verify_file() {
    local file=$1
    if [ ! -f "$file" ]; then
        exit_on_error "Required file not found: $file"
    fi
    log_info "File verified: $file"
}

# Verify directory exists
verify_directory() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        exit_on_error "Required directory not found: $dir"
    fi
    log_info "Directory verified: $dir"
}

# Get current architecture
get_current_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        *)
            echo "$arch"
            ;;
    esac
}

# Display build environment info
show_build_env() {
    log_section "Build Environment"
    log_info "Architecture: $(uname -m) ($(get_current_arch))"
    log_info "Docker version: $(docker --version)"
    log_info "Go version: $(go version 2>/dev/null || echo 'not installed')"
    log_info "Buildx version: $(docker buildx version 2>/dev/null || echo 'not installed')"
}

# Measure execution time
start_timer() {
    export TIMER_START=$(date +%s)
}

end_timer() {
    local end=$(date +%s)
    local duration=$((end - TIMER_START))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    log_info "Execution time: ${minutes}m ${seconds}s"
}

# Export functions for use in other scripts
export -f log_info log_success log_warning log_error log_section
export -f exit_on_error check_command
export -f verify_image verify_image_arch list_images
export -f clean_version_tag verify_file verify_directory
export -f get_current_arch show_build_env
export -f start_timer end_timer
