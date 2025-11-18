# Harbor ARM64 Deployment Guide

Complete guide for deploying Harbor ARM64 across different platforms.

## Table of Contents

- [Docker Standalone](#docker-standalone)
- [Docker Compose](#docker-compose)
- [Kubernetes with Helm](#kubernetes-with-helm)
- [Kubernetes Production](#kubernetes-production)
- [Configuration](#configuration)
- [Post-Installation](#post-installation)

## Docker Standalone

### Prerequisites

- Docker 20.10+ with ARM64 support
- Minimum 4GB RAM
- 20GB free disk space

### Quick Start

Run individual Harbor components:

```bash
# Create network
docker network create harbor

# Run Redis
docker run -d \
  --name harbor-redis \
  --network harbor \
  --restart always \
  hoon-ch/harbor-redis-arm64:2.14.0

# Run PostgreSQL
docker run -d \
  --name harbor-db \
  --network harbor \
  --restart always \
  -e POSTGRES_PASSWORD=rootpassword \
  -v /data/harbor/database:/var/lib/postgresql/data \
  hoon-ch/harbor-db-arm64:2.14.0

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
  -e REDIS_HOST=harbor-redis \
  -e REDIS_PORT=6379 \
  -v /data/harbor/core:/data \
  hoon-ch/harbor-core-arm64:2.14.0

# Run Registry
docker run -d \
  --name harbor-registry \
  --network harbor \
  --restart always \
  -v /data/harbor/registry:/storage \
  hoon-ch/harbor-registry-arm64:2.14.0

# Run Portal
docker run -d \
  --name harbor-portal \
  --network harbor \
  --restart always \
  hoon-ch/harbor-portal-arm64:2.14.0

# Run Nginx
docker run -d \
  --name harbor-nginx \
  --network harbor \
  --restart always \
  -p 80:8080 \
  -p 443:8443 \
  hoon-ch/harbor-nginx-arm64:2.14.0
```

### Verification

```bash
# Check containers
docker ps | grep harbor

# Access Harbor UI
open http://localhost
# Default: admin / Harbor12345
```

## Docker Compose

### Prerequisites

- Docker 20.10+ and Docker Compose 2.0+
- Minimum 4GB RAM
- 20GB free disk space

### Full Deployment

1. **Download compose file:**

```bash
wget https://raw.githubusercontent.com/hoon-ch/harbor-arm/main/examples/docker-compose/harbor-arm64.yml
```

2. **Start Harbor:**

```bash
docker-compose -f harbor-arm64.yml up -d
```

3. **Verify deployment:**

```bash
# Check status
docker-compose -f harbor-arm64.yml ps

# View logs
docker-compose -f harbor-arm64.yml logs -f

# Access UI
open http://localhost:8080
```

### Custom Configuration

Create your own `docker-compose.yml`:

```yaml
version: '3.8'

services:
  redis:
    image: hoon-ch/harbor-redis-arm64:2.14.0
    container_name: harbor-redis
    restart: always
    networks:
      - harbor

  database:
    image: hoon-ch/harbor-db-arm64:2.14.0
    container_name: harbor-db
    restart: always
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD:-changeme}
    volumes:
      - database-data:/var/lib/postgresql/data
    networks:
      - harbor

  core:
    image: hoon-ch/harbor-core-arm64:2.14.0
    container_name: harbor-core
    restart: always
    environment:
      DATABASE_TYPE: postgresql
      POSTGRESQL_HOST: database
      POSTGRESQL_PORT: 5432
      POSTGRESQL_USERNAME: postgres
      POSTGRESQL_PASSWORD: ${DB_PASSWORD:-changeme}
      POSTGRESQL_DATABASE: registry
      REDIS_HOST: redis
      REDIS_PORT: 6379
    volumes:
      - core-data:/data
    networks:
      - harbor
    depends_on:
      - database
      - redis

  jobservice:
    image: hoon-ch/harbor-jobservice-arm64:2.14.0
    container_name: harbor-jobservice
    restart: always
    environment:
      CORE_URL: http://core:8080
      REGISTRY_URL: http://registry:5000
    volumes:
      - jobservice-data:/var/log/jobs
    networks:
      - harbor
    depends_on:
      - core
      - registry

  registry:
    image: hoon-ch/harbor-registry-arm64:2.14.0
    container_name: harbor-registry
    restart: always
    volumes:
      - registry-data:/storage
    networks:
      - harbor

  registryctl:
    image: hoon-ch/harbor-registryctl-arm64:2.14.0
    container_name: harbor-registryctl
    restart: always
    environment:
      CORE_URL: http://core:8080
      JOBSERVICE_URL: http://jobservice:8080
    volumes:
      - registry-data:/storage
    networks:
      - harbor
    depends_on:
      - registry

  portal:
    image: hoon-ch/harbor-portal-arm64:2.14.0
    container_name: harbor-portal
    restart: always
    networks:
      - harbor
    depends_on:
      - core

  nginx:
    image: hoon-ch/harbor-nginx-arm64:2.14.0
    container_name: harbor-nginx
    restart: always
    ports:
      - "80:8080"
      - "443:8443"
    networks:
      - harbor
    depends_on:
      - portal
      - core
      - registry

volumes:
  database-data:
  core-data:
  jobservice-data:
  registry-data:

networks:
  harbor:
    driver: bridge
```

### Environment Variables

Create `.env` file:

```bash
# Database
DB_PASSWORD=securepassword123

# Harbor
HARBOR_ADMIN_PASSWORD=Harbor12345

# Version
HARBOR_VERSION=2.14.0
```

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
    tag: "2.14.0"

jobservice:
  image:
    repository: hoon-ch/harbor-jobservice-arm64
    tag: "2.14.0"

registry:
  registry:
    image:
      repository: hoon-ch/harbor-registry-arm64
      tag: "2.14.0"
  controller:
    image:
      repository: hoon-ch/harbor-registryctl-arm64
      tag: "2.14.0"

portal:
  image:
    repository: hoon-ch/harbor-portal-arm64
    tag: "2.14.0"

database:
  internal:
    image:
      repository: hoon-ch/harbor-db-arm64
      tag: "2.14.0"

redis:
  internal:
    image:
      repository: hoon-ch/harbor-redis-arm64
      tag: "2.14.0"

nginx:
  image:
    repository: hoon-ch/harbor-nginx-arm64
    tag: "2.14.0"

exporter:
  image:
    repository: hoon-ch/harbor-exporter-arm64
    tag: "2.14.0"

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

## Kubernetes Production

For production deployments with high availability, auto-scaling, and advanced features:

**See [Kubernetes Production Deployment Guide](../examples/kubernetes/PRODUCTION_DEPLOYMENT.md)**

Key features:
- Multiple replicas for HA
- HorizontalPodAutoscaler
- PodDisruptionBudgets
- Resource limits and requests
- Health checks
- Security contexts
- Monitoring integration

Quick deploy:

```bash
kubectl apply -f examples/kubernetes/harbor-production.yaml
```

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
- [Kubernetes Production Guide](../examples/kubernetes/PRODUCTION_DEPLOYMENT.md) - Production deployment

## Support

- **Issues**: [GitHub Issues](https://github.com/hoon-ch/harbor-arm/issues)
- **Harbor Docs**: [goharbor.io/docs](https://goharbor.io/docs)
- **Community**: [Harbor Discussions](https://github.com/goharbor/harbor/discussions)
