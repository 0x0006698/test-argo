{{/* Return Chart name with possible overrides */}}
{{- define "chart.name" -}}
{{- $context := . -}}
{{- default $context.Chart.Name $context.Values.global.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Return Release name with possible overrides */}}
{{- define "release.name" -}}
{{- $context := . -}}
{{- default $context.Release.Name $context.Values.global.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Render application component labels */}}
{{/* Render application component labels */}}
{{- define "labels.app" -}}
{{- $chart := index . 0 -}}
{{- $release := index . 1 -}}
{{- $app := index . 2 -}}
helm.sh/chart: {{ $chart | quote }}
app.kubernetes.io/name: {{ $app | quote }}
app.kubernetes.io/instance: {{ $release | quote }}
{{- if gt (len .) 3 }}
{{- $component := index . 3 }}
  {{- if not (empty $component) }}
app.kubernetes.io/component: {{ $component | quote }}
  {{- end }}
{{- end }}
{{- end -}}

{{/* Render application selector labels */}}
{{- define "labels.selector" -}}
{{- $app := index . 0 -}}
{{- $release := index . 1 -}}
app.kubernetes.io/name: {{ $app | quote }}
app.kubernetes.io/instance: {{ $release | quote }}
{{- end -}}

{{/* Render before release hook annotations */}}
{{- define "annotations.before" -}}
{{- $result := dict -}}
{{- $_ := set $result "helm.sh/hook" "pre-install,pre-upgrade" -}}
{{- $_ := set $result "helm.sh/hook-delete-policy" "before-hook-creation" -}}
{{- $_ := set $result "helm.sh/hook-weight" (.weight | toString) -}}
{{- $result | toJson -}}
{{- end -}}

{{/* Render before release hook annotations */}}
{{- define "annotations.after" -}}
{{- $result := dict -}}
{{- $_ := set $result "helm.sh/hook" "post-install,post-upgrade" -}}
{{- $_ := set $result "helm.sh/hook-delete-policy" "before-hook-creation" -}}
{{- $_ := set $result "helm.sh/hook-weight" (.weight | toString) -}}
{{- $result | toJson -}}
{{- end -}}

{{/* Render default container annotation that used by kubectl commands */}}
{{- define "annotations.defaultContainer" -}}
kubectl.kubernetes.io/default-container: {{ . }}
{{- end -}}
