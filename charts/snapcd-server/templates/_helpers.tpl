{{- define "snapcd-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "snapcd-server.fullname" -}}
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

{{- define "snapcd-server.sqlserver.fullname" -}}
{{- default (printf "%s-sqlserver" (include "snapcd-server.fullname" .)) .Values.sqlserver.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "snapcd-server.redis.fullname" -}}
{{- default (printf "%s-redis" (include "snapcd-server.fullname" .)) .Values.redis.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "snapcd-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Selector labels. Call with (dict "ctx" $ "component" "server"). Selectors are immutable, so nothing version-bound goes here. */}}
{{- define "snapcd-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "snapcd-server.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/* Labels for every resource. Call with (dict "ctx" $ "component" "server"). */}}
{{- define "snapcd-server.labels" -}}
helm.sh/chart: {{ include "snapcd-server.chart" .ctx }}
{{ include "snapcd-server.selectorLabels" . }}
app.kubernetes.io/version: {{ .ctx.Chart.AppVersion | quote }}
app.kubernetes.io/part-of: snapcd
app.kubernetes.io/managed-by: {{ .ctx.Release.Service }}
{{- with .ctx.Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/* Image reference. Call with (dict "image" .Values.image "defaultTag" .Chart.AppVersion). */}}
{{- define "snapcd-server.image" -}}
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

{{- define "snapcd-server.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "snapcd-server.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "snapcd-server.sqlserver.secretName" -}}
{{- default (printf "%s-credentials" (include "snapcd-server.sqlserver.fullname" .)) .Values.sqlserver.auth.existingSecret }}
{{- end }}

{{- define "snapcd-server.configSecretName" -}}
{{- default (printf "%s-config" (include "snapcd-server.fullname" .)) .Values.config.existingSecret }}
{{- end }}

{{/* The URL the Server is reached on through the chart's own ingress or HTTPRoute, or empty. */}}
{{- define "snapcd-server.exposedHost" -}}
{{- if and .Values.ingress.enabled .Values.ingress.host }}
{{- printf "%s://%s" (ternary "https" "http" (gt (len .Values.ingress.tls) 0)) .Values.ingress.host }}
{{- with .Values.ingress.publicPort }}:{{ . }}{{ end }}
{{- else if and .Values.httpRoute.enabled .Values.httpRoute.hostnames }}
{{- printf "%s://%s" .Values.httpRoute.scheme (first .Values.httpRoute.hostnames) }}
{{- with .Values.httpRoute.publicPort }}:{{ . }}{{ end }}
{{- end }}
{{- end }}

{{/* appsettings.json as rendered into the config Secret: the user's map with the chart-derived keys filled where absent. */}}
{{- define "snapcd-server.appsettings" -}}
{{- $cfg := deepCopy .Values.config.appsettings }}
{{- $ns := .Release.Namespace }}

{{- $server := default dict (get $cfg "Server") }}
{{- $exposed := include "snapcd-server.exposedHost" . }}
{{- if $exposed }}
{{- if and (get $server "Host") (ne (trimSuffix "/" (get $server "Host")) $exposed) }}
{{- fail (printf "config.appsettings.Server.Host is %q but the Server is exposed as %q. Server.Host is the token issuer and must match the URL clients use; set one to agree with the other, or leave Server.Host unset to derive it." (get $server "Host") $exposed) }}
{{- end }}
{{- $_ := set $server "Host" (default $exposed (get $server "Host")) }}
{{- end }}
{{- if not (get $server "Host") }}
{{- $_ := set $server "Host" (printf "http://localhost:%v" .Values.service.port) }}
{{- end }}
{{- $_ := set $cfg "Server" $server }}

{{- if not .Values.database.existingSecret }}
{{- $conn := .Values.database.connectionString }}
{{- if and (not $conn) .Values.sqlserver.enabled (not (get $cfg "ConnectionString")) }}
{{- if not .Values.sqlserver.auth.saPassword }}
{{- fail "The Server's database connection string cannot be derived: sqlserver.auth.saPassword is empty. Set database.connectionString, database.existingSecret, or config.appsettings.ConnectionString." }}
{{- end }}
{{- $conn = printf "Server=%s.%s.svc.cluster.local,1433;Database=%s;User Id=sa;Password=%s;TrustServerCertificate=True" (include "snapcd-server.sqlserver.fullname" .) $ns .Values.sqlserver.database .Values.sqlserver.auth.saPassword }}
{{- end }}
{{- if $conn }}
{{- $_ := set $cfg "ConnectionString" (default $conn (get $cfg "ConnectionString")) }}
{{- $bus := default dict (get $cfg "ServiceBus") }}
{{- $transport := default dict (get $bus "TransportOptions") }}
{{- $sql := default dict (get $transport "SqlServer") }}
{{- $_ := set $sql "ConnectionString" (default $conn (get $sql "ConnectionString")) }}
{{- $_ := set $transport "SqlServer" $sql }}
{{- $_ := set $bus "TransportOptions" $transport }}
{{- $_ := set $bus "BusType" (default "SqlServer" (get $bus "BusType")) }}
{{- $_ := set $cfg "ServiceBus" $bus }}
{{- end }}
{{- if not (get $cfg "ConnectionString") }}
{{- fail "The Server has no database connection string. Enable sqlserver with sqlserver.auth.saPassword, or set database.connectionString, database.existingSecret or config.appsettings.ConnectionString." }}
{{- end }}
{{- end }}

{{- if not .Values.cache.existingSecret }}
{{- $redis := .Values.cache.connectionString }}
{{- if and (not $redis) .Values.redis.enabled }}
{{- $redis = printf "%s.%s.svc.cluster.local:6379" (include "snapcd-server.redis.fullname" .) $ns }}
{{- end }}
{{- if $redis }}
{{- $caching := default dict (get $cfg "Caching") }}
{{- $_ := set $caching "Provider" (default "Redis" (get $caching "Provider")) }}
{{- $_ := set $caching "ConnectionString" (default $redis (get $caching "ConnectionString")) }}
{{- $_ := set $cfg "Caching" $caching }}
{{- end }}
{{- end }}

{{- toPrettyJson $cfg }}
{{- end }}

{{- define "snapcd-server.externalSettingsSecretName" -}}
{{- default (printf "%s-externalsettings" (include "snapcd-server.fullname" .)) .Values.externalSettings.existingSecret }}
{{- end }}

{{- define "snapcd-server.hasExternalSettings" -}}
{{- if or .Values.externalSettings.content .Values.externalSettings.existingSecret }}true{{ end }}
{{- end }}
