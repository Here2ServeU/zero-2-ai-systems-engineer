#!/usr/bin/env bash
# Chapter 15 cloud track tests.  Usage: test.sh <1|2|3>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../platform/scripts/lib.sh"

prom_has() {
  local q="http://localhost:9090/api/v1/query?query=sum(fraud_predictions_total)"
  for _ in $(seq 1 12); do
    if curl -fsS "$q" | grep -q '"value"'; then curl -fsS "$q"; echo; ok "Prometheus has the app's numbers"; return 0; fi
    sleep 5
  done
  die "Prometheus has no fraud_predictions_total yet (scrapes every 15 s; retry in a minute)"
}
grafana_has_dashboard() {
  local pw; pw=$(kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d)
  curl -fsS -u "admin:$pw" "http://localhost:3000/api/dashboards/uid/zero2ai-fraud-ch15" | grep -o '"title":"[^"]*"' | head -1
  ok "Grafana loaded the dashboard"
}

svc=monitored-api; [ "${1:-}" = "1" ] && svc=monitored-api-p1
case "${1:-}" in
  1|2|3)
    use_cluster
    bash "$HERE/load.sh" 45 "$svc"
    NAMESPACE=monitoring with_port_forward kube-prometheus-stack-prometheus 9090 9090 prom_has
    if [ "$1" != "1" ]; then
      helm test monitored-api -n "$NAMESPACE" --logs >/dev/null && ok "helm test monitored-api"
      NAMESPACE=monitoring with_port_forward kube-prometheus-stack-grafana 3000 80 grafana_has_dashboard
    fi
    if [ "$1" = "3" ]; then
      host=$(wait_for_ingress monitored-api /health); say "Public: http://$host"
      http_post "http://$host/predict" '{"amount":950,"hour":3}'
      kubectl -n "$NAMESPACE" get prometheusrule monitored-api -o jsonpath='{range .spec.groups[*].rules[*]}{.alert}{"\n"}{end}'
    fi
    echo
    echo "Open Grafana yourself:"
    echo "  kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80"
    echo "  http://localhost:3000   user: admin   password: terraform -chdir=$TF_DIR/eks-addons output -raw grafana_admin_password" ;;
  *) echo "Usage: $0 <1|2|3>"; exit 1 ;;
esac
ok "Phase ${1} checks passed"
