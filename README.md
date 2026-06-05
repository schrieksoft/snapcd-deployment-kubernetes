# snapcd-deployment-kubernetes

Reference Kubernetes deployment for [Snap CD](https://snapcd.io), covering all three Snap CD components — **Server**, **Runner** and **Agent** — in one repository.

Each component is a self-contained Kustomize overlay under `components/` and deploys to its own namespace (`snapcd-server`, `snapcd-runner`, `snapcd-agent`). The root `kustomization.yaml` aggregates all three for an all-in-one deploy. Use whichever shape fits your needs:

| You want…                                                                  | What to apply                                                  |
|----------------------------------------------------------------------------|----------------------------------------------------------------|
| **A full Self-Hosted stack** (Server + Runner + Agent in one cluster)      | `kubectl apply -k .` (from the repo root)                      |
| **Just the Server** (you'll run Runners/Agents elsewhere)                  | `kubectl apply -k components/server`                           |
| **Just a Runner** (you use Snap CD Cloud at snapcd.io)                     | `kubectl apply -k components/runner`                           |
| **Just an Agent** (you use Snap CD Cloud or a remote Self-Hosted Server)   | `kubectl apply -k components/agent`                            |

> Each component overlay is fully self-contained. You can copy a single `components/<name>/` directory out into its own repo if you'd rather not keep the other components around.

## What lives where

```
snapcd-deployment-kubernetes/
├── kustomization.yaml              # Root — aggregates the three component overlays
├── components/
│   ├── server/                     # namespace: snapcd-server
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── sql-server.yaml         # StatefulSet + headless Service (`sqlserver`)
│   │   ├── redis.yaml              # Deployment + Service (`redis`)
│   │   ├── server.yaml             # Deployment + Service (`snapcd-server`)
│   │   └── config/
│   │       ├── appsettings.json    # Mounted as a Secret (signing keys live here)
│   │       └── sql-secret.env      # SA_PASSWORD env file
│   ├── runner/                     # namespace: snapcd-runner
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── runner.yaml             # StatefulSet (init-container downloads engines)
│   │   └── config/
│   │       ├── appsettings.json    # ConfigMap (no secrets — ClientId only)
│   │       ├── runner-secret.env   # Runner__Credentials__ClientSecret
│   │       ├── known_hosts         # SSH known_hosts for GitHub / GitLab
│   │       ├── id_rsa              # Placeholder — replace before applying
│   │       └── preapproved-hooks/
│   │           └── sample.sh
│   └── agent/                      # namespace: snapcd-agent
│       ├── kustomization.yaml
│       ├── namespace.yaml
│       ├── agent.yaml              # Deployment (orchestrator)
│       ├── sidecar-claude.yaml     # Deployment + Service (Claude sidecar)
│       └── config/
│           ├── appsettings.json    # ConfigMap (ClientId only)
│           ├── agent-secret.env    # Agent__ClientSecret
│           └── sidecar-claude-secret.env  # ANTHROPIC_API_KEY
├── renovate.json                   # Auto-PR new Snap CD image versions
└── .github/workflows/renovate.yaml
```

## Cross-component DNS

Each component deploys to its own namespace, so cross-component traffic crosses namespaces using FQDNs:

| Caller                          | Target                                                          |
|---------------------------------|-----------------------------------------------------------------|
| Runner → Server                 | `http://snapcd-server.snapcd-server.svc.cluster.local:8080`     |
| Agent (orchestrator) → Server   | `http://snapcd-server.snapcd-server.svc.cluster.local:8080`     |
| Agent (sidecar) → Server (MCP)  | `http://snapcd-server.snapcd-server.svc.cluster.local:8080`     |
| Agent (orchestrator) → sidecar  | `http://snapcd-agent-sidecar-claude.snapcd-agent.svc.cluster.local:8080` |
| Server → SQL Server             | `sqlserver.snapcd-server.svc.cluster.local:1433`                |
| Server → Redis                  | `redis.snapcd-server.svc.cluster.local:6379`                    |

These URLs are baked into the shipped `appsettings.json` files. If your cluster runs NetworkPolicies that default-deny, you'll need to explicitly permit traffic between the `snapcd-runner` / `snapcd-agent` namespaces and `snapcd-server`.

## Bringing up the full stack

```bash
kubectl apply -k .
kubectl get pods -A -l 'app in (snapcd-server,snapcd-runner,snapcd-agent,sqlserver,redis,snapcd-agent-sidecar-claude)'
kubectl logs -n snapcd-server deployment/snapcd-server -f
```

Once the Server reports healthy, port-forward the Dashboard to your workstation:

```bash
kubectl port-forward -n snapcd-server svc/snapcd-server 8080:8080
```

Visit <http://localhost:8080> and sign in with the pre-seeded credentials:

- **Email:** `admin@preseeded.io`
- **Password:** `Admin#123`

> Change this password before you put the deployment in front of anything that matters.

The Runner and Agent both register automatically using the `default` / `defaultAgent` Service Principals that the Server pre-seeds on first start. For the all-in-one apply they need no further configuration.

## Bringing up a single component

### Server (only)

```bash
kubectl apply -k components/server
```

Brings up SQL Server, Redis and the Snap CD Server in the `snapcd-server` namespace.

Edit `components/server/config/appsettings.json` to:
- Replace the dev RSA / AES keys with your own (`OpenIdConnect.TokenSigning.RsaPrivateKey` / `RsaPublicKey`, `OpenIdConnect.TokenEncryption.SymmetricKey`, `SecretStore.SqlServer.SymmetricKey`) — see the [Server settings docs](https://docs.snapcd.io/components/server/#settings).
- Configure an `EmailSender` so users can self-serve password resets and invitations.
- Configure `OpenIdConnect.ExternalLoginProviders` if you want SSO sign-in.

Edit `components/server/config/sql-secret.env` to set a strong SA password (and update `Password=…` in the JSON's `ConnectionString` to match).

The Server's `appsettings.json` is mounted as a Kubernetes **Secret** (not a ConfigMap), since it contains signing keys and the DB password.

#### Generate fresh signing keys

```bash
# RSA keypair for OpenIdConnect token signing
openssl genrsa -out token-signing.key 2048
openssl rsa -in token-signing.key -pubout -out token-signing.pub

# AES-256 keys for token encryption + secret store
openssl rand -base64 32
```

Paste the PEM contents into the JSON value as a single string with literal `\n` separators (the shipped file shows the exact shape).

### Runner (only) — pointed at Snap CD Cloud

```bash
kubectl apply -k components/runner
```

Edit `components/runner/config/appsettings.json`:
- Set `Server.Url` to `https://snapcd.io` (or your Self-Hosted Server's external URL).
- Set `Runner.Id`, `Runner.OrganizationId` and `Runner.Credentials.ClientId` to the values shown when you registered the Runner in the Dashboard.

Set the client secret in `components/runner/config/runner-secret.env`:

```
Runner__Credentials__ClientSecret=<the-real-secret>
```

> `runner-secret.env` is the only place credentials live as plain text. Treat it like an `.env` file — keep your real values out of git (or maintain a private fork).

#### SSH for private Git repos

If your Terraform / OpenTofu modules use private Git repositories over SSH, replace the placeholder at `components/runner/config/id_rsa` with your real private key. Either keep it untracked locally (`git update-index --skip-worktree components/runner/config/id_rsa`) or use a private fork.

The `known_hosts` is pre-populated with GitHub and GitLab fingerprints. Add more with:

```bash
ssh-keyscan your-git-server.com >> components/runner/config/known_hosts
```

If you don't need SSH at all, delete the `snapcd-runner-ssh-key` entry from `components/runner/kustomization.yaml`'s `secretGenerator`.

#### Pre-approved hooks

Drop approved hook scripts into `components/runner/config/preapproved-hooks/` and list them in the `snapcd-runner-hooks` configMapGenerator in `components/runner/kustomization.yaml`. Then enable in the Runner's `appsettings.json`:

```json
{
  "HooksPreapproval": {
    "Enabled": true,
    "PreapprovedHooksDirectory": "/app/preapproved-hooks"
  }
}
```

#### Multiple replicas

Bump `spec.replicas` in `components/runner/runner.yaml`. Each replica gets its own PVC and a unique instance name (`snapcd-runner-0`, `snapcd-runner-1`, …) — the runner's `Runner__Instance` env var is set from the pod name.

#### Engine versions

The init container in `runner.yaml` downloads `tofu` 1.8.8 and `terraform` 1.5.7. To pin different versions, edit the `env` block at the top of the file.

> Snap CD strives to support the latest available version of `tofu`. For `terraform` we design for binaries up to release [1.5.7](https://github.com/hashicorp/terraform/releases/tag/v1.5.7), the final release under the [Mozilla Public License 2.0](https://github.com/hashicorp/terraform/blob/v1.5.7/LICENSE).

### Agent (only) — pointed at Snap CD Cloud

```bash
kubectl apply -k components/agent
```

Edit `components/agent/config/appsettings.json`:
- Set `Server.Url` to `https://snapcd.io` (or your Self-Hosted Server's external URL).
- Set `Agent.AgentId`, `Agent.OrganizationId` and `Agent.ClientId` to the values shown when you registered the Agent.

Set the client secret in `components/agent/config/agent-secret.env`:

```
Agent__ClientSecret=<the-real-secret>
```

The Agent ships with a Claude sidecar by default. If you want the sidecar to call Anthropic directly using your own Anthropic API key, fill in `components/agent/config/sidecar-claude-secret.env`:

```
ANTHROPIC_API_KEY=sk-ant-…
```

If left blank, the sidecar uses BYOK credentials configured on the Agent resource (the sidecar fetches them from the Server at mission time). If you've configured a different inference provider for your organization, swap `components/agent/sidecar-claude.yaml` for the matching sidecar manifest.

## Customization patterns

### Different namespaces

Each `components/<name>/kustomization.yaml` sets its own `namespace:` and includes a matching `namespace.yaml`. To deploy a component into a different namespace, change both fields together.

### Image tags

Image tags are pinned in each component's deployment manifest. A Renovate workflow in `.github/workflows/renovate.yaml` listens for `repository_dispatch: snapcd-released` events from the upstream Snap CD release pipeline and automatically opens PRs to bump them in lock-step. Configure the `RENOVATE_TOKEN` repository secret to enable it.

### Overlays

If you want to layer environment-specific overrides without forking, point your own overlay at this repo:

```yaml
# overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - github.com/schrieksoft/snapcd-deployment-kubernetes//components/server?ref=main
patches:
  - path: server-resources-patch.yaml
    target:
      kind: Deployment
      name: snapcd-server
```

## Teardown

```bash
kubectl delete -k .
```

> PVCs are not deleted automatically. To wipe SQL Server and Runner state too:
> ```bash
> kubectl delete pvc -n snapcd-server --all
> kubectl delete pvc -n snapcd-runner --all
> ```

## Troubleshooting

```bash
# SQL Server not coming up?
kubectl describe pod -n snapcd-server sqlserver-0
kubectl logs -n snapcd-server sqlserver-0

# Server can't reach the DB?
kubectl logs -n snapcd-server deployment/snapcd-server | grep -i "connection\|sql"

# Runner can't reach the Server?
kubectl logs -n snapcd-runner snapcd-runner-0
kubectl exec -it -n snapcd-runner snapcd-runner-0 -- /bin/bash
#   …then: curl -v http://snapcd-server.snapcd-server.svc.cluster.local:8080/healthz

# Agent or sidecar misbehaving?
kubectl logs -n snapcd-agent deployment/snapcd-agent
kubectl logs -n snapcd-agent deployment/snapcd-agent-sidecar-claude

# Init container failed to download engines?
kubectl logs -n snapcd-runner snapcd-runner-0 -c download-engines

# Azure Authentication for the Runner
kubectl exec -it -n snapcd-runner snapcd-runner-0 -- /bin/bash
az login
```

## Licensing

Snap CD Self-Hosted is distributed under the [Snap CD Source-Available License](https://github.com/schrieksoft/snapcd/blob/main/applications/snapcd/LICENSE.md). This deployment repository is published separately under its own license — see the upstream Snap CD documentation for tier comparisons and how to obtain a license token.
