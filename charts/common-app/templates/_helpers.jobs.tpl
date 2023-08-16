{{/* Render job specific options */}}
{{- define "components.jobs.options" -}}
{{- $spec := . -}}
{{- if $spec.activeDeadlineSeconds }}
activeDeadlineSeconds: {{ $spec.activeDeadlineSeconds }}
{{- end }}
backoffLimit: {{ default 0 $spec.backoffLimit }}
ttlSecondsAfterFinished: {{ $spec.ttlSecondsAfterFinished }}
{{- end -}}

{{/* Render cron job specific options */}}
{{- define "components.cronJobs.options" -}}
{{- $spec := . -}}
suspend: {{ $spec.suspend }}
concurrencyPolicy: {{ $spec.concurrencyPolicy | quote }}
failedJobsHistoryLimit: {{ $spec.failedJobsHistoryLimit }}
successfulJobsHistoryLimit: {{ $spec.successfulJobsHistoryLimit }}
schedule: {{ $spec.schedule | quote }}
startingDeadlineSeconds: {{ $spec.startingDeadlineSeconds }}
{{- end -}}
