#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../chapter-10-kubernetes/scripts/lib.sh"
use_cluster; delete_manifests "$HERE/phase1"; helm_uninstall metrics-api
ok "Chapter 11 app removed"
