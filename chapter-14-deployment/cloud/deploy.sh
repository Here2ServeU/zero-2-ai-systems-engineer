#!/usr/bin/env bash
# Chapter 14 cloud track: blue/green and canary releases on EKS.
#   deploy.sh build | 2a | 2b | 3 | broken
#   (broken = Phase 3 demo: ship a bad green with --atomic and watch Helm undo it)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../chapter-10-kubernetes/scripts/lib.sh"
APP=fraud-api      # same image as Chapter 10

case "${1:-}" in
  build) use_cluster; build_push "$APP" "$REPO_ROOT/chapter-10-kubernetes/fraud-api" ;;
  2a)
    use_cluster
    for r in fraud-router fraud-green fraud-blue; do helm_uninstall "$r"; done
    apply_manifests "$HERE/phase2a-yaml" "$(last_image "$APP")"
    kubectl -n "$NAMESPACE" rollout status deployment/fraud-blue-p1 --timeout=5m
    kubectl -n "$NAMESPACE" rollout status deployment/fraud-green-p1 --timeout=5m
    ok "Phase 2A: blue and green running, traffic on BLUE. Test: bash test.sh 2a" ;;
  2b|3)
    use_cluster; delete_manifests "$HERE/phase2a-yaml"
    img="$(last_image "$APP")"
    app3=(); router3=()
    if [ "$1" = "3" ]; then
      app3=(-f "$HERE/phase3-production/app.yaml" --set "networkPolicy.allowCidrs[0]=$(vpc_cidr)" --atomic)
      router3=(-f "$HERE/phase3-production/router.yaml")
    fi
    helm_deploy fraud-blue  "$img" -f "$HERE/phase2b-helm/blue.yaml"  ${app3[@]+"${app3[@]}"}
    helm_deploy fraud-green "$img" -f "$HERE/phase2b-helm/green.yaml" ${app3[@]+"${app3[@]}"}
    helm_deploy fraud-router "$img" -f "$HERE/phase2b-helm/router.yaml" ${router3[@]+"${router3[@]}"}
    ok "Phase $(echo "$1" | tr a-z A-Z) deployed: blue and green running, router on BLUE. Test: bash test.sh $1" ;;
  broken)
    use_cluster
    img="$(last_image "$APP")"
    say "Shipping a BROKEN green (it can't start) with --atomic..."
    # helm upgrade is called directly (not through helm_deploy): inside an `if`,
    # bash ignores `set -e`, so helm_deploy's final `helm history` would hide
    # the failure and make this demo report the wrong result.
    if helm upgrade --install fraud-green "$CHART_DIR" --namespace "$NAMESPACE" \
         --set image.repository="${img%:*}" --set image.tag="${img##*:}" \
         -f "$HERE/phase2b-helm/green.yaml" -f "$HERE/phase3-production/app.yaml" \
         --set "networkPolicy.allowCidrs[0]=$(vpc_cidr)" \
         --set 'command={python,does_not_exist.py}' --wait --timeout 3m --atomic; then
      die "Unexpected: the broken release succeeded"
    fi
    ok "Helm detected the failure and rolled green back automatically:"
    helm history fraud-green -n "$NAMESPACE" --max 4 ;;
  *) echo "Usage: $0 <build|2a|2b|3|broken>"; exit 1 ;;
esac
