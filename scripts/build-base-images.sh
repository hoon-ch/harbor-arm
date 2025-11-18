#!/bin/bash
set -e

# Build Harbor base images for ARM64
# This script builds the base Docker images required for Harbor components
# Usage: ./build-base-images.sh <version> <docker_username>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Check arguments
if [ $# -lt 2 ]; then
    log_error "Usage: $0 <version> <docker_username>"
    log_info "Example: $0 v2.11.0 myusername"
    exit 1
fi

VERSION=$1
DOCKER_USERNAME=$2
VERSION_TAG=$(clean_version_tag "$VERSION")

start_timer

log_section "Building Base Images for ARM64"
log_info "Version: $VERSION"
log_info "Version Tag: $VERSION_TAG"
log_info "Docker Username: $DOCKER_USERNAME"
log_info "Architecture: $(uname -m)"

# Verify we're in the Harbor directory
verify_file "make/photon/prepare/Dockerfile.base"

# Check what the base Dockerfile is based on
log_section "Checking Base Image Dependencies"
grep "^FROM" make/photon/prepare/Dockerfile.base || true

# Build harbor-prepare-base for ARM64 - this is the critical one
log_section "Building harbor-prepare-base:${VERSION}"

# Use regular docker build (not buildx) since we might be on native ARM64
# This prevents buildx from pulling remote AMD64 images
docker build \
    -t goharbor/harbor-prepare-base:${VERSION} \
    -t ${DOCKER_USERNAME}/harbor-prepare-base:${VERSION} \
    -f make/photon/prepare/Dockerfile.base \
    make/photon/prepare/

# Verify the image was built
verify_image "goharbor/harbor-prepare-base:${VERSION}" || exit_on_error "Failed to build harbor-prepare-base:${VERSION}"

log_success "Successfully built harbor-prepare-base:${VERSION}"

# Also tag with the exact version tag format Harbor expects
docker tag goharbor/harbor-prepare-base:${VERSION} goharbor/prepare:${VERSION_TAG}
docker tag goharbor/harbor-prepare-base:${VERSION} ${DOCKER_USERNAME}/prepare:${VERSION_TAG}

# Build other base images if they exist
log_section "Building Additional Base Images"

for base_dockerfile in $(find make/photon -name "Dockerfile.base" 2>/dev/null); do
    if [ -f "$base_dockerfile" ] && [ "$base_dockerfile" != "make/photon/prepare/Dockerfile.base" ]; then
        component_dir=$(dirname "$base_dockerfile")
        component_name=$(basename "$component_dir")

        log_info "Building base image for ${component_name}..."

        if docker build \
            -t goharbor/harbor-${component_name}-base:${VERSION} \
            -t ${DOCKER_USERNAME}/harbor-${component_name}-base:${VERSION} \
            -f "$base_dockerfile" \
            "$component_dir/"; then
            log_success "Built base image for ${component_name}"
        else
            log_warning "Failed to build base image for ${component_name}"
        fi
    fi
done

# List all built base images
list_images "harbor.*base|prepare"

end_timer
log_success "Base images build completed"
