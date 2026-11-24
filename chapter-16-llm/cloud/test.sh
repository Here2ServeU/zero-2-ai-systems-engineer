#!/usr/bin/env bash
# Chapter 16 cloud track tests (each question costs a fraction of a cent).  Usage: test.sh <2a|2b|3>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../chapter-10-kubernetes/scripts/lib.sh"
Q='{"question":"In one sentence: what is a chargeback?"}'
ask() { http_get "$1/health"; http_post "$1/chat" "$Q"; }

case "${1:-}" in
  2a) use_cluster; with_port_forward llm-api-p1 8080 80 ask http://localhost:8080 ;;
  2b) use_cluster; helm test llm-api -n "$NAMESPACE" --logs >/dev/null && ok "helm test llm-api"
     with_port_forward llm-api 8080 80 ask http://localhost:8080 ;;
  3) use_cluster
     say "External Secrets status (Ready=True means the key was copied from AWS)"
     kubectl -n "$NAMESPACE" get externalsecret llm-api
     helm test llm-api -n "$NAMESPACE" --logs >/dev/null && ok "helm test llm-api"
     host=$(wait_for_ingress llm-api /health); say "Public: http://$host"
     ask "http://$host" ;;
  *) echo "Usage: $0 <2a|2b|3>"; exit 1 ;;
esac
ok "Phase $(echo "$1" | tr a-z A-Z) checks passed"
