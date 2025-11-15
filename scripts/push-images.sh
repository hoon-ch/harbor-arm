#!/bin/bash
set -e

# Harbor ARM64 Image Push Script
# This script pushes locally built Harbor ARM64 images to container registries

VERSION_TAG="${1:-latest}"
DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-}"
COMPONENTS=(prepare core db jobservice log nginx portal redis registry registryctl trivy-adapter)

echo "=================================================="
echo "Harbor ARM64 Image Push Script"
echo "=================================================="
echo "Version: $VERSION_TAG"
echo "=================================================="

# Check if Docker is logged in
if [ -z "$DOCKERHUB_USERNAME" ]; then
    echo "Error: DOCKERHUB_USERNAME environment variable is not set"
    echo "Usage: DOCKERHUB_USERNAME=your-username $0 [version]"
    exit 1
fi

echo "Docker Hub Username: $DOCKERHUB_USERNAME"
echo ""

# Ask for confirmation
read -p "Push images to Docker Hub? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Function to push a component
push_component() {
    local component=$1
    local local_image="harbor-${component}-arm64:${VERSION_TAG}"
    local dockerhub_image="${DOCKERHUB_USERNAME}/harbor-${component}-arm64:${VERSION_TAG}"
    local dockerhub_latest="${DOCKERHUB_USERNAME}/harbor-${component}-arm64:latest"

    echo ""
    echo "Pushing $component..."

    # Check if local image exists
    if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${local_image}$"; then
        echo "Warning: Local image not found: $local_image"
        return 1
    fi

    # Tag for Docker Hub
    docker tag "$local_image" "$dockerhub_image"
    docker tag "$local_image" "$dockerhub_latest"

    # Push to Docker Hub
    docker push "$dockerhub_image"
    if [ "$VERSION_TAG" != "latest" ]; then
        docker push "$dockerhub_latest"
    fi

    echo "✅ Successfully pushed $component"
}

# Push all components
failed_components=()
for component in "${COMPONENTS[@]}"; do
    if ! push_component "$component"; then
        failed_components+=("$component")
    fi
done

# Summary
echo ""
echo "=================================================="
echo "Push Summary"
echo "=================================================="
echo "Version: $VERSION_TAG"
echo "Registry: Docker Hub ($DOCKERHUB_USERNAME)"
echo ""

if [ ${#failed_components[@]} -eq 0 ]; then
    echo "✅ All components pushed successfully!"
else
    echo "⚠️  Some components failed to push:"
    for component in "${failed_components[@]}"; do
        echo "  - $component"
    done
    exit 1
fi
