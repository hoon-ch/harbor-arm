#!/usr/bin/env bash
set -e

# Build registry binary for ARM64
# This script builds the Docker registry binary from source for ARM64 architecture
# Usage: ./build-registry-binary.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

normalize_registry_source_ref() {
    local ref=$1

    ref="${ref#\"}"
    ref="${ref%\"}"
    ref="${ref#\'}"
    ref="${ref%\'}"

    if [[ "$ref" =~ ^v ]]; then
        echo "$ref"
    elif [[ "$ref" =~ ^[0-9]+(\.[0-9]+){1,2}([-+][0-9A-Za-z.-]+)?$ ]]; then
        echo "v$ref"
    else
        echo "$ref"
    fi
}

normalize_go_module_registry_ref() {
    local ref=$1

    ref="${ref%%+incompatible}"
    normalize_registry_source_ref "$ref"
}

detect_registry_metadata_value() {
    local harbor_dir=$1
    local variable_name=$2
    local value=""

    while IFS= read -r metadata_file; do
        value=$(sed -nE "s|^[[:space:]]*${variable_name}[[:space:]]*[:?+]?=[[:space:]]*([^[:space:]#]+).*|\\1|p" "$metadata_file" | head -n 1)
        if [ -n "$value" ]; then
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"
            echo "$value"
            return 0
        fi
    done < <(
        # Only Makefiles carry the authoritative variable definitions. Other files
        # under make/photon/registry (e.g. the `builder` shell script whose line
        # reads DISTRIBUTION_SRC="$2") would otherwise pollute detection with
        # positional-parameter placeholders instead of real values.
        find "$harbor_dir" -name Makefile -type f 2>/dev/null
    )

    return 1
}

detect_registry_source_repo() {
    local harbor_dir=$1

    detect_registry_metadata_value "$harbor_dir" "DISTRIBUTION_SRC" || echo "https://github.com/distribution/distribution.git"
}

detect_registry_source_ref() {
    local harbor_dir=$1
    local ref=""

    if ref=$(detect_registry_metadata_value "$harbor_dir" "REGISTRY_SRC_TAG"); then
        normalize_registry_source_ref "$ref"
        return 0
    fi

    if ref=$(detect_registry_metadata_value "$harbor_dir" "REGISTRYVERSION"); then
        normalize_registry_source_ref "$ref"
        return 0
    fi

    if [ -f "$harbor_dir/src/go.mod" ]; then
        ref=$(sed -nE 's/^[[:space:]]*(require[[:space:]]+)?github\.com\/distribution\/distribution(\/v[0-9]+)?[[:space:]]+([^[:space:]]+).*/\3/p' "$harbor_dir/src/go.mod" | head -n 1)
        if [ -z "$ref" ]; then
            ref=$(sed -nE 's/^[[:space:]]*(replace[[:space:]]+)?[^[:space:]]+[[:space:]]+=>[[:space:]]+github\.com\/distribution\/distribution(\/v[0-9]+)?[[:space:]]+([^[:space:]]+).*/\3/p' "$harbor_dir/src/go.mod" | head -n 1)
        fi
        if [ -n "$ref" ]; then
            normalize_go_module_registry_ref "$ref"
            return 0
        fi
    fi

    return 1
}

start_timer

log_section "Building Registry Binary for ARM64"

check_command "go"
check_command "git"

HARBOR_GO_VERSION=$(get_harbor_go_version ".") || exit_on_error "Failed to detect Harbor Go version from src/go.mod"
ensure_installed_go_matches_harbor_requirement "." || exit_on_error "Installed Go toolchain does not meet Harbor requirements"
log_info "Using installed Go toolchain compatible with Harbor requirement ${HARBOR_GO_VERSION}"

# Create directories for registry binaries
CURRENT_DIR=$(pwd)
mkdir -p make/photon/registry/binary
mkdir -p make/photon/registryctl/binary

REGISTRY_SOURCE_REPO="${REGISTRY_SOURCE_REPO:-$(detect_registry_source_repo "$CURRENT_DIR")}"
if [ -z "${REGISTRY_SOURCE_REF:-}" ]; then
    if ! REGISTRY_SOURCE_REF=$(detect_registry_source_ref "$CURRENT_DIR"); then
        log_error "Unable to detect distribution/distribution source ref from Harbor source."
        log_error "Set REGISTRY_SOURCE_REF explicitly, or ensure Harbor source includes REGISTRY_SRC_TAG, REGISTRYVERSION, or github.com/distribution/distribution in src/go.mod."
        exit 1
    fi
fi

log_info "Registry source repository: ${REGISTRY_SOURCE_REPO}"
log_info "Registry source ref: ${REGISTRY_SOURCE_REF}"

# Clone and build registry from source for ARM64
log_info "Cloning distribution repository..."
DIST_DIR="/tmp/distribution-$$"
git clone --depth 1 --branch "$REGISTRY_SOURCE_REF" "$REGISTRY_SOURCE_REPO" "$DIST_DIR"

cd "$DIST_DIR"

# Verify go.mod exists
verify_file "go.mod"

# Download dependencies
log_info "Downloading Go dependencies..."
go mod vendor

# Build registry binary for ARM64
log_info "Building registry binary for ARM64..."
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -v -o /tmp/registry-bin ./cmd/registry

chmod +x /tmp/registry-bin

# Verify binary architecture
log_info "Verifying binary architecture..."
file /tmp/registry-bin

# Copy to Harbor build directories
log_info "Copying binary to Harbor directories..."
cp /tmp/registry-bin "${CURRENT_DIR}/make/photon/registry/binary/registry"
cp /tmp/registry-bin "${CURRENT_DIR}/make/photon/registryctl/binary/registry"

cd "$CURRENT_DIR"

# Cleanup
rm -rf "$DIST_DIR"

# Verify the binaries
log_section "Registry Binary Build Summary"
log_info "Registry binary location:"
ls -lh make/photon/registry/binary/registry
log_info "Registryctl binary location:"
ls -lh make/photon/registryctl/binary/registry

log_info "Binary architecture:"
file make/photon/registry/binary/registry

end_timer
log_success "Registry binary build completed"
