#!/bin/bash
set -e

# Build registry binary for ARM64
# This script builds the Docker registry binary from source for ARM64 architecture
# Usage: ./build-registry-binary.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

start_timer

log_section "Building Registry Binary for ARM64"

check_command "go"
check_command "git"

# Create directories for registry binaries
CURRENT_DIR=$(pwd)
mkdir -p make/photon/registry/binary
mkdir -p make/photon/registryctl/binary

# Clone and build registry from source for ARM64
log_info "Cloning distribution repository..."
DIST_DIR="/tmp/distribution-$$"
git clone --depth 1 https://github.com/distribution/distribution.git "$DIST_DIR"

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
