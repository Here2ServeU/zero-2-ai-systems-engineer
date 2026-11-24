#!/usr/bin/env bash
# validate-chart.sh: render the shared chart with EVERY chapter's Phase 2B and
# Phase 3 values, offline, and check the YAML. No cluster or AWS needed.
#   bash chapter-10-kubernetes/scripts/validate-chart.sh
# Uses kubeconform for schema checks if it's installed (CI installs it).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHART="$ROOT/chapter-10-kubernetes/helm/zero2ai-app"
IMG=(--set image.repository=123456789012.dkr.ecr.us-east-1.amazonaws.com/zero2ai-dev/demo --set image.tag=v1)
NP=(--set "networkPolicy.allowCidrs[0]=10.40.0.0/16")
fail=0

render() {
  local name="$1"; shift
  local out
  if ! out=$(helm template "$name" "$CHART" -n zero2ai "${IMG[@]}" "$@" 2>&1); then
    echo "[ERROR] $name $*"; echo "$out"; fail=1; return
  fi
  if command -v kubeconform >/dev/null 2>&1; then
    if ! echo "$out" | kubeconform -strict -summary -ignore-missing-schemas -kubernetes-version 1.32.0 >/dev/null; then
      echo "[ERROR] schema: $name $*"; echo "$out" | kubeconform -strict -ignore-missing-schemas -kubernetes-version 1.32.0; fail=1; return
    fi
  fi
  echo "[OK] $name ($(echo "$out" | grep -c '^kind:') objects)"
}

helm lint "$CHART" "${IMG[@]}"

c=$ROOT/chapter-10-kubernetes/cloud
render fraud-api -f $c/phase2b-helm/values.yaml
render fraud-api -f $c/phase2b-helm/values.yaml -f $c/phase3-production/values.yaml -f $c/phase3-production/values-prod.yaml "${NP[@]}"
c=$ROOT/chapter-11-monitoring/cloud
render metrics-api -f $c/phase2b-helm/values.yaml
render metrics-api -f $c/phase2b-helm/values.yaml -f $c/phase3-production/values.yaml "${NP[@]}"
c=$ROOT/chapter-12-aiops/cloud
render aiops -f $c/phase2b-helm/values.yaml
render aiops -f $c/phase2b-helm/values.yaml -f $c/phase3-production/values.yaml
c=$ROOT/chapter-13-retraining/cloud
render mlflow -f $c/phase2b-helm/mlflow-values.yaml
render mlflow -f $c/phase2b-helm/mlflow-values.yaml -f $c/phase3-production/mlflow-values.yaml
render retrain -f $c/phase2b-helm/values.yaml
render retrain -f $c/phase2b-helm/values.yaml -f $c/phase3-production/values.yaml
c=$ROOT/chapter-14-deployment/cloud
render fraud-blue -f $c/phase2b-helm/blue.yaml
render fraud-green -f $c/phase2b-helm/green.yaml -f $c/phase3-production/app.yaml "${NP[@]}"
render fraud-router -f $c/phase2b-helm/router.yaml
render fraud-router -f $c/phase2b-helm/router.yaml -f $c/phase3-production/router.yaml
c=$ROOT/chapter-15-dashboards/cloud
render monitored-api -f $c/phase2b-helm/values.yaml --set-file grafanaDashboard.json=$c/dashboard.json
render monitored-api -f $c/phase2b-helm/values.yaml -f $c/phase3-production/values.yaml --set-file grafanaDashboard.json=$c/dashboard.json "${NP[@]}"
c=$ROOT/chapter-16-llm/cloud
render llm-api -f $c/phase2b-helm/values.yaml
render llm-api -f $c/phase2b-helm/values.yaml -f $c/phase3-production/values.yaml "${NP[@]}"
c=$ROOT/chapter-17-rag/cloud
render rag-api -f $c/phase2b-helm/values.yaml
render rag-api -f $c/phase2b-helm/values.yaml -f $c/phase3-production/values.yaml "${NP[@]}"
c=$ROOT/chapter-18-prodllm/cloud
render prod-llm -f $c/phase2b-helm/values.yaml
render prod-llm -f $c/phase2b-helm/values.yaml -f $c/phase3-production/values.yaml "${NP[@]}"

# Phase 3 apps must join the shared platform ALB on their own port.
c=$ROOT/chapter-10-kubernetes/cloud
out=$(helm template fraud-api "$CHART" "${IMG[@]}" -f "$c/phase2b-helm/values.yaml" -f "$c/phase3-production/values.yaml" -s templates/ingress.yaml)
if echo "$out" | grep -q 'group.name: zero2ai' && echo "$out" | grep -q '"HTTP": 8010'; then
  echo "[OK] fraud-api joins ALB group zero2ai on :8010"
else
  echo "[ERROR] fraud-api ingress is not on the shared ALB :8010"; fail=1
fi

[ $fail -eq 0 ] && echo "All chart renders are valid." || { echo "Some renders failed."; exit 1; }
