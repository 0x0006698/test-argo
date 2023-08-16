{{/* Render HPA metrics spec for resource targets */}}
{{- define "hpa.metrics.resource" -}}
resource:
  name: {{ .resource | required ".hpa.metrics.item.resource must be defined" }}
  target:
  {{- with .target }}
    {{- $type := .type | required ".hpa.metrics.item.resource.target.type must be defined" }}
    {{- $value := .value | required ".hpa.metrics.item.resource.target.value must be defined" }}
    type: {{ $type }}
    {{- if $type | eq "AverageValue" }}
    averageValue: {{ $value }}
    {{- else if $type | eq "Utilization" }}
    averageUtilization: {{ $value }}
    {{- else if $type | eq "Value" }}
    value: {{ $value }}
    {{- else }}
    {{ fail ".hpa.metrics.item.resource.target.type is unsupported" }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/* Render HPA metrics spec for external targets */}}
{{- define "hpa.metrics.external" -}}
external:
  metric: {{ include "hpa.metrics.name" .metric | nindent 4 }}
  target:
  {{- with .target }}
    {{- $type := .type | required ".hpa.metrics.item.external.target.type must be defined" }}
    {{- $value := .value | required ".hpa.metrics.item.external.target.value must be defined" }}
    type: {{ $type }}
    {{- if $type | eq "AverageValue" }}
    averageValue: {{ $value }}
    {{- else if $type | eq "Value" }}
    value: {{ $value }}
    {{- else }}
    {{ fail ".hpa.metrics.item.external.target.type is unsupported" }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/* Render HPA metrics spec for custom pods metrics */}}
{{- define "hpa.metrics.pods" -}}
pods:
  metric: {{ include "hpa.metrics.name" .metric | nindent 4 }}
  target:
  {{- with .target }}
    {{- $type := .type | required ".hpa.metrics.item.pods.target.type must be defined" }}
    {{- $value := .value | required ".hpa.metrics.item.pods.target.value must be defined" }}
    type: {{ $type }}
    {{- if $type | eq "AverageValue" }}
    averageValue: {{ $value }}
    {{- else if $type | eq "Value" }}
    value: {{ $value }}
    {{- else }}
    {{ fail ".hpa.metrics.item.pods.target.type is unsupported" }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/* Render HPA metrics spec for custom object metrics */}}
{{- define "hpa.metrics.object" -}}
object:
  describedObject:
  {{- with .describedObject }}
    apiVersion: {{ .apiVersion | required ".hpa.metrics.item.object.describedObject.apiVersion must be defined" }}
    kind: {{ .kind | required ".hpa.metrics.item.object.describedObject.kind must be defined" }}
    name: {{ .name | required ".hpa.metrics.item.object.describedObject.name must be defined" }}
  {{- end }}
  metric: {{ include "hpa.metrics.name" .metric | nindent 4 }}
  target:
  {{- with .target }}
    {{- $type := .type | required ".hpa.metrics.item.object.target.type must be defined" }}
    {{- $value := .value | required ".hpa.metrics.item.object.target.value must be defined" }}
    type: {{ $type }}
    {{- if $type | eq "AverageValue" }}
    averageValue: {{ $value }}
    {{- else if $type | eq "Value" }}
    value: {{ $value }}
    {{- else }}
    {{ fail ".hpa.metrics.item.object.target.type is unsupported" }}
    {{- end }}
  {{- end }}
{{- end -}}

{{- define "hpa.behavior.scale" -}}
{{ if .selectPolicy }}
selectPolicy: {{ .selectPolicy }}
{{- end }}
{{ if .stabilizationWindowSeconds }}
stabilizationWindowSeconds: {{ .stabilizationWindowSeconds }}
{{- end }}
{{ if .policies }}
policies: {{ .policies | toYaml | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "hpa.metrics.name" -}}
{{- $ctx := . -}}
name: {{ $ctx.name | required ".hpa.metric.name must be defined" }}
{{- if $ctx.labels }}
selector:
  matchLabels: {{ $ctx.labels | toYaml | nindent 4 }}
{{- end }}
{{- end -}}