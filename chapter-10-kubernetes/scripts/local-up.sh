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

echo "==> Building $IMAGE from chapter-06-docker"
docker build -t "$IMAGE" "$REPO_ROOT/chapter-06-docker"

# minikube and kind run their OWN container engine, so an image built on your
# laptop is invisible to them until you load it in. Docker Desktop shares the
# same engine, so nothing to do there.
case "$CTX" in
  minikube*) echo "==> Loading image into minikube"; minikube image load "$IMAGE" ;;
  kind-*)    echo "==> Loading image into kind";     kind load docker-image "$IMAGE" --name "${CTX#kind-}" ;;
  *)         echo "==> Docker Desktop (or similar): image is already visible" ;;
esac

echo "==> Applying the wish-files"
kubectl apply -f "$HERE/deployment.yaml"
kubectl apply -f "$HERE/service.yaml"

echo "==> Waiting for both copies to be Ready (up to 2 minutes)"
kubectl rollout status deployment/zero2ai-fraud-api --timeout=120s
kubectl get pods -l app=zero2ai-fraud-api

echo
echo "Done. Now run:  bash chapter-10-kubernetes/scripts/local-test.sh"
