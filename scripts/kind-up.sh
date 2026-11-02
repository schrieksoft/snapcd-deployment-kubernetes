#!/usr/bin/env bash
# Brings up Snap CD on a local kind cluster, reachable at http://snapcd.localhost:<port>.
#
# Usage:
#   scripts/kind-up.sh               # the snapcd chart, in the snapcd namespace
#   scripts/kind-up.sh --kustomize   # the Kustomize deployment, in its three namespaces
#
# Environment:
#   KIND_CLUSTER     cluster name (default: snapcd)
#   KIND_HTTP_PORT   host port for the ingress (default: 9080)
#
# Everything else is the defaults: the reference deployment's sample settings. With the chart,
# the Agent is installed when kind/agent.env holds a Claude credential (see kind/agent.env.example).
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

CLUSTER="${KIND_CLUSTER:-snapcd}"
HTTP_PORT="${KIND_HTTP_PORT:-9080}"
INGRESS_NGINX_VERSION="controller-v1.11.3"
URL="http://snapcd.localhost:${HTTP_PORT}"

MODE="chart"
if [[ ${1:-} == "--kustomize" ]]; then
    MODE="kustomize"
fi

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

echo "Installing ingress-nginx"
"${KUBECTL[@]}" apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/${INGRESS_NGINX_VERSION}/deploy/static/provider/kind/deploy.yaml" >/dev/null
"${KUBECTL[@]}" -n ingress-nginx rollout status deployment/ingress-nginx-controller --timeout=300s

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

    echo "Installing Snap CD"
    helm dependency update charts/snapcd >/dev/null
    "${HELM[@]}" upgrade --install snapcd charts/snapcd \
        --namespace snapcd --create-namespace \
        --values kind/values.yaml \
        --set-string "server.ingress.publicPort=${HTTP_PORT}" \
        "${AGENT[@]}" \
        --wait --timeout 10m
else
    echo "Applying the Kustomize deployment"
    "${KUBECTL[@]}" kustomize kind/kustomize \
        | sed "s|http://snapcd.localhost:9080|${URL}|" \
        | "${KUBECTL[@]}" apply -f - >/dev/null
    "${KUBECTL[@]}" -n snapcd-server rollout status statefulset/sqlserver --timeout=300s
    "${KUBECTL[@]}" -n snapcd-server rollout status deployment/snapcd-server --timeout=600s
    "${KUBECTL[@]}" -n snapcd-runner rollout status statefulset/snapcd-runner --timeout=300s
    "${KUBECTL[@]}" -n snapcd-agent rollout status deployment/snapcd-agent --timeout=300s
fi

echo
echo "Snap CD is up at ${URL}"
