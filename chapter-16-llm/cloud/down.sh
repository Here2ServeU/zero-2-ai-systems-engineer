#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../chapter-10-kubernetes/scripts/lib.sh"
use_cluster
for f in "$HERE"/phase1/*.yaml; do sed -e "s#__IMAGE__#x#;s#__SCRIPT__#x#" "$f" | kubectl delete -n "$NAMESPACE" --ignore-not-found -f -; done
helm_uninstall llm-api
ok "Chapter 16 removed (the llm-api-keys Secret is kept for Chapters 17-18; delete with: kubectl -n $NAMESPACE delete secret llm-api-keys)"
