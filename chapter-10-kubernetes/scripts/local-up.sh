#!/usr/bin/env bash
# local-up.sh: build the fraud API image, hand it to your local cluster, deploy
# 2 copies, and wait until both are Ready.
# Works with Docker Desktop (kubeadm or multi-node), minikube and kind.
#
#   bash scripts/local-up.sh           (from the chapter-10-kubernetes folder)
#
# Safe to run again: after you change the app, it rebuilds and restarts the copies.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # the chapter folder
IMAGE="zero2ai-fraud-api:v1.0"
APP=zero2ai-fraud-api

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m[OK] %s\033[0m\n' "$*"; }
oops() { printf '\033[1;31m[ERROR] %s\033[0m\n' "$*" >&2; }

say "Step 1/5: checking your laptop"
CALLED_FROM_LOCAL_UP=1 bash "$HERE/scripts/local-check.sh"
CTX="$(kubectl config current-context)"

say "Step 2/5: building the image $IMAGE (from fraud-api/)"
echo "The first build downloads Python and libraries: allow a few minutes."
docker build -t "$IMAGE" "$HERE/fraud-api"
ok "Image built"

# minikube and kind run their OWN container engine, so an image built on your
# laptop is invisible to them until you load it in. Docker Desktop's classic
# single-node cluster (kubeadm) shares your laptop's engine, but its multi-node
# "kind" mode (nodes named desktop-control-plane, desktop-worker, ...) does
# NOT: each node is a container with its own image store, so we load the image in.
load_into_desktop_nodes() {
  if command -v kind >/dev/null 2>&1 && kind load docker-image "$IMAGE" --name desktop; then
    return 0
  fi
  local node failed=0
  for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
    echo "    -> $node"
    docker save "$IMAGE" | docker exec -i "$node" ctr --namespace=k8s.io images import --digests - >/dev/null || failed=1
  done
  if [ "$failed" = 1 ]; then
    oops "Could not copy the image into Docker Desktop's nodes. Either:"
    echo "    - Docker Desktop > Settings > Kubernetes: choose the kubeadm cluster type, or" >&2
    echo "    - install kind and run: kind load docker-image $IMAGE --name desktop" >&2
    return 1
  fi
}

say "Step 3/5: making the image visible to the cluster ($CTX)"
case "$CTX" in
  minikube*) minikube image load "$IMAGE" ;;
  kind-*)    kind load docker-image "$IMAGE" --name "${CTX#kind-}" ;;
  docker-desktop)
    if kubectl get nodes -o name | grep -q '^node/desktop-'; then
      echo "Docker Desktop multi-node mode: copying the image into each node"
      load_into_desktop_nodes
    else
      echo "Docker Desktop shares your laptop's images: nothing to copy"
    fi ;;
  rancher-desktop|orbstack)
    echo "$CTX shares your laptop's images: nothing to copy" ;;
  *) echo "Unknown cluster type '$CTX': assuming it can see your laptop's images" ;;
esac
ok "Image is available to the cluster"

say "Step 4/5: applying the two wish-files"
EXISTED=no
kubectl get deployment "$APP" >/dev/null 2>&1 && EXISTED=yes
kubectl apply -f "$HERE/deployment.yaml"
kubectl apply -f "$HERE/service.yaml"
if [ "$EXISTED" = yes ]; then
  # The tag (v1.0) didn't change, so Kubernetes wouldn't notice a rebuilt image.
  # A restart swaps the copies one by one for ones running the new image.
  echo "Already running: restarting the copies so they use the image you just built"
  kubectl rollout restart deployment "$APP"
fi

say "Step 5/5: waiting for both copies to be Ready (up to 3 minutes)"
if ! kubectl rollout status deployment "$APP" --timeout=180s; then
  kubectl get pods -l app="$APP"
  REASONS="$(kubectl get pods -l app="$APP" \
    -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' 2>/dev/null || true)"
  case "$REASONS" in
    *ImagePull*|*ErrImageNeverPull*)
      oops "The cluster '$CTX' can't see the image $IMAGE."
      echo "  It exists only in your laptop's Docker. See README → 'If something breaks' → ImagePullBackOff." >&2 ;;
    *CrashLoopBackOff*|*Error*)
      oops "The app starts and then crashes. Its last words:"
      kubectl logs deployment/"$APP" --tail=20 >&2 || true ;;
    *)
      oops "The copies are not Ready yet. Details:"
      kubectl describe pods -l app="$APP" | tail -20 >&2 || true ;;
  esac
  exit 1
fi
kubectl get pods -l app="$APP"
ok "2 copies of the fraud API are running"

echo
echo "Next:  bash scripts/local-test.sh"
