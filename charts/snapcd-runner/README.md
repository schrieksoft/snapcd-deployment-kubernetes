# snapcd-runner

![AppVersion: 1.16.3](https://img.shields.io/badge/AppVersion-1.16.3-informational?style=flat-square)

A Snap CD Runner, which executes OpenTofu, Terraform and Pulumi jobs for a Snap CD Server.

## Installing

```bash
helm install snapcd-runner oci://ghcr.io/schrieksoft/charts/snapcd-runner --namespace snapcd-runner --create-namespace
```

The defaults are the reference deployment's sample settings, the same as the Docker deployment: the Runner connects as the pre-seeded `default` service principal to a Server installed as `snapcd-server` in the `snapcd-server` namespace. Every credential in them is public. For a Runner of your own, set `config.appsettings.Runner` (its id, organization and client id), `config.appsettings.Server.Url`, and `credentials`.

The Runner clones over SSH with `ssh.privateKey` (or `ssh.existingSecret`) and `ssh.knownHosts`. The key is staged into the pod at 0600 by an init container running as the Runner's own user, and `GIT_SSH_COMMAND` points `git` at it.

More than one replica needs `allow_multiple_instances` on the Runner record. Each pod connects under its own pod name.

Cloud credentials come from `workloadIdentity` (Azure, AWS or GCP), which annotates the ServiceAccount and labels the pod.

**Homepage:** <https://snapcd.io>

## Source Code

* <https://github.com/schrieksoft/snapcd>
* <https://github.com/schrieksoft/snapcd-deployment-kubernetes>

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Affinity. |
| commonLabels | object | `{}` | Labels added to every resource. |
| config.appsettings | object | the reference deployment's sample settings | The Runner's `appsettings.json` as a map, rendered into a ConfigMap. It holds no secrets: the client secret comes from `credentials`. The defaults are the reference deployment's sample settings, the same as `components/runner/config/appsettings.json` and the Docker deployment, and connect to a Server installed as `snapcd-server` in the `snapcd-server` namespace. See the Snap CD runner settings reference for every key. |
| config.existingConfigMap | string | `""` | Name of an existing ConfigMap holding `appsettings.json`. When set, `config.appsettings` is ignored. |
| config.existingConfigMapKey | string | `"appsettings.json"` | Key of `appsettings.json` in `config.existingConfigMap`. |
| credentials.clientSecret | string | `"default"` | The Runner's client secret, injected as `Runner__Credentials__ClientSecret`. The default is the reference deployment's public sample secret for the pre-seeded `default` service principal. |
| credentials.existingSecret | string | `""` | Name of an existing Secret holding the client secret. |
| credentials.existingSecretKey | string | `"Runner__Credentials__ClientSecret"` | Key of the client secret in `credentials.existingSecret`. |
| engines.download.enabled | bool | `false` | Download engine binaries when the pod starts, checked against the release's SHA256SUMS, and use them in place of the ones the Runner image ships. Off uses the image's. |
| engines.download.image.digest | string | `""` | Download image digest. |
| engines.download.image.pullPolicy | string | `"IfNotPresent"` | Download image pull policy. |
| engines.download.image.registry | string | `""` | Download image registry. Empty pulls from Docker Hub. |
| engines.download.image.repository | string | `"alpine"` | Download image repository. Needs `wget`, `unzip` and `sha256sum`. |
| engines.download.image.tag | string | `"3.20"` | Download image tag. |
| engines.download.resources | object | `{"limits":{"cpu":"500m","memory":"256Mi"},"requests":{"cpu":"50m","memory":"64Mi"}}` | Resources of the `download-engines` init container, which downloads and unzips the engine archives. |
| engines.download.terraformVersion | string | `""` | Terraform version to download. Empty keeps the image's. Snap CD supports Terraform up to 1.5.7. |
| engines.download.tofuVersion | string | `""` | OpenTofu version to download. Empty keeps the image's. |
| externalSettings.content | object | `{}` | `externalsettings.json` as a map, mounted at `/app/externalsettings.json`. Each entry in `Providers` names a `Loader` (`AzureKeyVault`, `AmazonSecretsManager` or `Literal`), its `Configuration`, and in `Data` the settings it supplies. Settings from this file win over `appsettings.json` and environment variables. |
| externalSettings.existingSecret | string | `""` | Name of an existing Secret holding `externalsettings.json`. When set, `externalSettings.content` is ignored. |
| externalSettings.existingSecretKey | string | `"externalsettings.json"` | Key of `externalsettings.json` in `externalSettings.existingSecret`. |
| extraContainers | list | `[]` | Extra containers (sidecars). |
| extraEnv | list | `[]` | Extra environment variables for the Runner container. |
| extraEnvFrom | list | `[]` | Extra `envFrom` sources for the Runner container. |
| extraManifests | list | `[]` | Extra manifests, rendered through `tpl`. |
| extraVolumeMounts | list | `[]` | Extra volume mounts for the Runner container. |
| extraVolumes | list | `[]` | Extra volumes. |
| fullnameOverride | string | `""` | Overrides the full resource name. |
| image.digest | string | `""` | Image digest. Takes precedence over the tag when set. |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy. |
| image.registry | string | `"ghcr.io"` | Image registry. Set to a mirror (Artifactory, Harbor, ACR) to pull through it. |
| image.repository | string | `"schrieksoft/snapcd/snapcd-runner-azure"` | Image repository. `snapcd-runner` is the plain image, `snapcd-runner-azure` adds the Azure CLI and kubelogin. |
| image.tag | string | `""` | Image tag. Defaults to the chart's appVersion. |
| imagePullSecrets | list | `[]` | Pull secrets. |
| initContainers | list | `[]` | Init containers, run after SSH staging. |
| nameOverride | string | `""` | Overrides the chart name in resource names. |
| nodeSelector | object | `{}` | Node selector. |
| persistence.accessModes | list | `["ReadWriteOnce"]` | Access modes. |
| persistence.enabled | bool | `true` | Keep the working directory on a PersistentVolumeClaim per pod. Off uses an emptyDir. |
| persistence.mountPath | string | `"/app/runnerdata"` | Where the working directory is mounted. Must agree with `WorkingDirectory.WorkingDirectory` in the settings. |
| persistence.size | string | `"10Gi"` | Volume size. |
| persistence.storageClass | string | `""` | Storage class. Empty uses the cluster default. |
| podAnnotations | object | `{}` | Pod annotations. |
| podLabels | object | `{}` | Pod labels. |
| podManagementPolicy | string | `"OrderedReady"` | StatefulSet pod management policy. |
| podSecurityContext | object | `{"fsGroup":1654,"fsGroupChangePolicy":"OnRootMismatch","runAsGroup":1654,"runAsNonRoot":true,"runAsUser":1654,"seccompProfile":{"type":"RuntimeDefault"}}` | Pod security context. The defaults meet the restricted pod security profile; the images run as UID and GID 1654, and `fsGroup` makes provisioned volumes writable by it. |
| preapprovedHooks.existingConfigMap | string | `""` | Name of an existing ConfigMap holding the pre-approved hook scripts. |
| preapprovedHooks.hooks | object | the reference deployment's `sample.sh` | Pre-approved hook scripts, file name to content, mounted at `HooksPreapproval.PreapprovedHooksDirectory`. |
| priorityClassName | string | `""` | Priority class name. |
| replicaCount | int | `1` | Runner pods. More than one needs `allow_multiple_instances` on the Runner record; each pod connects under its own pod name. |
| resources | object | `{"limits":{"cpu":"2000m","memory":"4Gi"},"requests":{"cpu":"250m","memory":"512Mi"}}` | Container resources. A job runs OpenTofu or Terraform and its provider plugins inside this container, so the limit is sized for jobs rather than for the idle Runner (about 40 Mi); a provider alone can use several hundred MB. Raise it for large plans or many concurrent jobs. |
| securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true}` | Container security context. The defaults meet the restricted pod security profile. |
| serviceAccount.annotations | object | `{}` | ServiceAccount annotations. |
| serviceAccount.automount | bool | `true` | Mount the ServiceAccount token into the pod. |
| serviceAccount.create | bool | `true` | Create a ServiceAccount for the Runner. |
| serviceAccount.name | string | `""` | ServiceAccount name. Defaults to the full name when `create` is true, and to `default` otherwise. |
| ssh.existingKnownHostsConfigMap | string | `""` | Name of an existing ConfigMap holding `known_hosts`. |
| ssh.existingKnownHostsConfigMapKey | string | `"known_hosts"` | Key of `known_hosts` in `ssh.existingKnownHostsConfigMap`. |
| ssh.existingSecret | string | `""` | Name of an existing Secret holding the private key. |
| ssh.existingSecretKey | string | `"id_rsa"` | Key of the private key in `ssh.existingSecret`. |
| ssh.keyVolume | object | `{}` | Volume to read the private key from instead of a Secret, such as a Secrets Store CSI driver volume, so the key never has to exist as a Kubernetes Secret. Any volume source that `volumes` accepts. Takes precedence over `ssh.privateKey` and `ssh.existingSecret`. |
| ssh.keyVolumeKey | string | `"id_rsa"` | File in `ssh.keyVolume` that holds the private key. |
| ssh.knownHosts | string | GitHub and GitLab host keys | `known_hosts` content. The default covers GitHub and GitLab. |
| ssh.privateKey | string | `""` | Private key for cloning private Git repositories. Staged into the pod at 0600 for `git` over SSH. |
| ssh.resources | object | `{"limits":{"cpu":"100m","memory":"64Mi"},"requests":{"cpu":"10m","memory":"16Mi"}}` | Resources of the `stage-ssh` init container, which only copies two files. |
| tolerations | list | `[]` | Tolerations. |
| topologySpreadConstraints | list | `[]` | Topology spread constraints. |
| updateStrategy | object | `{}` | StatefulSet update strategy. |
| workloadIdentity.aws.roleArn | string | `""` | IAM role for IRSA. Sets `eks.amazonaws.com/role-arn` on the ServiceAccount. |
| workloadIdentity.azure.clientId | string | `""` | Azure workload identity client id. Sets the ServiceAccount annotation and the pod label. |
| workloadIdentity.azure.tenantId | string | `""` | Azure tenant id, when it differs from the cluster's. |
| workloadIdentity.gcp.serviceAccount | string | `""` | Google service account for GKE workload identity. Sets `iam.gke.io/gcp-service-account` on the ServiceAccount. |
