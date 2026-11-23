#!/usr/bin/env bash
# Chapter 10 cloud track: test each phase the same way you tested on your laptop.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../platform/scripts/lib.sh"

RELEASE=fraud-api
TXN='{"amount":950.0,"hour":3,"is_weekend":0,"amount_vs_avg":2.8,"is_large_txn":1,"is_late_night":1,"merch_txn_ct":4}'

checks() {
  local base="$1"
  http_get  "$base/health"
  http_get  "$base/info"
  http_post "$base/predict" "$TXN"
}

case "${1:-}" in
  1)
    use_cluster
    say "Through the tunnel (exactly like your laptop)"
    with_port_forward zero2ai-fraud-svc 8080 80 checks http://localhost:8080
    host=$(wait_for_lb_service zero2ai-fraud-svc /health)
    say "Through the public Network Load Balancer: http://$host"
    checks "http://$host"
    ;;
  2)
    use_cluster
    say "Through the tunnel"
    with_port_forward "$RELEASE" 8080 80 checks http://localhost:8080
    say "helm test (runs a curl pod inside the cluster)"
    helm test "$RELEASE" -n "$NAMESPACE" --logs
    ;;
  3)
    use_cluster
    helm test "$RELEASE" -n "$NAMESPACE" --logs
    host=$(wait_for_ingress "$RELEASE" /health)
    say "Through the public Application Load Balancer: http://$host"
    checks "http://$host"
    say "Production safety nets"
    kubectl -n "$NAMESPACE" get hpa,pdb,networkpolicy -l app.kubernetes.io/instance="$RELEASE"
    kubectl -n "$NAMESPACE" get pods -l app.kubernetes.io/instance="$RELEASE" -o wide
    ;;
  *) echo "Usage: $0 <1|2|3>"; exit 1 ;;
esac
ok "Phase ${1} checks passed"
