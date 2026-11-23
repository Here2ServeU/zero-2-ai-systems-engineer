#!/usr/bin/env bash
# Chapter 11 cloud track: metrics app + Prometheus on EKS.  Usage: deploy.sh <build|1|2|3>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../platform/scripts/lib.sh"
APP=metrics-api; RELEASE=metrics-api

case "${1:-}" in
  build) use_cluster; build_push "$APP" "$HERE/.." ;;
  1)
    use_cluster; helm_uninstall "$RELEASE"
    apply_manifests "$HERE/phase1" "$(last_image "$APP")"
    kubectl -n "$NAMESPACE" rollout status deployment/metrics-api-p1 --timeout=5m
    ok "Phase 1 deployed. Test it: bash test.sh 1" ;;
  2)
    use_cluster; delete_manifests "$HERE/phase1"
    values_args "$HERE/phase2"
    helm_deploy "$RELEASE" "$(last_image "$APP")" "${VALUES_ARGS[@]}"
    ok "Phase 2 deployed. Test it: bash test.sh 2" ;;
  3)
    use_cluster; delete_manifests "$HERE/phase1"
    values_args "$HERE/phase2" "$HERE/phase3"
    helm_deploy "$RELEASE" "$(last_image "$APP")" "${VALUES_ARGS[@]}" \
      --set "networkPolicy.allowCidrs[0]=$(vpc_cidr)" --atomic
    ok "Phase 3 deployed. Test it: bash test.sh 3" ;;
  *) usage_phase ;;
esac
