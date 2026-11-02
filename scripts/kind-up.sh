#!/usr/bin/env bash
# Brings up Snap CD on a local kind cluster, reachable at http://snapcd.localhost:<port>.
#
# Usage:
#   scripts/kind-up.sh
#
# Environment:
#   KIND_CLUSTER     cluster name (default: snapcd)
#   KIND_HTTP_PORT   host port for the ingress (default: 9080)
#
# Everything else is the charts' defaults: the reference deployment's sample settings.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

CLUSTER="${KIND_CLUSTER:-snapcd}"
HTTP_PORT="${KIND_HTTP_PORT:-9080}"
INGRESS_NGINX_VERSION="controller-v1.11.3"

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

kubectl config use-context "kind-${CLUSTER}" >/dev/null

echo "Installing ingress-nginx"
kubectl apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/${INGRESS_NGINX_VERSION}/deploy/static/provider/kind/deploy.yaml" >/dev/null
kubectl -n ingress-nginx rollout status deployment/ingress-nginx-controller --timeout=300s

echo "Installing the Server"
helm upgrade --install snapcd-server charts/snapcd-server \
    --namespace snapcd-server --create-namespace \
    --values kind/values-server.yaml \
    --set-string "ingress.publicPort=${HTTP_PORT}" \
    --wait --timeout 10m

echo "Installing the Runner"
helm upgrade --install snapcd-runner charts/snapcd-runner \
    --namespace snapcd-runner --create-namespace \
    --wait --timeout 5m

echo
echo "Snap CD is up at http://snapcd.localhost:${HTTP_PORT}"
