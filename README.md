# Harbor ARM64

Automated builds of [Harbor](https://github.com/goharbor/harbor) for ARM64 architecture.

[![Build Status](https://github.com/hoon-ch/harbor-arm/workflows/Check%20and%20Build%20Harbor%20ARM64/badge.svg)](https://github.com/hoon-ch/harbor-arm/actions)
[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-hoon--ch-blue)](https://hub.docker.com/u/hoon-ch)
[![GitHub Container Registry](https://img.shields.io/badge/GHCR-hoon--ch-purple)](https://github.com/hoon-ch?tab=packages)

## Overview

This repository automatically tracks new releases of Harbor and builds all components for ARM64 architecture (linux/arm64). Built images are published to both Docker Hub and GitHub Container Registry.

Perfect for running Harbor on:
- 🍎 Apple Silicon Macs (M1/M2/M3/M4)
- ☁️ AWS Graviton instances (20-40% cost savings)
- 🔷 Azure ARM-based VMs
- 🍊 Oracle Ampere A1 instances
- 🍓 Raspberry Pi 4/5
- 📱 ARM-based Kubernetes clusters

## Features

- ✅ **Automated Release Detection**: Daily checks for new Harbor releases
- ✅ **ARM64 Native Builds**: Built on ARM64 runners for optimal performance
- ✅ **All Components Included**: Complete Harbor deployment
- ✅ **Multi-Registry Support**: Docker Hub + GitHub Container Registry
- ✅ **Production Ready**: Comprehensive testing and validation
- ✅ **Cost Efficient**: 20-40% cheaper cloud instances

## Quick Start

### Pull Pre-built Images

```bash
# Latest version
docker pull hoon-ch/harbor-core-arm64:latest

# Specific version
docker pull hoon-ch/harbor-core-arm64:2.14.0

# All components available with -arm64 suffix:
# prepare, core, db, jobservice, log, nginx, portal,
# redis, registry, registryctl, exporter
```

### Kubernetes Deployment (Recommended)

For production deployments on Kubernetes:

```bash
# Deploy production-ready configuration
kubectl apply -f examples/kubernetes/harbor-production.yaml

# Get LoadBalancer IP
kubectl get svc harbor-nginx -n harbor
```

**See [Production Deployment Guide](examples/kubernetes/PRODUCTION_DEPLOYMENT.md) for complete instructions.**

### Docker Compose

```bash
# Download compose file
wget https://raw.githubusercontent.com/hoon-ch/harbor-arm/main/examples/docker-compose/harbor-arm64.yml

# Start Harbor
docker-compose -f harbor-arm64.yml up -d

# Access at http://localhost:8080
# Default credentials: admin / Harbor12345
```

## Documentation

- 📖 [Architecture Overview](docs/architecture.md) - Build pipeline and design decisions
- 🚀 [Deployment Guide](docs/DEPLOYMENT.md) - Detailed deployment instructions
- 🔧 [Development Guide](docs/DEVELOPMENT.md) - Local building and testing
- 🐛 [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions
- ☸️ [Kubernetes Production Guide](examples/kubernetes/PRODUCTION_DEPLOYMENT.md) - Production k8s deployment

## Supported Components

All Harbor components are built for ARM64:

| Component | Docker Hub | GHCR | Description |
|-----------|------------|------|-------------|
| prepare | `hoon-ch/harbor-prepare-arm64` | `ghcr.io/hoon-ch/harbor-prepare-arm64` | Installation prepare tool |
| core | `hoon-ch/harbor-core-arm64` | `ghcr.io/hoon-ch/harbor-core-arm64` | Core services |
| db | `hoon-ch/harbor-db-arm64` | `ghcr.io/hoon-ch/harbor-db-arm64` | PostgreSQL database |
| jobservice | `hoon-ch/harbor-jobservice-arm64` | `ghcr.io/hoon-ch/harbor-jobservice-arm64` | Async job processing |
| log | `hoon-ch/harbor-log-arm64` | `ghcr.io/hoon-ch/harbor-log-arm64` | Log collector |
| nginx | `hoon-ch/harbor-nginx-arm64` | `ghcr.io/hoon-ch/harbor-nginx-arm64` | Reverse proxy |
| portal | `hoon-ch/harbor-portal-arm64` | `ghcr.io/hoon-ch/harbor-portal-arm64` | Web UI |
| redis | `hoon-ch/harbor-redis-arm64` | `ghcr.io/hoon-ch/harbor-redis-arm64` | Cache |
| registry | `hoon-ch/harbor-registry-arm64` | `ghcr.io/hoon-ch/harbor-registry-arm64` | Docker registry |
| registryctl | `hoon-ch/harbor-registryctl-arm64` | `ghcr.io/hoon-ch/harbor-registryctl-arm64` | Registry controller |
| exporter | `hoon-ch/harbor-exporter-arm64` | `ghcr.io/hoon-ch/harbor-exporter-arm64` | Metrics exporter |

## Latest Versions

Check [built_versions.txt](built_versions.txt) for all available versions.

Latest: **v2.14.0**

## How It Works

1. **Daily Checks**: GitHub Actions runs daily at 00:00 UTC
2. **Release Detection**: Checks for new Harbor releases via GitHub API
3. **Automated Build**: Triggers ARM64-native build on ubuntu-24.04-arm runners
4. **Comprehensive Testing**: Validates architecture, runs integration tests, benchmarks
5. **Multi-Registry Push**: Publishes to Docker Hub and GHCR
6. **Version Tracking**: Updates `built_versions.txt` to prevent duplicate builds

See [Architecture Documentation](docs/architecture.md) for technical details.

## Manual Build Trigger

To build a specific version:

```bash
# Using GitHub CLI
gh workflow run build-harbor-arm64.yml -f version=v2.14.0

# Or via GitHub Actions UI:
# https://github.com/hoon-ch/harbor-arm/actions
```

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines.

## Performance & Cost

### ARM64 Benefits

- **Cost Savings**: 20-40% cheaper cloud instances
  - AWS Graviton: ~20% cheaper than x86
  - Azure ARM VMs: ~20% cheaper
  - Oracle Ampere A1: Free tier with 4 vCPUs
- **Energy Efficiency**: Lower power consumption
- **Performance**: Native ARM64 builds, no emulation overhead

### Benchmarks

See [Architecture Guide](docs/architecture.md#performance-benchmarks) for detailed benchmark results.

## Requirements

- **Docker**: 20.10+ with ARM64 support
- **Kubernetes**: 1.24+ (for k8s deployment)
- **ARM64 Hardware**: Native ARM64 processor or cloud instance
- **Memory**: Minimum 4GB RAM recommended
- **Storage**: Varies by deployment (10GB+ recommended)

## Security

- All images are built from official Harbor source code
- Trivy security scanning in CI/CD pipeline
- Regular updates following Harbor releases
- See [SECURITY.md](SECURITY.md) for security policy

## License

This project follows the same Apache 2.0 license as Harbor.

## Support

- **Issues**: [GitHub Issues](https://github.com/hoon-ch/harbor-arm/issues)
- **Harbor Docs**: [goharbor.io/docs](https://goharbor.io/docs)
- **Harbor Community**: [GitHub Discussions](https://github.com/goharbor/harbor/discussions)

## Acknowledgments

- [Harbor](https://github.com/goharbor/harbor) - The Cloud Native Registry
- [Distribution](https://github.com/distribution/distribution) - Docker Registry implementation
- All contributors to the Harbor project

---

**Made with ❤️ for the ARM64 community**
