# Troubleshooting Guide

Common issues and solutions for Harbor ARM64 deployment.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Image Issues](#image-issues)
- [Docker Issues](#docker-issues)
- [Kubernetes Issues](#kubernetes-issues)
- [Runtime Issues](#runtime-issues)
- [Performance Issues](#performance-issues)
- [Network Issues](#network-issues)

## Installation Issues

### Cannot Pull Images

**Problem**: `docker pull` fails with "manifest unknown" or "not found"

**Solutions**:

```bash
# Verify image exists
docker manifest inspect hoon-ch/harbor-core-arm64:2.14.0

# Check available tags
curl -s https://registry.hub.docker.com/v2/repositories/hoon-ch/harbor-core-arm64/tags | jq '.results[].name'

# Try specific registry
docker pull docker.io/hoon-ch/harbor-core-arm64:2.14.0

# Or use GHCR
docker pull ghcr.io/hoon-ch/harbor-core-arm64:2.14.0
```

### Wrong Architecture

**Problem**: "exec format error" when running containers

**Cause**: Trying to run ARM64 images on x86_64 architecture

**Solutions**:

```bash
# Check your architecture
uname -m  # Should show: aarch64 or arm64

# Verify image architecture
docker image inspect hoon-ch/harbor-core-arm64:2.14.0 --format '{{.Architecture}}'
# Should show: arm64

# If on x86_64, you need ARM64 hardware or use x86 Harbor images
```

### Insufficient Disk Space

**Problem**: Build or deployment fails with "no space left on device"

**Solutions**:

```bash
# Check disk usage
df -h
docker system df

# Clean up Docker
docker system prune -af
docker volume prune -f

# Remove old images
docker rmi $(docker images -f "dangling=true" -q)
```

## Image Issues

### Image Pull Rate Limit

**Problem**: "You have reached your pull rate limit"

**Solutions**:

```bash
# Login to Docker Hub
docker login
# Enter your credentials

# Or use GHCR (no rate limits)
docker pull ghcr.io/hoon-ch/harbor-core-arm64:2.14.0
```

### Image Verification Failed

**Problem**: Image fails validation tests

**Solutions**:

```bash
# Re-pull image
docker pull hoon-ch/harbor-core-arm64:2.14.0

# Check image integrity
docker image inspect hoon-ch/harbor-core-arm64:2.14.0

# Verify architecture
docker run --rm hoon-ch/harbor-core-arm64:2.14.0 uname -m
```

### Old Image Cached

**Problem**: Using old version despite pulling latest

**Solutions**:

```bash
# Force pull
docker pull hoon-ch/harbor-core-arm64:latest --disable-content-trust

# Remove old images
docker rmi hoon-ch/harbor-core-arm64:latest
docker pull hoon-ch/harbor-core-arm64:latest

# Check image creation date
docker image inspect hoon-ch/harbor-core-arm64:latest --format '{{.Created}}'
```

## Docker Issues

### Container Won't Start

**Problem**: Container exits immediately after start

**Diagnostic Steps**:

```bash
# Check container logs
docker logs harbor-core

# Check container exit code
docker inspect harbor-core --format='{{.State.ExitCode}}'

# Try running interactively
docker run -it hoon-ch/harbor-core-arm64:2.14.0 /bin/sh
```

**Common Causes**:

1. **Missing environment variables**:

```bash
# Add required env vars
docker run -d \
  -e DATABASE_TYPE=postgresql \
  -e POSTGRESQL_HOST=harbor-db \
  hoon-ch/harbor-core-arm64:2.14.0
```

2. **Database not ready**:

```bash
# Wait for database
docker run -d \
  --name harbor-core \
  --restart on-failure:3 \
  hoon-ch/harbor-core-arm64:2.14.0
```

3. **Volume mount errors**:

```bash
# Check volume permissions
ls -la /data/harbor/
sudo chown -R 10000:10000 /data/harbor/
```

### Port Already in Use

**Problem**: "address already in use" error

**Solutions**:

```bash
# Find process using port
sudo lsof -i :80
sudo lsof -i :443

# Kill process
sudo kill -9 <PID>

# Or use different ports
docker run -p 8080:8080 -p 8443:8443 hoon-ch/harbor-nginx-arm64:2.14.0
```

### Network Issues

**Problem**: Containers can't communicate

**Solutions**:

```bash
# Check network exists
docker network ls

# Create network
docker network create harbor

# Connect containers
docker network connect harbor harbor-core
docker network connect harbor harbor-db

# Verify connectivity
docker exec harbor-core ping harbor-db
```

## Kubernetes Issues

### Pods Not Scheduling

**Problem**: Pods stuck in "Pending" state

**Diagnostic Steps**:

```bash
# Check pod events
kubectl describe pod <pod-name> -n harbor

# Check node resources
kubectl top nodes

# Check node selectors
kubectl get nodes --show-labels | grep arm64
```

**Solutions**:

1. **No ARM64 nodes**:

```bash
# Verify ARM64 nodes exist
kubectl get nodes -o custom-columns=NAME:.metadata.name,ARCH:.status.nodeInfo.architecture

# Remove nodeSelector if not needed
kubectl edit deployment harbor-core -n harbor
# Remove nodeSelector section
```

2. **Insufficient resources**:

```bash
# Check resource requests
kubectl describe deployment harbor-core -n harbor

# Reduce resource requests
kubectl set resources deployment harbor-core \
  --requests=cpu=100m,memory=128Mi \
  --limits=cpu=500m,memory=512Mi \
  -n harbor
```

3. **PVC not bound**:

```bash
# Check PVC status
kubectl get pvc -n harbor

# Check storage class
kubectl get storageclass

# Manually create PV if needed
```

### Image Pull Errors in Kubernetes

**Problem**: "ImagePullBackOff" or "ErrImagePull"

**Solutions**:

```bash
# Check pod events
kubectl describe pod <pod-name> -n harbor

# Create image pull secret
kubectl create secret docker-registry harbor-registry-secret \
  --docker-server=docker.io \
  --docker-username=your-username \
  --docker-password=your-token \
  -n harbor

# Add secret to deployment
kubectl patch serviceaccount default \
  -p '{"imagePullSecrets": [{"name": "harbor-registry-secret"}]}' \
  -n harbor
```

### Pod CrashLoopBackOff

**Problem**: Pods repeatedly crashing

**Diagnostic Steps**:

```bash
# Check logs
kubectl logs -f <pod-name> -n harbor

# Check previous container logs
kubectl logs <pod-name> -n harbor --previous

# Check events
kubectl get events -n harbor --sort-by='.lastTimestamp'
```

**Common Causes**:

1. **Database connection failure**:

```bash
# Test database connectivity
kubectl exec -it deployment/harbor-core -n harbor -- nc -zv harbor-database 5432

# Check database password
kubectl get secret harbor-database-secret -n harbor -o yaml
```

2. **Missing ConfigMap**:

```bash
# List ConfigMaps
kubectl get configmap -n harbor

# Create missing ConfigMap
kubectl create configmap harbor-core-config \
  --from-file=app.conf \
  -n harbor
```

### HPA Not Scaling

**Problem**: HorizontalPodAutoscaler not working

**Solutions**:

```bash
# Check HPA status
kubectl get hpa -n harbor
kubectl describe hpa harbor-core-hpa -n harbor

# Check metrics-server
kubectl get deployment metrics-server -n kube-system

# Install metrics-server if missing
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify metrics available
kubectl top pods -n harbor
kubectl top nodes
```

## Runtime Issues

### Cannot Login to Harbor

**Problem**: Web UI shows login error

**Solutions**:

```bash
# Check default credentials
# Username: admin
# Password: Harbor12345 (or your configured password)

# Reset admin password (Docker Compose)
docker exec -it harbor-db psql -U postgres -d registry
# UPDATE harbor_user SET password='<new_hash>' WHERE username='admin';

# Check harbor-core logs
docker logs harbor-core
kubectl logs deployment/harbor-core -n harbor
```

### Cannot Push/Pull Images

**Problem**: Docker push/pull fails

**Diagnostic Steps**:

```bash
# Test registry endpoint
curl -k https://harbor.example.com/v2/

# Check registry logs
docker logs harbor-registry
kubectl logs deployment/harbor-registry -n harbor
```

**Solutions**:

1. **TLS certificate error**:

```bash
# Add insecure registry (for testing only)
# /etc/docker/daemon.json
{
  "insecure-registries": ["harbor.example.com"]
}

sudo systemctl restart docker

# Or add certificate
sudo mkdir -p /etc/docker/certs.d/harbor.example.com
sudo cp harbor.crt /etc/docker/certs.d/harbor.example.com/ca.crt
```

2. **Authentication error**:

```bash
# Login to registry
docker login harbor.example.com
# Enter credentials

# Verify token
cat ~/.docker/config.json
```

3. **Storage full**:

```bash
# Check storage
df -h /data/harbor/registry

# Clean up old images via Harbor UI
# Or increase storage
```

### Job Service Not Working

**Problem**: Vulnerability scanning or replication fails

**Solutions**:

```bash
# Check jobservice logs
docker logs harbor-jobservice
kubectl logs deployment/harbor-jobservice -n harbor

# Restart jobservice
docker restart harbor-jobservice
kubectl rollout restart deployment/harbor-jobservice -n harbor

# Check jobservice connectivity
docker exec harbor-jobservice curl http://harbor-core:8080/api/v2.0/ping
```

## Performance Issues

### Slow Image Push/Pull

**Problem**: Image operations are very slow

**Solutions**:

```bash
# Check network speed
iperf3 -c harbor.example.com

# Check registry performance
time docker pull harbor.example.com/test/alpine:latest

# Enable blob cache (registry config)
storage:
  cache:
    blobdescriptor: redis

# Increase registry replicas (Kubernetes)
kubectl scale deployment harbor-registry --replicas=3 -n harbor
```

### High Memory Usage

**Problem**: Components using excessive memory

**Solutions**:

```bash
# Check memory usage
docker stats
kubectl top pods -n harbor

# Reduce database cache (PostgreSQL)
# Set shared_buffers to 128MB instead of 256MB

# Enable Redis maxmemory policy
# In redis config:
maxmemory 256mb
maxmemory-policy allkeys-lru

# Adjust resource limits (Kubernetes)
kubectl set resources deployment harbor-core \
  --limits=memory=512Mi \
  -n harbor
```

### Database Performance

**Problem**: Slow database queries

**Solutions**:

```bash
# Check database performance
docker exec harbor-db psql -U postgres -d registry \
  -c "SELECT * FROM pg_stat_activity;"

# Analyze slow queries
docker exec harbor-db psql -U postgres -d registry \
  -c "SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"

# Optimize database
docker exec harbor-db psql -U postgres -d registry \
  -c "VACUUM ANALYZE;"

# Increase database resources
kubectl set resources statefulset harbor-database \
  --limits=cpu=2,memory=2Gi \
  -n harbor
```

## Network Issues

### DNS Resolution Failed

**Problem**: Containers can't resolve hostnames

**Solutions**:

```bash
# Test DNS
docker exec harbor-core nslookup harbor-db
kubectl exec deployment/harbor-core -n harbor -- nslookup harbor-database

# Use IP addresses temporarily
docker run -e POSTGRESQL_HOST=172.17.0.2 ...

# Fix Docker DNS
# /etc/docker/daemon.json
{
  "dns": ["8.8.8.8", "8.8.4.4"]
}

sudo systemctl restart docker
```

### Firewall Blocking Access

**Problem**: Can't access Harbor from outside

**Solutions**:

```bash
# Check firewall rules
sudo iptables -L -n

# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# For Kubernetes LoadBalancer
kubectl get svc harbor-nginx -n harbor
# Ensure LoadBalancer has external IP

# Check security groups (cloud providers)
# Ensure inbound rules allow ports 80, 443
```

### SSL/TLS Issues

**Problem**: Certificate errors

**Solutions**:

```bash
# Test SSL
openssl s_client -connect harbor.example.com:443

# Regenerate certificate
openssl req -new -x509 -key harbor.key -out harbor.crt -days 365

# Update certificate in deployment
docker cp harbor.crt harbor-nginx:/etc/nginx/cert/
docker restart harbor-nginx

# For Kubernetes
kubectl create secret tls harbor-tls \
  --cert=harbor.crt \
  --key=harbor.key \
  -n harbor
```

## Getting Help

### Collect Diagnostic Information

```bash
# Docker
docker ps -a
docker logs harbor-core > core.log
docker logs harbor-registry > registry.log
docker inspect harbor-core > core-inspect.json

# Kubernetes
kubectl get all -n harbor > k8s-resources.txt
kubectl describe pods -n harbor > pods-describe.txt
kubectl logs -l app=harbor-core -n harbor > core-logs.txt
```

### Report Issues

When creating an issue, include:

1. Environment details:
   - Architecture (`uname -m`)
   - OS version
   - Docker version
   - Kubernetes version (if applicable)

2. Harbor version being used

3. Deployment method (Docker, Docker Compose, Kubernetes)

4. Error messages and logs

5. Steps to reproduce

**GitHub Issues**: https://github.com/hoon-ch/harbor-arm/issues

## Additional Resources

- [Harbor Official Docs](https://goharbor.io/docs/)
- [Harbor Troubleshooting](https://goharbor.io/docs/latest/install-config/troubleshoot-installation/)
- [Docker Docs](https://docs.docker.com/)
- [Kubernetes Docs](https://kubernetes.io/docs/)
