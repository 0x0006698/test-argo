{{/* Return name of ingress resource */}}
{{- define "components.ingressName" -}}
{{- $chart := index . 0 -}}
{{- $component := index . 1 -}}
{{ (empty $component) | ternary ($chart) (printf "%s-%s" $chart $component) }}
{{- end -}}

{{/* Group tls secrets by hostnames */}}
{{- define "components.ingress.groupTLSSecrets" -}}
{{- $spec := . -}}
{{- $tlsSecrets := dict -}}
{{- range $spec.tls -}}
  {{ $tls := . }}
  {{- $secretHosts := list $tls.hostname -}}
  {{- if hasKey $tlsSecrets $tls.secret -}}
    {{- $secretHosts = append (index $tlsSecrets $tls.secret) $tls.hostname -}}
  {{- end -}}
  {{- $_ := set $tlsSecrets $tls.secret $secretHosts -}}
{{- end -}}
{{- $tlsSecrets | toJson -}}
{{- end -}}

{{/* Return matching service by component */}}
{{- define "components.ingress.findService" -}}
{{- $context := index . 0 -}}
{{- $component := index . 1 -}}
{{- $service := dict -}}
{{- range $context.Values.services -}}
  {{- $spec := . -}}
  {{- if eq $spec.component $component -}}
    {{- $_ := set $service "name" (include "components.serviceName" (tuple $context $spec)) -}}
    {{- $_ := set $service "port" $spec.port.name -}}
  {{- end -}}
{{- end }}
{{- $service | toJson -}}
{{- end -}}

{{/* Convert legacy hardcoded annotations to array */}}
{{- define "annotations.ingress.combine.legacy" -}}
{{- $context := . -}}
{{- $result := list -}}
{{- $result = append $result (dict "name" "kubernetes.io/ingress.allow-http" "value" "false") -}}
{{- $result = append $result (dict "name" "nginx.ingress.kubernetes.io/ssl-redirect" "value" "true") -}}
{{- $result = append $result (dict "name" "nginx.ingress.kubernetes.io/force-ssl-redirect" "value" "true") -}}
{{- if $context.externalDnsSkip -}}
  {{- $result = append $result (dict "name" "external-dns.kubernetes.io/ignore" "value" "true") -}}
{{- end -}}
{{ $result | compact | toJson }}
{{- end -}}

{{/* Merge defaults and additional annotation arrays to single one */}}
{{- define "annotations.ingress.combine" -}}
{{- $context := . -}}
{{- $result := list -}}
{{- if hasKey $context "defaults" -}}
  {{- range $context.defaults -}}
    {{- $result = append $result . -}}
  {{- end -}}
{{- else -}}
{{- $result = (include "annotations.ingress.combine.legacy" $context) | fromJsonArray -}}
{{- end -}}
{{- range $context.additional -}}
  {{- $result = append $result . -}}
{{- end -}}
{{ $result | compact | toJson }}
{{- end -}}

{{/* Merge several snippet annotations (configuration-snippet or server-snippet) to single annotation */}}
{{- define "annotations.ingress.mergeSnippets" -}}
{{- $source := . -}}
{{- $result := list -}}
{{- $configurationSnippet := dict -}}
{{- $serverSnippet := dict -}}
{{- range $source -}}
  {{- $annotation := . -}}
  {{- $name := $annotation.name | required "ingress.annotations.additional.item.name must be defined" }}
  {{- $value := $annotation.value | required "ingress.annotations.additional.item.value must be defined" }}
    {{- if eq $name "nginx.ingress.kubernetes.io/configuration-snippet" -}}
      {{ $configurationSnippet = ($configurationSnippet | empty) | ternary $annotation (dict "name" $name "value" (printf "%s\n%s" $configurationSnippet.value $value)) }}
    {{- else if eq $name "nginx.ingress.kubernetes.io/server-snippet" -}}
      {{ $serverSnippet = ($serverSnippet | empty) | ternary $annotation (dict "name" $name "value" (printf "%s\n%s" $serverSnippet.value $value)) }}
    {{- else -}}
      {{- $result = append $result $annotation -}}
    {{- end -}}
  {{- end -}}
{{- $result = append $result $configurationSnippet -}}
{{- $result = append $result $serverSnippet -}}
{{ $result | compact | toJson }}
{{- end -}}
