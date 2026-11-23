#!/usr/bin/env bash
# platform-down.sh <env>: delete EVERYTHING the cloud track created for one
# environment, in the safe order:
#   1. every Helm release and Phase 1 app in the app namespace
#      (this deletes the AWS load balancers they created; otherwise the VPC
#       can't be deleted and Terraform gets stuck)
#   2. terraform destroy eks-addons (removes the shared platform ALB too)
#   3. terraform destroy eks
# The Chapter 08 state backend is kept (it costs pennies). Remove it last with
#   terraform -chdir=chapter-08-cloud/terraform/backend destroy
set -euo pipefail
ENV="${1:-${ENV:-dev}}"; export ENV
source "$(dirname "$0")/lib.sh"
require_tools aws terraform kubectl helm

BUCKET=$(terraform -chdir="$TF_DIR/backend" output -raw state_bucket)

if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  use_cluster
  say "Removing every app in namespace $NAMESPACE"
  for r in $(helm list -n "$NAMESPACE" -q); do helm_uninstall "$r"; done
  kubectl -n "$NAMESPACE" delete ingress,service,deployment,cronjob,job --all --ignore-not-found --wait=true || true
fi

VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
         --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null || true)

# Load balancers the controller made in THIS cluster's VPC. They must be gone
# before the VPC can be deleted.
wait_for_lbs_gone() {
  [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ] || return 0
  say "Waiting for this cluster's AWS load balancers to disappear"
  local n=1
  for _ in $(seq 1 60); do
    n=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" \
        --query "length(LoadBalancers[?VpcId=='$VPC_ID'])" --output text 2>/dev/null || echo 0)
    [ "$n" = "0" ] && { ok "Load balancers gone"; return 0; }
    sleep 10
  done
  warn "$n load balancer(s) still in $VPC_ID. Delete the k8s-* ones in the EC2 console if destroy gets stuck."
}

for stack in eks-addons eks; do
  say "terraform destroy: $stack ($ENV)"
  terraform -chdir="$TF_DIR/$stack" init -input=false -reconfigure \
    -backend-config="environments/$ENV.tfbackend" \
    -backend-config="bucket=$BUCKET" >/dev/null
  terraform -chdir="$TF_DIR/$stack" destroy -input=false \
    -var-file="environments/$ENV.tfvars" ${AUTO_APPROVE:+-auto-approve} || {
      [ "$stack" = "eks-addons" ] && warn "Add-ons destroy failed (cluster may already be gone). Continuing." || exit 1; }
  # eks-addons removes the platform ALB; make sure AWS really deleted it.
  if [ "$stack" = "eks-addons" ]; then wait_for_lbs_gone; fi
done
rm -rf "$STATE_DIR"
ok "Everything for $ENV is destroyed. Check the AWS console (EC2, EKS, VPC) to be sure: no surprise bills."
