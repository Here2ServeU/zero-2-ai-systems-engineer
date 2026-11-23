{{/* Name of every object: the release name (e.g. "fraud-api"). */}}
{{- define "app.fullname" -}}
{{- default .Release.Name .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "app.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{ include "app.selectorLabels" . }}
app.kubernetes.io/version: {{ include "app.tag" . | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: zero2ai
{{- end -}}

{{- define "app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "app.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "app.tag" -}}
{{- default .Chart.AppVersion .Values.image.tag -}}
{{- end -}}

{{- define "app.image" -}}
{{- $repo := required "image.repository is required (the deploy script sets it from Terraform's ECR output)" .Values.image.repository -}}
{{- printf "%s:%s" $repo (include "app.tag" .) -}}
{{- end -}}

{{- define "app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "app.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "app.secretName" -}}
{{- default (printf "%s-secrets" (include "app.fullname" .)) .Values.externalSecret.targetSecretName -}}
{{- end -}}

{{/* env + envFrom shared by the app, init and cronjob containers */}}
{{- define "app.envBlock" -}}
{{- if .Values.env }}
env:
  {{- range $k, $v := .Values.env }}
  - name: {{ $k }}
    value: {{ $v | quote }}
  {{- end }}
{{- end }}
{{- if or .Values.envFromSecrets .Values.externalSecret.enabled }}
envFrom:
  {{- range .Values.envFromSecrets }}
  - secretRef:
      name: {{ . }}
  {{- end }}
  {{- if .Values.externalSecret.enabled }}
  - secretRef:
      name: {{ include "app.secretName" . }}
  {{- end }}
{{- end }}
{{- end -}}

{{/* Writable scratch folders: /tmp plus any listed in scratchMounts */}}
{{- define "app.scratchVolumeMounts" -}}
- name: tmp
  mountPath: /tmp
{{- range $i, $p := .Values.scratchMounts }}
- name: scratch-{{ $i }}
  mountPath: {{ $p }}
{{- end }}
{{- end -}}

{{- define "app.scratchVolumes" -}}
- name: tmp
  emptyDir: {}
{{- range $i, $p := .Values.scratchMounts }}
- name: scratch-{{ $i }}
  emptyDir: {}
{{- end }}
{{- end -}}
