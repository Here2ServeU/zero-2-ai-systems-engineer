#!/usr/bin/env bash
# local-down.sh: remove what local-up.sh created. Your cluster keeps running;
# turn it off in Docker Desktop (or `minikube stop`) when you're done for the day.
#
#   bash scripts/local-down.sh         (from the chapter-10-kubernetes folder)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "==> Removing the fraud API from '$(kubectl config current-context)'"
kubectl delete -f "$HERE/service.yaml" --ignore-not-found
kubectl delete -f "$HERE/deployment.yaml" --ignore-not-found
echo "Cleaned up."
