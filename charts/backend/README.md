# zymtrace Backend Helm Chart

This Helm chart deploys zymtrace backend services to a Kubernetes cluster.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- A metrics server installed in your cluster for HPA support
- PV provisioner support in the underlying infrastructure (for persistent storage)
- For Google Cloud SQL with IAM: GKE cluster with Workload Identity configured
- For NetworkPolicies: A CNI that supports NetworkPolicy enforcement (Calico, Cilium, Weave Net, etc.)

## Key Features

### ✨ Comprehensive Node Placement Control
- **Service-level configuration**: Configure nodeSelector, tolerations, and affinity for individual services
- **Database-level configuration**: Independent node placement settings for ClickHouse, PostgreSQL, and MinIO
- **Intelligent precedence**: Individual service settings override common settings
- **Complete coverage**: All services and databases support full node placement configuration

### 🔧 Flexible Environment Variables
- **Common environment variables**: Set shared environment variables across all services
- **Service-specific overrides**: Each service can define its own environment variables
- **Gateway service support**: Special handling for gateway service configuration
- **Precedence control**: Service-specific env vars take priority over common settings

### 🚀 Advanced Scheduling Features
- **Pod affinity/anti-affinity**: Control pod co-location and separation
- **Node affinity**: Schedule pods on specific node types
- **Toleration support**: Allow scheduling on tainted nodes
- **HPA integration**: Horizontal Pod Autoscaling with proper node placement

### 🔒 Enhanced Security
- **NetworkPolicies**: Fine-grained database access control
- **Service isolation**: Limit database access to authorized services only
- **CNI compatibility**: Automatic detection and graceful fallback

## Quick Start Examples

### Basic Installation
```bash
helm install zymtrace ./charts/backend \
  --set global.licenseKey="your-license-key"
```

### Installation with Node Placement
```bash
helm install zymtrace ./charts/backend \
  --set global.licenseKey="your-license-key" \
  --set services.common.nodeSelector."kubernetes\.io/arch"="amd64" \
  --set clickhouse.nodeSelector."workload-type"="database" \
  --set postgres.nodeSelector."workload-type"="database"
```

### Installation with Service-Specific Configuration
```bash
helm install zymtrace ./charts/backend \
  --set global.licenseKey="your-license-key" \
  --set services.symdb.env.RUST_LOG="debug" \
  --set services.web.env.RUST_LOG="info" \
  --set services.symdb.nodeSelector."storage-type"="high-iops"
```

### Installation with External Databases
```bash
helm install zymtrace ./charts/backend \
  --set global.licenseKey="your-license-key" \
  --set clickhouse.mode="use_existing" \
  --set clickhouse.use_existing.host="https://clickhouse.example.com:8443" \
  --set postgres.mode="use_existing" \
  --set postgres.use_existing.host="postgres.example.com:5432"
```

## Network Security with NetworkPolicies

This chart includes optional NetworkPolicy resources to secure database access within your cluster. NetworkPolicies restrict which pods can communicate with your PostgreSQL and ClickHouse databases.

### How NetworkPolicies Work

When enabled, the chart creates NetworkPolicies that:

- **PostgreSQL**: Only allow access from `migrate`, `identity`, and `symdb` services
- **ClickHouse**: Only allow access from `ingest` and `web` services
- **Block all other traffic**: Any other pods in the cluster are denied access to the databases

### CNI Compatibility

NetworkPolicies require a Container Network Interface (CNI) that supports policy enforcement:

### Enabling/Disabling NetworkPolicies

NetworkPolicies are **enabled by default**. To disable them (e.g., for Flannel clusters):

```yaml
services:
  activateNetworkPolicies: false
```

Or via Helm command:
```bash
helm install zymtrace ./charts/backend --set services.activateNetworkPolicies=false
```

### Important Notes

- NetworkPolicies only apply when databases are deployed within the cluster (`create` mode for ClickHouse, `create` or `gcp_cloudsql` modes for PostgreSQL)
- For `use_existing` database modes, no NetworkPolicies are created since databases are external
- The chart automatically detects if NetworkPolicy API is available and skips creation if not supported
- Standard Flannel users **must** set `activateNetworkPolicies: false` to avoid silent policy failures

### Troubleshooting NetworkPolicies

If you experience connectivity issues after enabling NetworkPolicies:

