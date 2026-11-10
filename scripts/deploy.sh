#!/usr/bin/env bash
# Deploys Snap CD to a kind cluster that already exists, and is what scripts/kind-up.sh calls
# once the cluster, the images and ingress-nginx are in place. Run it directly to redeploy
# without recreating the cluster.
#
# Usage:
#   scripts/deploy.sh               # the snapcd chart, in the snapcd namespace
#   scripts/deploy.sh --kustomize   # the Kustomize deployment, in its three namespaces
#   scripts/deploy.sh --local       # either of the above with the images tagged :local
#
# Environment:
#   KIND_CLUSTER     cluster name (default: snapcd)
#   KIND_HTTP_PORT   host port the ingress is on (default: 9080)
#   KIND_SQL_PORT    node port for SQL Server (default: 31433; empty to not expose it)
#   KIND_REDIS_PORT  node port for Redis (default: 31379; empty to not expose it)
#   SNAPCD_SSH_KEY   private key for the Runner, to clone private repositories over SSH
#
# The ports have to match the mappings kind was created with, so changing them means a new
# cluster. The Agent is installed when kind/agent.env holds a Claude credential (see
# kind/agent.env.example).
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

CLUSTER="${KIND_CLUSTER:-snapcd}"
HTTP_PORT="${KIND_HTTP_PORT:-9080}"
SQL_PORT="${KIND_SQL_PORT-31433}"
REDIS_PORT="${KIND_REDIS_PORT-31379}"
URL="http://snapcd.localhost:${HTTP_PORT}"

MODE="chart"
LOCAL=false
for arg in "$@"; do
    case "$arg" in
        --kustomize) MODE="kustomize" ;;
        --local) LOCAL=true ;;
        *) echo "unknown argument: $arg" >&2; exit 1 ;;
    esac
done

for tool in kubectl helm; do
    command -v "$tool" >/dev/null || { echo "$tool is required" >&2; exit 1; }
done

KUBECTL=(kubectl --context "kind-${CLUSTER}")
HELM=(helm --kube-context "kind-${CLUSTER}")

"${KUBECTL[@]}" cluster-info >/dev/null 2>&1 || {
    echo "No kind cluster named ${CLUSTER}. Bring it up with scripts/kind-up.sh." >&2
    exit 1
}

if [[ "$MODE" == "chart" ]]; then
    AGENT=(--set agent.enabled=false)
    if [[ -f kind/agent.env ]]; then
        OAUTH="$(grep -E '^CLAUDE_CODE_OAUTH_TOKEN=' kind/agent.env | cut -d= -f2- || true)"
        API_KEY="$(grep -E '^ANTHROPIC_API_KEY=' kind/agent.env | cut -d= -f2- || true)"
        if [[ -n "$OAUTH" || -n "$API_KEY" ]]; then
            AGENT=(--set agent.enabled=true
                   --set-string "agent.sidecar.credentials.oauthToken=${OAUTH}"
                   --set-string "agent.sidecar.credentials.apiKey=${API_KEY}")
        fi
    fi

    # The committed components/runner/config/id_rsa is a placeholder, so cloning a private
    # repository needs a real key. The chart builds its secret from runner.ssh.privateKey.
    SSH=()
    if [[ -n "${SNAPCD_SSH_KEY:-}" ]]; then
        [[ -f "$SNAPCD_SSH_KEY" ]] || { echo "SNAPCD_SSH_KEY is set but ${SNAPCD_SSH_KEY} does not exist" >&2; exit 1; }
        SSH=(--set-file "runner.ssh.privateKey=${SNAPCD_SSH_KEY}")
        echo "Giving the Runner the SSH key from ${SNAPCD_SSH_KEY}"
    fi

    # The Runner and the Agent authenticate with projected tokens, and the Server checks them
    # against the cluster's issuer keys, which it fetches without credentials.
    "${KUBECTL[@]}" create clusterrolebinding snapcd-oidc-discovery \
        --clusterrole=system:service-account-issuer-discovery --group=system:unauthenticated \
        --dry-run=client -o yaml | "${KUBECTL[@]}" apply -f - >/dev/null

    echo "Installing Snap CD"
    helm dependency update charts/snapcd >/dev/null
    LOCAL_VALUES=()
    if [[ "$LOCAL" == true ]]; then
        LOCAL_VALUES=(--values kind/values-local.yaml)
    fi

    DB_PORTS=()
    [[ -n "$SQL_PORT" ]] && DB_PORTS+=(--set server.sqlserver.nodePort.enabled=true)
    [[ -n "$REDIS_PORT" ]] && DB_PORTS+=(--set server.redis.nodePort.enabled=true)

    "${HELM[@]}" upgrade --install snapcd charts/snapcd \
        --namespace snapcd --create-namespace \
        --values kind/values.yaml \
        "${LOCAL_VALUES[@]}" \
        --set-string "server.ingress.publicPort=${HTTP_PORT}" \
        "${DB_PORTS[@]}" \
        "${AGENT[@]}" \
        "${SSH[@]}" \
        --wait --timeout 10m
else
    echo "Applying the Kustomize deployment"
    "${KUBECTL[@]}" kustomize kind/kustomize \
        | sed "s|http://snapcd.localhost:9080|${URL}|" \
        | if [[ "$LOCAL" == true ]]; then
              sed -E 's|(image: ghcr\.io/schrieksoft/snapcd/snapcd-[a-z-]+):[^ ]+|\1:local|'
          else
              cat
          fi \
        | "${KUBECTL[@]}" apply -f - >/dev/null
    "${KUBECTL[@]}" -n snapcd-server rollout status statefulset/snapcd-server-sqlserver --timeout=300s
    "${KUBECTL[@]}" -n snapcd-server rollout status deployment/snapcd-server --timeout=600s
    "${KUBECTL[@]}" -n snapcd-runner rollout status statefulset/snapcd-runner --timeout=300s
    "${KUBECTL[@]}" -n snapcd-agent rollout status deployment/snapcd-agent --timeout=300s
fi

echo
echo "Snap CD is up at ${URL}"
[[ -n "$SQL_PORT" ]] && echo "SQL Server:  localhost,${SQL_PORT}  (sa / the chart's sample password)"
[[ -n "$REDIS_PORT" ]] && echo "Redis:       localhost:${REDIS_PORT}"
