#  Zymtrace Backend Chart
![Chart: 26.2.4](https://img.shields.io/badge/Chart-26.2.4) ![AppChart: 26.2.4](https://img.shields.io/badge/AppChart-26.2.4)

Deploy zymtrace's self-hosted backend services - a complete observability platform for CPU and GPU profiling.

**Homepage:** <https://docs.zymtrace.com>

## Source Code

* <https://github.com/zystem-io/zymtrace-charts/tree/main/charts>

## Documentation

For detailed configuration and usage instructions, see:
* [Getting Started](https://docs.zymtrace.com/getting-started)
* [Install Backend](https://docs.zymtrace.com/install/backend)
* [Architecture](https://docs.zymtrace.com/architecture)
* [Authentication](https://docs.zymtrace.com/authentication)
* [Database Configuration](https://docs.zymtrace.com/databases)

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- A metrics server installed in your cluster for HPA support
- PV provisioner support in the underlying infrastructure (for persistent storage)
- For Google Cloud SQL with IAM: GKE cluster with Workload Identity configured
- For NetworkPolicies: A CNI that supports NetworkPolicy enforcement (Calico, Cilium, Weave Net, etc.)

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
helm install backend zymtrace/backend \
  --namespace zymtrace \
  --create-namespace \
  -f backend-values.yaml
```

### Install without a values file (basic)

```bash
helm install backend zymtrace/backend \
  --namespace zymtrace \
  --create-namespace \
  --set global.licenseKey="your-license-key"
```

### Install with external databases

```bash
helm install backend zymtrace/backend \
  --namespace zymtrace \
  --create-namespace \
  --set clickhouse.mode="use_existing" \
  --set clickhouse.use_existing.host="https://clickhouse.example.com:8443" \
  --set clickhouse.use_existing.user="your-user" \
  --set clickhouse.use_existing.password="your-password" \
  --set postgres.mode="use_existing" \
  --set postgres.use_existing.host="postgres.example.com:5432" \
  --set postgres.use_existing.user="your-user" \
  --set postgres.use_existing.password="your-password"
```

## Key Features

- **Comprehensive Node Placement Control**: Configure nodeSelector, tolerations, and affinity for individual services and databases
- **Advanced Scheduling**: Pod affinity/anti-affinity, node affinity, HPA integration
- **Enhanced Security**: NetworkPolicies for fine-grained database access control
- **Multiple Database Modes**: Create in-cluster or connect to existing ClickHouse, PostgreSQL, and object storage
- **Authentication Options**:  OIDC (Google, Okta, Auth0, Azure AD), or local auth

## Configuration Examples (values file)

See the [Values](#values) section for all available options.

### Basic with Ingress

```yaml
global:
  licenseKey: "your-license-key"

ingress:
  enabled: true
  className: "nginx"
  hosts:
    gateway:
      enabled: true
      host: "zymtrace.company.com"
  tls:
    - secretName: zymtrace-tls
      hosts:
        - zymtrace.company.com
```

### With External Databases

```yaml
clickhouse:
  mode: "use_existing"
  use_existing:
    host: "https://clickhouse.example.com:8443"
    user: "your-username"
    password: "your-password"

postgres:
  mode: "use_existing"
  use_existing:
    host: "postgres.example.com:5432"
    user: "your-username"
    password: "your-password"
    secure: true
```

### With Google Cloud SQL

```yaml
postgres:
  mode: "gcp_cloudsql"
  gcp_cloudsql:
    instance: "my-project:us-central1:zymtrace-pg"
    user: "zt-db@my-project.iam"
    workloadIdentity:
      enabled: true
    serviceAccount: "zymtrace-cloudsql-sa"
```

### With External Object Storage

```yaml
# AWS S3
storage:
  mode: "use_existing"
  use_existing:
    type: "s3"
    s3:
      region: "us-west-2"
      accessKey: "your-access-key"
      secretKey: "your-secret-key"

# Or Google Cloud Storage
storage:
  mode: "use_existing"
  use_existing:
    type: "gcs"
    gcs:
      accessKey: "your-hmac-access-key"
      secretKey: "your-hmac-secret-key"
```

### With AI Assistant

```yaml
aiAssistant:
  enabled: true

  # Configure one or more AI providers
  anthropic:
    apiKey: "sk-ant-api03-..."

  gemini:
    apiKey: "AIzaSy..."

  openai:
    apiKey: "sk-proj-..."

  # Optional: Custom LLM endpoint (e.g., Groq, Together AI, self-hosted)
  customLLM:
    url: "https://your-llm-endpoint.com/v1/chat/completions"
    apiKey: "your-custom-api-key"
    models: "model-1,model-2"

  # Optional: Advanced configuration
  defaultProvider: "anthropic"  # Which provider to use by default
  defaultModel: "claude-sonnet"
  requestSizeLimit: 20971520  # 20 MiB
  sessionClearFreq: 3600  # 1 hour
```

## Network Security with NetworkPolicies

NetworkPolicies are **enabled by default** and restrict database access:

- **PostgreSQL**: Only accessible from `migrate`, `identity`, and `symdb` services
- **ClickHouse**: Only accessible from `ingest` and `web` services

To disable (e.g., for Flannel clusters):

```yaml
services:
  activateNetworkPolicies: false
```

## Horizontal Pod Autoscaling (HPA)

Enable HPA for automatic scaling based on CPU/memory utilization:

```yaml
services:
  common:
    hpa:
      enabled: true
      minReplicas: 1
      maxReplicas: 10
      targetCPUUtilizationPercentage: 60
      targetMemoryUtilizationPercentage: 70
```

## Values

### Global Configuration

| Key | Type | Description |
|-----|------|-------------|
| global.licenseKey | string | Your zymtrace license key |
| global.namePrefix | string | Prefix for all resource names |
| global.imageRegistry | string | Default registry for all images |
| global.appImageRegistry | string | Specific registry for zymtrace backend services |
| global.registry.requirePullSecret | bool | Whether to use image pull secrets |
| global.registry.username | string | Registry username |
| global.registry.password | string | Registry password |
| global.imagePullPolicy | string | Image pull policy |
| global.dataRetentionDays | int | Data retention period in days (0 = forever) |
| global.migrateServicesToHeadless | bool | Use pre-upgrade hooks for service migration |
| global.skipCapabilityCheck | bool | Skip API capability checks |
| global.skipDBMigrations | bool | Skip running database migrations |
| global.skipPostgresMigration | bool | Skip PostgreSQL migrations specifically |
| global.skipClickHouseMigration | bool | Skip ClickHouse migrations specifically |

### Authentication

| Key | Type | Description |
|-----|------|-------------|
| auth.type | string | Authentication type: "basic", "oidc", "local", or "none" |
| auth.info.displayName | string | Branding display name for login page |
| auth.info.pictureUri | string | Custom logo URI for login page |
| auth.serviceToken.enabled | bool | Enable service token authentication |
| auth.basic.username | string | Basic auth username |
| auth.basic.password | string | Basic auth password |
| auth.admin.email | string | Admin user email |
| auth.admin.password | string | Admin user password |
| auth.admin.roles | list | Admin user roles |
| auth.cookie.refreshMaxAgeSec | int | Cookie refresh max age in seconds |
| auth.cookie.secure | bool | Use secure cookies |
| auth.cookie.httpOnly | bool | Use HTTP-only cookies |
| auth.validation.issuers | list | List of possible token issuers |
| auth.validation.audiences | list | List of possible token audiences |
| auth.validation.keys.privateKey | string | Private key for token signing (PEM format) |
| auth.validation.keys.publicKey | string | Public key for token validation (PEM format) |
| auth.oidc.provider.clientId | string | OIDC client ID |
| auth.oidc.provider.clientSecret | string | OIDC client secret |
| auth.oidc.provider.issuerUri | string | OIDC issuer URL |
| auth.oidc.provider.redirectUri | string | OIDC redirect URI |
| auth.oidc.provider.scopes | list | OIDC scopes |

### AI Assistant Configuration

| Key | Type | Description | Default |
|-----|------|-------------|---------|
| aiAssistant.enabled | bool | Enable AI Assistant features | `false` |
| aiAssistant.anthropic.apiKey | string | Anthropic Claude API key | - |
| aiAssistant.gemini.apiKey | string | Google Gemini API key | - |
| aiAssistant.openai.apiKey | string | OpenAI API key | - |
| aiAssistant.customLLM.url | string | Custom LLM endpoint URL (OpenAI-compatible) | - |
| aiAssistant.customLLM.apiKey | string | Custom LLM API key | - |
| aiAssistant.customLLM.models | string | Comma-separated list of available custom models | - |
| aiAssistant.requestSizeLimit | int | Maximum request size for AI queries (bytes) | `20971520` (20 MiB) |
| aiAssistant.defaultProvider | string | Default AI provider (`anthropic`, `gemini`, `openai`, `custom`) | `anthropic` |
| aiAssistant.defaultModel | string | Default model for the provider | `claude-sonnet` |
| aiAssistant.sessionClearFreq | int | Session cleanup frequency (seconds) | `3600` (1 hour) |
| aiAssistant.mcpServers | list | MCP server configurations | See values.yaml |

For detailed AI Assistant configuration, see the [AI Assistant documentation](https://docs.zymtrace.com/ai-assistant/configure-ai-assistant).

### Global Symbolization

| Key | Type | Description |
|-----|------|-------------|
| globalSymbolization.enabled | bool | Enable global symbolization service |
| globalSymbolization.config.bucketName | string | Global symbolization bucket name |
| globalSymbolization.config.accessKey | string | Global symbolization access key |
| globalSymbolization.config.secretKey | string | Global symbolization secret key |
| globalSymbolization.config.region | string | Global symbolization region |
| globalSymbolization.config.endpoint | string | Global symbolization endpoint |

### ClickHouse Configuration

| Key | Type | Description |
|-----|------|-------------|
| clickhouse.mode | string | Mode: "create" or "use_existing" |
| clickhouse.nodeSelector | object | Node selector for ClickHouse |
| clickhouse.tolerations | list | Tolerations for ClickHouse |
| clickhouse.affinity | object | Affinity rules for ClickHouse |
| clickhouse.create.image.repository | string | ClickHouse image repository |
| clickhouse.create.image.tag | string | ClickHouse image tag |
| clickhouse.create.config.user | string | ClickHouse username |
| clickhouse.create.config.password | string | ClickHouse password |
| clickhouse.create.config.database | string | ClickHouse database prefix |
| clickhouse.create.service.http.port | int | ClickHouse HTTP port |
| clickhouse.create.service.native.port | int | ClickHouse native port |
| clickhouse.create.replicas | int | Number of ClickHouse replicas |
| clickhouse.create.resources | object | ClickHouse resource requests/limits |
| clickhouse.create.storage.type | string | Storage type: "persistent" or "empty_dir" |
| clickhouse.create.storage.size | string | Storage size |
| clickhouse.create.storage.className | string | Storage class name |
| clickhouse.create.storage.existing_pvc.pvcName | string | Name of existing PVC to use |
| clickhouse.create.storage.existing_pvc.subPath | string | Optional: subdirectory within PVC (useful for shared storage) |
| clickhouse.use_existing.host | string | External ClickHouse URL (http://host:8123) |
| clickhouse.use_existing.user | string | External ClickHouse username |
| clickhouse.use_existing.password | string | External ClickHouse password |
| clickhouse.use_existing.database | string | External ClickHouse database prefix |
| clickhouse.use_existing.clusterName | string | ClickHouse cluster name for distributed setups |
| clickhouse.use_existing.autoCreateDBs | bool | Auto-create databases |

### PostgreSQL Configuration

| Key | Type | Description |
|-----|------|-------------|
| postgres.mode | string | Mode: "create", "use_existing", "aws_aurora", or "gcp_cloudsql" |
| postgres.nodeSelector | object | Node selector for PostgreSQL |
| postgres.tolerations | list | Tolerations for PostgreSQL |
| postgres.affinity | object | Affinity rules for PostgreSQL |
| postgres.create.image.repository | string | PostgreSQL image repository |
| postgres.create.image.tag | string | PostgreSQL image tag |
| postgres.create.config.user | string | PostgreSQL username |
| postgres.create.config.password | string | PostgreSQL password |
| postgres.create.service.port | int | PostgreSQL port |
| postgres.create.replicas | int | Number of PostgreSQL replicas |
| postgres.create.resources | object | PostgreSQL resource requests/limits |
| postgres.create.storage.type | string | Storage type: "persistent" |
| postgres.create.storage.size | string | Storage size |
| postgres.create.storage.className | string | Storage class name |
| postgres.create.storage.existing_pvc.pvcName | string | Name of existing PVC to use |
| postgres.create.storage.existing_pvc.subPath | string | Optional: subdirectory within PVC (useful for shared storage) |
| postgres.use_existing.host | string | External PostgreSQL host:port |
| postgres.use_existing.user | string | External PostgreSQL username |
| postgres.use_existing.password | string | External PostgreSQL password |
| postgres.use_existing.useIAM | string | Use IAM authentication (null or "aws") |
| postgres.use_existing.awsRegion | string | AWS region for IAM auth |
| postgres.use_existing.database | string | External PostgreSQL database prefix |
| postgres.use_existing.secure | bool | Enable TLS/secure connection |
| postgres.use_existing.autoCreateDBs | bool | Auto-create databases |
| postgres.gcp_cloudsql.instance | string | Cloud SQL instance (PROJECT:REGION:INSTANCE) |
| postgres.gcp_cloudsql.user | string | Cloud SQL IAM user |
| postgres.gcp_cloudsql.database | string | Cloud SQL database prefix |
| postgres.gcp_cloudsql.autoCreateDBs | bool | Auto-create databases |
| postgres.gcp_cloudsql.privateIP | bool | Use private IP connectivity |
| postgres.gcp_cloudsql.workloadIdentity.enabled | bool | Enable Workload Identity |
| postgres.gcp_cloudsql.proxy.image.repository | string | Cloud SQL Proxy image repository |
| postgres.gcp_cloudsql.proxy.image.tag | string | Cloud SQL Proxy image tag |
| postgres.gcp_cloudsql.proxy.resources | object | Proxy resource requests/limits |
| postgres.gcp_cloudsql.proxy.port | int | Proxy port |
| postgres.gcp_cloudsql.serviceAccount | string | Kubernetes service account for Workload Identity |
| postgres.gcp_cloudsql.replicas | int | Number of proxy replicas |
| postgres.gcp_cloudsql.hpa.enabled | bool | Enable HPA for proxy |
| postgres.gcp_cloudsql.hpa.minReplicas | int | Minimum proxy replicas |
| postgres.gcp_cloudsql.hpa.maxReplicas | int | Maximum proxy replicas |

### Object Storage Configuration

| Key | Type | Description |
|-----|------|-------------|
| storage.mode | string | Mode: "create" or "use_existing" |
| storage.nodeSelector | object | Node selector for MinIO |
| storage.tolerations | list | Tolerations for MinIO |
| storage.affinity | object | Affinity rules for MinIO |
| storage.create.image.repository | string | MinIO image repository |
| storage.create.image.tag | string | MinIO image tag |
| storage.create.config.user | string | MinIO access key |
| storage.create.config.password | string | MinIO secret key |
| storage.create.service.api.port | int | MinIO API port |
| storage.create.service.console.port | int | MinIO console port |
| storage.create.replicas | int | Number of MinIO replicas |
| storage.create.resources | object | MinIO resource requests/limits |
| storage.create.storage.type | string | Storage type: "persistent" |
| storage.create.storage.size | string | Storage size |
| storage.create.storage.className | string | Storage class name |
| storage.create.storage.existing_pvc.pvcName | string | Name of existing PVC to use |
| storage.create.storage.existing_pvc.subPath | string | Optional: subdirectory within PVC (useful for shared storage) |
| storage.use_existing.type | string | External storage type: "minio", "s3", or "gcs" |
| storage.use_existing.minio.endpoint | string | MinIO endpoint URL |
| storage.use_existing.minio.user | string | MinIO access key |
| storage.use_existing.minio.password | string | MinIO secret key |
| storage.use_existing.s3.region | string | AWS S3 region |
| storage.use_existing.s3.accessKey | string | AWS S3 access key |
| storage.use_existing.s3.secretKey | string | AWS S3 secret key |
| storage.use_existing.s3.useIAM | string | Use IAM authentication (null or "aws") |
| storage.use_existing.gcs.endpoint | string | GCS S3-compatible endpoint |
| storage.use_existing.gcs.accessKey | string | GCS HMAC access key |
| storage.use_existing.gcs.secretKey | string | GCS HMAC secret key |
| storage.buckets.symbols | string | Symbol storage bucket name |

### Services Configuration

| Key | Type | Description |
|-----|------|-------------|
| services.activateNetworkPolicies | bool | Enable NetworkPolicy creation |
| services.healthProbes.liveness | bool | Enable liveness probes for all services |
| services.healthProbes.readiness | bool | Enable readiness probes for all services |
| services.common.imageTag | string | Common image tag for all services |
| services.common.nodeSelector | object | Common node selector for all services |
| services.common.tolerations | list | Common tolerations for all services |
| services.common.affinity | object | Common affinity rules for all services |
| services.common.env | object | Common environment variables for all services |
| services.common.hpa.enabled | bool | Enable HPA for all services |
| services.common.hpa.minReplicas | int | Default minimum replicas for HPA |
| services.common.hpa.maxReplicas | int | Default maximum replicas for HPA |
| services.common.hpa.targetCPUUtilizationPercentage | int | Default CPU target for HPA |
| services.common.hpa.targetMemoryUtilizationPercentage | int | Default memory target for HPA |

### Individual Service Configuration

Each service (`ingest`, `web`, `symdb`, `ui`, `identity`, `migrate`, `gateway`) supports:

| Key | Type | Description |
|-----|------|-------------|
| services.&lt;service&gt;.image.repository | string | Service image repository |
| services.&lt;service&gt;.image.tag | string | Service image tag |
| services.&lt;service&gt;.port | int | Service port |
| services.&lt;service&gt;.replicas | int | Number of replicas |
| services.&lt;service&gt;.resources | object | Resource requests/limits |
| services.&lt;service&gt;.nodeSelector | object | Node selector (overrides common) |
| services.&lt;service&gt;.tolerations | list | Tolerations (overrides common) |
| services.&lt;service&gt;.affinity | object | Affinity rules (overrides common) |
| services.&lt;service&gt;.env | object | Environment variables (service-specific) |
| services.&lt;service&gt;.hpa.enabled | bool | Enable HPA for this service |
| services.&lt;service&gt;.hpa.minReplicas | int | Minimum replicas for HPA |
| services.&lt;service&gt;.hpa.maxReplicas | int | Maximum replicas for HPA |

### Gateway Service

| Key | Type | Description |
|-----|------|-------------|
| services.gateway.service.type | string | Service type: ClusterIP, NodePort, or LoadBalancer |
| services.gateway.service.nodePort | string | Node port when service type is NodePort |
| services.gateway.port | int | Gateway HTTP port |
| services.gateway.portTrusted | int | Gateway trusted port |
| services.gateway.adminPort | int | Gateway admin port |
| services.gateway.xff_append | bool | Append X-Forwarded-For header |
| services.gateway.xff_num_trusted_hops | int | Number of trusted hops for XFF |
| services.gateway.mtls.enabled | bool | Enable mTLS for Gateway |
| services.gateway.mtls.cert | string | Server certificate (PEM format) |
| services.gateway.mtls.key | string | Server private key (PEM format) |
| services.gateway.mtls.ca | string | CA certificate for client validation (PEM format) |
| services.gateway.mtls.port | int | mTLS port |

### Ingress Configuration

| Key | Type | Description |
|-----|------|-------------|
| ingress.enabled | bool | Enable ingress creation |
| ingress.className | string | Ingress class name (nginx, traefik, alb) |
| ingress.annotations | object | Common ingress annotations |
| ingress.hosts.gateway.enabled | bool | Enable gateway ingress |
| ingress.hosts.gateway.host | string | Gateway hostname |
| ingress.hosts.gateway.paths | list | Gateway paths |
| ingress.hosts.gateway.annotations | object | Gateway-specific annotations |
| ingress.hosts.gateway.mtls.enabled | bool | Enable mTLS ingress |
| ingress.hosts.gateway.mtls.host | string | mTLS hostname |
| ingress.hosts.gateway.mtls.paths | list | mTLS paths |
| ingress.hosts.gateway.mtls.annotations | object | mTLS-specific annotations |
| ingress.tls | list | TLS configuration |

### RBAC Configuration

| Key | Type | Description |
|-----|------|-------------|
| rbac.create | bool | Create RBAC resources |
| rbac.rules | list | RBAC rules |
| serviceAccount.annotations | object | Service account annotations |