1. **Check if your CNI supports NetworkPolicies**:
   ```bash
   kubectl get networkpolicies -n your-namespace
   kubectl describe networkpolicy zymtrace-postgres-network-policy -n your-namespace
   ```

2. **Verify pod labels match policy selectors**:
   ```bash
   kubectl get pods --show-labels -n your-namespace
   ```

3. **Test connectivity** from allowed services:
   ```bash
   kubectl exec -it zymtrace-identity-xxx -- nc -zv zymtrace-postgres 5432
   ```

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

## Service Configuration

This chart provides flexible configuration options for each service, allowing you to customize behavior at both the common level and individual service level.

### Individual Service Configuration

Each service supports individual configuration that takes precedence over common settings:

```yaml
services:
  # Common configuration applied to all services (unless overridden)
  common:
    nodeSelector:
      kubernetes.io/arch: amd64
    tolerations:
    - key: "shared"
      operator: "Equal"
      value: "zymtrace"
      effect: "NoSchedule"
    affinity: {}
    env:
      OTEL_EXPORTER_OTLP_METRICS_ENDPOINT: "http://jaeger:4317"
  
  # Individual service configuration (takes precedence over common)
  symdb:
    nodeSelector:
      storage-type: high-iops  # Overrides common nodeSelector
    tolerations:
    - key: "workload"          # Overrides common tolerations
      operator: "Equal"
      value: "symdb"
      effect: "NoSchedule"
    env:
      RUST_LOG: "debug"        # Service-specific environment variable
      SYMDB__DEBUGINFOD_SERVERS: "https://debuginfod.ubuntu.com"
    affinity:
      nodeAffinity:           # Service-specific affinity
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: workload-type
              operator: In
              values:
              - database
  
  # Another service with different configuration
  web:
    env:
      RUST_LOG: "info"
    affinity:
      podAntiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - zymtrace-web
            topologyKey: kubernetes.io/hostname

# Database configuration (independent of service settings)
clickhouse:
  nodeSelector:
    storage-type: high-performance
  tolerations:
  - key: "database"
    operator: "Equal"
    value: "clickhouse"
    effect: "NoSchedule"
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: workload-type
            operator: In
            values:
            - database

postgres:
  nodeSelector:
    database-tier: primary
  tolerations:
  - key: "database"
    operator: "Equal"
    value: "postgres"
    effect: "NoSchedule"
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values:
              - zymtrace-postgres
          topologyKey: kubernetes.io/hostname

storage:
  nodeSelector:
    storage-type: object-storage
  tolerations:
  - key: "storage"
    operator: "Equal"
    value: "minio"
    effect: "NoSchedule"
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 50
        preference:
          matchExpressions:
          - key: storage-type
            operator: In
            values:
            - high-iops
```

### Supported Individual Service Settings

Each service (`ingest`, `web`, `symdb`, `ui`, `identity`, `migrate`, `gateway`) supports:

- **nodeSelector**: Node selection constraints
- **tolerations**: Toleration of node taints
- **affinity**: Pod affinity and anti-affinity rules
- **env**: Service-specific environment variables
- **resources**: CPU and memory limits/requests
- **hpa**: Horizontal Pod Autoscaler settings

### Environment Variables

Set environment variables at the common level or per service:

```yaml
services:
  common:
    env:
      # Applied to all services
      SHARED_SETTING: "value"
      OTEL_ENDPOINT: "http://otel-collector:4317"
  
  web:
    env:
      # Only applied to web service
      WEB__CUSTOM_SETTING: "production"
      RUST_LOG: "info"
  
  ingest:
    env:
      # Only applied to ingest service
      RUST_LOG: "debug"  # Different log level for ingest
```

## Node Placement

Control where pods are scheduled using nodeSelector, tolerations, and affinity.

### Node Selectors

Specify node selectors at the common level or per service:

```yaml
# Common node selector for all services
services:
  common:
    nodeSelector:
      kubernetes.io/arch: amd64
      disk-type: ssd

# Individual service node selectors (override common)
services:
  symdb:
    nodeSelector:
      storage-type: high-performance
      workload-type: database

# Database node selectors
clickhouse:
  nodeSelector:
    storage-type: high-performance
    
postgres:
  nodeSelector:
    database-tier: primary
```

### Tolerations

