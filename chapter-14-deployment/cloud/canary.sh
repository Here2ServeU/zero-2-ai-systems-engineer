#!/usr/bin/env bash
# canary.sh <percent>: Phase 3 only. Send <percent>% of public traffic to green.
#   bash canary.sh 10    # a few guests taste the new recipe
#   bash canary.sh 50
#   bash canary.sh 100   # everyone on green
#   bash canary.sh 0     # instant rollback to blue
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../chapter-10-kubernetes/scripts/lib.sh"
w="${1:-}"
case "$w" in ''|*[!0-9]*) echo "Usage: $0 <0-100>"; exit 1 ;; esac
[ "$w" -le 100 ] || die "Percent must be 0-100"
use_cluster
helm upgrade fraud-router "$CHART_DIR" -n "$NAMESPACE" --reuse-values \
  --set "ingress.weighted.canaryWeight=$w" --wait
ok "ALB now sends $w% to green, $((100 - w))% to blue (takes ~10 s to apply)"
