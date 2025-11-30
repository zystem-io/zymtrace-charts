# zymtrace Profiler Helm Chart

This Helm chart deploys the zymtrace profiler


## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+

## Configuration

### Basic Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `profiler.image.repository` | Profiler image repository | `zymtrace-pub-profiler` |
| `profiler.image.tag` | Profiler image tag | `""` |
| `profiler.args` | Arguments passed to profiler | See values.yaml |
| `profiler.env` | Environment variables | See values.yaml |

### GPU Monitoring Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `profiler.gpuMetrics.enabled` | Enable GPU metrics collection | `false` |
| `profiler.gpuMetrics.nvmlLibPath` | Host path where NVIDIA libraries are located | `/home/kubernetes/bin/nvidia/lib64` |

### CUDA Profiler Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `profiler.cudaProfiler.enabled` | Enable CUDA profiler | `false` |
| `profiler.cudaProfiler.hostMountPath` | Host path for CUDA profiler data | `/var/lib/zymtrace/profiler` |
