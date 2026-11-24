#!/usr/bin/env bash
# Chapter 10 cloud track: remove this chapter's app (the cluster stays).
# To delete the whole cluster: bash ../scripts/platform-down.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../scripts/lib.sh"
use_cluster
delete_manifests "$HERE/phase2a-yaml"
helm_uninstall fraud-api
ok "Chapter 10 app removed from $CLUSTER_NAME"
