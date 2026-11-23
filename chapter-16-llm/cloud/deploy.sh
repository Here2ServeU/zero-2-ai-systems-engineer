#!/usr/bin/env bash
# Chapter 16 cloud track: the chat API on EKS.  Usage: deploy.sh <build|1|2|3>
# Pick your robot company:  LLM_PROVIDER=anthropic|openai|gemini (default anthropic)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../chapter-10-kubernetes/scripts/lib.sh"
APP=llm-api; RELEASE=llm-api

LLM_PROVIDER="${LLM_PROVIDER:-anthropic}"
case "$LLM_PROVIDER" in
  anthropic) SCRIPT=llm_api.py;        KEY=ANTHROPIC_API_KEY ;;
  openai)    SCRIPT=llm_api_openai.py; KEY=OPENAI_API_KEY ;;
  gemini)    SCRIPT=llm_api_gemini.py; KEY=GEMINI_API_KEY ;;
  *) die "LLM_PROVIDER must be anthropic, openai or gemini" ;;
esac

case "${1:-}" in
  build) use_cluster; build_push "$APP" "$HERE/.." ;;
  1)
    use_cluster; helm_uninstall "$RELEASE"
    create_llm_secret_from_env
    say "Phase 1 with $LLM_PROVIDER ($SCRIPT)"
    for f in "$HERE"/phase1/*.yaml; do
      sed -e "s#__IMAGE__#$(last_image "$APP")#g" -e "s#__SCRIPT__#$SCRIPT#g" "$f" | kubectl apply -n "$NAMESPACE" -f -
    done
    kubectl -n "$NAMESPACE" rollout restart deployment/llm-api-p1 >/dev/null   # pick up a changed key
    kubectl -n "$NAMESPACE" rollout status deployment/llm-api-p1 --timeout=5m
    ok "Phase 1 deployed. Test it: bash test.sh 1" ;;
  2)
    use_cluster; delete_manifests "$HERE/phase1"
    create_llm_secret_from_env
    values_args "$HERE/phase2"
    helm_deploy "$RELEASE" "$(last_image "$APP")" "${VALUES_ARGS[@]}" \
      --set "command={python,$SCRIPT}" \
      --set-string "podAnnotations.zero2ai/secret-refresh=$(date +%s)"
    ok "Phase 2 deployed ($LLM_PROVIDER). Test it: bash test.sh 2" ;;
  3)
    use_cluster; delete_manifests "$HERE/phase1"
    aws secretsmanager get-secret-value --region "$AWS_REGION" --secret-id "$PROJECT/$ENV/llm-api-keys" \
      --query SecretString --output text 2>/dev/null | grep -q "$KEY" \
      || die "$KEY is not in Secrets Manager yet. Run: export $KEY=...; bash ../../chapter-10-kubernetes/scripts/put-llm-secret.sh $ENV"
    values_args "$HERE/phase2" "$HERE/phase3"
    helm_deploy "$RELEASE" "$(last_image "$APP")" "${VALUES_ARGS[@]}" \
      --set "command={python,$SCRIPT}" \
      --set "externalSecret.remoteKey=$PROJECT/$ENV/llm-api-keys" \
      --set "externalSecret.keys={$KEY}" \
      --set "externalSecret.region=$AWS_REGION" \
      --set "networkPolicy.allowCidrs[0]=$(vpc_cidr)" --atomic
    kubectl -n "$NAMESPACE" delete secret llm-api-keys --ignore-not-found >/dev/null   # Phase 2's copy is no longer needed
    ok "Phase 3 deployed ($LLM_PROVIDER, keys from Secrets Manager). Test it: bash test.sh 3" ;;
  *) usage_phase ;;
esac
