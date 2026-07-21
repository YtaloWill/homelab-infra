{{- define "arr-stack.labels" -}}
app.kubernetes.io/part-of: arr-stack
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
