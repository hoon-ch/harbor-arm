#!/bin/bash

# Central configuration file for Harbor ARM64 build system
# This file contains all shared configuration variables and mappings

# Harbor components list
# These are the components that will be built, tested, and pushed
HARBOR_COMPONENTS=(
    "prepare"
    "core"
    "jobservice"
    "portal"
    "nginx"
    "log"
    "db"
    "redis"
    "registry"
    "registryctl"
    "exporter"
)

# Image name mappings: component_name -> actual_image_name
# Some Harbor components use different names for their Docker images
declare -A HARBOR_IMAGE_NAMES=(
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

# Build configuration
BUILD_CONFIG_GO_VERSION="1.24"
BUILD_CONFIG_NODE_VERSION="16.18.0"
BUILD_CONFIG_HARBOR_BASE_NAMESPACE="goharbor"

# Build flags
BUILD_FLAG_NOTARY=false
BUILD_FLAG_TRIVY=true
BUILD_FLAG_GOBUILDTAGS="include_oss include_gcs"

# Registry configuration
REGISTRY_DOCKERHUB="docker.io"
REGISTRY_GHCR="ghcr.io"
IMAGE_SUFFIX="-arm64"

# Testable components (can start standalone)
TESTABLE_COMPONENTS=(
    "redis"
    "db"
)

# Core components for security scanning
SCAN_COMPONENTS=(
    "core"
    "portal"
    "registry"
)

# Retry configuration for network operations
RETRY_MAX_ATTEMPTS=3
RETRY_TIMEOUT_SECONDS=5

# Helper function: Get image name for a component
get_image_name() {
    local component=$1
    echo "${HARBOR_IMAGE_NAMES[$component]}"
}

# Helper function: Build full image reference
get_image_reference() {
    local username=$1
    local component=$2
    local version=$3
    local image_name="${HARBOR_IMAGE_NAMES[$component]}"
    echo "${username}/${image_name}:${version}"
}

# Helper function: Build pushed image reference (with -arm64 suffix)
get_pushed_image_reference() {
    local username=$1
    local component=$2
    local version=$3
    echo "${username}/harbor-${component}${IMAGE_SUFFIX}:${version}"
}

# Helper function: Build GHCR image reference
get_ghcr_image_reference() {
    local repo_owner=$1
    local component=$2
    local version=$3
    echo "${REGISTRY_GHCR}/${repo_owner}/harbor-${component}${IMAGE_SUFFIX}:${version}"
}

# Export configuration
export HARBOR_COMPONENTS
export BUILD_CONFIG_GO_VERSION
export BUILD_CONFIG_NODE_VERSION
export BUILD_CONFIG_HARBOR_BASE_NAMESPACE
export BUILD_FLAG_NOTARY
export BUILD_FLAG_TRIVY
export BUILD_FLAG_GOBUILDTAGS
export REGISTRY_DOCKERHUB
export REGISTRY_GHCR
export IMAGE_SUFFIX
export TESTABLE_COMPONENTS
export SCAN_COMPONENTS
export RETRY_MAX_ATTEMPTS
export RETRY_TIMEOUT_SECONDS

# Export functions
export -f get_image_name
export -f get_image_reference
export -f get_pushed_image_reference
export -f get_ghcr_image_reference
