#!/usr/bin/env bash
# validate-chart.sh: render the shared chart with EVERY chapter's Phase 2 and
# Phase 3 values, offline, and check the YAML. No cluster or AWS needed.
#   bash platform/scripts/validate-chart.sh
# Uses kubeconform for schema checks if it's installed (CI installs it).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHART="$ROOT/platform/helm/zero2ai-app"
IMG=(--set image.repository=123456789012.dkr.ecr.us-east-1.amazonaws.com/zero2ai-dev/demo --set image.tag=v1)
NP=(--set "networkPolicy.allowCidrs[0]=10.40.0.0/16")
fail=0

render() {
  local name="$1"; shift
  local out
  if ! out=$(helm template "$name" "$CHART" -n zero2ai "${IMG[@]}" "$@" 2>&1); then
    echo "✘ $name $*"; echo "$out"; fail=1; return
  fi
  if command -v kubeconform >/dev/null 2>&1; then
    if ! echo "$out" | kubeconform -strict -summary -ignore-missing-schemas -kubernetes-version 1.32.0 >/dev/null; then
      echo "✘ schema: $name $*"; echo "$out" | kubeconform -strict -ignore-missing-schemas -kubernetes-version 1.32.0; fail=1; return
    fi
  fi
  echo "✔ $name ($(echo "$out" | grep -c '^kind:') objects)"
}

helm lint "$CHART" "${IMG[@]}"

c=$ROOT/chapter-10-kubernetes/cloud
render fraud-api -f $c/phase2/values.yaml
render fraud-api -f $c/phase2/values.yaml -f $c/phase3/values.yaml -f $c/phase3/values-prod.yaml "${NP[@]}"
c=$ROOT/chapter-11-monitoring/cloud
render metrics-api -f $c/phase2/values.yaml
render metrics-api -f $c/phase2/values.yaml -f $c/phase3/values.yaml "${NP[@]}"
c=$ROOT/chapter-12-aiops/cloud
render aiops -f $c/phase2/values.yaml
render aiops -f $c/phase2/values.yaml -f $c/phase3/values.yaml
c=$ROOT/chapter-13-retraining/cloud
render mlflow -f $c/phase2/mlflow-values.yaml
render mlflow -f $c/phase2/mlflow-values.yaml -f $c/phase3/mlflow-values.yaml
render retrain -f $c/phase2/values.yaml
render retrain -f $c/phase2/values.yaml -f $c/phase3/values.yaml
c=$ROOT/chapter-14-deployment/cloud
render fraud-blue -f $c/phase2/blue.yaml
render fraud-green -f $c/phase2/green.yaml -f $c/phase3/app.yaml "${NP[@]}"
render fraud-router -f $c/phase2/router.yaml
render fraud-router -f $c/phase2/router.yaml -f $c/phase3/router.yaml
c=$ROOT/chapter-15-dashboards/cloud
render monitored-api -f $c/phase2/values.yaml --set-file grafanaDashboard.json=$c/dashboard.json
render monitored-api -f $c/phase2/values.yaml -f $c/phase3/values.yaml --set-file grafanaDashboard.json=$c/dashboard.json "${NP[@]}"
c=$ROOT/chapter-16-llm/cloud
render llm-api -f $c/phase2/values.yaml
render llm-api -f $c/phase2/values.yaml -f $c/phase3/values.yaml "${NP[@]}"
c=$ROOT/chapter-17-rag/cloud
render rag-api -f $c/phase2/values.yaml
render rag-api -f $c/phase2/values.yaml -f $c/phase3/values.yaml "${NP[@]}"
c=$ROOT/chapter-18-prodllm/cloud
render prod-llm -f $c/phase2/values.yaml
render prod-llm -f $c/phase2/values.yaml -f $c/phase3/values.yaml "${NP[@]}"

[ $fail -eq 0 ] && echo "All chart renders are valid." || { echo "Some renders failed."; exit 1; }
