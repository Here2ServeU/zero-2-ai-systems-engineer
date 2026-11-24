#!/usr/bin/env bash
# Chapter 11 cloud track: metrics app + Prometheus on EKS.  Usage: deploy.sh <build|2a|2b|3>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../chapter-10-kubernetes/scripts/lib.sh"
APP=metrics-api; RELEASE=metrics-api

case "${1:-}" in
  build) use_cluster; build_push "$APP" "$HERE/.." ;;
  2a)
    use_cluster; helm_uninstall "$RELEASE"
    apply_manifests "$HERE/phase2a-yaml" "$(last_image "$APP")"
    kubectl -n "$NAMESPACE" rollout status deployment/metrics-api-p1 --timeout=5m
    ok "Phase 2A deployed. Test it: bash test.sh 2a" ;;
  2b)
    use_cluster; delete_manifests "$HERE/phase2a-yaml"
    values_args "$HERE/phase2b-helm"
    helm_deploy "$RELEASE" "$(last_image "$APP")" "${VALUES_ARGS[@]}"
    ok "Phase 2B deployed. Test it: bash test.sh 2b" ;;
  3)
    use_cluster; delete_manifests "$HERE/phase2a-yaml"
    values_args "$HERE/phase2b-helm" "$HERE/phase3-production"
    helm_deploy "$RELEASE" "$(last_image "$APP")" "${VALUES_ARGS[@]}" \
      --set "networkPolicy.allowCidrs[0]=$(vpc_cidr)" --atomic
    ok "Phase 3 deployed. Test it: bash test.sh 3" ;;
  *) usage_phase ;;
esac
