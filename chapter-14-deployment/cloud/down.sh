#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../chapter-10-kubernetes/scripts/lib.sh"
use_cluster; delete_manifests "$HERE/phase1"
for r in fraud-router fraud-green fraud-blue; do helm_uninstall "$r"; done
ok "Chapter 14 removed"
