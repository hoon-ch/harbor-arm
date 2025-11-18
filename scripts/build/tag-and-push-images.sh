#!/bin/bash
set -e

# Tag and push Harbor ARM64 images to registries
# This script tags and pushes built Harbor images to Docker Hub and GHCR
# Usage: ./tag-and-push-images.sh <version> <docker_username> <github_repo_owner>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Check arguments
if [ $# -lt 3 ]; then
    log_error "Usage: $0 <version> <docker_username> <github_repo_owner>"
    log_info "Example: $0 v2.11.0 myusername myorg"
    exit 1
fi

VERSION=$1
DOCKER_USERNAME=$2
GITHUB_REPO_OWNER=$3
VERSION_TAG=$(clean_version_tag "$VERSION")

start_timer

log_section "Tagging and Pushing Harbor ARM64 Images"
log_info "Version: $VERSION"
log_info "Version Tag: $VERSION_TAG"
log_info "Docker Username: $DOCKER_USERNAME"
log_info "GitHub Repo Owner: $GITHUB_REPO_OWNER"

# List built images to understand naming
log_section "Built Images"
docker images | grep ${DOCKER_USERNAME} || docker images | grep ${VERSION_TAG} || true

# The actual image names produced by Harbor's build
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
    ["trivy-adapter"]="trivy-adapter-photon"
)

# Debug: List all docker images to see what was actually built
log_section "All Available Images"
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | sort | head -30

# Track success/failure
PUSHED_IMAGES=()
FAILED_IMAGES=()

# Push all built components
log_section "Pushing Images to Registries"

for component in prepare core db jobservice log nginx portal redis registry registryctl exporter; do
    IMAGE_NAME="${IMAGE_NAMES[$component]}"
    SOURCE_IMAGE="${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION_TAG}"

    log_info "Processing ${component}..."

    # Check if image exists
    if docker image inspect ${SOURCE_IMAGE} >/dev/null 2>&1; then
        log_success "Found ${component} image: ${SOURCE_IMAGE}"

        # Tag for Docker Hub with -arm64 suffix
        docker tag ${SOURCE_IMAGE} ${DOCKER_USERNAME}/harbor-${component}-arm64:${VERSION_TAG}
        docker tag ${SOURCE_IMAGE} ${DOCKER_USERNAME}/harbor-${component}-arm64:latest

        # Tag for GHCR
        docker tag ${SOURCE_IMAGE} ghcr.io/${GITHUB_REPO_OWNER}/harbor-${component}-arm64:${VERSION_TAG}
        docker tag ${SOURCE_IMAGE} ghcr.io/${GITHUB_REPO_OWNER}/harbor-${component}-arm64:latest

        # Push to Docker Hub
        log_info "Pushing to Docker Hub..."
        if docker push ${DOCKER_USERNAME}/harbor-${component}-arm64:${VERSION_TAG} && \
           docker push ${DOCKER_USERNAME}/harbor-${component}-arm64:latest; then
            log_success "Pushed ${component} to Docker Hub"
        else
            log_warning "Failed to push ${component} to Docker Hub"
        fi

        # Push to GHCR
        log_info "Pushing to GHCR..."
        if docker push ghcr.io/${GITHUB_REPO_OWNER}/harbor-${component}-arm64:${VERSION_TAG} && \
           docker push ghcr.io/${GITHUB_REPO_OWNER}/harbor-${component}-arm64:latest; then
            log_success "Pushed ${component} to GHCR"
        else
            log_warning "Failed to push ${component} to GHCR"
        fi

        PUSHED_IMAGES+=("$component")
    else
        log_error "Image not found: ${SOURCE_IMAGE}"
        FAILED_IMAGES+=("$component")
    fi
done

# Summary
log_section "Push Summary"
log_info "Successfully pushed: ${#PUSHED_IMAGES[@]} images"
for img in "${PUSHED_IMAGES[@]}"; do
    log_success "✓ $img"
done

if [ ${#FAILED_IMAGES[@]} -gt 0 ]; then
    log_warning "Failed to push: ${#FAILED_IMAGES[@]} images"
    for img in "${FAILED_IMAGES[@]}"; do
        log_error "✗ $img"
    done
fi

end_timer

if [ ${#FAILED_IMAGES[@]} -eq 0 ]; then
    log_success "All images tagged and pushed successfully"
    exit 0
else
    log_error "Some images failed to push"
    exit 1
fi
