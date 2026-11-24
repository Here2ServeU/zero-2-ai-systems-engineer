#!/usr/bin/env bash
# Chapter 13 cloud track: drift + retraining + MLflow on EKS.  Usage: deploy.sh <build|2a|2b|3>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../chapter-10-kubernetes/scripts/lib.sh"
APP=retrain; RELEASE=retrain

case "${1:-}" in
  build)
    use_cluster
    build_push retrain "$HERE/.."
    build_push mlflow "$HERE/../mlflow-server" ;;
  2a)
    use_cluster; helm_uninstall "$RELEASE"
    kubectl -n "$NAMESPACE" delete job retrain-demo --ignore-not-found
    apply_manifests "$HERE/phase2a-yaml" "$(last_image "$APP")"
    ok "Phase 2A job started. See its report: bash test.sh 2a" ;;
  2b)
    use_cluster; delete_manifests "$HERE/phase2a-yaml"
    helm_deploy mlflow "$(last_image mlflow)" -f "$HERE/phase2b-helm/mlflow-values.yaml"
    values_args "$HERE/phase2b-helm"
    helm_deploy "$RELEASE" "$(last_image "$APP")" "${VALUES_ARGS[@]}"
    ok "Phase 2B deployed. Test it: bash test.sh 2b" ;;
  3)
    use_cluster; delete_manifests "$HERE/phase2a-yaml"
    bucket="${PROJECT}-eks-${ENV}-mlflow-$(aws_account_id)"
    say "MLflow artifacts bucket: s3://$bucket"
    mkdir -p "$STATE_DIR"
    sed "s#s3://BUCKET/#s3://$bucket/#" "$HERE/phase3-production/mlflow-values.yaml" > "$STATE_DIR/mlflow-values.yaml"
    helm_deploy mlflow "$(last_image mlflow)" \
      -f "$HERE/phase2b-helm/mlflow-values.yaml" -f "$STATE_DIR/mlflow-values.yaml" \
      --set env.AWS_DEFAULT_REGION="$AWS_REGION" --atomic
    values_args "$HERE/phase2b-helm" "$HERE/phase3-production"
    helm_deploy "$RELEASE" "$(last_image "$APP")" "${VALUES_ARGS[@]}" --atomic
    ok "Phase 3 deployed. Test it: bash test.sh 3" ;;
  *) usage_phase ;;
esac
