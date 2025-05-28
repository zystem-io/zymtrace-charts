# zymtrace Backend Helm Chart

This Helm chart deploys zymtrace backend services to a Kubernetes cluster.

## Prerequisites

- Kubernetes 1.20+
- Helm 3.2.0+
- A metrics server installed in your cluster for HPA support
- PV provisioner support in the underlying infrastructure (for persistent storage)

## Horizontal Pod Autoscaling (HPA)

This chart includes support for Horizontal Pod Autoscaling (HPA) for service components:

- Web service
- Ingest service
- SymDB service
- UI service
- Identity service

### How It Works

HPA automatically scales the number of pods based on observed CPU utilization. By default, HPA is disabled for all services.

To use HPA:

1. Ensure your cluster has the metrics server installed:
   ```
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   ```

2. Enable HPA for desired services in your values.yaml file or using --set:
   ```yaml
   services:
     web:
       hpa:
         enabled: true
         minReplicas: 1
         maxReplicas: 5
         targetCPUUtilizationPercentage: 80
   ```

   Or via Helm command:
   ```
   helm upgrade zymtrace ./charts/backend --set services.web.hpa.enabled=true
   ```

3. The HPA will automatically scale between minReplicas and maxReplicas to maintain the target CPU utilization (80% by default).

### Important Notes

- HPA is only supported for service components, not for database components
- HPA uses the default service account in your deployment namespace
- For production environments, verify the default service account has appropriate permissions for the autoscaling API

## Node Placement

This chart supports configuring node placement for both application services and database components using nodeSelector and tolerations.

### Node Selectors

You can specify node selectors to control which nodes the pods are scheduled on:

```yaml
# For all services
services:
  common:
    nodeSelector:
      kubernetes.io/arch: amd64
      disk-type: ssd

# For specific databases
clickhouse:
  nodeSelector:
    storage-type: high-performance
```

### Tolerations

Tolerations allow pods to be scheduled on nodes with matching taints:

```yaml
# For all services
services:
  common:
    tolerations:
    - key: "dedicated"
      operator: "Equal"
      value: "zymtrace"
      effect: "NoSchedule"

# For specific databases
postgres:
  tolerations:
  - key: "node.kubernetes.io/memory-pressure"
    operator: "Exists"
    effect: "NoExecute"
    tolerationSeconds: 3600
```

**IMPORTANT NOTE:** When using node tolerations with tainted nodes, you must specify tolerations in both places:

1. `services.common.tolerations` for all application services
2. `clickhouse.tolerations`, `postgres.tolerations`, and `storage.tolerations` for database services

Both sets of tolerations are necessary for initialization jobs (like zymtrace-minio-init) to work correctly.

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `services.<service>.hpa.enabled` | Enable HPA for the service | `false` |
| `services.<service>.hpa.minReplicas` | Minimum number of replicas | `1` |
| `services.<service>.hpa.maxReplicas` | Maximum number of replicas | `5` |
| `services.<service>.hpa.targetCPUUtilizationPercentage` | Target CPU utilization percentage | `80` |
| `services.ui.service.type` | Service type for UI (ClusterIP, NodePort, LoadBalancer) | `ClusterIP` |
| `services.ui.service.nodePort` | Node port when service type is NodePort | `""` |
| `services.ingest.service.type` | Service type for Ingest (ClusterIP, NodePort, LoadBalancer) | `ClusterIP` |
| `services.ingest.service.nodePort` | Node port when service type is NodePort | `""` |
| `services.common.nodeSelector` | Node selector for all application services | `{}` |
| `services.common.tolerations` | Tolerations for all application services | `[]` |
| `clickhouse.nodeSelector` | Node selector for Clickhouse database | `{}` |
| `clickhouse.tolerations` | Tolerations for Clickhouse database | `[]` |
| `postgres.nodeSelector` | Node selector for PostgreSQL database | `{}` |
| `postgres.tolerations` | Tolerations for PostgreSQL database | `[]` |
| `storage.nodeSelector` | Node selector for MinIO object storage | `{}` |
| `storage.tolerations` | Tolerations for MinIO object storage | `[]` |

## Usage Examples

### Enabling HPA

```bash
# Install the chart with HPA enabled for the web service
helm install backened zymtrace/backend --set services.web.hpa.enabled=true

# Check the HPA status
kubectl get hpa

# Test the autoscaling
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://zymtrace-web:9933; done"
```

### Service Type Configuration

```bash
# Install with LoadBalancer service type for UI and Ingest
helm install backened zymtrace/backend \
  --set services.ui.service.type=LoadBalancer \
  --set services.ingest.service.type=LoadBalancer

# Install with NodePort service type (specifying ports)
helm install backened zymtrace/backend \
  --set services.ui.service.type=NodePort \
  --set services.ui.service.nodePort=30080 \
  --set services.ingest.service.type=NodePort \
  --set services.ingest.service.nodePort=30375

# Note: When using Ingress for exposure, keep service type as ClusterIP (default)
```

### Node Placement Configuration

```bash
# Install with tolerations for all services to run on dedicated nodes
helm install backened zymtrace/backend \
  --set services.common.tolerations[0].key=dedicated \
  --set services.common.tolerations[0].operator=Equal \
  --set services.common.tolerations[0].value=zymtrace \
  --set services.common.tolerations[0].effect=NoSchedule

# Install with specific node selector for databases
helm install backened zymtrace/backend \
  --set clickhouse.nodeSelector.disk-type=ssd \
  --set postgres.nodeSelector.disk-type=ssd

# Combine both nodeSelector and tolerations
helm install backened zymtrace/backend \
  --set services.common.nodeSelector.service-tier=application \
  --set services.common.tolerations[0].key=service-tier \
  --set services.common.tolerations[0].operator=Equal \
  --set services.common.tolerations[0].value=application \
  --set services.common.tolerations[0].effect=NoSchedule \
  --set clickhouse.nodeSelector.service-tier=database \
  --set clickhouse.tolerations[0].key=service-tier \
  --set clickhouse.tolerations[0].operator=Equal \
  --set clickhouse.tolerations[0].value=database \
  --set clickhouse.tolerations[0].effect=NoSchedule
```
