#!/bin/bash

# Common utility functions for Harbor ARM64 build scripts

# Load configuration
SCRIPT_DIR_COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR_COMMON}/config.sh" ]; then
    source "${SCRIPT_DIR_COMMON}/config.sh"
fi

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

# Extract a Go version from a go.mod file.
get_go_mod_go_version() {
    local go_mod_file=${1:-go.mod}

    if [ ! -f "$go_mod_file" ]; then
        log_error "Required go.mod file not found: $go_mod_file" >&2
        return 1
    fi

    local version
    version=$(sed -nE 's/^go[[:space:]]+([0-9]+(\.[0-9]+){1,2}).*/\1/p' "$go_mod_file" | head -n 1)

    if [ -z "$version" ]; then
        log_error "Unable to determine Go version from $go_mod_file" >&2
        return 1
    fi

    echo "$version"
}

# Read the Harbor-required Go version from the checked-out Harbor repository.
get_harbor_go_version() {
    local harbor_dir=${1:-.}
    get_go_mod_go_version "${harbor_dir}/src/go.mod"
}

normalize_go_version() {
    local version=${1#go}

    if [[ "$version" =~ ^[0-9]+\.[0-9]+$ ]]; then
        echo "${version}.0"
    else
        echo "$version"
    fi
}

go_version_at_least() {
    local installed required
    installed=$(normalize_go_version "$1")
    required=$(normalize_go_version "$2")

    [ "$(printf '%s\n%s\n' "$installed" "$required" | sort -V | tail -n 1)" = "$installed" ]
}

ensure_installed_go_matches_harbor_requirement() {
    local harbor_dir=${1:-.}

    check_command "go"

    local required_version installed_version
    required_version=$(get_harbor_go_version "$harbor_dir") || return 1
    installed_version=$(go env GOVERSION 2>/dev/null || true)

    if [ -z "$installed_version" ]; then
        installed_version=$(go version | awk '{print $3}')
    fi

    installed_version=${installed_version#go}

    log_info "Harbor requires Go ${required_version} (from ${harbor_dir}/src/go.mod)"
    log_info "Installed Go toolchain: ${installed_version}"

    if go_version_at_least "$installed_version" "$required_version"; then
        log_success "Installed Go toolchain satisfies Harbor requirement"
        return 0
    fi

    log_error "Installed Go toolchain (${installed_version}) does not satisfy Harbor requirement (${required_version})"
    return 1
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

# Retry command with exponential backoff
retry_command() {
    local max_attempts=${RETRY_MAX_ATTEMPTS:-3}
    local timeout=${RETRY_TIMEOUT_SECONDS:-5}
    local attempt=1
    local exit_code=0

    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            return 0
        else
            exit_code=$?
            if [ $attempt -lt $max_attempts ]; then
                log_warning "Attempt $attempt/$max_attempts failed. Retrying in ${timeout}s..."
                sleep $timeout
                timeout=$((timeout * 2))  # Exponential backoff
            else
                log_error "All $max_attempts attempts failed"
            fi
        fi
        attempt=$((attempt + 1))
    done

    return $exit_code
}

# Retry docker pull with automatic retry
docker_pull_retry() {
    local image=$1
    log_info "Pulling image: $image"
    retry_command docker pull "$image"
}

# Retry docker push with automatic retry
docker_push_retry() {
    local image=$1
    log_info "Pushing image: $image"
    retry_command docker push "$image"
}

# Export functions for use in other scripts
export -f log_info log_success log_warning log_error log_section
export -f exit_on_error check_command
export -f get_go_mod_go_version get_harbor_go_version
export -f normalize_go_version go_version_at_least ensure_installed_go_matches_harbor_requirement
export -f verify_image verify_image_arch list_images
export -f clean_version_tag verify_file verify_directory
export -f get_current_arch show_build_env
export -f start_timer end_timer
export -f retry_command docker_pull_retry docker_push_retry
