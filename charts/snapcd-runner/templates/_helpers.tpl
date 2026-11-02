{{- define "snapcd-runner.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "snapcd-runner.fullname" -}}
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

{{- define "snapcd-runner.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Selector labels. Call with (dict "ctx" $ "component" "server"). Selectors are immutable, so nothing version-bound goes here. */}}
{{- define "snapcd-runner.selectorLabels" -}}
app.kubernetes.io/name: {{ include "snapcd-runner.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/* Labels for every resource. Call with (dict "ctx" $ "component" "server"). */}}
{{- define "snapcd-runner.labels" -}}
helm.sh/chart: {{ include "snapcd-runner.chart" .ctx }}
{{ include "snapcd-runner.selectorLabels" . }}
app.kubernetes.io/version: {{ .ctx.Chart.AppVersion | quote }}
app.kubernetes.io/part-of: snapcd
app.kubernetes.io/managed-by: {{ .ctx.Release.Service }}
{{- with .ctx.Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/* Image reference. Call with (dict "image" .Values.image "defaultTag" .Chart.AppVersion). */}}
{{- define "snapcd-runner.image" -}}
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

{{- define "snapcd-runner.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "snapcd-runner.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "snapcd-runner.configMapName" -}}
{{- default (printf "%s-config" (include "snapcd-runner.fullname" .)) .Values.config.existingConfigMap }}
{{- end }}

{{- define "snapcd-runner.credentialsSecretName" -}}
{{- default (printf "%s-credentials" (include "snapcd-runner.fullname" .)) .Values.credentials.existingSecret }}
{{- end }}

{{- define "snapcd-runner.hooksConfigMapName" -}}
{{- default (printf "%s-hooks" (include "snapcd-runner.fullname" .)) .Values.preapprovedHooks.existingConfigMap }}
{{- end }}

{{- define "snapcd-runner.sshKeySecretName" -}}
{{- default (printf "%s-ssh-key" (include "snapcd-runner.fullname" .)) .Values.ssh.existingSecret }}
{{- end }}

{{- define "snapcd-runner.knownHostsConfigMapName" -}}
{{- default (printf "%s-ssh" (include "snapcd-runner.fullname" .)) .Values.ssh.existingKnownHostsConfigMap }}
{{- end }}

{{- define "snapcd-runner.hasSshKey" -}}
{{- if or .Values.ssh.privateKey .Values.ssh.existingSecret }}true{{ end }}
{{- end }}

{{- define "snapcd-runner.hasKnownHosts" -}}
{{- if or .Values.ssh.knownHosts .Values.ssh.existingKnownHostsConfigMap }}true{{ end }}
{{- end }}

{{- define "snapcd-runner.hasHooks" -}}
{{- if or .Values.preapprovedHooks.hooks .Values.preapprovedHooks.existingConfigMap }}true{{ end }}
{{- end }}

{{/* ServiceAccount annotations: the user's plus those the workload identity block implies. */}}
{{- define "snapcd-runner.serviceAccountAnnotations" -}}
{{- $a := deepCopy .Values.serviceAccount.annotations }}
{{- with .Values.workloadIdentity.azure.clientId }}{{ $_ := set $a "azure.workload.identity/client-id" . }}{{ end }}
{{- with .Values.workloadIdentity.azure.tenantId }}{{ $_ := set $a "azure.workload.identity/tenant-id" . }}{{ end }}
{{- with .Values.workloadIdentity.aws.roleArn }}{{ $_ := set $a "eks.amazonaws.com/role-arn" . }}{{ end }}
{{- with .Values.workloadIdentity.gcp.serviceAccount }}{{ $_ := set $a "iam.gke.io/gcp-service-account" . }}{{ end }}
{{- if $a }}{{ toYaml $a }}{{ end }}
{{- end }}

{{- define "snapcd-runner.externalSettingsSecretName" -}}
{{- default (printf "%s-externalsettings" (include "snapcd-runner.fullname" .)) .Values.externalSettings.existingSecret }}
{{- end }}

{{- define "snapcd-runner.hasExternalSettings" -}}
{{- if or .Values.externalSettings.content .Values.externalSettings.existingSecret }}true{{ end }}
{{- end }}
