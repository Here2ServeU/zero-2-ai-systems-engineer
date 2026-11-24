#!/usr/bin/env bash
# switch.sh <2a|2b|3> <blue|green>: flip ALL traffic to one color (blue/green).
# Rolling back is just switching to blue again (or `helm rollback fraud-router`).
# 2b and 3 move the fraud-router Service. In Phase 3 the public ALB splits
# traffic itself, so use canary.sh for that (canary.sh 100 = all green).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../chapter-10-kubernetes/scripts/lib.sh"
phase="${1:-}"; color="${2:-}"
case "$color" in blue|green) ;; *) echo "Usage: $0 <2a|2b|3> <blue|green>"; exit 1 ;; esac
case "$phase" in 2a|2b|3) ;; *) echo "Usage: $0 <2a|2b|3> <blue|green>"; exit 1 ;; esac
use_cluster
case "$phase" in
  2a) kubectl -n "$NAMESPACE" patch service fraud-live-p1 \
       -p "{\"spec\":{\"selector\":{\"app\":\"fraud-bg\",\"color\":\"$color\"}}}" ;;
  2b|3) helm upgrade fraud-router "$CHART_DIR" -n "$NAMESPACE" --reuse-values \
         --set "service.selectorOverride.zero2ai-color=$color" --wait
       helm history fraud-router -n "$NAMESPACE" --max 3 ;;
  *) echo "Usage: $0 <2a|2b|3> <blue|green>"; exit 1 ;;
esac
ok "Traffic now goes to $color"
