#!/usr/bin/env bash
# platform-up.sh <env>: build the whole cloud platform for one environment.
#   1. checks the Chapter 08 state backend exists
#   2. terraform apply  chapter-08-cloud/terraform/eks         (network, cluster, ECR, IAM)
#   3. terraform apply  chapter-08-cloud/terraform/eks-addons  (Helm: LB controller, monitoring, ...)
#   4. points kubectl at the new cluster
# Takes ~20 minutes the first time. Costs money while it exists.
set -euo pipefail
ENV="${1:-${ENV:-dev}}"; export ENV
source "$(dirname "$0")/lib.sh"
require_tools aws terraform kubectl helm

BACKEND="$TF_DIR/backend"
say "Checking the Terraform state backend (Chapter 08)"
if ! BUCKET=$(terraform -chdir="$BACKEND" output -raw state_bucket 2>/dev/null) || [ -z "$BUCKET" ]; then
  warn "No backend found. Creating it now (S3 bucket + DynamoDB lock table, pennies per month)."
  terraform -chdir="$BACKEND" init -input=false
  terraform -chdir="$BACKEND" apply -input=false -auto-approve
  BUCKET=$(terraform -chdir="$BACKEND" output -raw state_bucket)
fi
ok "State bucket: $BUCKET"

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
ok "Platform ready. Next: pick a chapter's cloud/README.md (start with chapter-10-kubernetes/cloud)."
echo "Grafana password: terraform -chdir=$TF_DIR/eks-addons output -raw grafana_admin_password"
