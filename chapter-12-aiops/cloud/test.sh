#!/usr/bin/env bash
# Chapter 12 cloud track tests.  Usage: test.sh <1|2|3> [--load]
#   --load  first make metrics-api busy for ~4 minutes, so the guard sees a
#           rising CPU trend and says WARNING (Phase 3: and adds a copy).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../chapter-10-kubernetes/scripts/lib.sh"
RELEASE=aiops

run_now() {
  local name; name="aiops-now-$(date +%s)"
  say "Running the guard right now (job $name)"
  kubectl -n "$NAMESPACE" create job "$name" --from=cronjob/"$RELEASE" >/dev/null
  kubectl -n "$NAMESPACE" wait --for=condition=complete "job/$name" --timeout=3m \
    || { kubectl -n "$NAMESPACE" logs "job/$name"; die "The guard's run failed"; }
  kubectl -n "$NAMESPACE" logs "job/$name"
}

make_load() {
  say "Making metrics-api busy for 4 minutes (watch: kubectl -n $NAMESPACE top pods)"
  kubectl -n "$NAMESPACE" delete pod aiops-load --ignore-not-found >/dev/null
  kubectl -n "$NAMESPACE" run aiops-load --image=curlimages/curl:8.11.1 --restart=Never -- \
    sh -c 'end=$(( $(date +%s) + 240 )); while [ $(date +%s) -lt $end ]; do
             for i in 1 2 3 4 5 6 7 8; do curl -s -o /dev/null -X POST http://metrics-api/predict \
               -H "Content-Type: application/json" -d "{\"amount\":999}" & done; wait; done' >/dev/null
  sleep 240
  kubectl -n "$NAMESPACE" delete pod aiops-load --ignore-not-found >/dev/null
}

case "${1:-}" in
  1)
    use_cluster
    kubectl -n "$NAMESPACE" wait --for=condition=complete job/aiops-demo --timeout=3m
    say "The guard's report (same as your laptop)"
    kubectl -n "$NAMESPACE" logs job/aiops-demo ;;
  2|3)
    use_cluster
    [ "${2:-}" = "--load" ] && make_load
    kubectl -n "$NAMESPACE" get deploy metrics-api
    run_now
    say "After the guard ran"
    kubectl -n "$NAMESPACE" get deploy metrics-api
    kubectl -n "$NAMESPACE" get hpa metrics-api 2>/dev/null || true
    [ "$1" = "3" ] && { say "What the guard may do (RBAC)"; kubectl -n "$NAMESPACE" describe role "$RELEASE" | sed -n '/PolicyRule/,$p'; } ;;
  *) echo "Usage: $0 <1|2|3> [--load]"; exit 1 ;;
esac
ok "Phase ${1} checks passed"
