#!/usr/bin/env bash
# Chapter 13 cloud track: drift + retraining + MLflow on EKS.  Usage: deploy.sh <build|1|2|3>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../platform/scripts/lib.sh"
APP=retrain; RELEASE=retrain

case "${1:-}" in
  build)
    use_cluster
    build_push retrain "$HERE/.."
    build_push mlflow "$HERE/../mlflow-server" ;;
  1)
    use_cluster; helm_uninstall "$RELEASE"
    kubectl -n "$NAMESPACE" delete job retrain-demo --ignore-not-found
    apply_manifests "$HERE/phase1" "$(last_image "$APP")"
    ok "Phase 1 job started. See its report: bash test.sh 1" ;;
  2)
    use_cluster; delete_manifests "$HERE/phase1"
    helm_deploy mlflow "$(last_image mlflow)" -f "$HERE/phase2/mlflow-values.yaml"
    values_args "$HERE/phase2"
    helm_deploy "$RELEASE" "$(last_image "$APP")" "${VALUES_ARGS[@]}"
    ok "Phase 2 deployed. Test it: bash test.sh 2" ;;
  3)
    use_cluster; delete_manifests "$HERE/phase1"
    bucket="${PROJECT}-eks-${ENV}-mlflow-$(aws_account_id)"
    say "MLflow artifacts bucket: s3://$bucket"
    mkdir -p "$STATE_DIR"
    sed "s#s3://BUCKET/#s3://$bucket/#" "$HERE/phase3/mlflow-values.yaml" > "$STATE_DIR/mlflow-values.yaml"
    helm_deploy mlflow "$(last_image mlflow)" \
      -f "$HERE/phase2/mlflow-values.yaml" -f "$STATE_DIR/mlflow-values.yaml" \
      --set env.AWS_DEFAULT_REGION="$AWS_REGION" --atomic
    values_args "$HERE/phase2" "$HERE/phase3"
    helm_deploy "$RELEASE" "$(last_image "$APP")" "${VALUES_ARGS[@]}" --atomic
    ok "Phase 3 deployed. Test it: bash test.sh 3" ;;
  *) usage_phase ;;
esac
