#!/bin/bash
set -e

# Build Harbor components for ARM64
# This script builds all Harbor Docker images for ARM64 architecture
# Usage: ./build-harbor-components.sh <version> <docker_username>

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

log_section "Building Harbor Components for ARM64"
log_info "Version: $VERSION"
log_info "Version Tag: $VERSION_TAG"
log_info "Docker Username: $DOCKER_USERNAME"
show_build_env

# List all our local ARM64 base images
list_images "goharbor|${DOCKER_USERNAME}"

# Compile the Go binaries (including core, jobservice)
log_section "Compiling Go Binaries"
make compile \
    GOBUILDIMAGE=golang:${BUILD_CONFIG_GO_VERSION} \
    COMPILETAG=compile_golangimage \
    BUILDBIN=true \
    NOTARYFLAG=${BUILD_FLAG_NOTARY} \
    TRIVYFLAG=${BUILD_FLAG_TRIVY} \
    GOBUILDTAGS="${BUILD_FLAG_GOBUILDTAGS}"

log_success "Go binaries compiled"

# Compile exporter manually (make target doesn't exist in v2.14.0)
log_section "Compiling Exporter Binary for ARM64"
mkdir -p make/photon/exporter

if [ -d "src/cmd/exporter" ]; then
    log_info "Building exporter from source..."
    cd src/cmd/exporter

    # Build exporter binary for ARM64
    CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -v -o ../../../make/photon/exporter/harbor_exporter .

    cd ../../..

    # Set permissions and verify
    chmod +x make/photon/exporter/harbor_exporter

    log_success "Exporter binary created:"
    file make/photon/exporter/harbor_exporter
    ls -lh make/photon/exporter/harbor_exporter
else
    log_warning "Exporter source directory not found, skipping exporter build"
fi

# Now build each Docker image manually using regular docker build
log_section "Building Docker Images Manually"

# Build prepare image using our local ARM64 base
log_info "Building prepare image..."
docker build \
    --build-arg harbor_base_namespace=goharbor \
    --build-arg harbor_base_image_version=${VERSION} \
    -t ${DOCKER_USERNAME}/prepare:${VERSION_TAG} \
    -f make/photon/prepare/Dockerfile \
    .

# Build core images
for component in core jobservice; do
    log_info "Building $component..."
    if docker build \
        --build-arg harbor_base_namespace=goharbor \
        --build-arg harbor_base_image_version=${VERSION} \
        -t ${DOCKER_USERNAME}/harbor-$component:${VERSION_TAG} \
        -f make/photon/$component/Dockerfile \
        .; then
        log_success "Built $component"
    else
        log_warning "Failed to build $component"
    fi
done

# Build portal with NODE argument
log_info "Building portal..."
if docker build \
    --build-arg harbor_base_namespace=${BUILD_CONFIG_HARBOR_BASE_NAMESPACE} \
    --build-arg harbor_base_image_version=${VERSION} \
    --build-arg NODE=node:${BUILD_CONFIG_NODE_VERSION} \
    -t ${DOCKER_USERNAME}/harbor-portal:${VERSION_TAG} \
    -f make/photon/portal/Dockerfile \
    .; then
    log_success "Built portal"
else
    log_warning "Failed to build portal"
fi

# Build nginx, log, db, redis
for component in nginx log db redis; do
    if [ ! -d "make/photon/$component" ]; then
        log_warning "Component directory not found: $component"
        continue
    fi

    log_info "Building $component..."

    # Determine output image name
    case $component in
        nginx) image_name="nginx-photon" ;;
        redis) image_name="redis-photon" ;;
        *) image_name="harbor-$component" ;;
    esac

    if docker build \
        --build-arg harbor_base_namespace=goharbor \
        --build-arg harbor_base_image_version=${VERSION} \
        -t ${DOCKER_USERNAME}/$image_name:${VERSION_TAG} \
        -f make/photon/$component/Dockerfile \
        .; then
        log_success "Built $component"
    else
        log_warning "Failed to build $component"
    fi
done

# Build registry and registryctl (requires registry binary)
log_info "Building registry..."
if docker build \
    --build-arg harbor_base_namespace=goharbor \
    --build-arg harbor_base_image_version=${VERSION} \
    -t ${DOCKER_USERNAME}/registry-photon:${VERSION_TAG} \
    -f make/photon/registry/Dockerfile \
    .; then
    log_success "Built registry"
else
    log_warning "Failed to build registry"
fi

log_info "Building registryctl..."
if docker build \
    --build-arg harbor_base_namespace=goharbor \
    --build-arg harbor_base_image_version=${VERSION} \
    -t ${DOCKER_USERNAME}/harbor-registryctl:${VERSION_TAG} \
    -f make/photon/registryctl/Dockerfile \
    .; then
    log_success "Built registryctl"
else
    log_warning "Failed to build registryctl"
fi

# Build exporter using our pre-built ARM64 binary
if [ -f "make/photon/exporter/harbor_exporter" ]; then
    log_info "Building exporter..."

    # Create a Dockerfile for exporter
    cat > /tmp/Dockerfile.exporter <<'EOF'
ARG harbor_base_namespace
ARG harbor_base_image_version
FROM ${harbor_base_namespace}/harbor-exporter-base:${harbor_base_image_version}

COPY make/photon/exporter/harbor_exporter /harbor/harbor_exporter
COPY ./make/photon/exporter/entrypoint.sh ./make/photon/common/install_cert.sh /harbor/

RUN chown -R harbor:harbor /etc/pki/tls/certs \
    && chown harbor:harbor /harbor/harbor_exporter && chmod u+x /harbor/harbor_exporter \
    && chown harbor:harbor /harbor/entrypoint.sh && chmod u+x /harbor/entrypoint.sh \
    && chown harbor:harbor /harbor/install_cert.sh && chmod u+x /harbor/install_cert.sh

WORKDIR /harbor
USER harbor

ENTRYPOINT ["/harbor/entrypoint.sh"]
EOF

    if docker build \
        --build-arg harbor_base_namespace=goharbor \
        --build-arg harbor_base_image_version=${VERSION} \
        -t ${DOCKER_USERNAME}/harbor-exporter:${VERSION_TAG} \
        -f /tmp/Dockerfile.exporter \
        .; then
        log_success "Built exporter"
    else
        log_warning "Failed to build exporter"
    fi

    rm -f /tmp/Dockerfile.exporter
else
    log_warning "Exporter binary not found, skipping exporter image build"
fi

# List all built images
log_section "Built Images Summary"
list_images "${DOCKER_USERNAME}"

end_timer
log_success "Harbor components build completed"
