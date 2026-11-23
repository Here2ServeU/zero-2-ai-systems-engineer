#!/usr/bin/env bash
# put-llm-secret.sh <env>: copy the LLM API keys from YOUR shell's environment
# into AWS Secrets Manager (secret <project>/<env>/llm-api-keys, created by
# Terraform). Phase 3 of Chapters 16-18 reads them from there.
#
#   export ANTHROPIC_API_KEY=sk-ant-...      # any of the three
#   export GEMINI_API_KEY=...
#   bash chapter-10-kubernetes/scripts/put-llm-secret.sh dev
set -euo pipefail
ENV="${1:-${ENV:-dev}}"; export ENV
source "$(dirname "$0")/lib.sh"
require_tools aws

json="{"; sep=""
for k in ANTHROPIC_API_KEY OPENAI_API_KEY GEMINI_API_KEY; do
  if [ -n "${!k:-}" ]; then json="$json$sep\"$k\":\"${!k}\""; sep=","; fi
done
json="$json}"
[ "$json" != "{}" ] || die "No keys found. export ANTHROPIC_API_KEY=... (or OPENAI_API_KEY / GEMINI_API_KEY) first."

# Write to a private temp file so the key never appears in the process list.
tmp=$(mktemp); chmod 600 "$tmp"; trap 'rm -f "$tmp"' EXIT
printf '%s' "$json" > "$tmp"
aws secretsmanager put-secret-value --region "$AWS_REGION" \
  --secret-id "${PROJECT}/${ENV}/llm-api-keys" \
  --secret-string "file://$tmp" >/dev/null
ok "Stored keys in ${PROJECT}/${ENV}/llm-api-keys: $(printf '%s' "$json" | grep -o '"[A-Z_]*":' | tr -d '":' | tr '\n' ' ')"
