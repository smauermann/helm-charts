{{/*
Common labels
*/}}
{{- define "chart.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: backup
app.kubernetes.io/part-of: {{ .Values.appName }}
{{- end }}

{{- define "chart.repository" -}}
{{ required ".Values.appName is required" .Values.appName }}-volsync-{{ .Values.s3.provider }}
{{- end }}
