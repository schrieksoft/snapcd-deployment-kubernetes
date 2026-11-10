# snapcd-agent

![AppVersion: 1.16.1](https://img.shields.io/badge/AppVersion-1.16.1-informational?style=flat-square)

The Snap CD Agent, with its Claude sidecar for inference.

## Installing

```bash
helm install snapcd-agent oci://ghcr.io/schrieksoft/charts/snapcd-agent --namespace snapcd-agent --create-namespace \
  --set sidecar.credentials.apiKey='<your Anthropic API key>'
```

The Claude sidecar needs exactly one Anthropic credential: `sidecar.credentials.oauthToken` for a Claude subscription, `sidecar.credentials.apiKey` for an API key, or `sidecar.credentials.existingSecret`. The install fails with neither, since the sidecar would otherwise start healthy and only fail when a mission calls for inference. `sidecar.enabled=false` runs the Agent without it.

The defaults are the reference deployment's sample settings, the same as the Docker deployment: the Agent connects as the pre-seeded `defaultAgent` service principal to a Server installed as `snapcd-server` in the `snapcd-server` namespace. Every credential in them is public.

**Homepage:** <https://snapcd.io>

## Source Code

* <https://github.com/schrieksoft/snapcd>
* <https://github.com/schrieksoft/snapcd-deployment-kubernetes>

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Affinity, for the Agent and the sidecar. |
| commonLabels | object | `{}` | Labels added to every resource. |
| config.appsettings | object | the reference deployment's sample settings | The Agent's `appsettings.json` as a map, rendered into a ConfigMap. It holds no secrets: the client secret comes from `credentials`. The chart fills `Agent.Sidecars` with the Claude sidecar when that key is absent. The defaults are the reference deployment's sample settings, the same as `components/agent/config/appsettings.json` and the Docker deployment, and connect to a Server installed as `snapcd-server` in the `snapcd-server` namespace. See the Snap CD agent settings reference for every key. |
| config.existingConfigMap | string | `""` | Name of an existing ConfigMap holding `appsettings.json`. When set, `config.appsettings` is ignored and the chart derives nothing into it. |
| config.existingConfigMapKey | string | `"appsettings.json"` | Key of `appsettings.json` in `config.existingConfigMap`. |
| credentials.clientSecret | string | `"defaultAgent"` | The Agent's client secret, injected as `Agent__ClientSecret`. The default is the reference deployment's public sample secret for the pre-seeded `defaultAgent` service principal. |
| credentials.existingSecret | string | `""` | Name of an existing Secret holding the client secret. |
| credentials.existingSecretKey | string | `"Agent__ClientSecret"` | Key of the client secret in `credentials.existingSecret`. |
| externalSettings.content | object | `{}` | `externalsettings.json` as a map, mounted at `/app/externalsettings.json`. Each entry in `Providers` names a `Loader` (`AzureKeyVault`, `AmazonSecretsManager` or `Literal`), its `Configuration`, and in `Data` the settings it supplies. Settings from this file win over `appsettings.json` and environment variables. |
| externalSettings.existingSecret | string | `""` | Name of an existing Secret holding `externalsettings.json`. When set, `externalSettings.content` is ignored. |
| externalSettings.existingSecretKey | string | `"externalsettings.json"` | Key of `externalsettings.json` in `externalSettings.existingSecret`. |
| extraEnv | list | `[]` | Extra environment variables for the Agent container. |
| extraEnvFrom | list | `[]` | Extra `envFrom` sources for the Agent container. |
| extraManifests | list | `[]` | Extra manifests, rendered through `tpl`. |
| extraVolumeMounts | list | `[]` | Extra volume mounts for the Agent container. |
| extraVolumes | list | `[]` | Extra volumes for the Agent pod. |
| fullnameOverride | string | `""` | Overrides the full resource name. |
| image.digest | string | `""` | Image digest. Takes precedence over the tag when set. |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy. |
| image.registry | string | `"ghcr.io"` | Image registry. Set to a mirror (Artifactory, Harbor, ACR) to pull through it. |
| image.repository | string | `"schrieksoft/snapcd/snapcd-agent"` | Image repository. |
| image.tag | string | `""` | Image tag. Defaults to the chart's appVersion. |
| imagePullSecrets | list | `[]` | Pull secrets for the Agent and the sidecar. |
| nameOverride | string | `""` | Overrides the chart name in resource names. |
| nodeSelector | object | `{}` | Node selector, for the Agent and the sidecar. |
| podAnnotations | object | `{}` | Agent pod annotations. |
| podLabels | object | `{}` | Agent pod labels. |
| podSecurityContext | object | `{"fsGroup":1654,"runAsGroup":1654,"runAsNonRoot":true,"runAsUser":1654,"seccompProfile":{"type":"RuntimeDefault"}}` | Agent pod security context. The defaults meet the restricted pod security profile; the images run as UID and GID 1654, and `fsGroup` makes provisioned volumes writable by it. |
| priorityClassName | string | `""` | Priority class name, for the Agent and the sidecar. |
| resources | object | `{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"50m","memory":"128Mi"}}` | Agent container resources. The Agent only relays between the Server and its sidecar; inference runs in the sidecar. |
| securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true}` | Agent container security context. The defaults meet the restricted pod security profile. |
| serviceAccount.annotations | object | `{}` | ServiceAccount annotations. |
| serviceAccount.automount | bool | `true` | Mount the ServiceAccount token into the pods. |
| serviceAccount.create | bool | `true` | Create a ServiceAccount for the Agent and the sidecar. |
| serviceAccount.name | string | `""` | ServiceAccount name. Defaults to the full name when `create` is true, and to `default` otherwise. |
| sidecar.credentials.apiKey | string | `""` | Anthropic API key (`sk-ant-api03-...`), as `ANTHROPIC_API_KEY`. Set this or `oauthToken`, not both. |
| sidecar.credentials.existingSecret | string | `""` | Name of an existing Secret holding `CLAUDE_CODE_OAUTH_TOKEN` or `ANTHROPIC_API_KEY`, and optionally `GITHUB_TOKEN`. Every key is optional in it. |
| sidecar.credentials.githubToken | string | `""` | GitHub token for the AutoFix path (clone and open a pull request), as `GITHUB_TOKEN`. Optional. |
| sidecar.credentials.oauthToken | string | `""` | Claude subscription token (`sk-ant-oat01-...`), as `CLAUDE_CODE_OAUTH_TOKEN`. Set this or `apiKey`, not both. |
| sidecar.enabled | bool | `true` | Deploy the Claude sidecar, the Agent's inference provider. It needs exactly one of `credentials.oauthToken`, `credentials.apiKey`, or an existing Secret holding one. |
| sidecar.extraEnv | list | `[]` | Extra environment variables for the sidecar. |
| sidecar.image.digest | string | `""` | Sidecar image digest. |
| sidecar.image.pullPolicy | string | `"IfNotPresent"` | Sidecar image pull policy. |
| sidecar.image.registry | string | `"ghcr.io"` | Sidecar image registry. |
| sidecar.image.repository | string | `"schrieksoft/snapcd/snapcd-agent-sidecar-claude"` | Sidecar image repository. |
| sidecar.image.tag | string | `""` | Sidecar image tag. Defaults to the chart's appVersion. |
| sidecar.livenessProbe | object | `{"httpGet":{"path":"/health","port":"http"},"initialDelaySeconds":30,"periodSeconds":30}` | Sidecar liveness probe. |
| sidecar.podAnnotations | object | `{}` | Sidecar pod annotations. |
| sidecar.podLabels | object | `{}` | Sidecar pod labels. |
| sidecar.podSecurityContext | object | `{"fsGroup":1000,"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000,"seccompProfile":{"type":"RuntimeDefault"}}` | Sidecar pod security context. The sidecar image's `app` user is UID and GID 1000, unlike the .NET images' 1654. |
| sidecar.port | int | `7001` | Port the sidecar serves on. |
| sidecar.readinessProbe | object | `{"httpGet":{"path":"/health","port":"http"},"periodSeconds":10}` | Sidecar readiness probe. |
| sidecar.resources | object | `{"limits":{"cpu":"1000m","memory":"2Gi"},"requests":{"cpu":"100m","memory":"256Mi"}}` | Sidecar resources. The Claude CLI runs in this container during a mission. |
| sidecar.securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}` | Sidecar container security context. The root filesystem stays writable: the Claude CLI lives in the home directory and writes `~/.claude.json` beside it, so the home directory cannot be replaced with an empty volume. |
| sidecar.serverUrl | string | `""` | Server URL the sidecar calls for MCP. Defaults to the Agent's `Server.Url`. |
| tolerations | list | `[]` | Tolerations, for the Agent and the sidecar. |
