#!/bin/bash
set -e

# Harbor ARM64 Local Build Script
# This script builds Harbor components for ARM64 architecture locally

HARBOR_VERSION="${1:-latest}"
COMPONENTS=(prepare core db jobservice log nginx portal redis registry registryctl trivy-adapter)
HARBOR_REPO="https://github.com/goharbor/harbor.git"
BUILD_DIR="./harbor"

echo "=================================================="
echo "Harbor ARM64 Build Script"
echo "=================================================="
echo "Version: $HARBOR_VERSION"
echo "Platform: linux/arm64"
echo "=================================================="

# Check if Docker Buildx is available
if ! docker buildx version &> /dev/null; then
    echo "Error: Docker Buildx is not installed or not available"
    echo "Please install Docker Buildx first"
    exit 1
fi

# Clone Harbor repository if not exists
if [ ! -d "$BUILD_DIR" ]; then
    echo "Cloning Harbor repository..."
    git clone --depth 1 --branch "$HARBOR_VERSION" "$HARBOR_REPO" "$BUILD_DIR"
else
    echo "Harbor repository already exists, pulling latest changes..."
    cd "$BUILD_DIR"
    git fetch origin
    git checkout "$HARBOR_VERSION"
    cd ..
fi

# Get version tag
if [ "$HARBOR_VERSION" = "latest" ]; then
    cd "$BUILD_DIR"
    VERSION_TAG=$(git describe --tags --abbrev=0)
    cd ..
else
    VERSION_TAG="$HARBOR_VERSION"
fi
VERSION_TAG="${VERSION_TAG#v}"

echo "Building version: $VERSION_TAG"

# Setup buildx builder if not exists
if ! docker buildx inspect harbor-arm-builder &> /dev/null; then
    echo "Creating buildx builder..."
    docker buildx create --name harbor-arm-builder --use
else
    echo "Using existing buildx builder..."
    docker buildx use harbor-arm-builder
fi

# Function to build a component
build_component() {
    local component=$1
    local component_dir="$BUILD_DIR/make/photon/$component"

    echo ""
    echo "=================================================="
    echo "Building component: $component"
    echo "=================================================="

    if [ ! -d "$component_dir" ]; then
        echo "Warning: Component directory not found: $component_dir"
        return 1
    fi

    cd "$component_dir"

    # Find Dockerfile
    if [ -f "Dockerfile" ]; then
        DOCKERFILE="Dockerfile"
    elif [ -f "Dockerfile.base" ]; then
        DOCKERFILE="Dockerfile.base"
    else
        echo "Error: No Dockerfile found for $component"
        cd - > /dev/null
        return 1
    fi

    # Build image
    echo "Building from $DOCKERFILE..."
    docker buildx build \
        --platform linux/arm64 \
        --file "$DOCKERFILE" \
        --tag "harbor-${component}-arm64:${VERSION_TAG}" \
        --tag "harbor-${component}-arm64:latest" \
        --load \
        .

    cd - > /dev/null
    echo "✅ Successfully built $component"
}

# Build all components
failed_components=()
for component in "${COMPONENTS[@]}"; do
    if ! build_component "$component"; then
        failed_components+=("$component")
    fi
done

# Summary
echo ""
echo "=================================================="
echo "Build Summary"
echo "=================================================="
echo "Version: $VERSION_TAG"
echo "Platform: linux/arm64"
echo ""

if [ ${#failed_components[@]} -eq 0 ]; then
    echo "✅ All components built successfully!"
else
    echo "⚠️  Some components failed to build:"
    for component in "${failed_components[@]}"; do
        echo "  - $component"
    done
    exit 1
fi

echo ""
echo "To list built images:"
echo "  docker images | grep harbor-.*-arm64"
echo ""
echo "To push to registry, use scripts/push-images.sh"
