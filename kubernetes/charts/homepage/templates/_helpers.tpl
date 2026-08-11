{{- define "homepage.labels" -}}
app.kubernetes.io/part-of: homepage
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
