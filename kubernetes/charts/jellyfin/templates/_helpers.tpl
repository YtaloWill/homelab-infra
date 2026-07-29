{{- define "jellyfin.labels" -}}
app.kubernetes.io/part-of: jellyfin
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
