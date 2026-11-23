#!/usr/bin/env bash
# Chapter 10 cloud track: deploy the fraud API to EKS.
#   bash deploy.sh build   # build chapter-06-docker and push to ECR
#   bash deploy.sh 1       # Phase 1: same YAML as your laptop
#   bash deploy.sh 2       # Phase 2: Helm chart
#   bash deploy.sh 3       # Phase 3: production values
# Choose the environment with ENV=dev|qa|prod (default dev).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../chapter-10-kubernetes/scripts/lib.sh"

APP=fraud-api            # ECR repository + Helm release name
RELEASE=fraud-api

case "${1:-}" in
  build)
    use_cluster
    build_push "$APP" "$REPO_ROOT/chapter-06-docker"
    ;;
  1)
    use_cluster
    helm_uninstall "$RELEASE"                       # in case Phase 2/3 was running
    apply_manifests "$HERE/phase1" "$(last_image "$APP")"
    kubectl -n "$NAMESPACE" rollout status deployment/zero2ai-fraud-api --timeout=5m
    kubectl -n "$NAMESPACE" get pods,svc -l app=zero2ai-fraud-api
    ok "Phase 1 deployed. Test it: bash test.sh 1"
    ;;
  2)
    use_cluster
    delete_manifests "$HERE/phase1"                 # removes Phase 1's load balancer too
    values_args "$HERE/phase2"
    helm_deploy "$RELEASE" "$(last_image "$APP")" "${VALUES_ARGS[@]}"
    ok "Phase 2 deployed. Test it: bash test.sh 2"
    ;;
  3)
    use_cluster
    delete_manifests "$HERE/phase1"
    values_args "$HERE/phase2" "$HERE/phase3"
    helm_deploy "$RELEASE" "$(last_image "$APP")" "${VALUES_ARGS[@]}" \
      --set "networkPolicy.allowCidrs[0]=$(vpc_cidr)" \
      --atomic                                       # failed upgrade = automatic rollback
    ok "Phase 3 deployed. Test it: bash test.sh 3"
    ;;
  *) usage_phase ;;
esac
