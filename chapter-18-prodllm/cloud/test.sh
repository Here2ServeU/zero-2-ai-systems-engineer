#!/usr/bin/env bash
# Chapter 18 cloud track tests: every grown-up feature, checked.  Usage: test.sh <1|2|3>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../platform/scripts/lib.sh"

features() {
  local b="$1"
  http_get "$b/health"
  say "1. A real question"
  http_post "$b/llm" '{"user_id":"student1","prompt":"In one sentence, what is KYC?"}'
  say "2. Same question again: \"cached\": true (free) if the same copy answers. With 2+ copies behind the ALB it may be false: each copy has its own memory box (see phase3/values.yaml)"
  http_post "$b/llm" '{"user_id":"student1","prompt":"In one sentence, what is KYC?"}'
  say "3. Safety filter: should be rejected with 422"
  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$b/llm" -H 'Content-Type: application/json' \
         -d '{"user_id":"student1","prompt":"my ssn: 123-45-6789"}')
  [ "$code" = "422" ] && ok "Blocked (HTTP 422)" || die "Expected 422, got $code"
}
metrics() { echo "llm_ metrics:"; curl -fsS "$1/metrics" | grep '^llm_calls_total\|^llm_tokens_total'; }

case "${1:-}" in
  1) use_cluster
     with_port_forward prod-llm-p1 8080 80 features http://localhost:8080
     with_port_forward prod-llm-p1 8000 8000 metrics http://localhost:8000 ;;
  2) use_cluster
     helm test prod-llm -n "$NAMESPACE" --logs >/dev/null && ok "helm test prod-llm"
     with_port_forward prod-llm 8080 80 features http://localhost:8080
     with_port_forward prod-llm 8000 8000 metrics http://localhost:8000 ;;
  3) use_cluster
     kubectl -n "$NAMESPACE" get externalsecret prod-llm
     helm test prod-llm -n "$NAMESPACE" --logs >/dev/null && ok "helm test prod-llm"
     host=$(wait_for_ingress prod-llm /health); say "Public: http://$host"
     features "http://$host"
     say "Production safety nets"
     kubectl -n "$NAMESPACE" get hpa,pdb,networkpolicy,servicemonitor,prometheusrule -l app.kubernetes.io/instance=prod-llm ;;
  *) echo "Usage: $0 <1|2|3>"; exit 1 ;;
esac
ok "Phase ${1} checks passed"
