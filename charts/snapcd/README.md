# snapcd

![AppVersion: 1.16.1](https://img.shields.io/badge/AppVersion-1.16.1-informational?style=flat-square)

Snap CD in one release - the Server, a Runner and optionally the Agent, in one namespace.

## Installing

```bash
helm install snapcd oci://ghcr.io/schrieksoft/charts/snapcd --namespace snapcd --create-namespace
kubectl -n snapcd port-forward svc/snapcd-server 5000:5000
```

The dashboard is then at http://localhost:5000, with the pre-seeded admin of the reference deployment, and the Runner is already connected. Every default is the reference deployment's public sample settings, the same as the Docker deployment; replace the keys, passwords and credentials before the Server holds anything that matters.

To add the Agent:

```bash
helm upgrade snapcd oci://ghcr.io/schrieksoft/charts/snapcd --namespace snapcd --reuse-values \
  --set agent.enabled=true \
  --set agent.sidecar.credentials.apiKey='<your Anthropic API key>'
```

Each component's values go under its key: `server`, `runner` and `agent`, as documented in the snapcd-server, snapcd-runner and snapcd-agent charts.

**Homepage:** <https://snapcd.io>

## Source Code

* <https://github.com/schrieksoft/snapcd>
* <https://github.com/schrieksoft/snapcd-deployment-kubernetes>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../snapcd-agent | agent(snapcd-agent) | 0.0.0 |
| file://../snapcd-runner | runner(snapcd-runner) | 0.0.0 |
| file://../snapcd-server | server(snapcd-server) | 0.0.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| agent.config.appsettings.Server.Url | string | `"http://snapcd-server:5000"` | The Server in the same namespace. |
| agent.enabled | bool | `false` | Install the Agent. Off by default, since its Claude sidecar needs a credential: set `agent.sidecar.credentials.oauthToken` or `apiKey` when turning it on. See the snapcd-agent chart for its values, set here under `agent`. |
| agent.fullnameOverride | string | `"snapcd-agent"` | The Agent's resource name. |
| runner.config.appsettings.Server.Url | string | `"http://snapcd-server:5000"` | The Server in the same namespace. |
| runner.enabled | bool | `true` | Install a Runner. See the snapcd-runner chart for its values, set here under `runner`. |
| runner.fullnameOverride | string | `"snapcd-runner"` | The Runner's resource name. |
| server.enabled | bool | `true` | Install the Server. See the snapcd-server chart for its values, set here under `server`. |
| server.fullnameOverride | string | `"snapcd-server"` | The Server's resource name, which the Runner and the Agent below connect to. |
