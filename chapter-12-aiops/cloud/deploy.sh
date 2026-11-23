#!/usr/bin/env bash
# Chapter 12 cloud track: the AIOps guard on EKS.  Usage: deploy.sh <build|1|2|3>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../platform/scripts/lib.sh"
APP=aiops; RELEASE=aiops
CH11="$REPO_ROOT/chapter-11-monitoring/cloud"

# The guard needs something to watch: Chapter 11's metrics-api (Phase 2 style,
# no autoscaler, so the guard's scaling is easy to see).
ensure_patient() {
  if ! kubectl -n "$NAMESPACE" get deployment metrics-api >/dev/null 2>&1; then
    warn "metrics-api (Chapter 11) isn't running; deploying it as the app to watch"
    [ -f "$STATE_DIR/metrics-api.image" ] || bash "$CH11/deploy.sh" build
    bash "$CH11/deploy.sh" 2
  fi
  ok "Watching deployment/metrics-api"
}

case "${1:-}" in
  build) use_cluster; build_push "$APP" "$HERE/.." ;;
  1)
    use_cluster; helm_uninstall "$RELEASE"
    kubectl -n "$NAMESPACE" delete job aiops-demo --ignore-not-found
    apply_manifests "$HERE/phase1" "$(last_image "$APP")"
    ok "Phase 1 job started. See its report: bash test.sh 1" ;;
  2)
    use_cluster; delete_manifests "$HERE/phase1"; ensure_patient
    values_args "$HERE/phase2"
    helm_deploy "$RELEASE" "$(last_image "$APP")" "${VALUES_ARGS[@]}"
    ok "Phase 2 deployed (report-only, every 5 min). Test it: bash test.sh 2" ;;
  3)
    use_cluster; delete_manifests "$HERE/phase1"; ensure_patient
    values_args "$HERE/phase2" "$HERE/phase3"
    helm_deploy "$RELEASE" "$(last_image "$APP")" "${VALUES_ARGS[@]}" --atomic
    ok "Phase 3 deployed (may scale metrics-api, every 2 min). Test it: bash test.sh 3" ;;
  *) usage_phase ;;
esac
