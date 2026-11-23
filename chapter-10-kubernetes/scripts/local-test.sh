#!/usr/bin/env bash
# local-test.sh: reach the app through the Service and call /health, /info, /predict.
#
# Why port-forward? `curl localhost:30080` only works on Docker Desktop.
# On minikube (Docker driver) and kind, the NodePort lives INSIDE a container,
# so localhost:30080 on your laptop is a closed door ("Could not connect").
# `kubectl port-forward` opens a tunnel that works on every cluster, local or cloud.
set -euo pipefail

LOCAL_PORT="${LOCAL_PORT:-8080}"
SVC="service/zero2ai-fraud-svc"

echo "==> Opening a tunnel: localhost:$LOCAL_PORT -> $SVC:80"
kubectl port-forward "$SVC" "$LOCAL_PORT:80" >/tmp/zero2ai-pf.log 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT

# Wait for the tunnel to open (up to ~15 seconds).
for _ in $(seq 1 30); do
  if curl -s "http://localhost:$LOCAL_PORT/health" >/dev/null 2>&1; then break; fi
  sleep 0.5
done

BASE="http://localhost:$LOCAL_PORT"
echo "==> GET /health";  curl -sf "$BASE/health"; echo
echo "==> GET /info";    curl -sf "$BASE/info"; echo
echo "==> POST /predict"
curl -sf -X POST "$BASE/predict" -H "Content-Type: application/json" \
  -d '{"amount":950.0,"hour":3,"is_weekend":0,"amount_vs_avg":2.8,"is_large_txn":1,"is_late_night":1,"merch_txn_ct":4}'
echo
echo "All checks passed."
