# Zymtrace Profiler Chart

![Chart: 26.1.1](https://img.shields.io/badge/Chart-26.1.1-blue) ![AppVersion: 26.1.1](https://img.shields.io/badge/AppVersion-26.1.1-blue)


Deploy zymtrace's profiler agent - a lightweight, low-overhead continuous profiler for CPU and GPU workloads.

**Homepage:** <https://docs.zymtrace.com>

## Source Code

* <https://github.com/zystem-io/zymtrace-charts/tree/main/charts>

## Documentation

For detailed configuration and usage instructions, see:
* [Profiler Configuration](https://docs.zymtrace.com/profiler-configuration)
* [Install Profiler](https://docs.zymtrace.com/install/profiler/install-profiler)
* [Environment Variables and CLI Arguments Reference](https://docs.zymtrace.com/profiler-configuration)
* [GPU Metrics](https://docs.zymtrace.com/gpu-metrics)

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+

## Installation

Add the zymtrace Helm repository:

```bash
helm repo add zymtrace https://helm.zystem.io
helm repo update
```

To search for available versions:

```bash
helm search repo zymtrace --versions
```

### Install with a values file

```bash
helm install profiler zymtrace/profiler \
  --namespace zymtrace \
  --create-namespace \
  -f profiler-values.yaml
```

### Install without a values file (GPU profiling with metrics)

```bash
helm install profiler zymtrace/profiler \
  --namespace zymtrace \
  --create-namespace \
  --set profiler.cudaProfiler.enabled=true \
  --set profiler.args[0]="--collection-agent=zymtrace-gateway.zymtrace.svc.cluster.local:80" \
  --set profiler.args[1]="--disable-tls" \
  --set profiler.args[2]="--enable-gpu-metrics" \
  --set profiler.args[3]="--nvml-auto-scan"
```

> **Note:** Use `--nvml-path=/path/to/libnvidia-ml.so` instead of `--nvml-auto-scan` if you know the exact NVML library path.

### Install without a values file (CPU profiling only)

```bash
helm install profiler zymtrace/profiler \
  --namespace zymtrace \
  --create-namespace \
  --set profiler.args[0]="--collection-agent=zymtrace-gateway.zymtrace.svc.cluster.local:80" \
  --set profiler.args[1]="--disable-tls"
```

> **Note:** For CPU-only profiling, simply omit `profiler.cudaProfiler.enabled`, `--enable-gpu-metrics`, and `--nvml-auto-scan` options.

## Configuration Examples (values file)

### CPU Profiling Only

```yaml
profiler:
  args:
    - "--collection-agent=zymtrace-gateway.zymtrace.svc.cluster.local:80"
    - "--disable-tls"
```

### CUDA Profiling with GPU Metrics

```yaml
profiler:
  cudaProfiler:
    enabled: true  # Enables CUDA/GPU kernel profiling
  args:
    - "--collection-agent=zymtrace-gateway.zymtrace.svc.cluster.local:80"
    - "--disable-tls"
    - "--enable-gpu-metrics"  # Enables GPU metrics collection
    - "--nvml-auto-scan"
```

### CUDA Profiling with GPU Metrics (explicit NVML path)

```yaml
profiler:
  cudaProfiler:
    enabled: true  # Enables CUDA/GPU kernel profiling
  args:
    - "--collection-agent=zymtrace-gateway.zymtrace.svc.cluster.local:80"
    - "--disable-tls"
    - "--enable-gpu-metrics"  # Enables GPU metrics collection
    - "--nvml-path=/usr/lib/x86_64-linux-gnu/libnvidia-ml.so.1"
```

### CUDA Profiling Only (without GPU metrics)

```yaml
profiler:
  cudaProfiler:
    enabled: true
  args:
    - "--collection-agent=zymtrace-gateway.zymtrace.svc.cluster.local:80"
    - "--disable-tls"
```

### Target GPU Nodes Only

```yaml
profiler:
  cudaProfiler:
    enabled: true
  nodeSelector:
    nvidia.com/gpu: "true"
  args:
    - "--collection-agent=zymtrace-gateway.zymtrace.svc.cluster.local:80"
    - "--disable-tls"
    - "--enable-gpu-metrics"
    - "--nvml-auto-scan"
```

### GPU Profiling with Custom Tags

```yaml
profiler:
  cudaProfiler:
    enabled: true
  args:
    - "--collection-agent=zymtrace-gateway.zymtrace.svc.cluster.local:80"
    - "--disable-tls"
    - "--enable-gpu-metrics"
    - "--nvml-auto-scan"
    - "--tags=cloud_region:us-central1;env:staging"
```

### Full GPU Configuration Example

```yaml
profiler:
  cudaProfiler:
    enabled: true
    hostMountPath: "/var/lib/zymtrace/profiler"
  args:
    - "--collection-agent=zymtrace-gateway.zymtrace.svc.cluster.local:80"
    - "--disable-tls"
    - "--enable-gpu-metrics"
    - "--nvml-auto-scan"
    - "--tags=cloud_region:us-central1;env:production"
  nodeSelector:
    nvidia.com/gpu: "true"
  resources:
    requests:
      cpu: "200m"
      memory: "256Mi"
    limits:
      cpu: "1000m"
      memory: "1Gi"
```

## Values

| Key | Type | Description |
|-----|------|-------------|
| global.namePrefix | string | Prefix for resource names |
| global.imageRegistry | string | Container image registry |
| global.registry.requirePullSecret | bool | Whether to require image pull secret |
| global.imagePullPolicy | string | Image pull policy |
| global.ClusterMetadata.cluster_id | string | Cluster ID to add as a tag to the profiler agent |
| rbac.create | bool | Create RBAC resources |
| rbac.rules | list | RBAC rules for the profiler |
| serviceAccount.annotations | object | Annotations for the service account (e.g., for IAM roles) |
| profiler.image.repository | string | Profiler image repository |
| profiler.image.tag | string | Profiler image tag (override with `--set profiler.image.tag=<version>`) |
| profiler.securityContext.capabilities.add | list | Required SYS permissions |
| profiler.cudaProfiler.enabled | bool | Enable CUDA profiler (for GPU profiling) |
| profiler.cudaProfiler.hostMountPath | string | Host path for CUDA profiler data |
| profiler.args | list | Arguments passed to the profiler. See [CLI Args](https://docs.zymtrace.com/profiler-configuration) |
| profiler.env | object | Environment variables. See [Env Variables](https://docs.zymtrace.com/profiler-configuration) |
| profiler.env.fieldRefs.NODE_NAME | bool | Enable NODE_NAME from Kubernetes downward API (maps to spec.nodeName) |
| profiler.env.fieldRefs.KUBERNETES_NODE_NAME | bool | Enable KUBERNETES_NODE_NAME from Kubernetes downward API (maps to spec.nodeName) |
| profiler.resources.requests.cpu | string | CPU request |
| profiler.resources.requests.memory | string | Memory request |
| profiler.resources.limits.cpu | string | CPU limit |
| profiler.resources.limits.memory | string | Memory limit |
| profiler.nodeSelector | object | Node selector for pod assignment |
| profiler.tolerations | list | Tolerations for pod assignment (includes GPU node toleration by default) |
| profiler.affinity | object | Affinity rules for pod assignment |

