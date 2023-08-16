{{/* Return total count of components */}}
{{- define "components.total" -}}
{{- $context := .Values -}}
{{- $deployments := default (list) $context.deployments -}}
{{- $jobs := default (list) $context.jobs -}}
{{- $crons := default (list) $context.cronJobs -}}
{{- add (len $deployments) (len $jobs) (len $crons) -}}
{{- end -}}

{{/* Return service name for specified component */}}
{{- define "components.serviceName" -}}
{{- $context := index . 0 -}}
{{- $spec := index . 1 -}}
{{- if not (empty $spec.slug) -}}
  {{- $spec.slug -}}
{{- else -}}
  {{- $total := len $context.Values.services -}}
  {{- $chart := include "chart.name" $context -}}
  {{- (eq $total 1) | ternary ($chart) (printf "%s-%s" $chart $spec.component) -}}
{{- end -}}
{{- end -}}

{{/* Return deployment name for specified component */}}
{{- define "components.deploymentName" -}}
{{- $context := index . 0 -}}
{{- $component := index . 1 -}}
{{- $chart := include "chart.name" $context -}}
{{- $total := len $context.Values.deployments -}}
{{- (eq $total 1) | ternary ($chart) (printf "%s-%s" $chart $component) -}}
{{- end -}}

{{/* Return job name for component*/}}
{{- define "components.jobName" -}}
{{- $chart := index . 0 -}}
{{- $component := index . 1 -}}
{{- printf "%s-%s" $chart $component  -}}
{{- end -}}

{{/* Render component pod container spec */}}
{{- define "components.app" -}}
{{- $context := index . 0 -}}
{{- $spec := index . 1 -}}
{{- $component := $spec.component -}}
name: {{ $component | quote }}
{{ include "components.entrypoint" (tuple $context $spec) }}
env:
{{ include "components.diagnostics.tracing" $spec }}
{{ include "components.secrets.environment" (tuple $context $component) }}
{{ include "components.env" (tuple $context $component) }}
{{- if $spec.ports }}
ports:
  {{- range $spec.ports }}
- name: {{ .name }}
  containerPort: {{ .port }}
  protocol: TCP
  {{- end }}
{{- end }}
{{- if $spec.probes }}
  {{- with $spec.probes.live }}
livenessProbe: {{ toYaml . | nindent 2 }}
  {{- end }}
  {{- with $spec.probes.ready }}
readinessProbe: {{ toYaml . | nindent 2 }}
  {{- end }}
  {{- with $spec.probes.startup }}
startupProbe: {{ toYaml . | nindent 2 }}
  {{- end }}
{{- end }}
{{ include "components.lifecycle" $spec }}
resources: {{ toYaml $spec.resources | nindent 2 }}
terminationMessagePolicy: FallbackToLogsOnError
{{- if $spec.securityContext }}
securityContext: {{ $spec.securityContext | toYaml | nindent 2 }}
{{- end }}
volumeMounts:
{{ include "components.secrets.volumeMounts" (tuple $context $component) | nindent 2 }}
{{ include "components.configMaps.volumeMounts" (tuple $context $component) | nindent 2 }}
{{ include "components.diagnostics.profiling.volumeMounts" $spec | nindent 2 }}
{{ include "components.storage.volumeMounts" $spec | nindent 2 }}
{{- end -}}

{{/* Render container image, command and args for component */}}
{{- define "components.entrypoint" -}}
{{- $context := index . 0 -}}
{{- $spec := index . 1 -}}
{{- $image := $context.Values.image -}}
{{- $registry := "dodoreg.azurecr.io" -}}
{{- $chart := include "chart.name" $context -}}
{{- $total := int (include "components.total" $context) -}}
{{- if $spec.workingDir }}
workingDir: {{ $spec.workingDir }}
{{- end }}
{{- if ($spec.command | or $spec.args) }}
image: {{ printf "%s/%s:%s" $registry $chart $image }}
  {{- if $spec.command }}
command: {{ $spec.command | toJson }}
  {{- end }}
  {{- if $spec.args }}
args: {{ $spec.args | toJson }}
  {{- end }}
{{- else if (eq $total 1) }}
image: {{ printf "%s/%s:%s" $registry $chart $image }}
{{- else }}
image: {{ printf "%s/%s/%s:%s" $registry $chart $spec.component $image }}
{{- end }}
{{- end -}}

{{/* Render environment values */}}
{{- define "components.env" -}}
{{- $context := index . 0 -}}
{{- $component := index . 1 -}}
{{- range $context.Values.environment }}
  {{- if (has $component .components) }}
- name: {{ .name }}
  value: {{ .value | quote }}
  {{- end }}
{{- end }}
{{- end -}}

{{/* Return application image pull secrets */}}
{{- define "components.imagePullSecrets" -}}
{{- $context := . -}}
{{- if $context.Values.imagePullSecrets }}
imagePullSecrets:
- name: azurecr-io-regcred
{{- end }}
{{- end -}}

{{/* Return container lifecycle */}}
{{- define "components.lifecycle" -}}
{{- $spec := . -}}
{{- with $spec.lifecycle }}
lifecycle:
{{- if .preStopHook.enabled }}
  preStop:
    exec:
      command:
      - "/bin/sh"
      - "-c"
      - "sleep 30"
{{- end }}
{{- end }}
{{- end -}}

