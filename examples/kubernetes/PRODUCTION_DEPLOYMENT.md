# Harbor ARM64 Production Deployment on Kubernetes

This guide provides step-by-step instructions for deploying Harbor ARM64 on Kubernetes in a production environment.

## Prerequisites

- Kubernetes cluster with ARM64 nodes (v1.24+)
- kubectl configured to access your cluster
- At least 4GB RAM and 2 CPU cores available per node
- Storage class supporting ReadWriteMany (for registry data)
- LoadBalancer support (for external access)

## Architecture Overview

The production deployment includes:
- **High Availability**: Multiple replicas for critical components
- **Auto-scaling**: HorizontalPodAutoscaler for dynamic scaling
- **Resource Management**: Resource requests and limits
- **Health Checks**: Liveness and readiness probes
- **Security**: PodDisruptionBudgets, security contexts, secrets
- **Persistent Storage**: StatefulSets for database and Redis

## Quick Start

### 1. Verify ARM64 Nodes

```bash
# Check that you have ARM64 nodes available
kubectl get nodes -o custom-columns=NAME:.metadata.name,ARCH:.status.nodeInfo.architecture

# Expected output should show 'arm64' for some nodes
```

### 2. Update Secrets

Before deploying, update the secrets in `harbor-production.yaml`:

```bash
# Generate secure passwords
DB_PASSWORD=$(openssl rand -base64 32)
CORE_SECRET=$(openssl rand -base64 32)
JOBSERVICE_SECRET=$(openssl rand -base64 32)
ENCRYPTION_KEY=$(openssl rand -base64 32)

# Update the secrets section in harbor-production.yaml
# Replace 'changeme123', 'changeme-core-secret', etc. with the generated values
```

**Important**: Never commit secrets to version control!

### 3. Configure Storage

Update the storage class in `harbor-production.yaml` to match your cluster:

```yaml
# For AWS EFS
storageClassName: efs-sc

# For Azure Files
storageClassName: azurefile

# For GCP Filestore
storageClassName: filestore

# For NFS
storageClassName: nfs-client
```

### 4. Deploy Harbor

```bash
# Apply the manifest
kubectl apply -f harbor-production.yaml

# Watch the deployment
kubectl get pods -n harbor -w

# Check status
kubectl get all -n harbor
```

### 5. Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n harbor

# Check services
kubectl get svc -n harbor

# Get the LoadBalancer IP
kubectl get svc harbor-nginx -n harbor -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

## Configuration

### Resource Requirements

Minimum resource requirements per component:

| Component | Replicas | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|----------|-------------|----------------|-----------|--------------|
| Core | 2 | 250m | 256Mi | 1000m | 1Gi |
| Registry | 2 | 250m | 256Mi | 2000m | 2Gi |
| Portal | 2 | 100m | 128Mi | 500m | 512Mi |
| JobService | 2 | 250m | 256Mi | 1000m | 1Gi |
| Database | 1 | 250m | 256Mi | 1000m | 1Gi |
| Redis | 1 | 100m | 128Mi | 500m | 512Mi |
| Nginx | 2 | 100m | 128Mi | 500m | 512Mi |

**Total Minimum**: ~2.3 CPU cores, ~2.3Gi memory

### Auto-scaling Configuration

The deployment includes HorizontalPodAutoscalers (HPA) for:
- **harbor-core**: 2-10 replicas (scales at 70% CPU, 80% memory)
- **harbor-registry**: 2-10 replicas (scales at 70% CPU, 80% memory)

To adjust scaling:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: harbor-core-hpa
  namespace: harbor
spec:
  minReplicas: 2  # Adjust minimum
  maxReplicas: 20  # Adjust maximum
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60  # Scale at 60% CPU
```

### PodDisruptionBudgets

PodDisruptionBudgets ensure at least 1 replica remains available during:
- Node maintenance
- Cluster upgrades
- Voluntary disruptions

Components with PDB:
- harbor-core
- harbor-registry
- harbor-portal
- harbor-jobservice

### Storage Configuration

#### Database (PostgreSQL)
- Type: StatefulSet with PVC
- Default size: 10Gi
- Access mode: ReadWriteOnce

#### Redis
- Type: StatefulSet with PVC
- Default size: 5Gi
- Access mode: ReadWriteOnce

#### Registry Data
- Type: PersistentVolumeClaim
- Default size: 100Gi
- Access mode: ReadWriteMany (required for multi-replica registry)

To resize:

```bash
# Edit the PVC
kubectl edit pvc harbor-registry-data -n harbor

# Update the storage request
spec:
  resources:
    requests:
      storage: 500Gi  # New size
```

## Security Considerations

### Secrets Management

For production, use external secret management:

```bash
# Using Sealed Secrets
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/controller.yaml

# Create sealed secret
echo -n "mypassword" | kubectl create secret generic harbor-database-secret \
  --dry-run=client --from-file=password=/dev/stdin -o yaml | \
  kubeseal -o yaml > harbor-database-sealed-secret.yaml

# Apply sealed secret
kubectl apply -f harbor-database-sealed-secret.yaml -n harbor
```

Or use cloud-native solutions:
- **AWS**: AWS Secrets Manager + External Secrets Operator
- **Azure**: Azure Key Vault + External Secrets Operator
- **GCP**: Google Secret Manager + External Secrets Operator

### Network Policies (Optional)

To restrict network traffic between pods:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: harbor-core-netpol
  namespace: harbor
spec:
  podSelector:
    matchLabels:
      app: harbor-core
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: harbor-nginx
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: harbor-database
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - podSelector:
        matchLabels:
          app: harbor-redis
    ports:
    - protocol: TCP
      port: 6379
```

