#!/usr/bin/env bash
# Chapter 15 cloud track: dashboards on EKS.  Usage: deploy.sh <build|1|2|3>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../chapter-10-kubernetes/scripts/lib.sh"
APP=monitored-api; RELEASE=monitored-api

case "${1:-}" in
  build) use_cluster; build_push "$APP" "$HERE/.." ;;
  1)
    use_cluster; helm_uninstall "$RELEASE"
    apply_manifests "$HERE/phase1" "$(last_image "$APP")"
    kubectl -n "$NAMESPACE" rollout status deployment/monitored-api-p1 --timeout=5m
    ok "Phase 1 deployed. Test it: bash test.sh 1" ;;
  2|3)
    use_cluster; delete_manifests "$HERE/phase1"
    cd "$HERE"   # relative path below: works the same in Git Bash on Windows
    dirs=("$HERE/phase2"); extra=(--set-file "grafanaDashboard.json=dashboard.json")
    if [ "$1" = "3" ]; then dirs+=("$HERE/phase3"); extra+=(--set "networkPolicy.allowCidrs[0]=$(vpc_cidr)" --atomic); fi
    values_args "${dirs[@]}"
    helm_deploy "$RELEASE" "$(last_image "$APP")" "${VALUES_ARGS[@]}" "${extra[@]}"
    ok "Phase $1 deployed. Test it: bash test.sh $1" ;;
  *) usage_phase ;;
esac
