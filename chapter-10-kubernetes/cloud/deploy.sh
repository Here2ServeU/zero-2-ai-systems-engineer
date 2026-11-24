#!/usr/bin/env bash
# Chapter 10 cloud track: deploy the fraud API to EKS.
#   bash deploy.sh build   # build ../fraud-api and push to ECR
#   bash deploy.sh 2a       # Phase 2A: same YAML as your laptop
#   bash deploy.sh 2b       # Phase 2B: Helm chart
#   bash deploy.sh 3       # Phase 3: production values
# Choose the environment with ENV=dev|qa|prod (default dev).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../scripts/lib.sh"

APP=fraud-api            # ECR repository + Helm release name
RELEASE=fraud-api

case "${1:-}" in
  build)
    use_cluster
    build_push "$APP" "$HERE/../fraud-api"
    ;;
  2a)
    use_cluster
    helm_uninstall "$RELEASE"                       # in case Phase 2B/3 was running
    apply_manifests "$HERE/phase2a-yaml" "$(last_image "$APP")"
    kubectl -n "$NAMESPACE" rollout status deployment/zero2ai-fraud-api --timeout=5m
    kubectl -n "$NAMESPACE" get pods,svc -l app=zero2ai-fraud-api
    ok "Phase 2A deployed. Test it: bash test.sh 2a"
    ;;
  2b)
    use_cluster
    delete_manifests "$HERE/phase2a-yaml"                 # removes Phase 2A's load balancer too
    values_args "$HERE/phase2b-helm"
    helm_deploy "$RELEASE" "$(last_image "$APP")" "${VALUES_ARGS[@]}"
    ok "Phase 2B deployed. Test it: bash test.sh 2b"
    ;;
  3)
    use_cluster
    delete_manifests "$HERE/phase2a-yaml"
    values_args "$HERE/phase2b-helm" "$HERE/phase3-production"
    helm_deploy "$RELEASE" "$(last_image "$APP")" "${VALUES_ARGS[@]}" \
      --set "networkPolicy.allowCidrs[0]=$(vpc_cidr)" \
      --atomic                                       # failed upgrade = automatic rollback
    ok "Phase 3 deployed. Test it: bash test.sh 3"
    ;;
  *) usage_phase ;;
esac
