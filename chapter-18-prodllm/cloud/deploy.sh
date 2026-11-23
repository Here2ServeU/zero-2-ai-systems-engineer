#!/usr/bin/env bash
# Chapter 18 cloud track: the production LLM service on EKS.  Usage: deploy.sh <build|1|2|3>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../chapter-10-kubernetes/scripts/lib.sh"
APP=prod-llm; RELEASE=prod-llm

case "${1:-}" in
  build) use_cluster; build_push "$APP" "$HERE/.." ;;
  1)
    use_cluster; helm_uninstall "$RELEASE"; create_llm_secret_from_env
    apply_manifests "$HERE/phase1" "$(last_image "$APP")"
    kubectl -n "$NAMESPACE" rollout restart deployment/prod-llm-p1 >/dev/null
    kubectl -n "$NAMESPACE" rollout status deployment/prod-llm-p1 --timeout=5m
    ok "Phase 1 deployed. Test it: bash test.sh 1" ;;
  2)
    use_cluster; delete_manifests "$HERE/phase1"; create_llm_secret_from_env
    values_args "$HERE/phase2"
    helm_deploy "$RELEASE" "$(last_image "$APP")" "${VALUES_ARGS[@]}" \
      --set-string "podAnnotations.zero2ai/secret-refresh=$(date +%s)"
    ok "Phase 2 deployed. Test it: bash test.sh 2" ;;
  3)
    use_cluster; delete_manifests "$HERE/phase1"
    aws secretsmanager get-secret-value --region "$AWS_REGION" --secret-id "$PROJECT/$ENV/llm-api-keys" \
      --query SecretString --output text 2>/dev/null | grep -q ANTHROPIC_API_KEY \
      || die "ANTHROPIC_API_KEY is not in Secrets Manager yet: bash ../../chapter-10-kubernetes/scripts/put-llm-secret.sh $ENV"
    values_args "$HERE/phase2" "$HERE/phase3"
    helm_deploy "$RELEASE" "$(last_image "$APP")" "${VALUES_ARGS[@]}" \
      --set "externalSecret.remoteKey=$PROJECT/$ENV/llm-api-keys" \
      --set "externalSecret.region=$AWS_REGION" \
      --set "networkPolicy.allowCidrs[0]=$(vpc_cidr)" --atomic
    ok "Phase 3 deployed. Test it: bash test.sh 3" ;;
  *) usage_phase ;;
esac
