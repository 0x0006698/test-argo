{{/* Render deployment replicas */}}
{{- define "components.deployments.replicas" -}}
{{- $spec := . -}}
{{- if not $spec.hpa }}
replicas: {{ $spec.replicas | required "deployment.replicas must be defined" }}
{{- end }}
{{- end -}}

{{/* Render deployment replicas */}}
{{- define "components.deployments.strategy" -}}
{{- $spec := . -}}
{{- if $spec.strategy }}
{{- with $spec.strategy }}
strategy:
  type: {{ .type | required "deployment.strategy.type must be defined" }}
  {{- if eq .type "RollingUpdate" }}
  rollingUpdate: {{ .rollingUpdate | toYaml | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
{{- end -}}