### TLS/SSL Configuration

For production, enable TLS:

```bash
# Create TLS secret
kubectl create secret tls harbor-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n harbor

# Update nginx deployment to mount the TLS secret
```

Or use cert-manager:

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create certificate
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: harbor-tls
  namespace: harbor
spec:
  secretName: harbor-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - harbor.example.com
EOF
```

## Monitoring and Observability

### Prometheus Metrics

Harbor components expose Prometheus metrics:

```yaml
apiVersion: v1
kind: ServiceMonitor
metadata:
  name: harbor-core
  namespace: harbor
spec:
  selector:
    matchLabels:
      app: harbor-core
  endpoints:
  - port: http
    path: /metrics
```

### Logging

Configure log aggregation:

```bash
# Using Fluentd/Fluent Bit
# Logs are automatically collected from stdout/stderr

# View logs
kubectl logs -f deployment/harbor-core -n harbor
kubectl logs -f deployment/harbor-registry -n harbor
```

### Health Checks

Check component health:

```bash
# Core API health
kubectl exec -it deployment/harbor-core -n harbor -- \
  curl http://localhost:8080/api/v2.0/ping

# Registry health
kubectl exec -it deployment/harbor-registry -n harbor -- \
  curl http://localhost:5000/v2/
```

## Backup and Disaster Recovery

### Database Backup

```bash
# Backup PostgreSQL database
kubectl exec -it harbor-database-0 -n harbor -- \
  pg_dump -U postgres registry > harbor-db-backup.sql

# Restore
kubectl exec -i harbor-database-0 -n harbor -- \
  psql -U postgres registry < harbor-db-backup.sql
```

### Registry Data Backup

```bash
# Using Velero for backup
velero backup create harbor-backup \
  --include-namespaces harbor \
  --wait

# Restore
velero restore create --from-backup harbor-backup
```

## Troubleshooting

### Pods not starting

```bash
# Check pod events
kubectl describe pod <pod-name> -n harbor

# Check logs
kubectl logs <pod-name> -n harbor

# Common issues:
# 1. ARM64 node not available -> Add nodeSelector
# 2. Image pull error -> Check image registry access
# 3. PVC not bound -> Check storage class availability
```

### Database connection errors

```bash
# Test database connectivity
kubectl exec -it deployment/harbor-core -n harbor -- \
  nc -zv harbor-database 5432

# Check database logs
kubectl logs harbor-database-0 -n harbor
```

### Registry push/pull failures

```bash
# Check registry logs
kubectl logs deployment/harbor-registry -n harbor

# Test registry endpoint
kubectl port-forward svc/harbor-registry 5000:5000 -n harbor
curl http://localhost:5000/v2/
```

### HPA not scaling

```bash
# Check metrics server
kubectl top nodes
kubectl top pods -n harbor

# View HPA status
kubectl get hpa -n harbor
kubectl describe hpa harbor-core-hpa -n harbor

# Install metrics-server if missing
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

## Upgrading

### Rolling Update

```bash
# Update image version in manifest
sed -i 's/2.14.0/2.15.0/g' harbor-production.yaml

# Apply changes (rolling update)
kubectl apply -f harbor-production.yaml

# Watch rollout
kubectl rollout status deployment/harbor-core -n harbor
kubectl rollout status deployment/harbor-registry -n harbor
```

### Rollback

```bash
# Rollback deployment
kubectl rollout undo deployment/harbor-core -n harbor

# Check rollout history
kubectl rollout history deployment/harbor-core -n harbor
```

## Performance Tuning

### Database Performance

```yaml
# In harbor-database StatefulSet, add:
env:
- name: POSTGRES_SHARED_BUFFERS
  value: "256MB"
- name: POSTGRES_MAX_CONNECTIONS
  value: "200"
- name: POSTGRES_WORK_MEM
  value: "4MB"
```

### Redis Performance

```yaml
# In harbor-redis StatefulSet, add:
command:
- redis-server
- --maxmemory
- 256mb
- --maxmemory-policy
- allkeys-lru
```

### Registry Performance

```yaml
# In registry ConfigMap, add:
storage:
  cache:
    blobdescriptor: redis
  redis:
    addr: harbor-redis:6379
```

## Cost Optimization

### ARM64 vs x86_64 Cost Savings

Using ARM64 nodes can reduce costs by 20-40%:

- **AWS**: Graviton instances (t4g, m6g, c6g) are ~20% cheaper
- **Azure**: ARM-based VMs are ~20% cheaper
- **Oracle Cloud**: Ampere A1 instances offer up to 4 vCPUs free tier

### Resource Optimization

```bash
# Reduce replicas for non-prod
kubectl scale deployment harbor-portal --replicas=1 -n harbor

# Use VPA (VerticalPodAutoscaler) for right-sizing
kubectl apply -f https://github.com/kubernetes/autoscaler/releases/latest/download/vertical-pod-autoscaler.yaml
```

## Support and Community

- **Harbor Documentation**: https://goharbor.io/docs/
- **Harbor GitHub**: https://github.com/goharbor/harbor
- **Harbor Slack**: https://cloud-native.slack.com/#harbor
- **This Project**: https://github.com/hoon-ch/harbor-arm

## License

This deployment configuration follows the same license as Harbor (Apache 2.0).