Allow pods to be scheduled on tainted nodes:

```yaml
# Common tolerations for all services
services:
  common:
    tolerations:
    - key: "dedicated"
      operator: "Equal"
      value: "zymtrace"
      effect: "NoSchedule"

# Individual service tolerations (override common)
services:
  ingest:
    tolerations:
    - key: "workload"
      operator: "Equal"
      value: "compute-intensive"
      effect: "NoSchedule"

# Database tolerations
postgres:
  tolerations:
  - key: "node.kubernetes.io/memory-pressure"
    operator: "Exists"
    effect: "NoExecute"
    tolerationSeconds: 3600
```

### Affinity Rules

Configure pod affinity and anti-affinity for both services and databases:

```yaml
# Common affinity for all services
services:
  common:
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: kubernetes.io/arch
              operator: In
              values:
              - amd64

# Individual service affinity (overrides common)
services:
  web:
    affinity:
      podAntiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - zymtrace-web
            topologyKey: kubernetes.io/hostname

# Database affinity configuration
clickhouse:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: workload-type
            operator: In
            values:
            - database

postgres:
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values:
              - zymtrace-postgres
          topologyKey: kubernetes.io/hostname

storage:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 50
        preference:
          matchExpressions:
          - key: storage-type
            operator: In
            values:
            - high-iops
```

### Configuration Precedence

The configuration precedence (highest to lowest) is:

1. **Individual service settings** (e.g., `services.symdb.nodeSelector`)
2. **Common service settings** (e.g., `services.common.nodeSelector`)
3. **Default values**

**Database Configuration:** Databases (ClickHouse, PostgreSQL, MinIO) support their own dedicated configuration sections and do not inherit from service common settings. Each database component supports:
- `nodeSelector`: Node selection constraints
- `tolerations`: Toleration of node taints  
- `affinity`: Pod affinity and anti-affinity rules

**IMPORTANT NOTE:** When using tolerations with tainted nodes, ensure you configure tolerations for both:

1. `services.common.tolerations` (for application services)
2. Database component tolerations (e.g., `clickhouse.tolerations`, `postgres.tolerations`, `storage.tolerations`)

This ensures initialization jobs and database pods can also run on tainted nodes.

## Parameters

