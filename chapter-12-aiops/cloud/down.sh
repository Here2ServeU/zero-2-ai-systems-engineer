#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../chapter-10-kubernetes/scripts/lib.sh"
use_cluster; delete_manifests "$HERE/phase2a-yaml"; helm_uninstall aiops
kubectl -n "$NAMESPACE" delete pod aiops-load --ignore-not-found
ok "Chapter 12 guard removed (metrics-api from Chapter 11 is left running: bash ../../chapter-11-monitoring/cloud/down.sh)"
