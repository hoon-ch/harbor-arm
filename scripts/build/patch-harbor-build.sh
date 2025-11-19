#!/bin/bash
set -e

# Patch Harbor build files for ARM64
# This script patches Makefiles and Dockerfiles to use local ARM64 base images
# Usage: ./patch-harbor-build.sh <version>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

# Check arguments
if [ $# -lt 1 ]; then
    log_error "Usage: $0 <version>"
    log_info "Example: $0 v2.11.0"
    exit 1
fi

VERSION=$1

start_timer

log_section "Patching Harbor Build Files for ARM64"
log_info "Version: $VERSION"

# Skip API linting to avoid Spectral build issues
log_info "Disabling API linting in Makefile..."
if [ -f "Makefile" ]; then
    sed -i 's/compile: check_environment lint_apis compile_core compile_jobservice/compile: check_environment compile_core compile_jobservice/' Makefile
    log_success "API linting disabled"
fi

# Patch Harbor Makefile to prevent pulling remote images
log_section "Patching Makefile to Disable Image Pulling"

if [ -f "make/photon/Makefile" ]; then
    # Harbor uses DOCKERBUILD variable - patch it to include --pull=false
    sed -i 's/DOCKERBUILD\s*?=\s*docker/DOCKERBUILD ?= docker/g' make/photon/Makefile
    sed -i '/DOCKERBUILD.*:=/s/$/ --pull=false/' make/photon/Makefile
    sed -i '/DOCKERBUILD.*?=/s/$/ --pull=false/' make/photon/Makefile

    # Also patch any direct docker/buildx build commands
    find make/photon -name "Makefile" -exec sed -i 's/docker buildx build /docker buildx build --pull=false /g' {} \;
    find make/photon -name "Makefile" -exec sed -i 's/docker build /docker build --pull=false /g' {} \;

    # Show what we patched
    log_info "Checking DOCKERBUILD variable:"
    grep "DOCKERBUILD" make/photon/Makefile || log_warning "DOCKERBUILD not found in Makefile"

    log_success "Makefile patched to disable image pulling"
fi

# Patch Dockerfiles to use local ARM64 base images
log_section "Patching Dockerfiles to Use Local ARM64 Base Images"

# Replace FROM lines with ARG variables to hardcoded values
for dockerfile in $(find make/photon -name "Dockerfile" -type f); do
    log_info "Patching $dockerfile..."

    # Replace FROM lines that use variables
    sed -i "s|FROM \${harbor_base_namespace}/harbor-prepare-base:\${harbor_base_image_version}|FROM goharbor/harbor-prepare-base:${VERSION}|g" "$dockerfile"

    # Also handle non-variable format
    sed -i "s|FROM goharbor/harbor-prepare-base:.*|FROM goharbor/harbor-prepare-base:${VERSION}|g" "$dockerfile"

    # Show what we have now (only if there are prepare-base references)
    if grep -q "prepare-base" "$dockerfile"; then
        log_info "$(basename $dockerfile): $(grep 'FROM.*prepare-base' $dockerfile | head -1)"
    fi
done

log_success "All Dockerfiles patched"

end_timer
log_success "Harbor build files patching completed"
