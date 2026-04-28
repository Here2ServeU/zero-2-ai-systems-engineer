#!/usr/bin/env bash
# End-to-end demo runbook for the Nawex AI Reliability Platform.
# Walks a reviewer through every layer in under 10 minutes.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
cd "$SRC"

echo "==> 1. Train fraud + anomaly models, log to MLflow"
python train_models.py

echo "==> 2. Ingest knowledge base into ChromaDB"
python ingest_kb.py

echo "==> 3. Run AIOps anomaly detection on synthetic platform telemetry"
python aiops_anomaly.py

echo "==> 4. Run drift check (expect drift on the shifted sample)"
python drift_check.py || echo "    (non-zero exit is expected — drift detected)"

echo "==> 5. Promote fraud model v1 through staging -> canary -> production"
python promote_model.py --model fraud --stage staging --version v1
python promote_model.py --model fraud --stage canary --version v1
python promote_model.py --model fraud --stage production --version v1

echo "==> 6. Start the platform (background)"
python serve.py &
SERVE_PID=$!
trap 'kill $SERVE_PID 2>/dev/null || true' EXIT
sleep 4

echo "==> 7. Smoke-test endpoints"
curl -sf http://localhost:8080/health
echo
curl -sf -X POST http://localhost:8080/predict/fraud \
  -H 'Content-Type: application/json' \
  -d '{"amount": 1820.0, "hour": 2, "merchant_risk": 0.95, "country_risk": 0.85}'
echo
curl -sf -X POST http://localhost:8080/predict/anomaly \
  -H 'Content-Type: application/json' \
  -d '{"heart_rate": 130, "systolic_bp": 165, "oxygen_sat": 89, "temperature": 38.9}'
echo

echo "==> 8. Run RAG eval set (requires ANTHROPIC_API_KEY)"
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  python eval.py
else
  echo "    Skipped: ANTHROPIC_API_KEY not set"
fi

echo "==> Demo complete."
