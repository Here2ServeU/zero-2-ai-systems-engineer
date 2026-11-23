#!/usr/bin/env bash
# Chapter 17 cloud track tests (the final step costs a fraction of a cent).  Usage: test.sh <1|2|3>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../chapter-10-kubernetes/scripts/lib.sh"
Q='{"question":"What documents are required for KYC?"}'
ask() { http_get "$1/health"; http_post "$1/ask" "$Q" | head -c 1500; echo; }

case "${1:-}" in
  1) use_cluster; with_port_forward rag-api-p1 8080 80 ask http://localhost:8080 ;;
  2) use_cluster
     say "Init container output (filing the notes)"
     kubectl -n "$NAMESPACE" logs deploy/rag-api -c init | tail -3
     helm test rag-api -n "$NAMESPACE" --logs >/dev/null && ok "helm test rag-api"
     with_port_forward rag-api 8080 80 ask http://localhost:8080 ;;
  3) use_cluster
     kubectl -n "$NAMESPACE" get externalsecret rag-api
     helm test rag-api -n "$NAMESPACE" --logs >/dev/null && ok "helm test rag-api"
     host=$(wait_for_ingress rag-api /health); say "Public: http://$host"
     ask "http://$host" ;;
  *) echo "Usage: $0 <1|2|3>"; exit 1 ;;
esac
ok "Phase ${1} checks passed"
