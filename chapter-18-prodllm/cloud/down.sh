#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../platform/scripts/lib.sh"
use_cluster; delete_manifests "$HERE/phase1"; helm_uninstall prod-llm
kubectl -n "$NAMESPACE" delete secret llm-api-keys --ignore-not-found
ok "Chapter 18 removed. Finished the course? bash ../../platform/scripts/platform-down.sh $ENV"
