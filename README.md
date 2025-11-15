# Harbor ARM64

Automated builds of [Harbor](https://github.com/goharbor/harbor) for ARM64 architecture.

## Overview

This repository automatically tracks new releases of Harbor and builds all components for ARM64 architecture (linux/arm64). Built images are published to both Docker Hub and GitHub Container Registry.

## Features

- ✅ **Automated Release Detection**: Daily checks for new Harbor releases
- ✅ **ARM64 Support**: Native builds for ARM64 architecture
- ✅ **All Components**: Builds all Harbor components
- ✅ **Multi-Registry**: Publishes to Docker Hub and GitHub Container Registry
- ✅ **Manual Triggers**: Support for manual builds of specific versions

## Supported Components

All Harbor components are built for ARM64:

- `harbor-prepare-arm64` - Prepare tool for Harbor installation
- `harbor-core-arm64` - Harbor core services
- `harbor-db-arm64` - PostgreSQL database
- `harbor-jobservice-arm64` - Job service for async tasks
- `harbor-log-arm64` - Log collector
- `harbor-nginx-arm64` - Nginx reverse proxy
- `harbor-portal-arm64` - Web UI
- `harbor-redis-arm64` - Redis cache
- `harbor-registry-arm64` - Docker registry (based on Distribution)
- `harbor-registryctl-arm64` - Registry controller
- `harbor-trivy-adapter-arm64` - Trivy vulnerability scanner adapter

## Quick Start

### Using Pre-built Images

Images are available on Docker Hub and GitHub Container Registry:

```bash
# Docker Hub
docker pull <username>/harbor-core-arm64:latest
docker pull <username>/harbor-core-arm64:v2.11.0

# GitHub Container Registry
docker pull ghcr.io/<owner>/harbor-core-arm64:latest
docker pull ghcr.io/<owner>/harbor-core-arm64:v2.11.0
```

### Local Build

To build Harbor ARM64 images locally:

```bash
# Build latest release
./scripts/build-local.sh

# Build specific version
./scripts/build-local.sh v2.11.0
```

### Push to Registry

To push locally built images to Docker Hub:

```bash
DOCKERHUB_USERNAME=your-username ./scripts/push-images.sh v2.11.0
```

## GitHub Actions Setup

### Required Secrets

Configure the following secrets in your GitHub repository:

1. **Docker Hub** (for Docker Hub publishing):
   - `DOCKERHUB_USERNAME`: Your Docker Hub username
   - `DOCKERHUB_TOKEN`: Docker Hub access token

2. **GitHub Token** (automatically available):
   - `GITHUB_TOKEN`: Used for GitHub Container Registry (no setup needed)

### Workflow Triggers

The workflow can be triggered in two ways:

1. **Automatic (Daily)**:
   - Runs daily at 00:00 UTC
   - Checks for new Harbor releases
   - Builds automatically if a new version is detected

2. **Manual**:
   ```bash
   # Via GitHub UI: Actions → Check and Build Harbor ARM64 → Run workflow
   # Optionally specify a version (e.g., v2.11.0)
   ```

## How It Works

1. **Release Detection**:
   - GitHub Actions checks for new releases from `goharbor/harbor`
   - Compares with previously built versions in `built_versions.txt`

2. **Build Process**:
   - Clones the Harbor repository at the specified version
   - Uses Docker Buildx for ARM64 cross-compilation
   - Builds each component in parallel using matrix strategy

3. **Publishing**:
   - Tags images with version and `latest`
   - Pushes to both Docker Hub and GitHub Container Registry

4. **Version Tracking**:
   - Updates `built_versions.txt` with successfully built versions
   - Prevents duplicate builds

## Directory Structure

```
harbor-arm/
├── .github/
│   └── workflows/
│       └── check-and-build.yml    # Main CI/CD workflow
├── scripts/
│   ├── build-local.sh             # Local build script
│   └── push-images.sh             # Registry push script
├── built_versions.txt             # Tracks built versions
└── README.md                      # This file
```

## Requirements

### For GitHub Actions
- GitHub repository with Actions enabled
- Docker Hub account (optional, for Docker Hub publishing)
- Configured secrets (see above)

### For Local Build
- Docker with Buildx support
- QEMU for ARM64 emulation (if building on x86_64)
- Git

## Platform Support

Currently building for:
- `linux/arm64` (Apple Silicon, AWS Graviton, Raspberry Pi 4, etc.)

## Troubleshooting

### Build Failures

If a component fails to build:

1. Check the GitHub Actions logs for specific error messages
2. Verify the component exists in the Harbor version you're building
3. Some components may have architecture-specific dependencies

### Manual Build Issues

```bash
# Setup QEMU for ARM64 emulation (on x86_64)
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Create buildx builder
docker buildx create --name harbor-arm-builder --use
docker buildx inspect --bootstrap
```

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

This repository follows the same license as Harbor. See the [Harbor repository](https://github.com/goharbor/harbor) for details.

## Upstream

- **Harbor**: https://github.com/goharbor/harbor
- **Harbor Documentation**: https://goharbor.io/docs/

## Disclaimer

This is an unofficial build repository. For official Harbor releases, please visit the [official Harbor repository](https://github.com/goharbor/harbor).

## Support

For issues related to:
- **ARM64 builds**: Open an issue in this repository
- **Harbor functionality**: Please refer to the [official Harbor repository](https://github.com/goharbor/harbor/issues)
