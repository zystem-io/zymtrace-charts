{{/*
Create a resource name with prefix
*/}}
{{- define "zymtrace.resourceName" -}}
{{- $ctx := index . 0 -}}
{{- $name := index . 1 -}}
{{- printf "%s-%s" $ctx.Values.global.namePrefix $name | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Get component name from chart
*/}}
{{- define "zymtrace.componentName" -}}
{{- .Chart.Name -}}
{{- end }}

{{/*
Common labels
*/}}
{{- define "zymtrace.labels" -}}
component: {{ include "zymtrace.componentName" . }}
provider: zystem
managed-by: helm
chart-version: {{ .Chart.Version }} 
{{- end }}

{{/*
Selector labels
*/}}
{{- define "zymtrace.selectorLabels" -}}
component: {{ include "zymtrace.componentName" . }}
app: {{ include "zymtrace.resourceName" (list $ .) }}
{{- end }}

{{/*
  Determine if registry pull secret should be used
*/}}
{{- define "zymtrace.useRegistrySecret" -}}
{{- if or (not (hasKey .Values.global.registry "requirePullSecret")) (eq .Values.global.registry.requirePullSecret true) -}}
true
{{- end -}}
{{- end }}

{{/*
Image pull secrets helper
*/}}
{{- define "zymtrace.imagePullSecrets" -}}
{{- if include "zymtrace.useRegistrySecret" . }}
imagePullSecrets:
  - name: {{ include "zymtrace.resourceName" (list . "registry-cred") }}
{{- end }}
{{- end }}

{{/*
Common environment configuration
*/}}
{{- define "zymtrace.envConfig" -}}
envFrom:
  - configMapRef:
      name: {{ include "zymtrace.resourceName" (list . "config") }}
  - secretRef:
      name: {{ include "zymtrace.resourceName" (list . "secrets") }}
{{- end }}


{{/* Return the appropriate zymtrace image registry with trailing slash, or empty if not specified */}}
{{- define "zymtrace.imageRegistry" -}}
{{- if .Values.global.appImageRegistry -}}
{{- printf "%s/" .Values.global.appImageRegistry -}}
{{- else if .Values.global.imageRegistry -}}
{{- printf "%s/" .Values.global.imageRegistry -}}
{{- end -}}
{{- end }}

{{/* Return the appropriate repository name based on requirePullSecret, inserting -pub- in the middle when not requiring pull secret */}}
{{- define "zymtrace.repositoryName" -}}
{{- $root := index . 0 -}}
{{- $service := index . 1 -}}
{{- $serviceConfig := index $root.Values.services $service -}}
{{- if eq $root.Values.global.registry.requirePullSecret false -}}
{{- if hasPrefix "zymtrace-" $serviceConfig.image.repository -}}
{{- printf "zymtrace-pub-%s" (trimPrefix "zymtrace-" $serviceConfig.image.repository) -}}
{{- else -}}
{{- printf "zymtrace-pub-%s" $serviceConfig.image.repository -}}
{{- end -}}
{{- else -}}
{{- $serviceConfig.image.repository -}}
{{- end -}}
{{- end -}}


{{/* Return the appropriate database image registry with trailing slash, or empty if not specified */}}
{{- define "database.imageRegistry" -}}
{{- if .Values.global.dbImageRegistry -}}
{{- printf "%s/" .Values.global.dbImageRegistry -}}
{{- else if .Values.global.imageRegistry -}}
{{- printf "%s/" .Values.global.imageRegistry -}}
{{- end -}}
{{- end }}

{{/*
Return image tag version. Precedence is: 1) service tag 2. Common service tag. 3 Chart.AppVersion
*/}}
{{- define "zymtrace.serviceTag" -}}
{{- $root := index . 0 -}}
{{- $service := index . 1 -}}
{{- $serviceConfig := index $root.Values.services $service -}}
{{- $serviceConfig.image.tag | default $root.Values.services.common.imageTag | default $root.Chart.AppVersion -}}
{{- end }}

{{/* Node Selector configuration for services */}}
{{- define "zymtrace.nodeSelector" -}}
{{- with .Values.services.common.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/* Tolerations configuration for services */}}
{{- define "zymtrace.tolerations" -}}
{{- with .Values.services.common.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/* Node Selector configuration for databases */}}
{{- define "zymtrace.dbNodeSelector" -}}
{{- $component := index . 0 -}}
{{- $root := index . 1 -}}
{{- if hasKey (index $root.Values $component) "nodeSelector" }}
nodeSelector:
  {{- toYaml (index $root.Values $component "nodeSelector") | nindent 2 }}
{{- end }}
{{- end }}

