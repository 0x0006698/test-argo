{{/* Render configmap name for component */}}
{{- define "components.configMapName" -}}
{{- $context := index . 0 -}}
{{- $component := index . 1 -}}
{{- $chart := include "chart.name" $context -}}
{{- printf "%s-%s" $chart $component  -}}
{{- end -}}

{{/* Render custom configmap volumes */}}
{{- define "components.configMaps.volumes" -}}
{{- $context := index . 0 -}}
{{- $component := index . 1 -}}
{{- $name := include "components.configMapName" (tuple $context $component) -}}
{{- range $context.Values.configMaps }}
  {{- $cm := . -}}
  {{- if eq $cm.component $component }}
- name: {{ $name | quote }}
  configMap:
    name: {{ $name | quote }}
  {{- end }}
{{- end }}
{{- end -}}

{{/* Render volumeMounts for configmap */}}
{{- define "components.configMaps.volumeMounts" -}}
{{- $context := index . 0 -}}
{{- $component := index . 1 -}}
{{- $name := include "components.configMapName" (tuple $context $component) -}}
{{- range $context.Values.configMaps }}
  {{- $cm := . -}}
  {{- if eq $cm.component $component }}
- name: {{ $name }}
  mountPath: {{ .mountPath }}
  {{- end }}
{{- end }}
{{- end -}}