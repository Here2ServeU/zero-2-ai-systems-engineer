#!/usr/bin/env bash
# Chapter 14 cloud track tests: who answers, blue or green?  Usage: test.sh <1|2|3>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../platform/scripts/lib.sh"

# Ask /info N times and count the colors, like get_usage_stats() in router.py.
count_colors() {
  local base="$1" n="${2:-20}" blue=0 green=0 c
  for _ in $(seq 1 "$n"); do
    c=$(curl -fsS --max-time 5 "$base/info" | grep -o '"color": *"[a-z]*"' | grep -o 'blue\|green' || echo none)
    case "$c" in blue) blue=$((blue+1));; green) green=$((green+1));; esac
  done
  echo "Out of $n visits: blue=$blue green=$green"
}

case "${1:-}" in
  1)
    use_cluster
    with_port_forward fraud-live-p1 8080 80 count_colors http://localhost:8080 10
    host=$(wait_for_lb_service fraud-live-p1 /health)
    say "Public NLB: http://$host"
    count_colors "http://$host" 10
    echo "Now flip it: bash switch.sh 1 green   then run this test again." ;;
  2)
    use_cluster
    for r in fraud-blue fraud-green fraud-router; do helm test "$r" -n "$NAMESPACE" --logs >/dev/null && ok "helm test $r"; done
    with_port_forward fraud-router 8080 80 count_colors http://localhost:8080 10
    echo "Now flip it: bash switch.sh 2 green   (undo: helm rollback fraud-router -n $NAMESPACE)" ;;
  3)
    use_cluster
    host=$(wait_for_ingress fraud-router /health)
    say "Public ALB: http://$host  (canary split)"
    sleep 10
    count_colors "http://$host" 40
    kubectl -n "$NAMESPACE" get ingress fraud-router \
      -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/actions\.weighted-routing}'; echo
    echo "Shift traffic: bash canary.sh 50   |   Demo auto-rollback: bash deploy.sh broken" ;;
  *) echo "Usage: $0 <1|2|3>"; exit 1 ;;
esac
ok "Phase ${1} checks passed"
