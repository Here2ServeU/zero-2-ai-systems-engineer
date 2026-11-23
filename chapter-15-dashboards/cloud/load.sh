#!/usr/bin/env bash
# load.sh [seconds] [service]: send random payments to the app from INSIDE the
# cluster so the dashboard has something to draw. Default: 120 s, monitored-api.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../platform/scripts/lib.sh"
secs="${1:-120}"; svc="${2:-monitored-api}"
use_cluster
kubectl -n "$NAMESPACE" delete pod ch15-load --ignore-not-found >/dev/null
say "Sending traffic to $svc for $secs seconds"
kubectl -n "$NAMESPACE" run ch15-load --image=curlimages/curl:8.11.1 --restart=Never -- \
  sh -c "end=\$(( \$(date +%s) + $secs )); while [ \$(date +%s) -lt \$end ]; do
           a=\$(( (\$RANDOM % 1500) )); h=\$(( \$RANDOM % 24 ));
           curl -s -o /dev/null -X POST http://$svc/predict -H 'Content-Type: application/json' \
             -d \"{\\\"amount\\\":\$a,\\\"hour\\\":\$h}\"; done" >/dev/null
kubectl -n "$NAMESPACE" wait --for=jsonpath='{.status.phase}'=Succeeded pod/ch15-load --timeout="$((secs + 60))s" >/dev/null || true
kubectl -n "$NAMESPACE" delete pod ch15-load --ignore-not-found >/dev/null
ok "Done. Look at the dashboard."
