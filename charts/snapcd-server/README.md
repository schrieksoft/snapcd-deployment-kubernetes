# snapcd-server

![AppVersion: 1.15.10](https://img.shields.io/badge/AppVersion-1.15.10-informational?style=flat-square)

The Snap CD Server, with optional bundled SQL Server and Redis.

## Installing

```bash
helm install snapcd-server oci://ghcr.io/schrieksoft/charts/snapcd-server --namespace snapcd-server --create-namespace
kubectl -n snapcd-server port-forward svc/snapcd-server 5000:5000
```

The dashboard is then at http://localhost:5000. The defaults are the reference deployment's sample settings, the same as the Docker deployment: they work as installed, and every key, password and pre-seeded credential in them is public. Replace them before the Server holds anything that matters.

The bundled SQL Server and Redis are for trials. For anything else, turn them off and point the Server at managed services with `database.*` and `cache.*`.

`config.appsettings` is the Server's `appsettings.json` as a map. The chart fills in the database, transport and cache connection strings from the bundled services when those keys are absent, and `Server.Host` from the ingress or HTTPRoute host. `Server.Host` is the token issuer: when it is set and the Server is exposed on a different host, the render fails.

**Homepage:** <https://snapcd.io>

## Source Code

* <https://github.com/schrieksoft/snapcd>
* <https://github.com/schrieksoft/snapcd-deployment-kubernetes>

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Affinity. |
| aspnetcoreEnvironment | string | `"Production"` | Value of `ASPNETCORE_ENVIRONMENT`. |
| cache.connectionString | string | `""` | Connection string to an external Redis, merged into `appsettings.json` as `Caching.ConnectionString`. |
| cache.existingSecret | string | `""` | Name of an existing Secret holding the Redis connection string. Injected as an environment variable. |
| cache.existingSecretKey | string | `"connection-string"` | Key of the connection string in `cache.existingSecret`. |
| commonLabels | object | `{}` | Labels added to every resource. |
| config.appsettings | object | the reference deployment's sample settings | The Server's `appsettings.json` as a map, rendered into a Secret. The chart fills `ConnectionString`, the SQL Server transport connection string and `Caching` from the bundled SQL Server and Redis when those are enabled and the keys are absent, and `Server.Host` from the ingress or HTTPRoute host, or `http://localhost:<service.port>` for a port-forward. The defaults are the reference deployment's sample settings, the same as `components/server/config/appsettings.json` and the Docker deployment: they work as installed, and every key, password and pre-seeded credential in them is public, so replace them before the Server holds anything that matters. See the Snap CD server settings reference for every key. |
| config.existingSecret | string | `""` | Name of an existing Secret holding `appsettings.json`. When set, `config.appsettings` is ignored and the chart derives nothing into it. |
| config.existingSecretKey | string | `"appsettings.json"` | Key of `appsettings.json` in `config.existingSecret`. |
| database.connectionString | string | `""` | Connection string to an external SQL Server database, merged into `appsettings.json` as `ConnectionString` and the SQL Server transport connection string. |
| database.existingSecret | string | `""` | Name of an existing Secret holding the connection string. Injected as environment variables, so it works with `config.existingSecret` too. |
| database.existingSecretKey | string | `"connection-string"` | Key of the connection string in `database.existingSecret`. |
| externalSettings.content | object | `{}` | `externalsettings.json` as a map, mounted at `/app/externalsettings.json`. Each entry in `Providers` names a `Loader` (`AzureKeyVault`, `AmazonSecretsManager` or `Literal`), its `Configuration`, and in `Data` the settings it supplies. Settings from this file win over `appsettings.json` and environment variables. |
| externalSettings.existingSecret | string | `""` | Name of an existing Secret holding `externalsettings.json`. When set, `externalSettings.content` is ignored. |
| externalSettings.existingSecretKey | string | `"externalsettings.json"` | Key of `externalsettings.json` in `externalSettings.existingSecret`. |
| extraContainers | list | `[]` | Extra containers (sidecars) for the Server pod. |
| extraEnv | list | `[]` | Extra environment variables for the Server container. |
| extraEnvFrom | list | `[]` | Extra `envFrom` sources for the Server container. |
| extraManifests | list | `[]` | Extra manifests, rendered through `tpl`. |
| extraVolumeMounts | list | `[]` | Extra volume mounts for the Server container. |
| extraVolumes | list | `[]` | Extra volumes for the Server pod. |
| fullnameOverride | string | `""` | Overrides the full resource name of the Server. |
| httpRoute.annotations | object | `{}` | HTTPRoute annotations. |
| httpRoute.enabled | bool | `false` | Create a Gateway API HTTPRoute for the Server. |
| httpRoute.hostnames | list | `[]` | Hostnames. The first one sets `Server.Host` when that is absent, and must agree with it when present. |
| httpRoute.parentRefs | list | `[]` | Gateways the route attaches to. |
| httpRoute.publicPort | string | `""` | Port clients reach the Gateway on, when it is not the scheme's default. Appended to the derived `Server.Host`. |
| httpRoute.scheme | string | `"https"` | Scheme the Gateway serves the hostnames on, used to build `Server.Host`. |
| image.digest | string | `""` | Image digest. Takes precedence over the tag when set. |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy. |
| image.registry | string | `"ghcr.io"` | Image registry. Set to a mirror (Artifactory, Harbor, ACR) to pull through it. |
| image.repository | string | `"schrieksoft/snapcd/snapcd-server"` | Image repository. |
| image.tag | string | `""` | Image tag. Defaults to the chart's appVersion. |
| imagePullSecrets | list | `[]` | Pull secrets for every workload in the chart. |
| ingress.annotations | object | `{}` | Ingress annotations. |
| ingress.className | string | `""` | Ingress class name. |
| ingress.enabled | bool | `false` | Create an Ingress for the Server. |
| ingress.host | string | `""` | Host the Server is reached on. Sets `Server.Host` when that is absent, and must agree with it when present. |
| ingress.path | string | `"/"` | Path. |
| ingress.pathType | string | `"Prefix"` | Path type. |
| ingress.publicPort | string | `""` | Port clients reach the ingress on, when it is not the scheme's default. Appended to the derived `Server.Host`. |
| ingress.tls | list | `[]` | TLS entries. Any entry makes `Server.Host` an `https` URL. |
| initContainers | list | `[]` | Init containers for the Server pod. |
| livenessProbe | object | `{"httpGet":{"path":"/health","port":"http"},"initialDelaySeconds":60,"periodSeconds":30}` | Liveness probe. |
| nameOverride | string | `""` | Overrides the chart name in resource names. |
| nodeSelector | object | `{}` | Node selector. |
| podAnnotations | object | `{}` | Pod annotations. |
| podDisruptionBudget.enabled | bool | `false` | Create a PodDisruptionBudget. With a single replica, `minAvailable: 1` blocks every node drain. |
| podDisruptionBudget.maxUnavailable | int | `1` | Maximum unavailable pods. |
| podDisruptionBudget.minAvailable | string | `""` | Minimum available pods. |
| podLabels | object | `{}` | Pod labels, for example `azure.workload.identity/use: "true"`. |
| podSecurityContext | object | `{"fsGroup":1654,"runAsGroup":1654,"runAsNonRoot":true,"runAsUser":1654,"seccompProfile":{"type":"RuntimeDefault"}}` | Pod security context. The defaults meet the restricted pod security profile; the images run as UID and GID 1654, and `fsGroup` makes provisioned volumes writable by it. |
| priorityClassName | string | `""` | Priority class name. |
| readinessProbe | object | `{"failureThreshold":6,"httpGet":{"path":"/health","port":"http"},"initialDelaySeconds":30,"periodSeconds":10}` | Readiness probe. |
| redis.affinity | object | `{}` | Redis affinity. |
| redis.enabled | bool | `true` | Deploy a bundled Redis. For trials; use `cache.*` for a managed cache. |
| redis.fullnameOverride | string | `""` | Overrides the full resource name of Redis. |
| redis.image.digest | string | `""` | Redis image digest. |
| redis.image.pullPolicy | string | `"IfNotPresent"` | Redis image pull policy. |
| redis.image.registry | string | `""` | Redis image registry. Empty pulls from Docker Hub. |
| redis.image.repository | string | `"redis"` | Redis image repository. |
| redis.image.tag | string | `"7-alpine"` | Redis image tag. |
| redis.nodeSelector | object | `{}` | Redis node selector. |
| redis.podAnnotations | object | `{}` | Redis pod annotations. |
| redis.podLabels | object | `{}` | Redis pod labels. |
| redis.podSecurityContext | object | `{"fsGroup":1000,"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":999,"seccompProfile":{"type":"RuntimeDefault"}}` | Redis pod security context. The image's `redis` user is UID 999, GID 1000. |
| redis.resources | object | `{"limits":{"cpu":"500m","memory":"256Mi"},"requests":{"cpu":"50m","memory":"64Mi"}}` | Redis resources. |
| redis.securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true}` | Redis container security context. |
| redis.tolerations | list | `[]` | Redis tolerations. |
| resources | object | `{"limits":{"cpu":"2000m","memory":"2Gi"},"requests":{"cpu":"250m","memory":"512Mi"}}` | Container resources. |
| securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true}` | Container security context. The defaults meet the restricted pod security profile. |
| service.annotations | object | `{}` | Service annotations. |
| service.port | int | `5000` | Service port. |
| service.type | string | `"ClusterIP"` | Service type. |
| serviceAccount.annotations | object | `{}` | ServiceAccount annotations, for example `azure.workload.identity/client-id`. |
| serviceAccount.automount | bool | `true` | Mount the ServiceAccount token into the pod. |
| serviceAccount.create | bool | `true` | Create a ServiceAccount for the Server. |
| serviceAccount.name | string | `""` | ServiceAccount name. Defaults to the full name when `create` is true, and to `default` otherwise. |
| sqlserver.affinity | object | `{}` | SQL Server affinity. |
| sqlserver.auth.existingSecret | string | `""` | Name of an existing Secret holding the `sa` password. |
| sqlserver.auth.existingSecretKey | string | `"SA_PASSWORD"` | Key of the password in `sqlserver.auth.existingSecret`. |
| sqlserver.auth.saPassword | string | `"myPassw0rd"` | `sa` password. The default is the reference deployment's public sample password. |
| sqlserver.database | string | `"SnapCd"` | Database name used in the derived connection string. |
| sqlserver.edition | string | `"Developer"` | Value of `MSSQL_PID`. |
| sqlserver.enabled | bool | `true` | Deploy a bundled SQL Server. For trials; use `database.*` for a managed database. |
| sqlserver.fullnameOverride | string | `""` | Overrides the full resource name of the SQL Server. |
| sqlserver.image.digest | string | `""` | SQL Server image digest. |
| sqlserver.image.pullPolicy | string | `"IfNotPresent"` | SQL Server image pull policy. |
| sqlserver.image.registry | string | `"mcr.microsoft.com"` | SQL Server image registry. |
| sqlserver.image.repository | string | `"mssql/server"` | SQL Server image repository. |
| sqlserver.image.tag | string | `"2022-latest"` | SQL Server image tag. |
| sqlserver.nodeSelector | object | `{}` | SQL Server node selector. |
| sqlserver.persistence.accessModes | list | `["ReadWriteOnce"]` | Access modes. |
| sqlserver.persistence.size | string | `"20Gi"` | Volume size. |
| sqlserver.persistence.storageClass | string | `""` | Storage class. Empty uses the cluster default. |
| sqlserver.podAnnotations | object | `{}` | SQL Server pod annotations. |
| sqlserver.podLabels | object | `{}` | SQL Server pod labels. |
| sqlserver.podSecurityContext | object | `{"fsGroup":10001,"fsGroupChangePolicy":"OnRootMismatch","runAsGroup":10001,"runAsNonRoot":true,"runAsUser":10001,"seccompProfile":{"type":"RuntimeDefault"}}` | SQL Server pod security context. The image runs as `mssql`, UID and GID 10001. |
| sqlserver.resources | object | `{"limits":{"cpu":"2000m","memory":"4Gi"},"requests":{"cpu":"500m","memory":"2Gi"}}` | SQL Server resources. |
| sqlserver.securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"add":["NET_BIND_SERVICE"],"drop":["ALL"]},"readOnlyRootFilesystem":true}` | SQL Server container security context. `NET_BIND_SERVICE` is the one capability the restricted profile permits adding, and the `sqlservr` binary will not start without it, since it carries that file capability. |
| sqlserver.tolerations | list | `[]` | SQL Server tolerations. |
| startupProbe | object | `{"failureThreshold":60,"httpGet":{"path":"/health","port":"http"},"periodSeconds":10}` | Startup probe. Liveness and readiness wait for it to pass, so a slow start is not killed: after a restart against a running database, the Server's message bus can take minutes to start. |
| strategy | object | `{"type":"Recreate"}` | Deployment strategy. `Recreate`, because the Server runs as a single replica. |
| tolerations | list | `[]` | Tolerations. |
| topologySpreadConstraints | list | `[]` | Topology spread constraints. |
