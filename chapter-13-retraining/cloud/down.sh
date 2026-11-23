#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../chapter-10-kubernetes/scripts/lib.sh"
use_cluster; delete_manifests "$HERE/phase1"; helm_uninstall retrain; helm_uninstall mlflow
kubectl -n "$NAMESPACE" delete jobs -l app.kubernetes.io/instance=retrain --ignore-not-found
ok "Chapter 13 removed (S3 model files stay until platform-down.sh)"