### Global Configuration
| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.licenseKey` | Your zymtrace license key | `""` |
| `global.namePrefix` | Prefix for all resource names | `"zymtrace"` |
| `global.imageRegistry` | Default registry for all images | `"docker.io"` |
| `global.appImageRegistry` | Specific registry for zymtrace backend services | `"ghcr.io/zystem-io"` |
| `global.registry.requirePullSecret` | Whether to use image pull secrets | `false` |
| `global.imagePullPolicy` | Image pull policy | `"IfNotPresent"` |
| `global.dataRetentionDays` | Data retention period in days (0 = forever) | `30` |

### Network Security
| Parameter | Description | Default |
|-----------|-------------|---------|
| `services.activateNetworkPolicies` | Enable NetworkPolicy creation for database access control | `true` |

### Service Configuration
| Parameter | Description | Default |
|-----------|-------------|---------|
| `services.common.nodeSelector` | Node selector for all application services | `{}` |
| `services.common.tolerations` | Tolerations for all application services | `[]` |
| `services.common.affinity` | Affinity rules for all application services | `{}` |
| `services.common.env` | Environment variables for all application services | `{}` |
| `services.common.hpa.enabled` | Enable HPA for all services (unless overridden) | `false` |
| `services.common.hpa.minReplicas` | Default minimum replicas for HPA | `1` |
| `services.common.hpa.maxReplicas` | Default maximum replicas for HPA | `5` |
| `services.common.hpa.targetCPUUtilizationPercentage` | Default CPU target for HPA | `80` |

### Individual Service Configuration
Each service (`ingest`, `web`, `symdb`, `ui`, `identity`, `migrate`, `gateway`) supports:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `services.<service>.nodeSelector` | Node selector (overrides common) | `{}` |
| `services.<service>.tolerations` | Tolerations (overrides common) | `[]` |
| `services.<service>.affinity` | Affinity rules (overrides common) | `{}` |
| `services.<service>.env` | Environment variables (service-specific) | `{}` |
| `services.<service>.replicas` | Number of replicas | `1` |
| `services.<service>.resources` | CPU/memory requests and limits | varies |
| `services.<service>.hpa.enabled` | Enable HPA for this service | `false` |
| `services.<service>.hpa.minReplicas` | Minimum replicas for HPA | `1` |
| `services.<service>.hpa.maxReplicas` | Maximum replicas for HPA | `5` |
| `services.<service>.hpa.targetCPUUtilizationPercentage` | CPU target for HPA | `80` |

### Gateway Service
| Parameter | Description | Default |
|-----------|-------------|---------|
| `services.gateway.service.type` | Service type (ClusterIP, NodePort, LoadBalancer) | `"ClusterIP"` |
| `services.gateway.service.nodePort` | Node port when service type is NodePort | `""` |
| `services.gateway.port` | Gateway HTTP port | `80` |
| `services.gateway.adminPort` | Gateway admin port | `9901` |

### Authentication
| Parameter | Description | Default |
|-----------|-------------|---------|
| `auth.basic.enabled` | Enable HTTP basic authentication | `false` |
| `auth.basic.username` | Basic auth username (required when enabled) | `""` |
| `auth.basic.password` | Basic auth password (required when enabled) | `""` |

### Database Configuration

#### ClickHouse
| Parameter | Description | Default |
|-----------|-------------|---------|
| `clickhouse.mode` | ClickHouse mode: "create" or "use_existing" | `"create"` |
| `clickhouse.nodeSelector` | Node selector for ClickHouse database | `{}` |
| `clickhouse.tolerations` | Tolerations for ClickHouse database | `[]` |
| `clickhouse.affinity` | Affinity rules for ClickHouse database | `{}` |
| `clickhouse.create.replicas` | Number of ClickHouse replicas | `1` |
| `clickhouse.create.config.user` | ClickHouse username | `"clickhouse"` |
| `clickhouse.create.config.password` | ClickHouse password | `"clickhouse123"` |
| `clickhouse.create.config.database` | ClickHouse database prefix | `"zymtrace"` |
| `clickhouse.use_existing.host` | External ClickHouse URL (http://host:8123) | `""` |
| `clickhouse.use_existing.user` | External ClickHouse username | `""` |
| `clickhouse.use_existing.password` | External ClickHouse password | `""` |
| `clickhouse.use_existing.database` | External ClickHouse database prefix | `"zymtrace"` |
| `clickhouse.use_existing.autoCreateDBs` | Auto-create databases on external ClickHouse | `false` |

#### PostgreSQL
| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgres.mode` | PostgreSQL mode: "create", "use_existing", or "gcp_cloudsql" | `"create"` |
| `postgres.nodeSelector` | Node selector for PostgreSQL database | `{}` |
| `postgres.tolerations` | Tolerations for PostgreSQL database | `[]` |
| `postgres.affinity` | Affinity rules for PostgreSQL database | `{}` |
| `postgres.create.replicas` | Number of PostgreSQL replicas | `1` |
| `postgres.create.config.user` | PostgreSQL username | `"postgres"` |
| `postgres.create.config.password` | PostgreSQL password | `"postgres123"` |
| `postgres.use_existing.host` | External PostgreSQL host:port | `""` |
| `postgres.use_existing.user` | External PostgreSQL username | `""` |
| `postgres.use_existing.password` | External PostgreSQL password | `""` |
| `postgres.use_existing.database` | External PostgreSQL database prefix | `"zymtrace"` |
| `postgres.use_existing.secure` | Enable TLS for external PostgreSQL | `false` |
| `postgres.use_existing.autoCreateDBs` | Auto-create databases on external PostgreSQL | `false` |

