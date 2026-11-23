#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../platform/scripts/lib.sh"
use_cluster; delete_manifests "$HERE/phase1"; helm_uninstall rag-api
ok "Chapter 17 removed"
