# Harbor ARM64

Automated builds of [Harbor](https://github.com/goharbor/harbor) for ARM64 architecture.

[![Build Status](https://github.com/hoon-ch/harbor-arm/workflows/Check%20and%20Build%20Harbor%20ARM64/badge.svg)](https://github.com/hoon-ch/harbor-arm/actions)
[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-hoon--ch-blue)](https://hub.docker.com/u/hoon-ch)
[![GitHub Container Registry](https://img.shields.io/badge/GHCR-hoon--ch-purple)](https://github.com/hoon-ch?tab=packages)

## Overview

This repository automatically tracks new releases of Harbor and builds all components for ARM64 architecture (linux/arm64). Built images are published to both Docker Hub and GitHub Container Registry.

Perfect for running Harbor on:
- 🍎 Apple Silicon Macs (M1/M2/M3)
- ☁️ AWS Graviton instances
- 🔷 Azure ARM-based VMs
- 🍊 Oracle Ampere A1 instances
- 🍓 Raspberry Pi 4/5
- 📱 ARM-based Kubernetes clusters

## Features

- ✅ **Automated Release Detection**: Daily checks for new Harbor releases
- ✅ **ARM64 Support**: Native builds for ARM64 architecture
- ✅ **All Components**: Builds all Harbor components
- ✅ **Multi-Registry**: Publishes to Docker Hub and GitHub Container Registry
- ✅ **Manual Triggers**: Support for manual builds of specific versions
- ✅ **Latest Version**: Currently supports Harbor v2.13.0+

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
docker pull hoon-ch/harbor-core-arm64:latest
docker pull hoon-ch/harbor-core-arm64:2.13.0

# GitHub Container Registry
docker pull ghcr.io/hoon-ch/harbor-core-arm64:latest
docker pull ghcr.io/hoon-ch/harbor-core-arm64:2.13.0
```

## 🚀 Deployment Guides

### 🐳 Docker Standalone

Run individual Harbor components with Docker:

```bash
# Create network
docker network create harbor

# Run Redis
docker run -d \
  --name harbor-redis \
  --network harbor \
  --restart always \
  hoon-ch/harbor-redis-arm64:2.13.0

# Run Database
docker run -d \
  --name harbor-db \
  --network harbor \
  --restart always \
  -e POSTGRES_PASSWORD=rootpassword \
  -v /data/harbor/database:/var/lib/postgresql/data \
  hoon-ch/harbor-db-arm64:2.13.0

# Run Core
docker run -d \
  --name harbor-core \
  --network harbor \
  --restart always \
  -e DATABASE_TYPE=postgresql \
  -e POSTGRESQL_HOST=harbor-db \
  -e POSTGRESQL_PORT=5432 \
  -e POSTGRESQL_USERNAME=postgres \
  -e POSTGRESQL_PASSWORD=rootpassword \
  -e POSTGRESQL_DATABASE=registry \
  -v /data/harbor/core:/data \
  hoon-ch/harbor-core-arm64:2.13.0
```

### 🎼 Docker Compose

Complete Harbor deployment with Docker Compose:

```yaml
# docker-compose.yml
version: '3.8'

services:
  redis:
    image: hoon-ch/harbor-redis-arm64:2.13.0
    container_name: harbor-redis
    restart: always
    networks:
      - harbor

  db:
    image: hoon-ch/harbor-db-arm64:2.13.0
    container_name: harbor-db
    restart: always
    environment:
      POSTGRES_PASSWORD: rootpassword
    volumes:
      - /data/harbor/database:/var/lib/postgresql/data
    networks:
      - harbor

  core:
    image: hoon-ch/harbor-core-arm64:2.13.0
    container_name: harbor-core
    restart: always
    environment:
      DATABASE_TYPE: postgresql
      POSTGRESQL_HOST: db
      POSTGRESQL_PORT: 5432
      POSTGRESQL_USERNAME: postgres
      POSTGRESQL_PASSWORD: rootpassword
      POSTGRESQL_DATABASE: registry
      REDIS_HOST: redis
      REDIS_PORT: 6379
    volumes:
      - /data/harbor/core:/data
    networks:
      - harbor
    depends_on:
      - db
      - redis

  jobservice:
    image: hoon-ch/harbor-jobservice-arm64:2.13.0
    container_name: harbor-jobservice
    restart: always
    environment:
      DATABASE_TYPE: postgresql
      POSTGRESQL_HOST: db
      REDIS_HOST: redis
    volumes:
      - /data/harbor/job_logs:/var/log/jobs
    networks:
      - harbor
    depends_on:
      - db
      - redis
      - core

  registry:
    image: hoon-ch/harbor-registry-arm64:2.13.0
    container_name: harbor-registry
    restart: always
    volumes:
      - /data/harbor/registry:/storage
    networks:
      - harbor

  registryctl:
    image: hoon-ch/harbor-registryctl-arm64:2.13.0
    container_name: harbor-registryctl
    restart: always
    environment:
      REGISTRY_HTTP_SECRET: secretkey
    volumes:
      - /data/harbor/registry:/storage
    networks:
      - harbor
    depends_on:
      - registry

  portal:
    image: hoon-ch/harbor-portal-arm64:2.13.0
    container_name: harbor-portal
    restart: always
    networks:
      - harbor
    depends_on:
      - core

  nginx:
    image: hoon-ch/harbor-nginx-arm64:2.13.0
    container_name: harbor-nginx
    restart: always
    ports:
      - "80:8080"
      - "443:8443"
    volumes:
      - /data/harbor/nginx:/etc/nginx
    networks:
      - harbor
    depends_on:
      - portal
      - core
      - registry

  trivy-adapter:
    image: hoon-ch/harbor-trivy-adapter-arm64:2.13.0
    container_name: harbor-trivy-adapter
    restart: always
    environment:
      SCANNER_TRIVY_CACHE_DIR: /home/scanner/.cache/trivy
      SCANNER_TRIVY_REPORTS_DIR: /home/scanner/.cache/reports
    volumes:
      - /data/harbor/trivy-adapter:/home/scanner/.cache
    networks:
      - harbor

networks:
  harbor:
    driver: bridge
```

Start Harbor with Docker Compose:

```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f

# Stop all services
docker-compose down
```

### ☸️ Kubernetes Deployment

#### Using Helm Chart

1. **Add Harbor Helm repository:**
```bash
helm repo add harbor https://helm.goharbor.io
helm repo update
```

2. **Create custom values for ARM64:**

```yaml
# values-arm64.yaml
expose:
  type: ingress
  tls:
    enabled: true
  ingress:
    hosts:
      core: harbor.example.com

externalURL: https://harbor.example.com

persistence:
  enabled: true
  persistentVolumeClaim:
    registry:
      size: 50Gi
    database:
      size: 10Gi
    redis:
      size: 1Gi

harborAdminPassword: "Harbor12345"

# ARM64 Image Overrides
core:
  image:
    repository: hoon-ch/harbor-core-arm64
    tag: 2.13.0

jobservice:
  image:
    repository: hoon-ch/harbor-jobservice-arm64
    tag: 2.13.0

registry:
  registry:
    image:
      repository: hoon-ch/harbor-registry-arm64
      tag: 2.13.0
  controller:
    image:
      repository: hoon-ch/harbor-registryctl-arm64
      tag: 2.13.0

portal:
  image:
    repository: hoon-ch/harbor-portal-arm64
    tag: 2.13.0

trivy:
  enabled: true
  image:
    repository: hoon-ch/harbor-trivy-adapter-arm64
    tag: 2.13.0

database:
  type: internal
  internal:
    image:
      repository: hoon-ch/harbor-db-arm64
      tag: 2.13.0

redis:
  type: internal
  internal:
    image:
      repository: hoon-ch/harbor-redis-arm64
      tag: 2.13.0

nginx:
  image:
    repository: hoon-ch/harbor-nginx-arm64
    tag: 2.13.0

# Ensure pods are scheduled on ARM64 nodes
nodeSelector:
  kubernetes.io/arch: arm64

# Optional: Toleration for ARM64 nodes
tolerations:
  - key: "arch"
    operator: "Equal"
    value: "arm64"
    effect: "NoSchedule"
```

3. **Deploy Harbor:**
```bash
# Create namespace
kubectl create namespace harbor

# Install Harbor
helm install harbor harbor/harbor \
  -f values-arm64.yaml \
  -n harbor

# Check deployment status
kubectl get pods -n harbor
kubectl get svc -n harbor
kubectl get ingress -n harbor

# Get admin password (if not set in values)
kubectl get secret harbor-core -n harbor -o jsonpath="{.data.HARBOR_ADMIN_PASSWORD}" | base64 -d
```

#### Manual Kubernetes Deployment

For a simple deployment without Helm:

```yaml
# harbor-arm64-k8s.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: harbor
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: harbor-db
  namespace: harbor
spec:
  replicas: 1
  selector:
    matchLabels:
      app: harbor-db
  template:
    metadata:
      labels:
        app: harbor-db
    spec:
      nodeSelector:
        kubernetes.io/arch: arm64
      containers:
      - name: postgres
        image: hoon-ch/harbor-db-arm64:2.13.0
        env:
        - name: POSTGRES_PASSWORD
          value: "rootpassword"
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: db-data
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: db-data
        persistentVolumeClaim:
          claimName: harbor-db-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: harbor-db
  namespace: harbor
spec:
  selector:
    app: harbor-db
  ports:
  - port: 5432
    targetPort: 5432
---
# Add similar deployments for other components...
```

### 🔧 Configuration Tips

#### Storage Configuration
```bash
# Create directories for persistent storage
sudo mkdir -p /data/harbor/{database,registry,redis,core,jobservice}
sudo chown -R 10000:10000 /data/harbor
```

#### TLS/SSL Setup
```bash
# Generate self-signed certificate
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes

# Mount in nginx container
-v /path/to/cert.pem:/etc/nginx/cert/server.crt
-v /path/to/key.pem:/etc/nginx/cert/server.key
```

#### Performance Tuning for ARM64
```yaml
# Recommended resource limits for ARM64
resources:
  limits:
    cpu: 2
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 512Mi
```

### Local Build

To build Harbor ARM64 images locally:

```bash
# Build latest release
./scripts/build-local.sh

# Build specific version
./scripts/build-local.sh v2.13.0
```

### Push to Registry

To push locally built images to Docker Hub:

```bash
DOCKERHUB_USERNAME=your-username ./scripts/push-images.sh v2.13.0
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

## 🔍 Verification

### Check ARM64 Architecture

Verify that images are built for ARM64:

```bash
# Check image architecture
docker inspect hoon-ch/harbor-core-arm64:2.13.0 | grep Architecture
# Output: "Architecture": "arm64"

# Or use docker manifest
docker manifest inspect hoon-ch/harbor-core-arm64:2.13.0 | grep architecture
# Output: "architecture": "arm64"
```

### Test on ARM64 Machine

```bash
# On Apple Silicon Mac, AWS Graviton, or Raspberry Pi
docker run --rm hoon-ch/harbor-core-arm64:2.13.0 harbor_core --version
```

## 📊 Available Versions

| Version | Status | Docker Hub | GHCR | Notes |
|---------|--------|------------|------|-------|
| v2.13.0 | ✅ Built | ✅ Available | ✅ Available | Latest stable |
| v2.13.1 | 🔄 Auto-build | When released | When released | Automated |
| v2.14.0 | 🔄 Auto-build | When released | When released | Automated |

Check all available tags:
- Docker Hub: https://hub.docker.com/u/hoon-ch
- GitHub Packages: https://github.com/hoon-ch?tab=packages

## 🛠 Troubleshooting

### Common Issues

#### 1. Image Pull Error on non-ARM64 machines

```bash
# Error: exec format error
# Solution: These images are ARM64 only. Use on ARM64 machines or enable QEMU emulation:
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

#### 2. Pod not scheduling in Kubernetes

```bash
# Check node architecture
kubectl get nodes -o custom-columns=NAME:.metadata.name,ARCH:.status.nodeInfo.architecture

# Ensure nodeSelector is set
nodeSelector:
  kubernetes.io/arch: arm64
```

#### 3. Storage permission issues

```bash
# Harbor uses UID 10000
sudo chown -R 10000:10000 /data/harbor
```

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
