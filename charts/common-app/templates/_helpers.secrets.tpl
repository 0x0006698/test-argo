{{/* Render environment secrets */}}
{{- define "components.secrets.environment" -}}
{{- $context := index . 0 -}}
{{- $component := index . 1 -}}
{{- $chart := include "chart.name" $context -}}
{{- if $context.Values.global.features.akvs -}}
  {{- range $context.Values.secrets.items }}
    {{- if (has $component .components) | and (not .mountPath) }}
    {{- $secretName := printf "%s-%s" $chart .k8s_secret }}
    {{- $secretKey := .variable }}
- name: {{ $secretKey }}
  valueFrom:
    secretKeyRef:
      key: {{ $secretKey }}
      name: {{ $secretName }}
    {{- end }}
  {{- end -}}
{{- end }}
{{- if $context.Values.global.features.externalSecrets -}}
  {{- range $context.Values.externalSecrets }}
    {{- if .component | eq $component }}
    {{- $secretName := printf "%s-%s" $chart $component }}
      {{- range .items }}
        {{- if not .mountPath }}
        {{- $secretKey := .variable }}
- name: {{ $secretKey }}
  valueFrom:
    secretKeyRef:
      key: {{ $secretKey }}
      name: {{ $secretName }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end -}}
{{- end -}}

{{/* Render volumes for secrets */}}
{{- define "components.secrets.volumes" -}}
{{- $context := index . 0 -}}
{{- $component := index . 1 -}}
{{- $chart := include "chart.name" $context -}}
{{- if $context.Values.global.features.akvs -}}
  {{- range $context.Values.secrets.items }}
    {{- if (has $component .components) | and (.mountPath) }}
    {{- $volumeName := .k8s_secret }}
    {{- $secretName := printf "%s-%s" $chart $volumeName }}
- name: {{ $volumeName }}
  secret:
    secretName: {{ $secretName }}
    {{- end }}
  {{- end }}
{{- end -}}
{{- if $context.Values.global.features.externalSecrets -}}
  {{- range $context.Values.externalSecrets }}
    {{- if and (.component | eq $component) (.mount) }}
    {{- $secretName := printf "%s-%s" $chart $component }}
    {{- $volumeName := printf "%s-secrets" $component }}
- name: {{ $volumeName }}
  secret:
    secretName: {{ $secretName }}
    {{- end }}
  {{- end }}
{{- end -}}
{{- end -}}

{{/* Render volumeMounts for secrets */}}
{{- define "components.secrets.volumeMounts" -}}
{{- $context := index . 0 -}}
{{- $component := index . 1 -}}
{{- if $context.Values.global.features.akvs -}}
  {{- range $context.Values.secrets.items }}
    {{- if (has $component .components) | and (.mountPath) }}
- name: {{ .k8s_secret }}
  mountPath: {{ .mountPath }}
  subPath: {{ .variable }}
  readOnly: true
    {{- end }}
  {{- end }}
{{- end -}}
{{- if $context.Values.global.features.externalSecrets -}}
  {{- range $context.Values.externalSecrets }}
    {{- if .component | eq $component }}
    {{- $volumeName := printf "%s-secrets" $component }}
      {{- range .items }}
        {{- if .mountPath }}
- name: {{ $volumeName }}
  mountPath: {{ .mountPath }}
  subPath: {{ .variable }}
  readOnly: true
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end -}}
{{- end -}}