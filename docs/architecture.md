# Harbor ARM64 Build Architecture

This document describes the architecture and workflow of the Harbor ARM64 build system.

## Overview

This project automates the building, testing, and publishing of selected Harbor container images for ARM64 architecture. The workflow is triggered daily or manually to check for new Harbor releases and build the configured component matrix for ARM64.

## Repository Classification

This is not the Harbor upstream repository and it is not a long-lived source
fork. It is a downstream build/distribution repository. The source of truth for
Harbor code remains `goharbor/harbor`; this repository owns only the automation
that rebuilds, validates, and publishes selected ARM64 images. Signing is
planned as a future hardening step.

## Directory Structure

```
harbor-arm/
├── .github/
│   └── workflows/
│       └── build-harbor-arm64.yml     # Main CI/CD workflow
├── docs/
│   ├── CONTRIBUTING.md                # Contribution guidelines
│   ├── DEPLOYMENT.md                  # Deployment instructions
│   ├── DEVELOPMENT.md                 # Local build and test guide
│   ├── TROUBLESHOOTING.md             # Troubleshooting guide
│   └── architecture.md                # This file
├── examples/
│   ├── docker-compose/
│   │   └── harbor-arm64.yml          # Docker Compose example
│   ├── kubernetes/
│   │   ├── deployment.yaml           # Current Kubernetes example manifest
│   │   ├── harbor-production.yaml    # Kubernetes deployment example
│   │   └── PRODUCTION_DEPLOYMENT.md  # Kubernetes deployment guide
│   └── helm/
│       └── values-arm64.yaml         # Helm values for ARM64
├── scripts/
│   ├── build/                        # Build-related scripts
│   │   ├── build-base-images.sh
│   │   ├── build-harbor-components.sh
│   │   ├── build-registry-binary.sh
│   │   ├── patch-harbor-build.sh
│   │   └── tag-and-push-images.sh
│   ├── test/                         # Test-related scripts
│   │   ├── api-test-simple.sh
│   │   ├── benchmark-simple.sh
│   │   ├── integration-test-simple.sh
│   │   └── validate-images.sh
│   ├── common.sh                     # Common utility functions
│   ├── config.sh                     # Component matrix and image name mapping
│   ├── build-local.sh                # User script for local builds
│   └── push-images.sh                # User script for pushing images
├── built_versions.txt                # Tracks built versions
└── README.md                         # Main documentation

```

## Workflow Pipeline

The CI/CD pipeline consists of 8 main jobs:

### 1. Check Release
- Checks official `goharbor/harbor-core` image tags for the highest stable Harbor version
- Compares with `built_versions.txt`
- Outputs whether a build is needed

### 2. Build Harbor
- Checks out both harbor-arm and Harbor repositories
- Builds base images (harbor-prepare-base, etc.)
- Compiles ARM64 registry binary from source
- Patches Harbor build files for ARM64 compatibility
- Builds selected component images from the `scripts/config.sh` component matrix
- Tags and pushes to Docker Hub and GHCR

### 3. retag-latest
- Runs when release detection determines an already-built version should become `latest`
- Retags existing Docker Hub and GHCR versioned images as `latest`
- Avoids rebuilding images solely to maintain latest tag pointers

### 4. Validate Images
- Verifies image existence and availability
- Confirms ARM64 architecture
- Reports image sizes
- Runs optional standalone smoke checks where supported
- Includes inline Trivy security scan summaries
- Uploads validation markdown reports

### 5. Integration Test
- Tests image availability
- Verifies ARM64 architecture
- Tests Redis container (basic functionality)
- Reports image sizes

### 6. API Test
- Validates that API service images are available
- Ensures all components needed for API functionality exist

### 7. Benchmark
- Measures image pull performance
- Tests container startup times
- Monitors memory usage

### 8. Update Version File
- Adds successfully built version to `built_versions.txt`
- Commits and pushes the update

## Build Scripts

### Build Phase (`scripts/build/`)

1. **build-base-images.sh**
   - Builds harbor-prepare-base image
   - Required for other Harbor components

2. **build-registry-binary.sh**
   - Compiles Docker registry from source for ARM64
   - Uses CGO_ENABLED=0 for static binary

3. **patch-harbor-build.sh**
   - Disables API linting (incompatible with ARM64)
   - Prevents pulling remote images during build
   - Patches Dockerfiles for ARM64 compatibility

4. **build-harbor-components.sh**
   - Builds the configured Harbor component images:
     - Core, Portal, Jobservice
     - Registry, RegistryCtl
     - Nginx, Log, DB, Redis
     - Exporter

5. **tag-and-push-images.sh**
   - Tags images with `-arm64` suffix
   - Pushes to Docker Hub and GHCR
   - Creates `latest` tags only when building the highest stable Harbor image version

### Test Phase (`scripts/test/`)

1. **validate-images.sh**
   - Critical tests: Image existence, ARM64 architecture
   - Optional checks: Standalone smoke checks and security scans
   - Produces markdown validation reports for workflow upload

2. **integration-test-simple.sh**
   - Simplified integration testing
   - Tests basic container functionality

3. **api-test-simple.sh**
   - Validates API component availability

4. **benchmark-simple.sh**
   - Performance measurements

## Image Naming Convention

- **Pushed images**: `{username}/harbor-{component}-arm64:{version}`
- **Internal names**: Follow `HARBOR_IMAGE_NAMES` in `scripts/config.sh`, which maps component keys to Harbor image names such as `harbor-core`, `nginx-photon`, `redis-photon`, and `registry-photon`.

Examples:
- `hoon-ch/harbor-core-arm64:2.15.1` (pushed)
- `hoon-ch/harbor-core:2.15.1` (internal/testing)
- `hoon-ch/nginx-photon:2.15.1` (internal/testing)

## Key Design Decisions

### 1. Simplified Testing
Full Harbor deployment requires extensive configuration files. Our tests validate:
- Images are built correctly
- Architecture is ARM64
- Basic functionality (Redis only)

This approach keeps CI/CD fast while ensuring quality.

### 2. Native ARM64 Builds
Using `ubuntu-24.04-arm` runners provides:
- Faster builds (no emulation)
- True ARM64 compatibility
- Architecture-specific validation

### 3. Dual Registry Push
Images are pushed to both:
- Docker Hub (public access)
- GHCR (GitHub integration)

### 4. Version Tracking
`built_versions.txt` prevents:
- Duplicate builds
- Unnecessary CI/CD runs
- Version conflicts

## Local Development

Users can build locally using:

```bash
# Build Harbor ARM64 images locally
./scripts/build-local.sh v2.15.1

# Push to Docker Hub
DOCKERHUB_USERNAME=your-username ./scripts/push-images.sh 2.15.1
```

## Future Improvements

Potential enhancements:
1. Multi-version support (build multiple versions in parallel)
2. Automated testing with full Harbor deployment
3. Performance comparison with AMD64 builds
4. Automated changelog generation
5. Support for Harbor RC (release candidate) versions
