#!/usr/bin/env bash
# Chapter 13 cloud track tests.  Usage: test.sh <1|2|3>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../chapter-10-kubernetes/scripts/lib.sh"
RELEASE=retrain

run_now() {
  local name; name="retrain-now-$(date +%s)"
  say "Running the retraining job right now ($name) instead of waiting for Monday"
  kubectl -n "$NAMESPACE" create job "$name" --from=cronjob/"$RELEASE" >/dev/null
  kubectl -n "$NAMESPACE" wait --for=condition=complete "job/$name" --timeout=10m \
    || { kubectl -n "$NAMESPACE" logs "job/$name"; die "Retraining failed or the model was rejected"; }
  kubectl -n "$NAMESPACE" logs "job/$name"
}

registered_models() {
  http_get "http://localhost:5000/health"
  echo "Registered models in MLflow:"
  curl -fsS "http://localhost:5000/api/2.0/mlflow/registered-models/search" \
    | grep -o '"name":"[^"]*"\|"version":"[^"]*"' | sort -u
}

case "${1:-}" in
  1)
    use_cluster
    kubectl -n "$NAMESPACE" wait --for=condition=complete job/retrain-demo --timeout=10m \
      || { kubectl -n "$NAMESPACE" logs job/retrain-demo; die "Job failed"; }
    kubectl -n "$NAMESPACE" logs job/retrain-demo ;;
  2|3)
    use_cluster
    helm test mlflow -n "$NAMESPACE" --logs
    run_now
    with_port_forward mlflow 5000 80 registered_models
    if [ "$1" = "3" ]; then
      bucket="${PROJECT}-eks-${ENV}-mlflow-$(aws_account_id)"
      say "Model files in S3 (s3://$bucket/artifacts)"
      aws s3 ls "s3://$bucket/artifacts/" --recursive | tail -5
    fi
    echo "See it yourself: kubectl -n $NAMESPACE port-forward svc/mlflow 5000:80   ->  http://localhost:5000" ;;
  *) echo "Usage: $0 <1|2|3>"; exit 1 ;;
esac
ok "Phase ${1} checks passed"