#### Google Cloud SQL
| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgres.gcp_cloudsql.instance` | Cloud SQL instance (PROJECT:REGION:INSTANCE) | `""` |
| `postgres.gcp_cloudsql.user` | Cloud SQL IAM user | `""` |
| `postgres.gcp_cloudsql.database` | Cloud SQL database prefix | `"zymtrace"` |
| `postgres.gcp_cloudsql.autoCreateDBs` | Auto-create databases on Cloud SQL | `false` |
| `postgres.gcp_cloudsql.privateIP` | Use private IP connectivity | `false` |
| `postgres.gcp_cloudsql.workloadIdentity.enabled` | Enable Workload Identity | `true` |
| `postgres.gcp_cloudsql.proxy.port` | Cloud SQL Proxy port | `5432` |
| `postgres.gcp_cloudsql.serviceAccount` | Kubernetes service account for Workload Identity | `""` |
| `postgres.gcp_cloudsql.replicas` | Number of proxy replicas (when HPA disabled) | `1` |
| `postgres.gcp_cloudsql.hpa.enabled` | Enable HPA for Cloud SQL proxy | `false` |

#### Object Storage
| Parameter | Description | Default |
|-----------|-------------|---------|
| `storage.mode` | Storage mode: "create" or "use_existing" | `"create"` |
| `storage.nodeSelector` | Node selector for MinIO object storage | `{}` |
| `storage.tolerations` | Tolerations for MinIO object storage | `[]` |
| `storage.affinity` | Affinity rules for MinIO object storage | `{}` |
| `storage.create.replicas` | Number of MinIO replicas | `1` |
| `storage.create.config.user` | MinIO access key | `"minio"` |
| `storage.create.config.password` | MinIO secret key | `"minio123"` |
| `storage.use_existing.type` | External storage type: "minio", "s3", or "gcs" | `"minio"` |
| `storage.use_existing.minio.endpoint` | MinIO endpoint URL (must include http:// or https://) | `""` |
| `storage.use_existing.minio.user` | MinIO access key | `""` |
| `storage.use_existing.minio.password` | MinIO secret key | `""` |
| `storage.use_existing.s3.region` | AWS S3 region | `""` |
| `storage.use_existing.s3.accessKey` | AWS S3 access key | `""` |
| `storage.use_existing.s3.secretKey` | AWS S3 secret key | `""` |
| `storage.use_existing.s3.endpoint` | Custom S3 endpoint (optional) | `""` |
| `storage.use_existing.s3.sessionToken` | AWS S3 session token (optional) | `""` |
| `storage.use_existing.gcs.endpoint` | GCS S3-compatible endpoint | `"https://storage.googleapis.com"` |
| `storage.use_existing.gcs.accessKey` | GCS HMAC access key | `""` |
| `storage.use_existing.gcs.secretKey` | GCS HMAC secret key | `""` |
| `storage.buckets.symbols` | Symbol storage bucket name | `"zymtrace-symdb"` |

### Global Symbolization
| Parameter | Description | Default |
|-----------|-------------|---------|
| `globalSymbolization.enabled` | Enable global symbolization service | `false` |
| `globalSymbolization.config.bucketName` | Global symbolization bucket name | `""` |
| `globalSymbolization.config.accessKey` | Global symbolization access key | `""` |
| `globalSymbolization.config.secretKey` | Global symbolization secret key | `""` |
| `globalSymbolization.config.region` | Global symbolization region | `""` |
| `globalSymbolization.config.endpoint` | Global symbolization endpoint | `""` |

### Ingress
| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress creation | `false` |
| `ingress.className` | Ingress class name | `"nginx"` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.hosts.gateway.enabled` | Enable gateway ingress | `true` |
| `ingress.hosts.gateway.host` | Gateway hostname | `""` |
| `ingress.tls` | TLS configuration | `[]` |

## Google Cloud SQL with IAM Authentication

This chart supports using Google Cloud SQL for PostgreSQL with IAM authentication via the Cloud SQL Auth Proxy.

### Setting up IAM Authentication for Cloud SQL

1. **Create a Google Cloud SQL PostgreSQL instance**

   ```bash
   gcloud sql instances create zymtrace-pg \
     --database-version=POSTGRES_14 \
     --cpu=2 \
     --memory=4GB \
     --region=us-central1
   ```

2. **Create a database user with the Cloud SQL IAM Authentication enabled**

   ```bash
   gcloud sql users create postgres \
     --instance=zymtrace-pg \
     --type=cloud_iam_service_account
   ```

3. **Create a database (if needed)**

   ```bash
   gcloud sql databases create zymtrace --instance=zymtrace-pg
   ```

4. **Create a service account for the Cloud SQL Auth Proxy**

   ```bash
   gcloud iam service-accounts create zymtrace-cloudsql-sa \
     --display-name="Service Account for zymtrace Cloud SQL"
   ```

