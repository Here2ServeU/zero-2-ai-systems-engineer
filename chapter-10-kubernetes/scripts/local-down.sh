#!/usr/bin/env bash
# local-down.sh: remove what local-up.sh created.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kubectl delete -f "$HERE/service.yaml" --ignore-not-found
kubectl delete -f "$HERE/deployment.yaml" --ignore-not-found
echo "Cleaned up."
