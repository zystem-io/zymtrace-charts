{{- define "zymtrace.hpa" -}}
{{- $root := index . 0 -}}
{{- $serviceName := index . 1 -}}
{{- $serviceValues := index . 2 -}}
{{- $commonHpa := $root.Values.services.common.hpa -}}
{{- $hpaEnabled := false -}}

{{- if hasKey $serviceValues "hpa" -}}
  {{- if hasKey $serviceValues.hpa "enabled" -}}
    {{- $hpaEnabled = $serviceValues.hpa.enabled -}}
  {{- end -}}
{{- else if and $commonHpa (hasKey $commonHpa "enabled") -}}
  {{- $hpaEnabled = $commonHpa.enabled -}}
{{- end -}}

{{- if and $hpaEnabled (hasKey $serviceValues "replicas") -}}
{{- include "zymtrace.metricsServerAvailable" $root -}}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "zymtrace.resourceName" (list $root $serviceName) }}
  namespace: {{ $root.Release.Namespace }}
  labels:
    {{- include "zymtrace.labels" $root | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "zymtrace.resourceName" (list $root $serviceName) }}
  minReplicas: {{ if hasKey $serviceValues "hpa" }}{{ if hasKey $serviceValues.hpa "minReplicas" }}{{ $serviceValues.hpa.minReplicas }}{{ else }}{{ $commonHpa.minReplicas | default 1 }}{{ end }}{{ else }}{{ $commonHpa.minReplicas | default 1 }}{{ end }}
  maxReplicas: {{ if hasKey $serviceValues "hpa" }}{{ if hasKey $serviceValues.hpa "maxReplicas" }}{{ $serviceValues.hpa.maxReplicas }}{{ else }}{{ $commonHpa.maxReplicas | default 10 }}{{ end }}{{ else }}{{ $commonHpa.maxReplicas | default 10 }}{{ end }}
  metrics:
    {{- $cpuTarget := "" -}}
    {{- if hasKey $serviceValues "hpa" -}}
      {{- if hasKey $serviceValues.hpa "targetCPUUtilizationPercentage" -}}
        {{- $cpuTarget = $serviceValues.hpa.targetCPUUtilizationPercentage -}}
      {{- else -}}
        {{- $cpuTarget = $commonHpa.targetCPUUtilizationPercentage -}}
      {{- end -}}
    {{- else -}}
      {{- $cpuTarget = $commonHpa.targetCPUUtilizationPercentage -}}
    {{- end -}}
    {{- if $cpuTarget }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ $cpuTarget }}
    {{- end }}

    {{- $memTarget := "" -}}
    {{- if hasKey $serviceValues "hpa" -}}
      {{- if hasKey $serviceValues.hpa "targetMemoryUtilizationPercentage" -}}
        {{- $memTarget = $serviceValues.hpa.targetMemoryUtilizationPercentage -}}
      {{- else -}}
        {{- $memTarget = $commonHpa.targetMemoryUtilizationPercentage -}}
      {{- end -}}
    {{- else -}}
      {{- $memTarget = $commonHpa.targetMemoryUtilizationPercentage -}}
    {{- end -}}
    {{- if $memTarget }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ $memTarget }}
    {{- end }}

  {{- $behavior := "" -}}
  {{- if hasKey $serviceValues "hpa" -}}
    {{- if hasKey $serviceValues.hpa "behavior" -}}
      {{- $behavior = $serviceValues.hpa.behavior -}}
    {{- else if $commonHpa -}}
      {{- $behavior = $commonHpa.behavior -}}
    {{- end -}}
  {{- else if $commonHpa -}}
    {{- $behavior = $commonHpa.behavior -}}
  {{- end -}}
  {{- with $behavior }}
  behavior:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}

---

apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "zymtrace.resourceName" (list $root $serviceName) }}-pdb
spec:
  {{- if $hpaEnabled }}
  maxUnavailable: 30%
  {{- else }}
  maxUnavailable: 1
  {{- end }}
  selector:
    matchLabels:
      app: {{ include "zymtrace.resourceName" (list $root $serviceName) }}

{{- end }}
