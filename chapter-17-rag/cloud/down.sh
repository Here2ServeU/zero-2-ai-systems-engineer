#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../chapter-10-kubernetes/scripts/lib.sh"
use_cluster; delete_manifests "$HERE/phase2a-yaml"; helm_uninstall rag-api
ok "Chapter 17 removed"