{{/* Tolerations configuration for databases */}}
{{- define "zymtrace.dbTolerations" -}}
{{- $component := index . 0 -}}
{{- $root := index . 1 -}}
{{- if hasKey (index $root.Values $component) "tolerations" }}
tolerations:
  {{- toYaml (index $root.Values $component "tolerations") | nindent 2 }}
{{- end }}
{{- end }}

{{/* Get database tolerations as a value, not inside a "tolerations:" key */}}
{{- define "zymtrace.dbTolerationsValue" -}}
{{- $component := index . 0 -}}
{{- $root := index . 1 -}}
{{- if hasKey (index $root.Values $component) "tolerations" -}}
{{- toYaml (index $root.Values $component "tolerations") -}}
{{- end -}}
{{- end -}}

{{/*
Common resource configuration helper.
*/}}
{{- define "zymtrace.resourceConfig" -}}
{{- $root := index . 0 -}}
{{- $component := index . 1 -}}
resources:
{{- with (index $root.Values $component).create.resources }}
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Storage configuration helper
*/}}
{{- define "zymtrace.storage" -}}
{{- $root := index . 0 -}}
{{- $component := index . 1 -}}
{{- $configKey := ternary "storage" $component (eq $component "minio") -}}
{{- $config := index $root.Values $configKey -}}
{{- if eq $config.mode "create" -}}
{{- with $config.create.storage -}}
{{- if eq .type "persistent" }}
persistentVolumeClaim:
  claimName: {{ include "zymtrace.resourceName" (list $root $component) }}
{{- else if eq .type "empty_dir" }}
emptyDir: {}
{{- else }}
{{- fail "unsupported storage type" }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}


{{/*
Common environment variables handling with validation
*/}}
{{- define "zymtrace.commonEnvVars" -}}
{{- if .Values.services.common }}
{{- if .Values.services.common.env }}
{{- range $key, $value := .Values.services.common.env }}
{{- if and $key $value }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/* Validate mode for components */}}
{{- define "zymtrace.validateMode" -}}
{{- $component := index . 0 -}}
{{- $mode := index . 1 -}}
{{- if eq $component "postgres" -}}
{{- if not (or (eq $mode "create") (eq $mode "use_existing") (eq $mode "gcp_cloudsql")) -}}
{{- fail (printf "Invalid mode '%s' for component '%s'. Allowed values are 'create', 'use_existing', or 'gcp_cloudsql'" $mode $component) -}}
{{- end -}}
{{- else -}}
# For other components, only allow 2 modes
{{- if not (or (eq $mode "create") (eq $mode "use_existing")) -}}
{{- fail (printf "Invalid mode '%s' for component '%s'. Allowed values are 'create' or 'use_existing'" $mode $component) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Validate endpoint starts with http:// or https:// */}}
{{- define "zymtrace.validateEndpoint" -}}
{{- $endpoint := index . 0 -}}
{{- if not (or (hasPrefix "http://" $endpoint) (hasPrefix "https://" $endpoint)) -}}
{{- fail (printf "Invalid endpoint '%s'. Must start with http:// or https://" $endpoint) -}}
{{- end -}}
{{- end -}}

{{/* Validate basic auth credentials are provided when basic auth is enabled */}}
{{- define "zymtrace.validateBasicAuth" -}}
{{- if .Values.auth.basic.enabled -}}
{{- if or (eq .Values.auth.basic.username "") (eq .Values.auth.basic.password "") -}}
{{- fail "Basic authentication is enabled but username or password is empty. Please provide both auth.basic.username and auth.basic.password in the values.yaml or via --set." -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Check if metrics-server is available in the cluster */}}
{{- define "zymtrace.metricsServerAvailable" -}}
{{- $result := (lookup "apiregistration.k8s.io/v1" "APIService" "" "v1beta1.metrics.k8s.io") -}}
{{- if not $result -}}
{{- fail "\n⛔ ERROR: Metrics Server not detected\n\nHorizontal Pod Autoscaler (HPA) requires Metrics Server to function.\n\nOptions:\n  1. Install Metrics Server:\n     kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml\n\n  2. Disable HPA in your values.yaml:\n     hpa.enabled: false\n\nVerify installation with:\n  kubectl get apiservice v1beta1.metrics.k8s.io" -}}
{{- end -}}
{{- end -}}