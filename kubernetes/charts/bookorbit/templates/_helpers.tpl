{{- define "bookorbit.labels" -}}
app.kubernetes.io/part-of: bookorbit
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
