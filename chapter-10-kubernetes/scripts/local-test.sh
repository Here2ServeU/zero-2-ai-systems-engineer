#!/usr/bin/env bash
# local-test.sh: reach the app through the Service and call /health, /info, /predict.
#
#   bash scripts/local-test.sh         (from the chapter-10-kubernetes folder)
#
# Why port-forward? `curl localhost:30080` only works on Docker Desktop's
# single-node cluster. On minikube, kind and Docker Desktop's multi-node mode
# the NodePort lives INSIDE a container, so localhost:30080 on your laptop is a
# closed door. `kubectl port-forward` opens a tunnel that works on every
# cluster, local or cloud.
set -euo pipefail

APP=zero2ai-fraud-api
SVC=zero2ai-fraud-svc

ok()   { printf '\033[1;32m[OK] %s\033[0m\n' "$*"; }
oops() { printf '\033[1;31m[ERROR] %s\033[0m\n' "$*" >&2; }

# Is the app deployed and Ready?
if ! kubectl get deployment "$APP" >/dev/null 2>&1 || ! kubectl get service "$SVC" >/dev/null 2>&1; then
  oops "The app isn't deployed on '$(kubectl config current-context 2>/dev/null)'. Run first:  bash scripts/local-up.sh"
  exit 1
fi
if ! kubectl rollout status deployment "$APP" --timeout=60s >/dev/null 2>&1; then
  oops "The app's copies aren't Ready. Look at:  kubectl get pods   and   kubectl logs deployment/$APP"
  exit 1
fi

# Pick a free door on the laptop: 8080, or the next free one if 8080 is busy.
port_busy() { (echo >"/dev/tcp/127.0.0.1/$1") >/dev/null 2>&1; }
LOCAL_PORT="${LOCAL_PORT:-}"
if [ -z "$LOCAL_PORT" ]; then
  for p in 8080 8081 8082 8083 8084 8085 8086 8087 8088 8089; do
    if ! port_busy "$p"; then LOCAL_PORT=$p; break; fi
  done
  [ -n "$LOCAL_PORT" ] || { oops "Ports 8080-8089 are all busy. Pick one: LOCAL_PORT=9000 bash scripts/local-test.sh"; exit 1; }
fi

PF_LOG="$(mktemp)"
echo "==> Opening a tunnel: localhost:$LOCAL_PORT -> service/$SVC:80"
kubectl port-forward "service/$SVC" "$LOCAL_PORT:80" >"$PF_LOG" 2>&1 &
PF_PID=$!
disown "$PF_PID" 2>/dev/null || true   # no "Terminated" message when we close it at the end
trap 'kill $PF_PID 2>/dev/null || true; rm -f "$PF_LOG"' EXIT

BASE="http://localhost:$LOCAL_PORT"
for _ in $(seq 1 40); do
  curl -s "$BASE/health" >/dev/null 2>&1 && break
  if ! kill -0 "$PF_PID" 2>/dev/null; then
    oops "The tunnel closed. kubectl said:"; cat "$PF_LOG" >&2; exit 1
  fi
  sleep 0.5
done

call() {   # call <label> <curl args...>
  local label="$1"; shift
  echo "==> $label"
  if ! curl -sSf "$@"; then
    echo; oops "$label failed. Look at the app's logs:  kubectl logs deployment/$APP"; exit 1
  fi
  echo
}
call "GET /health"   "$BASE/health"
call "GET /info"     "$BASE/info"
call "POST /predict" -X POST "$BASE/predict" -H "Content-Type: application/json" \
  -d '{"amount":950.0,"hour":3,"is_weekend":0,"amount_vs_avg":2.8,"is_large_txn":1,"is_late_night":1,"merch_txn_ct":4}'

echo
ok "All checks passed."