{{/* Return affinity configuration */}}
{{- define "components.affinity" -}}
{{- $chart := . -}}
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - podAffinityTerm:
        topologyKey: "topology.kubernetes.io/zone"
        labelSelector:
          matchExpressions:
          - key: "app.kubernetes.io/name"
            operator: In
            values:
            - {{ $chart | quote }}
      weight: 100
    - podAffinityTerm:
        topologyKey: "kubernetes.io/hostname"
        labelSelector:
          matchExpressions:
          - key: "app.kubernetes.io/name"
            operator: In
            values:
            - {{ $chart | quote }}
      weight: 100
{{- end -}}

{{/* Return nodeSelector configuration */}}
{{- define "components.nodeSelector" -}}
{{- $spec := . -}}
{{- if $spec.nodeSchedule }}
nodeSelector:
  {{- if $spec.nodeSchedule.isSpot }}
  kubernetes.azure.com/scalesetpriority: "spot"
  {{- end }}
  {{- if $spec.nodeSchedule.nodePool }}
  node.kubernetes.io/workload: "{{ $spec.nodeSchedule.nodePool }}"
  {{- end }}
{{- end -}}
{{- end -}}

{{/* Return tolerations configuration */}}
{{- define "components.tolerations" -}}
{{- $spec := . -}}
{{- if $spec.nodeSchedule }}
tolerations:
  {{- if $spec.nodeSchedule.isSpot }}
  - effect: NoSchedule
    key: kubernetes.azure.com/scalesetpriority
    operator: Equal
    value: spot
  {{- end }}
  {{- if $spec.nodeSchedule.nodePool }}
  - effect: NoSchedule
    key: node.kubernetes.io/workload
    operator: Equal
    value: "{{ $spec.nodeSchedule.nodePool }}"
  {{- end }}
{{- end }}
{{- end -}}

{{/* Render priority class */}}
{{- define "components.priorityClassName" -}}
{{- $spec := . -}}
{{- if $spec.priorityClassName }}
priorityClassName: {{ $spec.priorityClassName }}
{{- end }}
{{- end -}}

{{/* Render restart policy */}}
{{- define "components.restartPolicy" -}}
restartPolicy: {{ . }}
{{- end -}}

{{/* Render termination grace period */}}
{{- define "components.terminationGracePeriod" -}}
{{- $spec := . -}}
{{- if $spec.terminationGracePeriodSeconds }}
terminationGracePeriodSeconds: {{ $spec.terminationGracePeriodSeconds }}
{{- end }}
{{- end -}}

{{/* Render service account specific options */}}
{{- define "components.serviceAccount" -}}
{{- $name := index . 0 -}}
{{- $spec := index . 1 -}}
{{- $serviceAccount := (($spec.rbac).serviceAccount).create -}}
{{- if $serviceAccount -}}
automountServiceAccountToken: true
serviceAccountName: {{ $name }}
{{- else -}}
automountServiceAccountToken: false
serviceAccountName: default
{{- end -}}
{{- end -}}

{{- define "components.dnsConfig" -}}
{{- $spec := . -}}
{{- if $spec.dns.hostAliases }}
hostAliases: {{ $spec.dns.hostAliases | toYaml | nindent 2 }}
{{- end }}
dnsPolicy: {{ $spec.dns.policy }}
{{- if $spec.dns.config }}
dnsConfig: {{ $spec.dns.config | toYaml | nindent 2 }}
{{- end }}
{{- end -}}

{{/* Render volumes associated with component */}}
{{- define "components.volumes" -}}
{{- $context := index . 0 -}}
{{- $spec := index . 1 -}}
volumes:
{{ include "components.secrets.volumes" (tuple $context $spec.component) | nindent 2 }}
{{ include "components.configMaps.volumes" (tuple $context $spec.component) | nindent 2 }}
{{ include "components.diagnostics.profiling.volumes" $spec | nindent 2 }}
{{ include "components.storage.volumes" $spec | nindent 2 }}
{{- end -}}

{{- define "components.storage.volumes" -}}
{{- $spec := . -}}
{{- range $spec.volumes }}
  {{- $volume := . -}}
  {{- if eq $volume.type "emptyDir" }}
- name: {{ $volume.name }}
  emptyDir:
    medium: {{ $volume.medium }}
    sizeLimit: {{ $volume.size }}
  {{- else }}
  {{ fail "Invalid volume type specified" }}
  {{- end }}
{{- end }}
{{- end -}}

{{- define "components.storage.volumeMounts" -}}
{{- $spec := . -}}
{{- range $spec.volumes }}
  {{- $volume := . }}
- name: {{ $volume.name }}
  mountPath: {{ $volume.mountPath }}
{{- end }}
{{- end -}}

{{- define "components.msi.labels" -}}
{{- $name := index . 0 -}}
{{- $spec := index . 1 -}}
{{- if $spec.msi -}}
aadpodidbinding: {{ $name }}
{{- end -}}
{{- end -}}

{{- define "components.msi.annotations" -}}
{{- $spec := . -}}
{{- if $spec.msi -}}
automation.dodois.io/identity-name: {{ $spec.msi.identity }}
{{- end -}}
{{- end -}}