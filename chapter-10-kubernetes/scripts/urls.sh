#!/usr/bin/env bash
# urls.sh: every address on the platform's shared ALB, for your browser and
# for curl. Run it any time after platform-up.sh:
#   bash chapter-10-kubernetes/scripts/urls.sh          (ENV=qa / ENV=prod for the others)
set -euo pipefail
source "$(dirname "$0")/lib.sh"
use_cluster

alb=$(platform_alb)
[ -n "$alb" ] || die "No platform ALB yet. Run: bash chapter-10-kubernetes/scripts/platform-up.sh $ENV  (or wait 2-3 minutes)"

say "Platform ALB ($ENV): http://$alb"
printf '  %-28s %s\n' "Landing page (browser)" "http://$alb/"

say "Monitoring"
for i in grafana prometheus alertmanager; do
  if kubectl -n monitoring get ingress "zero2ai-$i" >/dev/null 2>&1; then
    port=$(kubectl -n monitoring get ingress "zero2ai-$i" \
      -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/listen-ports}' | grep -o '[0-9][0-9]*' | head -1)
    printf '  %-28s %s\n' "$i" "http://$alb:$port/"
  else
    printf '  %-28s %s\n' "$i" "not on the ALB (port-forward; see platform/README.md)"
  fi
done
echo "  Grafana login: admin / \$(terraform -chdir=$TF_DIR/eks-addons output -raw grafana_admin_password)"

say "Chapter apps on the ALB (namespace $NAMESPACE)"
found=0
for ing in $(kubectl -n "$NAMESPACE" get ingress -o name 2>/dev/null); do
  name=${ing#*/}
  host=$(kubectl -n "$NAMESPACE" get "$ing" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  port=$(ingress_port "$name")
  addr="${host:-<pending>}"; [ "${port:-80}" = "80" ] || addr="$addr:$port"
  printf '  %-28s %s\n' "$name" "http://$addr/health"
  found=1
done
[ $found -eq 1 ] || echo "  none yet: run a chapter's  bash deploy.sh 3"

say "From the command line"
cat <<TXT
  curl -i http://$alb/                         # landing page
  curl -s http://$alb:3000/api/health          # Grafana
  curl -s http://$alb:8010/health              # Chapter 10 (after its deploy.sh 3)
  kubectl get nodes                            # the cluster itself (kubectl was set up by use_cluster)
TXT
