#!/usr/bin/env bash
# local-up.sh: build the image, hand it to your local cluster, and deploy.
# Works with Docker Desktop Kubernetes, minikube, and kind.
# Run from anywhere:  bash chapter-10-kubernetes/scripts/local-up.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
IMAGE="zero2ai-fraud-api:v1.0"

echo "==> Checking the cluster is awake"
kubectl get nodes

CTX="$(kubectl config current-context)"
echo "==> Current cluster: $CTX"

# This script is for a LOCAL cluster. If kubectl points at EKS (platform-up.sh
# switches it there), the cluster can't see an image that only exists on your
# laptop, and the pods end up in ImagePullBackOff. Use the cloud track instead.
case "$CTX" in
  arn:aws:eks:*|*eks*)
    echo "✘ kubectl is pointed at a cloud cluster ($CTX), not your laptop." >&2
    echo "  Cloud:  bash chapter-10-kubernetes/cloud/deploy.sh build && bash chapter-10-kubernetes/cloud/deploy.sh 1" >&2
    echo "  Local:  kubectl config get-contexts   then   kubectl config use-context docker-desktop   (or minikube / kind-<name>)" >&2
    exit 1 ;;
esac

echo "==> Building $IMAGE from chapter-06-docker"
docker build -t "$IMAGE" "$REPO_ROOT/chapter-06-docker"

# minikube and kind run their OWN container engine, so an image built on your
# laptop is invisible to them until you load it in. Docker Desktop shares the
# same engine, so nothing to do there.
case "$CTX" in
  minikube*) echo "==> Loading image into minikube"; minikube image load "$IMAGE" ;;
  kind-*)    echo "==> Loading image into kind";     kind load docker-image "$IMAGE" --name "${CTX#kind-}" ;;
  docker-desktop|rancher-desktop|orbstack)
             echo "==> $CTX shares your laptop's images: nothing to load" ;;
  *)         echo "==> Unknown cluster '$CTX': assuming it can see your laptop's images" ;;
esac

echo "==> Applying the wish-files"
kubectl apply -f "$HERE/deployment.yaml"
kubectl apply -f "$HERE/service.yaml"

echo "==> Waiting for both copies to be Ready (up to 2 minutes)"
if ! kubectl rollout status deployment/zero2ai-fraud-api --timeout=120s; then
  kubectl get pods -l app=zero2ai-fraud-api
  if kubectl get pods -l app=zero2ai-fraud-api \
       -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' \
     | grep -qE 'ErrImagePull|ImagePullBackOff|ErrImageNeverPull'; then
    echo "✘ The cluster '$CTX' can't see the image $IMAGE." >&2
    echo "  It exists only in your laptop's Docker. Load it into the cluster, then restart:" >&2
    echo "    minikube:  minikube image load $IMAGE" >&2
    echo "    kind:      kind load docker-image $IMAGE --name <cluster>" >&2
    echo "    then:      kubectl rollout restart deployment zero2ai-fraud-api" >&2
  fi
  exit 1
fi
kubectl get pods -l app=zero2ai-fraud-api

echo
echo "Done. Now run:  bash chapter-10-kubernetes/scripts/local-test.sh"
