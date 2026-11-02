{{- define "snapcd-agent.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "snapcd-agent.fullname" -}}
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

{{- define "snapcd-agent.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Selector labels. Call with (dict "ctx" $ "component" "server"). Selectors are immutable, so nothing version-bound goes here. */}}
{{- define "snapcd-agent.selectorLabels" -}}
app.kubernetes.io/name: {{ include "snapcd-agent.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/* Labels for every resource. Call with (dict "ctx" $ "component" "server"). */}}
{{- define "snapcd-agent.labels" -}}
helm.sh/chart: {{ include "snapcd-agent.chart" .ctx }}
{{ include "snapcd-agent.selectorLabels" . }}
app.kubernetes.io/version: {{ .ctx.Chart.AppVersion | quote }}
app.kubernetes.io/part-of: snapcd
app.kubernetes.io/managed-by: {{ .ctx.Release.Service }}
{{- with .ctx.Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/* Image reference. Call with (dict "image" .Values.image "defaultTag" .Chart.AppVersion). */}}
{{- define "snapcd-agent.image" -}}
{{- $repo := .image.repository }}
{{- if .image.registry }}
{{- $repo = printf "%s/%s" .image.registry .image.repository }}
{{- end }}
{{- if .image.digest }}
{{- printf "%s@%s" $repo .image.digest }}
{{- else }}
{{- printf "%s:%s" $repo (default .defaultTag .image.tag | toString) }}
{{- end }}
{{- end }}

{{- define "snapcd-agent.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "snapcd-agent.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "snapcd-agent.sidecar.fullname" -}}
{{- printf "%s-sidecar-claude" (include "snapcd-agent.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "snapcd-agent.configMapName" -}}
{{- default (printf "%s-config" (include "snapcd-agent.fullname" .)) .Values.config.existingConfigMap }}
{{- end }}

{{- define "snapcd-agent.credentialsSecretName" -}}
{{- default (printf "%s-credentials" (include "snapcd-agent.fullname" .)) .Values.credentials.existingSecret }}
{{- end }}

{{- define "snapcd-agent.sidecar.secretName" -}}
{{- default (printf "%s-credentials" (include "snapcd-agent.sidecar.fullname" .)) .Values.sidecar.credentials.existingSecret }}
{{- end }}

{{/* appsettings.json as rendered: the user's map, with the Claude sidecar filled into Agent.Sidecars when that is absent. */}}
{{- define "snapcd-agent.appsettings" -}}
{{- $cfg := deepCopy .Values.config.appsettings }}
{{- $agent := default dict (get $cfg "Agent") }}
{{- if and .Values.sidecar.enabled (not (hasKey $agent "Sidecars")) }}
{{- $url := printf "http://%s.%s.svc.cluster.local:%v" (include "snapcd-agent.sidecar.fullname" .) .Release.Namespace .Values.sidecar.port }}
{{- $_ := set $agent "Sidecars" (list (dict "Name" "claude" "BaseUrl" $url)) }}
{{- end }}
{{- $_ := set $cfg "Agent" $agent }}
{{- toPrettyJson $cfg }}
{{- end }}

{{/* The Server URL the sidecar reaches MCP on: sidecar.serverUrl, or the Agent's own Server.Url. */}}
{{- define "snapcd-agent.sidecar.serverUrl" -}}
{{- default (dig "Server" "Url" "" .Values.config.appsettings) .Values.sidecar.serverUrl }}
{{- end }}

{{- define "snapcd-agent.externalSettingsSecretName" -}}
{{- default (printf "%s-externalsettings" (include "snapcd-agent.fullname" .)) .Values.externalSettings.existingSecret }}
{{- end }}

{{- define "snapcd-agent.hasExternalSettings" -}}
{{- if or .Values.externalSettings.content .Values.externalSettings.existingSecret }}true{{ end }}
{{- end }}
