{{/* Render monitoring annotations */}}
{{- define "components.diagnostics.metrics" -}}
{{- $spec := . -}}
{{- if $spec.ports | and $spec.diagnostics.metrics }}
prometheus.io/port: {{ index .ports 0 "port" | quote }}
prometheus.io/probe: "true"
prometheus.io/scrape: "true"
{{- end }}
{{- end -}}

{{/* Render profiling annotations */}}
{{- define "components.diagnostics.tracing.annotations" -}}
{{- $spec := index . 0 -}}
{{- $name := index . 1 -}}
{{- with $spec.diagnostics.profiling }}
  {{- $profiling := . -}}
  {{- if $profiling.enabled }}
pyroscope.io/application-name: {{ $name }}
  {{- if $spec.ports }}
pyroscope.io/port: {{ index $spec.ports 0 "port" | quote }}
  {{- end }}
pyroscope.io/scrape: "true"
    {{- if $profiling.configuration.pyroscopeScrapeMemory }}
pyroscope.io/profile-mem-enabled: "true"
    {{- end }}
    {{- if $profiling.configuration.pyroscopeScrapeCpu }}
pyroscope.io/profile-cpu-enabled: "true"
    {{- end }}
  {{- end }}
{{- end -}}
{{- end -}}

{{/* Render tracing environment variables */}}
{{- define "components.diagnostics.tracing" -}}
{{- $spec := . -}}
{{- if $spec.diagnostics.tracing }}
- name: JAEGER_AGENT_HOST
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP
- name: OTEL_EXPORTER_JAEGER_AGENT_HOST
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP
- name: JAEGER_SAMPLING_ENDPOINT
  value: "http://jaeger-agent.infra-jaeger.svc.cluster.local:5778"
{{- end }}
{{- end -}}

{{/* Return profiling side car container startup command */}}
{{- define "components.diagnostics.profiling.command" -}}
{{- $conf := . -}}
# combine startup script here
# wait several secs when main container starts
{{- $script := "sleep 10s;" -}}
# define required pyroscope args (pid)
# hardcode pid to 1, because majority of apps started as single process
{{- $script := printf "%s %s" $script "pyroscope connect --pid 1" -}}
# define tags for pyroscope
{{- range $key, $val := $conf.tags }}
{{- $script = printf "%s %s %s=%s" $script "--tag" $key $val -}}
{{- end }}
# render command as yaml array
{{ toYaml (tuple "/bin/sh" "-c" $script) }}
{{- end -}}

{{/* Render profiling side car container environment variables */}}
{{- define "components.diagnostics.profiling.env" -}}
{{- $conf := index . 0 -}}
{{- $chart := index . 1 -}}
{{- $component := index . 2 -}}
{{- $prefix := "PYROSCOPE" -}}
- name: {{ printf "%s_%s" $prefix "SERVER_ADDRESS" }}
  value: "http://pyroscope.infra-pyroscope.svc.cluster.local:4040"
- name: {{ printf "%s_%s" $prefix "SPY_NAME" }}
  value: "dotnetspy"
- name: {{ printf "%s_%s" $prefix "LOG_LEVEL" }}
  value: "debug"
- name: {{ printf "%s_%s" $prefix "APPLICATION_NAME" }}
  value: {{ printf "dodo.%s.%s" $chart $component }}
- name: {{ printf "%s_%s" $prefix "SAMPLE_RATE" }}
  value: {{ $conf.sampleRate | quote }}
{{- end -}}

{{/* Render profiling side car container volume mounts */}}
{{- define "components.diagnostics.profiling.volumeMounts" -}}
{{- $spec := . -}}
{{- with $spec.diagnostics.profiling }}
  {{- $profiling := . -}}
  {{- if $profiling.enabled }}
- mountPath: /tmp
  name: dotnet-profiling
  {{- end }}
{{- end }}
{{- end -}}

{{/* Render profiling side car container volumes */}}
{{- define "components.diagnostics.profiling.volumes" -}}
{{- $spec := . -}}
{{- with $spec.diagnostics.profiling }}
  {{- $profiling := . -}}
  {{- if $profiling.enabled }}
- name: dotnet-profiling
  emptyDir: {}
  {{- end }}
{{- end }}
{{- end -}}

{{/* Render profiling side car container spec */}}
{{- define "components.diagnostics.profiling.container" -}}
{{- $chart := index . 0 -}}
{{- $spec := index . 1 -}}
{{- $component := $spec.component -}}
{{- with $spec.diagnostics.profiling }}
  {{- $profiling := . -}}
  {{- if $profiling.enabled }}
    {{ $conf := $profiling.configuration }}
- name: pyroscope
  image: pyroscope/pyroscope:0.34.0
  imagePullPolicy: IfNotPresent
  command: {{ include "components.diagnostics.profiling.command" $conf | nindent 2 }}
  env: {{ include "components.diagnostics.profiling.env" (tuple $conf $chart $component) | nindent 2 }}
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
  securityContext:
    runAsUser: 0
    capabilities:
      add:
      - SYS_PTRACE
  terminationMessagePolicy: FallbackToLogsOnError
  volumeMounts:
  {{ include "components.diagnostics.profiling.volumeMounts" $spec | nindent 2 }}
  {{- end }}
{{- end }}
{{- end -}}