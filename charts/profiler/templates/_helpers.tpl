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
app: {{ .Values.global.namePrefix }}
component: {{ include "zymtrace.componentName" . }}
provider: zystem
managed-by: helm
chart-version: {{ .Chart.Version }} 
{{- end }}

{{/*
Selector labels
*/}}
{{- define "zymtrace.selectorLabels" -}}
app: {{ .Values.global.namePrefix }}
component: {{ include "zymtrace.componentName" . }}
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
  - name: {{ include "zymtrace.resourceName" (list . "registry-cred-profiler") }}
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

{{/*
Return the appropriate image registry
*/}}
{{- define "zymtrace.imageRegistry" -}}
{{- .Values.global.imageRegistry -}}
{{- end }}

{{/*
Return image tag for profiler
*/}}
{{- define "zymtrace.profilerTag" -}}
{{- .Values.profiler.image.tag | default .Chart.AppVersion -}}
{{- end }}

{{/*
Environment variables helper template
*/}}
{{- define "zymtrace.profiler.env" -}}
{{- range $key, $value := .env }}
{{- if and (ne $key "fieldRefs") }}
{{- if $value }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- range $key, $fieldPath := .env.fieldRefs }}
{{- if $fieldPath }}
- name: {{ $key }}
  valueFrom:
    fieldRef:
      {{- if or (eq $key "NODE_NAME") (eq $key "KUBERNETES_NODE_NAME") }}
      fieldPath: spec.nodeName
      {{- else if eq $key "POD_NAME" }}
      fieldPath: metadata.name
      {{- else if eq $key "POD_NAMESPACE" }}
      fieldPath: metadata.namespace
      {{- else }}
      fieldPath: spec.nodeName  # Default fallback
      {{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Command line arguments helper template
Handles dynamic cluster_id tag injection when running as a subchart
*/}}
{{- define "zymtrace.profiler.args" -}}
{{- $clusterTag := "" -}}
{{- $metadata := .Values.global.ClusterMetadata -}}
{{- if and $metadata (hasKey $metadata "cluster_id") $metadata.cluster_id }}
{{- $clusterTag = printf "cluster_id:%s" $metadata.cluster_id -}}
{{- end -}}
{{- $tagsHandled := false -}}
{{- range .Values.profiler.args }}
{{- if hasPrefix "-tags=" . }}
{{- $tagsHandled = true }}
{{- if $clusterTag }}
{{- $existingTags := trimPrefix "-tags=" . }}
- {{ printf "-tags=%s;%s" $existingTags $clusterTag | quote }}
{{- else }}
- {{ . | quote }}
{{- end }}
{{- else }}
- {{ . | quote }}
{{- end }}
{{- end }}
{{- if and $clusterTag (not $tagsHandled) }}
- {{ printf "-tags=%s" $clusterTag | quote }}
{{- end }}
{{- end -}}