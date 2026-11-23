#!/usr/bin/env bash
# Chapter 14 cloud track: blue/green and canary releases on EKS.
#   deploy.sh build | 1 | 2 | 3 | broken
#   (broken = Phase 3 demo: ship a bad green with --atomic and watch Helm undo it)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../platform/scripts/lib.sh"
APP=fraud-api      # same image as Chapter 10

case "${1:-}" in
  build) use_cluster; build_push "$APP" "$REPO_ROOT/chapter-06-docker" ;;
  1)
    use_cluster
    for r in fraud-router fraud-green fraud-blue; do helm_uninstall "$r"; done
    apply_manifests "$HERE/phase1" "$(last_image "$APP")"
    kubectl -n "$NAMESPACE" rollout status deployment/fraud-blue-p1 --timeout=5m
    kubectl -n "$NAMESPACE" rollout status deployment/fraud-green-p1 --timeout=5m
    ok "Phase 1: blue and green running, traffic on BLUE. Test: bash test.sh 1" ;;
  2|3)
    use_cluster; delete_manifests "$HERE/phase1"
    img="$(last_image "$APP")"
    app3=(); router3=()
    if [ "$1" = "3" ]; then
      app3=(-f "$HERE/phase3/app.yaml" --set "networkPolicy.allowCidrs[0]=$(vpc_cidr)" --atomic)
      router3=(-f "$HERE/phase3/router.yaml")
    fi
    helm_deploy fraud-blue  "$img" -f "$HERE/phase2/blue.yaml"  ${app3[@]+"${app3[@]}"}
    helm_deploy fraud-green "$img" -f "$HERE/phase2/green.yaml" ${app3[@]+"${app3[@]}"}
    helm_deploy fraud-router "$img" -f "$HERE/phase2/router.yaml" ${router3[@]+"${router3[@]}"}
    ok "Phase $1 deployed: blue and green running, router on BLUE. Test: bash test.sh $1" ;;
  broken)
    use_cluster
    say "Shipping a BROKEN green (it can't start) with --atomic..."
    if helm_deploy fraud-green "$(last_image "$APP")" -f "$HERE/phase2/green.yaml" \
         -f "$HERE/phase3/app.yaml" --set "networkPolicy.allowCidrs[0]=$(vpc_cidr)" \
         --set 'command={python,does_not_exist.py}' --timeout 3m --atomic; then
      die "Unexpected: the broken release succeeded"
    fi
    ok "Helm detected the failure and rolled green back automatically:"
    helm history fraud-green -n "$NAMESPACE" --max 4 ;;
  *) echo "Usage: $0 <build|1|2|3|broken>"; exit 1 ;;
esac
