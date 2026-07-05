#!/usr/bin/env bash
set -e

# Build Harbor base images for ARM64
# This script builds the base Docker images required for Harbor components
# Usage: ./build-base-images.sh <version> <docker_username>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

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

FAILED_REQUIRED_BASE_IMAGES=()
FAILED_OPTIONAL_BASE_IMAGES=()

record_base_image_failure() {
    local component=$1

    if is_optional_component "$component"; then
        if [[ " ${FAILED_OPTIONAL_BASE_IMAGES[*]} " != *" $component "* ]]; then
            FAILED_OPTIONAL_BASE_IMAGES+=("$component")
        fi
        log_warning "Optional base image failed: $component"
    else
        if [[ " ${FAILED_REQUIRED_BASE_IMAGES[*]} " != *" $component "* ]]; then
            FAILED_REQUIRED_BASE_IMAGES+=("$component")
        fi
        log_error "Required base image failed: $component"
    fi
}

log_section "Building Base Images for ARM64"
log_info "Version: $VERSION"
log_info "Version Tag: $VERSION_TAG"
log_info "Docker Username: $DOCKER_USERNAME"
log_info "Architecture: $(uname -m)"

# Verify we're in the Harbor directory
verify_file "make/photon/prepare/Dockerfile.base"

log_section "Patching Photon Base Images for ARM64"

patched_files=0
while IFS= read -r base_dockerfile; do
    if grep -Eq 'goharbor/photon:5\.0(-legacy)?' "$base_dockerfile"; then
        sed -i -E 's|goharbor/photon:5\.0(-legacy)?|photon:5.0|g' "$base_dockerfile"
        log_info "Patched $base_dockerfile to use multi-arch photon:5.0"
        patched_files=$((patched_files + 1))
    fi

    # Official multi-arch photon:5.0 has no pinned photon-snapshot repo (that file
    # exists only on goharbor's custom photon), so the db image's snapshot cleanup
    # aborts with "No such file or directory". Make that edit tolerant of a missing
    # file instead of failing the build.
    if grep -q "photon-snapshot.repo" "$base_dockerfile" && ! grep -q "photon-snapshot.repo 2>/dev/null" "$base_dockerfile"; then
        sed -i "s#sed -i '/^snapshot/d' /etc/yum.repos.d/photon-snapshot.repo#& 2>/dev/null || true#" "$base_dockerfile"
        log_info "Made photon-snapshot repo cleanup tolerant in $base_dockerfile"
    fi
done < <(find make/photon -name "Dockerfile.base" -type f 2>/dev/null)

if [ "$patched_files" -eq 0 ]; then
    log_warning "No goharbor/photon:5.0 (or 5.0-legacy) base images found to patch"
else
    log_success "Patched $patched_files Photon base Dockerfile(s)"
fi

# Check what the base Dockerfile is based on
log_section "Checking Base Image Dependencies"
grep "^FROM" make/photon/prepare/Dockerfile.base || true

# Build harbor-prepare-base for ARM64 - this is the critical one
log_section "Building harbor-prepare-base:${VERSION}"

# Use regular docker build (not buildx) since we might be on native ARM64
# This prevents buildx from pulling remote AMD64 images
docker build \
    -t goharbor/harbor-prepare-base:"${VERSION}" \
    -t "${DOCKER_USERNAME}"/harbor-prepare-base:"${VERSION}" \
    -f make/photon/prepare/Dockerfile.base \
    make/photon/prepare/

# Verify the image was built
verify_image "goharbor/harbor-prepare-base:${VERSION}" || exit_on_error "Failed to build harbor-prepare-base:${VERSION}"

log_success "Successfully built harbor-prepare-base:${VERSION}"

# Also tag with the exact version tag format Harbor expects
docker tag goharbor/harbor-prepare-base:"${VERSION}" goharbor/prepare:"${VERSION_TAG}"
docker tag goharbor/harbor-prepare-base:"${VERSION}" "${DOCKER_USERNAME}"/prepare:"${VERSION_TAG}"

# Build other base images if they exist
log_section "Building Additional Base Images"

while IFS= read -r base_dockerfile; do
    if [ -f "$base_dockerfile" ] && [ "$base_dockerfile" != "make/photon/prepare/Dockerfile.base" ]; then
        component_dir=$(dirname "$base_dockerfile")
        component_name=$(basename "$component_dir")

        log_info "Building base image for ${component_name}..."

        if docker build \
            -t goharbor/harbor-"${component_name}"-base:"${VERSION}" \
            -t "${DOCKER_USERNAME}"/harbor-"${component_name}"-base:"${VERSION}" \
            -f "$base_dockerfile" \
            "$component_dir/"; then
            log_success "Built base image for ${component_name}"
        else
            record_base_image_failure "$component_name"
        fi
    fi
done < <(find make/photon -name "Dockerfile.base" -type f 2>/dev/null)

# List all built base images
list_images "harbor.*base|prepare"

if [ ${#FAILED_OPTIONAL_BASE_IMAGES[@]} -gt 0 ]; then
    log_warning "Optional base image failures: ${FAILED_OPTIONAL_BASE_IMAGES[*]}"
fi

if [ ${#FAILED_REQUIRED_BASE_IMAGES[@]} -gt 0 ]; then
    log_error "Required base image failures: ${FAILED_REQUIRED_BASE_IMAGES[*]}"
    exit 1
fi

end_timer
log_success "Base images build completed"
