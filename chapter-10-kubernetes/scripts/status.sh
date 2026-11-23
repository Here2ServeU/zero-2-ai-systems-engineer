#!/usr/bin/env bash
# status.sh: one screen showing what's running (and costing money) right now.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
use_cluster
say "Nodes";            kubectl get nodes -L node.kubernetes.io/instance-type,topology.kubernetes.io/zone,eks.amazonaws.com/capacityType
say "Helm releases";    helm list -A
say "Apps ($NAMESPACE)"; kubectl -n "$NAMESPACE" get deploy,cronjob,svc,ingress,hpa,pdb 2>/dev/null
say "Load balancers";   aws elbv2 describe-load-balancers --region "$AWS_REGION" \
                          --query 'LoadBalancers[].[LoadBalancerName,Type,DNSName]' --output table
say "Platform ALB";     echo "http://$(platform_alb)   (all URLs: bash chapter-10-kubernetes/scripts/urls.sh)"