5. **Grant the necessary IAM roles to the service account**

   ```bash
   # Get the project ID
   PROJECT_ID=$(gcloud config get-value project)

   # Grant the Cloud SQL Client role
   gcloud projects add-iam-policy-binding $PROJECT_ID \
     --member="serviceAccount:zymtrace-cloudsql-sa@$PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/cloudsql.client"

   # Grant the IAM role to use the Cloud SQL instance
   gcloud projects add-iam-policy-binding $PROJECT_ID \
     --member="serviceAccount:zymtrace-cloudsql-sa@$PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/cloudsql.instanceUser"
   ```

6. **Create a Kubernetes service account and link it to the GCP service account using Workload Identity**

   ```bash
   # Create a Kubernetes service account
   kubectl create serviceaccount zymtrace-cloudsql-sa -n your-namespace

   # Annotate the Kubernetes service account to use with Workload Identity
   kubectl annotate serviceaccount zymtrace-cloudsql-sa \
     --namespace your-namespace \
     iam.gke.io/gcp-service-account=zymtrace-cloudsql-sa@$PROJECT_ID.iam.gserviceaccount.com

   # Allow the Kubernetes ServiceAccount to impersonate the GCP service account
   gcloud iam service-accounts add-iam-policy-binding \
     --role="roles/iam.workloadIdentityUser" \
     --member="serviceAccount:$PROJECT_ID.svc.id.goog[your-namespace/zymtrace-cloudsql-sa]" \
     zymtrace-cloudsql-sa@$PROJECT_ID.iam.gserviceaccount.com
   ```

7. **Install the Helm chart with Google Cloud SQL configuration**

   ```bash
   helm install zymtrace ./charts/backend \
     --set postgres.mode=gcp_cloudsql \
     --set postgres.gcp_cloudsql.instance="$PROJECT_ID:us-central1:zymtrace-pg" \
     --set postgres.gcp_cloudsql.user="postgres" \
     --set postgres.gcp_cloudsql.database="zymtrace" \
     --set postgres.gcp_cloudsql.serviceAccount="zymtrace-cloudsql-sa"
   ```

### Example values.yaml for Cloud SQL with IAM

```yaml
postgres:
  mode: "gcp_cloudsql"
  gcp_cloudsql:
    instance: "my-project:us-central1:zymtrace-pg"  # PROJECT:REGION:INSTANCE
    user: "postgres"
    database: "zymtrace"
    autoCreateDBs: true  # Enable automatic database creation
    proxy:
      serviceAccount: "zymtrace-cloudsql-sa"  # Kubernetes service account with Workload Identity
      # Optional: customize resource limits
      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "500m"
          memory: "256Mi"
```

## Object Storage Configuration

This chart supports three types of object storage for storing symbol files:

1. **Create mode**: Deploys MinIO within the cluster
2. **Use existing**: Connects to external storage services (MinIO, AWS S3, or Google Cloud Storage)

## ClickHouse Database Configuration

This chart supports two modes for ClickHouse database deployment:

1. **Create mode**: Deploys ClickHouse within the cluster (default)
2. **Use existing**: Connects to an external ClickHouse instance

### Using an Existing ClickHouse Instance
Only the HTTP interface port is supported due to limitations in the official ClickHouse Rust client. The native protocol port (9000) is not supported.

As a result, when connecting to an external ClickHouse instance, you must provide a complete URL with protocol and port:

```yaml
clickhouse:
  mode: "use_existing"
  use_existing:
    host: "https://clickhouse.example.com:8443"  # Must include protocol and port
    user: "your-username"
    password: "your-password"
    database: "zymtrace"  # Database prefix - actual DBs will be zymtrace_profiling and zymtrace_metrics
    autoCreateDBs: false  # Enable automatic database creation if user has permissions
```

#### Host URL Requirements

The `host` field must include:
- **Protocol**: `http://` or `https://`
- **Hostname/IP**: The ClickHouse server address
- **Port**: The HTTP interface port (typically 8123 for HTTP, 8443 for HTTPS)


**Valid examples:**
- `http://clickhouse.internal:8123`
- `https://my-clickhouse.example.com:8443`
- `http://192.168.1.100:8123`


#### Auto-Database Creation

When `autoCreateDBs: true`, the chart will automatically create the required databases (`zymtrace_profiling` and `zymtrace_metrics`) if they don't exist. The database user must have `CREATE DATABASE` permissions for this to work.

### Storage Types

#### MinIO (Self-hosted)
Use an existing MinIO instance:

