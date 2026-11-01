{{- define "charger-dashboard.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "charger-dashboard.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "charger-dashboard.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "charger-dashboard.labels" -}}
app.kubernetes.io/name: {{ include "charger-dashboard.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "charger-dashboard.selectorLabels" -}}
app.kubernetes.io/name: {{ include "charger-dashboard.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Image reference: values.image.tag overrides, else the chart appVersion.

The digest is appended when known, so a tag rebuilt in place still pulls the
right layers. It comes from the `imageDigest` chart annotation, which Renovate
keeps in step with appVersion. `image.digest` in values.yaml overrides it.

Note an empty `image.digest` means "fall back to the annotation", not "no
digest" -- `default` cannot tell those apart. To deploy by tag alone, set
`image.digest: none`.
*/}}
{{- define "charger-dashboard.image" -}}
{{- $ref := printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- $digest := .Values.image.digest | default (.Chart.Annotations).imageDigest -}}
{{- if and $digest (ne $digest "none") }}{{- $ref = printf "%s@%s" $ref $digest -}}{{- end -}}
{{- $ref -}}
{{- end -}}
