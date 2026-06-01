# Harbor ARM64 Deployment Guide

Complete guide for deploying Harbor ARM64 across different platforms.

## Table of Contents

- [Supported Deployment Paths](#supported-deployment-paths)
- [Kubernetes with Helm](#kubernetes-with-helm)
- [Kubernetes Reference Manifests](#kubernetes-reference-manifests)
- [Configuration](#configuration)
- [Post-Installation](#post-installation)

## Supported Deployment Paths

Harbor containers are not supported as individually launched standalone `docker run` services. A working Harbor deployment requires generated configuration, secrets, certificates, component-specific config files, and coordinated service wiring.

Supported deployment paths for these ARM64 images are:

- Official Harbor Helm chart with ARM64 image overrides. See [Kubernetes with Helm](#kubernetes-with-helm) and [`examples/helm/values-arm64.yaml`](../examples/helm/values-arm64.yaml).
- Docker Compose generated through the Harbor `prepare` flow. The compose reference in [`examples/docker-compose/harbor-arm64.yml`](../examples/docker-compose/harbor-arm64.yml) requires generated `common/config`, secrets, and data directories.
- Kubernetes reference manifests that are validated by `scripts/test/e2e-harbor-smoke.sh` or an equivalent CI job before being promoted for production use.

## Kubernetes with Helm

### Prerequisites

- Kubernetes 1.24+
- Helm 3.0+
- ARM64 nodes available
- kubectl configured

### Installation Steps

1. **Add Harbor Helm repository:**

```bash
helm repo add harbor https://helm.goharbor.io
helm repo update
```

2. **Create ARM64 values file** (`values-arm64.yaml`):

```yaml
expose:
  type: loadBalancer
  tls:
    enabled: true
    certSource: auto
    auto:
      commonName: harbor.example.com
  loadBalancer:
    name: harbor
    ports:
      httpPort: 80
      httpsPort: 443

externalURL: https://harbor.example.com

persistence:
  enabled: true
  persistentVolumeClaim:
    registry:
      storageClass: "standard"
      size: 100Gi
    database:
      storageClass: "standard"
      size: 10Gi
    redis:
      storageClass: "standard"
      size: 5Gi

harborAdminPassword: "Harbor12345"

# ARM64 Image Overrides
core:
  image:
    repository: hoon-ch/harbor-core-arm64
    tag: "2.15.1"

jobservice:
  image:
    repository: hoon-ch/harbor-jobservice-arm64
    tag: "2.15.1"

registry:
  registry:
    image:
      repository: hoon-ch/harbor-registry-arm64
      tag: "2.15.1"
  controller:
    image:
      repository: hoon-ch/harbor-registryctl-arm64
      tag: "2.15.1"

portal:
  image:
    repository: hoon-ch/harbor-portal-arm64
    tag: "2.15.1"

database:
  internal:
    image:
      repository: hoon-ch/harbor-db-arm64
      tag: "2.15.1"

redis:
  internal:
    image:
      repository: hoon-ch/harbor-redis-arm64
      tag: "2.15.1"

nginx:
  image:
    repository: hoon-ch/harbor-nginx-arm64
    tag: "2.15.1"

exporter:
  image:
    repository: hoon-ch/harbor-exporter-arm64
    tag: "2.15.1"

# NodeSelector for ARM64
nodeSelector:
  kubernetes.io/arch: arm64
```

3. **Install Harbor:**

```bash
# Create namespace
kubectl create namespace harbor

# Install with Helm
helm install harbor harbor/harbor \
  -f values-arm64.yaml \
  -n harbor \
  --timeout 10m

# Check status
kubectl get pods -n harbor
kubectl get svc -n harbor
```

4. **Get LoadBalancer IP:**

```bash
kubectl get svc harbor -n harbor
```

### Upgrade

```bash
# Update to new version
helm upgrade harbor harbor/harbor \
  -f values-arm64.yaml \
  -n harbor \
  --timeout 10m

# Check upgrade status
helm status harbor -n harbor
```

### Uninstall

```bash
helm uninstall harbor -n harbor
kubectl delete namespace harbor
```

## Kubernetes Reference Manifests

The Kubernetes manifests in `examples/kubernetes/` are reference examples until
they are covered by `scripts/test/e2e-harbor-smoke.sh` or an equivalent CI job.

**See [Kubernetes reference guide](../examples/kubernetes/PRODUCTION_DEPLOYMENT.md)**

Key features:
- Multiple replicas for HA
- HorizontalPodAutoscaler
- PodDisruptionBudgets
- Resource limits and requests
- Health checks
- Security contexts
- Monitoring integration

Use these manifests as reference inputs only. Do not promote them to a
deployment path until they are covered by `scripts/test/e2e-harbor-smoke.sh` or
an equivalent CI job for your target Harbor version and cluster shape.

## Configuration

### SSL/TLS Configuration

#### Generate Self-Signed Certificate

```bash
# Create certificate directory
mkdir -p /data/harbor/ssl
cd /data/harbor/ssl

# Generate private key
openssl genrsa -out harbor.key 4096

# Generate certificate
openssl req -new -x509 -key harbor.key -out harbor.crt -days 365 \
  -subj "/CN=harbor.example.com"

# For Docker Compose, mount certificates:
volumes:
  - /data/harbor/ssl:/etc/nginx/ssl:ro
```

#### Using Let's Encrypt

```bash
# Install certbot
apt-get install certbot

# Get certificate
certbot certonly --standalone \
  -d harbor.example.com \
  --agree-tos \
  --email admin@example.com

# Certificates will be in:
# /etc/letsencrypt/live/harbor.example.com/
```

### Storage Configuration

#### Local Storage

```yaml
# docker-compose.yml
volumes:
  - /data/harbor/registry:/storage
```

#### S3 Storage

```yaml
# Registry configuration
storage:
  s3:
    accesskey: YOUR_ACCESS_KEY
    secretkey: YOUR_SECRET_KEY
    region: us-east-1
    bucket: harbor-registry
```

#### Azure Blob Storage

```yaml
storage:
  azure:
    accountname: YOUR_ACCOUNT
    accountkey: YOUR_KEY
    container: harbor
```

### Database Configuration

#### External PostgreSQL

```yaml
database:
  type: external
  external:
    host: postgres.example.com
    port: 5432
    username: harbor
    password: securepassword
    database: registry
    sslmode: disable
```

### Redis Configuration

#### External Redis

```yaml
redis:
  type: external
  external:
    addr: redis.example.com:6379
    password: redispassword
    db: 0
```

## Post-Installation

### Initial Login

1. Access Harbor UI:
   - URL: http://your-harbor-ip or https://harbor.example.com
   - Username: `admin`
   - Password: `Harbor12345` (or your configured password)

2. **Change admin password immediately!**

### Create First Project

```bash
# Using Harbor UI
1. Click "New Project"
2. Enter project name
3. Set access level (Public/Private)
4. Click "OK"

# Using API
curl -X POST "https://harbor.example.com/api/v2.0/projects" \
  -H "authorization: Basic YWRtaW46SGFyYm9yMTIzNDU=" \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "myproject",
    "public": false
  }'
```

### Configure Docker Client

```bash
# For HTTPS with self-signed cert
mkdir -p /etc/docker/certs.d/harbor.example.com
cp harbor.crt /etc/docker/certs.d/harbor.example.com/ca.crt

# Restart Docker
systemctl restart docker

# Login to Harbor
docker login harbor.example.com
# Username: admin
# Password: Harbor12345

# Push image
docker tag myimage:latest harbor.example.com/myproject/myimage:latest
docker push harbor.example.com/myproject/myimage:latest

# Pull image
docker pull harbor.example.com/myproject/myimage:latest
```

### Setup Replication

1. Go to "Registries" → "New Endpoint"
2. Configure remote registry
3. Create replication rule in "Replications"

### Enable Vulnerability Scanning

1. Go to "Interrogation Services"
2. Configure Trivy scanner
3. Enable "Scan on Push" for projects

## Troubleshooting

See [Troubleshooting Guide](TROUBLESHOOTING.md) for common issues and solutions.

### Quick Checks

```bash
# Check all containers running
docker ps | grep harbor

# Check logs
docker logs harbor-core
docker logs harbor-registry

# For Kubernetes
kubectl get pods -n harbor
kubectl logs -f deployment/harbor-core -n harbor
```

### Common Issues

1. **Cannot access UI**: Check nginx container and port mappings
2. **Cannot push images**: Verify Docker client configuration
3. **Database connection errors**: Check PostgreSQL container and credentials
4. **Registry storage full**: Clean up old images or expand storage

## Next Steps

- [Development Guide](DEVELOPMENT.md) - Build images locally
- [Architecture Guide](architecture.md) - Understand the build system
- [Troubleshooting Guide](TROUBLESHOOTING.md) - Solve common problems
- [Kubernetes Reference Guide](../examples/kubernetes/PRODUCTION_DEPLOYMENT.md) - Reference deployment

## Support

- **Issues**: [GitHub Issues](https://github.com/hoon-ch/harbor-arm/issues)
- **Harbor Docs**: [goharbor.io/docs](https://goharbor.io/docs)
- **Community**: [Harbor Discussions](https://github.com/goharbor/harbor/discussions)
