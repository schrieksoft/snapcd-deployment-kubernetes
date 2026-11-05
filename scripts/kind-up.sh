#!/usr/bin/env bash
# Brings up Snap CD on a local kind cluster, reachable at http://snapcd.localhost:<port>.
#
# Usage:
#   scripts/kind-up.sh               # the snapcd chart, in the snapcd namespace
#   scripts/kind-up.sh --kustomize   # the Kustomize deployment, in its three namespaces
#   scripts/kind-up.sh --local       # either of the above with images built locally and tagged :local
#   scripts/kind-up.sh --restricted  # enforce the restricted pod security profile on the Snap CD namespaces
#
# Environment:
#   KIND_CLUSTER     cluster name (default: snapcd)
#   KIND_HTTP_PORT   host port for the ingress (default: 9080)
#   KIND_SQL_PORT    host port for SQL Server (default: 31433; empty to not expose it)
#   KIND_REDIS_PORT  host port for Redis (default: 31379; empty to not expose it)
#   SNAPCD_SSH_KEY   private key for the Runner, to clone private repositories over SSH
#
# The deploy step is scripts/deploy.sh, which this calls and which can be run on its own to
# redeploy against a cluster that is already up.
#
# Everything else is the defaults: the reference deployment's sample settings. With the chart,
# the Agent is installed when kind/agent.env holds a Claude credential (see kind/agent.env.example).
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

CLUSTER="${KIND_CLUSTER:-snapcd}"
HTTP_PORT="${KIND_HTTP_PORT:-9080}"
# The database and the cache are published on the node so they can be queried from the host.
# kind maps host ports when the cluster is created, so these have to match the node ports the
# chart asks for, and the cluster has to be recreated to change them.
SQL_PORT="${KIND_SQL_PORT-31433}"
REDIS_PORT="${KIND_REDIS_PORT-31379}"
INGRESS_NGINX_VERSION="controller-v1.11.3"

MODE="chart"
LOCAL=false
RESTRICTED=false
for arg in "$@"; do
    case "$arg" in
        --kustomize) MODE="kustomize" ;;
        --local) LOCAL=true ;;
        --restricted) RESTRICTED=true ;;
        *) echo "unknown argument: $arg" >&2; exit 1 ;;
    esac
done

LOCAL_IMAGES=(
    ghcr.io/schrieksoft/snapcd/snapcd-server:local
    ghcr.io/schrieksoft/snapcd/snapcd-runner-azure:local
    ghcr.io/schrieksoft/snapcd/snapcd-agent:local
    ghcr.io/schrieksoft/snapcd/snapcd-agent-sidecar-claude:local
)

for tool in kind kubectl helm; do
    command -v "$tool" >/dev/null || { echo "$tool is required" >&2; exit 1; }
done

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK:?}"' EXIT

if ! kind get clusters | grep -qx "$CLUSTER"; then
    cat > "$WORK/cluster.yaml" <<YAML
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    labels:
      ingress-ready: "true"
    extraPortMappings:
      - containerPort: 80
        hostPort: ${HTTP_PORT}
        protocol: TCP
$( [[ -n "$SQL_PORT" ]] && cat <<SQL
      - containerPort: 31433
        hostPort: ${SQL_PORT}
        protocol: TCP
SQL
)
$( [[ -n "$REDIS_PORT" ]] && cat <<REDIS
      - containerPort: 31379
        hostPort: ${REDIS_PORT}
        protocol: TCP
REDIS
)
YAML
    kind create cluster --name "$CLUSTER" --config "$WORK/cluster.yaml"
fi

KUBECTL=(kubectl --context "kind-${CLUSTER}")
HELM=(helm --kube-context "kind-${CLUSTER}")

# The two modes create the same names, so a cluster holds one or the other.
if [[ "$MODE" == "kustomize" ]] && "${HELM[@]}" status snapcd --namespace snapcd >/dev/null 2>&1; then
    echo "The cluster has the chart installed; run scripts/kind-down.sh first." >&2
    exit 1
fi
if [[ "$MODE" == "chart" ]] && "${KUBECTL[@]}" get namespace snapcd-server >/dev/null 2>&1; then
    echo "The cluster has the Kustomize deployment; run scripts/kind-down.sh first." >&2
    exit 1
fi

if [[ "$LOCAL" == true ]]; then
    echo "Loading the :local images"
    for image in "${LOCAL_IMAGES[@]}"; do
        docker image inspect "$image" >/dev/null 2>&1 || { echo "$image is not built" >&2; exit 1; }
        kind load docker-image "$image" --name "$CLUSTER" >/dev/null
    done
fi

if [[ "$RESTRICTED" == true ]]; then
    if [[ "$MODE" == "chart" ]]; then NAMESPACES=(snapcd); else NAMESPACES=(snapcd-server snapcd-runner snapcd-agent); fi
    for ns in "${NAMESPACES[@]}"; do
        "${KUBECTL[@]}" create namespace "$ns" --dry-run=client -o yaml | "${KUBECTL[@]}" apply -f - >/dev/null
        "${KUBECTL[@]}" label namespace "$ns" pod-security.kubernetes.io/enforce=restricted --overwrite >/dev/null
    done
    echo "Enforcing the restricted pod security profile on: ${NAMESPACES[*]}"
fi

echo "Installing ingress-nginx"
"${KUBECTL[@]}" apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/${INGRESS_NGINX_VERSION}/deploy/static/provider/kind/deploy.yaml" >/dev/null
"${KUBECTL[@]}" -n ingress-nginx rollout status deployment/ingress-nginx-controller --timeout=300s

DEPLOY=()
[[ "$MODE" == "kustomize" ]] && DEPLOY+=(--kustomize)
[[ "$LOCAL" == true ]] && DEPLOY+=(--local)

KIND_CLUSTER="$CLUSTER" KIND_HTTP_PORT="$HTTP_PORT" KIND_SQL_PORT="$SQL_PORT" \
    KIND_REDIS_PORT="$REDIS_PORT" scripts/deploy.sh "${DEPLOY[@]+"${DEPLOY[@]}"}"
