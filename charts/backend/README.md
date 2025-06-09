# zymtrace Backend Helm Chart

This Helm chart deploys zymtrace backend services to a Kubernetes cluster.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- A metrics server installed in your cluster for HPA support
- PV provisioner support in the underlying infrastructure (for persistent storage)
- For Google Cloud SQL with IAM: GKE cluster with Workload Identity configured
- For NetworkPolicies: A CNI that supports NetworkPolicy enforcement (Calico, Cilium, Weave Net, etc.)

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
| `services.activateNetworkPolicies` | Enable NetworkPolicy creation for database access control | `true` |
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
| `postgres.use_existing.database` | Database name for existing PostgreSQL server | `postgres` |
| `postgres.use_existing.autoCreateDBs` | Enable automatic database creation for existing PostgreSQL | `false` |
| `postgres.gcp_cloudsql.instance` | Google Cloud SQL instance connection name (PROJECT:REGION:INSTANCE) | `""` |
| `postgres.gcp_cloudsql.user` | Database user for Cloud SQL IAM authentication | `""` |
| `postgres.gcp_cloudsql.database` | Database name in Cloud SQL | `postgres` |
| `postgres.gcp_cloudsql.autoCreateDBs` | Enable automatic database creation for Cloud SQL | `false` |
| `postgres.gcp_cloudsql.proxy.image.repository` | Cloud SQL Auth Proxy container image repository | `gcr.io/cloud-sql-connectors/cloud-sql-proxy` |
| `postgres.gcp_cloudsql.proxy.image.tag` | Cloud SQL Auth Proxy container image tag | `2.11.0` |
| `postgres.gcp_cloudsql.proxy.resources.requests.cpu` | CPU resource requests for Cloud SQL Auth Proxy | `100m` |
| `postgres.gcp_cloudsql.proxy.resources.requests.memory` | Memory resource requests for Cloud SQL Auth Proxy | `128Mi` |
| `postgres.gcp_cloudsql.proxy.resources.limits.cpu` | CPU resource limits for Cloud SQL Auth Proxy | `500m` |
| `postgres.gcp_cloudsql.proxy.resources.limits.memory` | Memory resource limits for Cloud SQL Auth Proxy | `256Mi` |
| `postgres.gcp_cloudsql.proxy.port` | Port for Cloud SQL Auth Proxy | `5432` |
| `postgres.gcp_cloudsql.serviceAccount` | Kubernetes service account for Cloud SQL Auth Proxy | `""` |
| `storage.nodeSelector` | Node selector for MinIO object storage | `{}` |
| `storage.tolerations` | Tolerations for MinIO object storage | `[]` |
| `storage.mode` | Storage mode: "create" or "use_existing" | `"create"` |
| `storage.use_existing.type` | Storage type: "minio", "s3", or "gcs" | `"minio"` |
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

