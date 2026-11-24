#!/usr/bin/env bash
# Chapter 17 cloud track: RAG on EKS.  Usage: deploy.sh <build|2a|2b|3>
# The book's code uses Anthropic Claude, so ANTHROPIC_API_KEY is needed.
# Note: the image is ~1.5 GB (PyTorch); the first build and push take a while.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../chapter-10-kubernetes/scripts/lib.sh"
APP=rag-api; RELEASE=rag-api

case "${1:-}" in
  build) use_cluster; build_push "$APP" "$HERE/.." ;;
  2a)
    use_cluster; helm_uninstall "$RELEASE"; create_llm_secret_from_env
    apply_manifests "$HERE/phase2a-yaml" "$(last_image "$APP")"
    kubectl -n "$NAMESPACE" rollout restart deployment/rag-api-p1 >/dev/null
    kubectl -n "$NAMESPACE" rollout status deployment/rag-api-p1 --timeout=10m
    ok "Phase 2A deployed. Test it: bash test.sh 2a" ;;
  2b)
    use_cluster; delete_manifests "$HERE/phase2a-yaml"; create_llm_secret_from_env
    values_args "$HERE/phase2b-helm"
    helm_deploy "$RELEASE" "$(last_image "$APP")" "${VALUES_ARGS[@]}" \
      --set-string "podAnnotations.zero2ai/secret-refresh=$(date +%s)"
    ok "Phase 2B deployed. Test it: bash test.sh 2b" ;;
  3)
    use_cluster; delete_manifests "$HERE/phase2a-yaml"
    aws secretsmanager get-secret-value --region "$AWS_REGION" --secret-id "$PROJECT/$ENV/llm-api-keys" \
      --query SecretString --output text 2>/dev/null | grep -q ANTHROPIC_API_KEY \
      || die "ANTHROPIC_API_KEY is not in Secrets Manager yet: bash ../../chapter-10-kubernetes/scripts/put-llm-secret.sh $ENV"
    values_args "$HERE/phase2b-helm" "$HERE/phase3-production"
    helm_deploy "$RELEASE" "$(last_image "$APP")" "${VALUES_ARGS[@]}" \
      --set "externalSecret.remoteKey=$PROJECT/$ENV/llm-api-keys" \
      --set "externalSecret.region=$AWS_REGION" \
      --set "networkPolicy.allowCidrs[0]=$(vpc_cidr)" --atomic
    ok "Phase 3 deployed. Test it: bash test.sh 3" ;;
  *) usage_phase ;;
esac