```yaml
storage:
  mode: "use_existing"
  use_existing:
    type: "minio"
    minio:
      endpoint: "https://minio.example.com"  # Must be a complete URL with http:// or https://
      user: "your-access-key"
      password: "your-secret-key"
```

#### Amazon S3
Use AWS S3 buckets:

```yaml
storage:
  mode: "use_existing"
  use_existing:
    type: "s3"
    s3:
      region: "us-west-2"
      accessKey: ""
      secretKey: ""
```

#### Google Cloud Storage (GCS)
Use Google Cloud Storage buckets via S3-compatible API:

```yaml
storage:
  mode: "use_existing"
  use_existing:
    type: "gcs"
    gcs:
      endpoint: "https://storage.googleapis.com"  # Optional, defaults to this value
      accessKey: "GOOGXXYY..."  # GCS access key (HMAC key)
      secretKey: "your-gcs-secret-key"  # GCS secret key (HMAC key)
```


### Storage Validation

The chart includes automatic validation and bucket connectivity checks:

- **Endpoint validation**: Ensures all endpoints start with `http://` or `https://`
- **Storage type validation**: Only accepts `"minio"`, `"s3"`, or `"gcs"` as valid types
- **Bucket connectivity**: Post-installation jobs verify bucket access and permissions

During deployment, you'll see debug output showing the storage configuration being used:

```
Storage Type: GCS (S3-compatible)
Bucket Name: zymtrace-symbols
Endpoint: https://storage.googleapis.com
```

## PostgreSQL Database Auto-Creation

For PostgreSQL databases, you can enable automatic database creation in Cloud SQL or on existing servers.

### Enabling Auto-Creation

To enable automatic database creation:

1. Set `postgres.use_existing.autoCreateDBs` to `true` in your values.yaml or via --set:
   ```yaml
   postgres:
     use_existing:
       autoCreateDBs: true
   ```

   Or via Helm command:
   ```
   helm upgrade zymtrace ./charts/backend --set postgres.use_existing.autoCreateDBs=true
   ```

2. Specify the desired database name(s) in `postgres.use_existing.database`:
   ```yaml
   postgres:
     use_existing:
       database: "zymtrace"
   ```

3. The specified database will be automatically created on the PostgreSQL server if it doesn't already exist.

### Important Notes

- Auto-creation is only supported for PostgreSQL databases, not for other database types.
- The specified database name must be a valid PostgreSQL identifier.
- Ensure the database user has sufficient privileges to create databases.

### Example values.yaml for Auto-Creation

```yaml
postgres:
  mode: "gcp_cloudsql"
  gcp_cloudsql:
    instance: "my-project:us-central1:zymtrace-pg"  # PROJECT:REGION:INSTANCE
    user: "postgres"
    database: "zymtrace"
    autoCreateDBs: true  # Enable automatic database creation
    proxy:
      serviceAccount: "zymtrace-cloudsql-sa"  # Kubernetes service account with Workload Identity
      # Optional: customize resource limits
      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "500m"
          memory: "256Mi"
```

## Debugging Tips

If you encounter issues during deployment or operation, consider the following debugging tips:

- **Check pod logs** for error messages or stack traces:
  ```
  kubectl logs <pod-name>
  ```

- **Describe pods or services** to see detailed configuration and status:
  ```
  kubectl describe pod <pod-name>
  kubectl describe service <service-name>
  ```

- **Check Helm release status** and history for potential issues:
  ```
  helm status zymtrace
  helm history zymtrace
  ```

- **Review Kubernetes events** in the namespace for relevant warnings or errors:
  ```
  kubectl get events -n your-namespace
  ```

- **Check Cloud SQL instance** and database connectivity:
  ```
  # Connect to Cloud SQL instance
  gcloud sql connect zymtrace-pg --user=postgres

  # List databases
  \l

  # Check user privileges
  \du
  ```

- **Inspect HPA configuration** and status:
  ```
  kubectl get hpa -n your-namespace
  kubectl describe hpa <hpa-name> -n your-namespace
  ```

- **Review node placement** and scheduling:
  ```
  kubectl get pods -o wide
  kubectl describe node <node-name>
  ```

- **Review resource usage** and limits:
  ```
  kubectl top pods -n your-namespace
  kubectl top nodes
  ```

