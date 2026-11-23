#!/usr/bin/env bash
# platform-up.sh <env>: build the whole cloud platform for one environment.
#   1. checks Chapter 10's state backend exists (terraform/backend; created if not)
#   2. terraform apply  chapter-10-kubernetes/terraform/eks         (network, cluster, ECR, IAM)
#   3. terraform apply  chapter-10-kubernetes/terraform/eks-addons  (Helm: LB controller, monitoring, ...
#                                                               + the shared platform ALB)
#   4. points kubectl at the new cluster and prints every URL (urls.sh)
# Takes ~20 minutes the first time. Costs money while it exists.
set -euo pipefail
ENV="${1:-${ENV:-dev}}"; export ENV
source "$(dirname "$0")/lib.sh"
require_tools aws terraform kubectl helm

BACKEND="$TF_DIR/backend"
say "Checking the Terraform state backend (chapter-10-kubernetes/terraform/backend)"
if ! BUCKET=$(terraform -chdir="$BACKEND" output -raw state_bucket 2>/dev/null) || [ -z "$BUCKET" ]; then
  warn "No backend found. Creating it now (S3 bucket + DynamoDB lock table, pennies per month)."
  terraform -chdir="$BACKEND" init -input=false
  terraform -chdir="$BACKEND" apply -input=false -auto-approve
  BUCKET=$(terraform -chdir="$BACKEND" output -raw state_bucket)
fi
ok "State bucket: $BUCKET"

# Prometheus/Alertmanager have no login, so the platform ALB only opens them
# to YOUR public IP. Override with  export TF_VAR_alb_admin_cidrs='["x.x.x.x/32"]'
if [ -z "${TF_VAR_alb_admin_cidrs:-}" ]; then
  me=$(my_public_cidr)
  if [ -n "$me" ]; then
    export TF_VAR_alb_admin_cidrs="[\"$me\"]"
    ok "Prometheus/Alertmanager on the ALB will be open to your IP only: $me"
  else
    warn "Couldn't find your public IP; Prometheus/Alertmanager stay private (use port-forward)."
  fi
fi

for stack in eks eks-addons; do
  say "terraform apply: $stack ($ENV)"
  terraform -chdir="$TF_DIR/$stack" init -input=false -reconfigure \
    -backend-config="environments/$ENV.tfbackend" \
    -backend-config="bucket=$BUCKET"
  terraform -chdir="$TF_DIR/$stack" apply -input=false \
    -var-file="environments/$ENV.tfvars" ${AUTO_APPROVE:+-auto-approve}
done

use_cluster
say "Cluster is up"
kubectl get nodes -o wide
echo
bash "$SCRIPTS_DIR/urls.sh"
echo
ok "Platform ready. Open the landing page above in your browser (new ALBs need 1-3 minutes for DNS)."
echo "Next: pick a chapter's cloud/README.md (start with chapter-10-kubernetes/cloud)."
