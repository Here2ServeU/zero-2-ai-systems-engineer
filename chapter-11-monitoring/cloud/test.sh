#!/usr/bin/env bash
# Chapter 11 cloud track tests.  Usage: test.sh <1|2|3>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../platform/scripts/lib.sh"
RELEASE="metrics-api"

# Same as your laptop: visit the app a few times, then read its fitness watch.
poke_and_read() {
  local base="$1" metrics="$2"
  http_get "$base/health"
  for a in 120 450 990 30 1200; do http_post "$base/predict" "{\"amount\":$a}" >/dev/null; done
  echo "GET $metrics/metrics (api_ lines only)"
  curl -fsS "$metrics/metrics" | grep '^api_' | head -12
}

# Ask the cluster's Prometheus whether it is collecting this service.
prometheus_sees() {
  local svc="$1"
  say "Asking Prometheus: is it scraping $svc? (can take up to 1 minute after deploy)"
  local q="http://localhost:9090/api/v1/query?query=up%7Bservice%3D%22${svc}%22%7D"
  for _ in $(seq 1 12); do
    out=$(curl -fsS "$q" || true)
    if echo "$out" | grep -q '"value"'; then echo "$out"; ok "Prometheus is collecting $svc"; return 0; fi
    sleep 5
  done
  die "Prometheus has no 'up' series for $svc yet. Check Status > Targets in the Prometheus UI."
}
prom() { NAMESPACE=monitoring with_port_forward kube-prometheus-stack-prometheus 9090 9090 "$@"; }

case "${1:-}" in
  1)
    use_cluster
    with_port_forward metrics-api-p1 8080 80 \
      with_port_forward metrics-api-p1 8000 8000 poke_and_read http://localhost:8080 http://localhost:8000
    prom prometheus_sees metrics-api-p1 ;;
  2)
    use_cluster
    with_port_forward "$RELEASE" 8080 80 \
      with_port_forward "$RELEASE" 8000 8000 poke_and_read http://localhost:8080 http://localhost:8000
    helm test "$RELEASE" -n "$NAMESPACE" --logs
    prom prometheus_sees "$RELEASE" ;;
  3)
    use_cluster
    helm test "$RELEASE" -n "$NAMESPACE" --logs
    host=$(wait_for_ingress "$RELEASE" /health)
    say "Public address: http://$host"
    for a in 120 990 1500; do http_post "http://$host/predict" "{\"amount\":$a}"; done
    prom prometheus_sees "$RELEASE"
    say "Alert rules loaded into Prometheus"
    kubectl -n "$NAMESPACE" get prometheusrule "$RELEASE" -o jsonpath='{range .spec.groups[*].rules[*]}{.alert}{"\n"}{end}'
    kubectl -n "$NAMESPACE" get hpa,pdb -l app.kubernetes.io/instance="$RELEASE" ;;
  *) echo "Usage: $0 <1|2|3>"; exit 1 ;;
esac
ok "Phase ${1} checks passed"
