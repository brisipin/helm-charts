{{- define "affine.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "affine.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "affine.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
app.kubernetes.io/name: {{ include "affine.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Selector labels take the component as .component in a dict with .ctx */}}
{{- define "affine.selectorLabels" -}}
app.kubernetes.io/name: {{ include "affine.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{- define "affine.secretName" -}}
{{- default (include "affine.fullname" .) .Values.secret.existingSecret }}
{{- end }}

{{- define "affine.redisHost" -}}
{{- if .Values.redis.enabled }}
{{- printf "%s-redis" (include "affine.fullname" .) }}
{{- else }}
{{- required "externalRedis.host is required when redis.enabled=false" .Values.externalRedis.host }}
{{- end }}
{{- end }}

{{- define "affine.redisPort" -}}
{{- if .Values.redis.enabled }}6379{{ else }}{{ .Values.externalRedis.port }}{{ end }}
{{- end }}

{{/* Env shared by the migration init container and the server. */}}
{{- define "affine.env" -}}
- name: DEPLOYMENT_TYPE
  value: selfhosted
- name: REDIS_SERVER_HOST
  value: {{ include "affine.redisHost" . | quote }}
- name: REDIS_SERVER_PORT
  value: {{ include "affine.redisPort" . | quote }}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ include "affine.secretName" . }}
      key: DATABASE_URL
- name: AFFINE_PRIVATE_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "affine.secretName" . }}
      key: AFFINE_PRIVATE_KEY
{{- if .Values.mailer.enabled }}
- name: MAILER_HOST
  value: {{ required "mailer.host is required when mailer.enabled=true" .Values.mailer.host | quote }}
- name: MAILER_PORT
  value: {{ .Values.mailer.port | quote }}
- name: MAILER_USER
  value: {{ .Values.mailer.username | quote }}
- name: MAILER_SENDER
  value: {{ .Values.mailer.sender | quote }}
- name: MAILER_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "affine.secretName" . }}
      key: MAILER_PASSWORD
{{- end }}
{{- with .Values.extraEnv }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "affine.volumeMounts" -}}
- name: config
  mountPath: /root/.affine/config
- name: config-file
  mountPath: /root/.affine/config/config.json
  subPath: config.json
  readOnly: true
- name: storage
  mountPath: /root/.affine/storage
{{- end }}
