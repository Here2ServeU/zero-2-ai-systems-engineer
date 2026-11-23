#!/usr/bin/env bash
# lib.sh: shared helpers for every chapter's cloud scripts (Chapters 10-18).
#
# Chapter scripts `source` this file, then call the functions below. Nothing
# here needs jq or envsubst, so it runs in Git Bash on Windows, macOS and Linux.
#
# Settings you can change by exporting them before running a script:
#   ENV         dev | qa | prod          (default: dev)
#   AWS_REGION  AWS region               (default: us-east-1)
#   IMAGE_TAG   force an image tag       (default: git commit, e.g. 3f9c2ab)
#   NAMESPACE   Kubernetes namespace     (default: zero2ai)

set -euo pipefail

PLATFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$PLATFORM_DIR/.." && pwd)"
CHART_DIR="$PLATFORM_DIR/helm/zero2ai-app"
# shellcheck disable=SC2034  # used by the scripts that source this file
TF_DIR="$REPO_ROOT/chapter-08-cloud/terraform"

ENV="${ENV:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"
NAMESPACE="${NAMESPACE:-zero2ai}"
PROJECT="${PROJECT:-zero2ai}"
CLUSTER_NAME="${PROJECT}-eks-${ENV}"
STATE_DIR="$REPO_ROOT/.zero2ai/$ENV"   # remembers the last image you pushed (git-ignored)

# Pretty output ---------------------------------------------------------------
# Messages go to stderr, so functions that "return" a value with echo (like
# wait_for_ingress) can still print progress.
say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*" >&2; }
ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$*" >&2; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m✘ %s\033[0m\n' "$*" >&2; exit 1; }

case "$ENV" in dev|qa|prod) ;; *) die "ENV must be dev, qa or prod (got '$ENV')";; esac

# Never leave a port-forward tunnel running after a script ends (even on error).
trap 'kill $(jobs -p) 2>/dev/null || true' EXIT

# Tools -----------------------------------------------------------------------
require_tools() {
  local missing=()
  for t in "$@"; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done
  [ ${#missing[@]} -eq 0 ] || die "Missing tools: ${missing[*]}. Run platform/scripts/check-tools.sh"
}

# AWS + cluster ---------------------------------------------------------------
aws_account_id() {
  aws sts get-caller-identity --query Account --output text
}

ecr_registry() {
  echo "$(aws_account_id).dkr.ecr.${AWS_REGION}.amazonaws.com"
}

# Repo names match the eks stack: <project>-<env>/<app>
ecr_repo() {
  echo "$(ecr_registry)/${PROJECT}-${ENV}/$1"
}

use_cluster() {
  require_tools aws kubectl
  say "Connecting kubectl to $CLUSTER_NAME ($AWS_REGION)"
  aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" >/dev/null 2>&1 \
    || die "Cluster $CLUSTER_NAME not found. Build it first: bash platform/scripts/platform-up.sh $ENV"
  aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" --alias "$CLUSTER_NAME" >/dev/null
  kubectl config use-context "$CLUSTER_NAME" >/dev/null
  kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE" >/dev/null
  ok "kubectl now talks to $CLUSTER_NAME (namespace $NAMESPACE)"
}

vpc_cidr() {
  local vpc
  vpc=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
        --query 'cluster.resourcesVpcConfig.vpcId' --output text)
  aws ec2 describe-vpcs --vpc-ids "$vpc" --region "$AWS_REGION" --query 'Vpcs[0].CidrBlock' --output text
}

# Images ----------------------------------------------------------------------
default_tag() {
  local sha
  sha=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "manual")
  # Uncommitted changes get a timestamp, so prod's immutable tags never clash.
  if [ -n "$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)" ]; then
    sha="${sha}-$(date +%Y%m%d%H%M%S)"
  fi
  echo "$sha"
}

# build_push <app> <build-context-dir> [dockerfile]
# Builds for linux/amd64 (EKS nodes are x86 even if your laptop is an M-series
# Mac), pushes to ECR, and remembers the result in .zero2ai/<env>/<app>.image
build_push() {
  local app="$1" ctx="$2" dockerfile="${3:-}"
  require_tools docker aws
  local repo tag image
  repo=$(ecr_repo "$app")
  tag="${IMAGE_TAG:-$(default_tag)}"
  image="$repo:$tag"

  say "Logging in to ECR"
  aws ecr get-login-password --region "$AWS_REGION" \
    | docker login --username AWS --password-stdin "$(ecr_registry)" >/dev/null
  ok "Logged in to $(ecr_registry)"

  say "Building $image"
  if [ -n "$dockerfile" ]; then
    docker build --platform linux/amd64 -t "$image" -f "$dockerfile" "$ctx"
  else
    docker build --platform linux/amd64 -t "$image" "$ctx"
  fi

  say "Pushing $image"
  docker push "$image"
  mkdir -p "$STATE_DIR"
  echo "$image" > "$STATE_DIR/$app.image"
  ok "Pushed $image"
}

# last_image <app>: the image build_push pushed most recently for this env.
last_image() {
  local f="$STATE_DIR/$1.image"
  [ -f "$f" ] || die "No image recorded for '$1' in $ENV. Run this chapter's deploy.sh build step first."
  cat "$f"
}

# Phase 1: plain YAML ---------------------------------------------------------
# apply_manifests <dir> <image>: replaces __IMAGE__ in every *.yaml and applies.
apply_manifests() {
  local dir="$1" image="$2" f
  say "Phase 1: kubectl apply -f $dir (image $image)"
  for f in "$dir"/*.yaml; do
    sed -e "s#__IMAGE__#${image}#g" "$f" | kubectl apply -n "$NAMESPACE" -f -
  done
}

delete_manifests() {
  local dir="$1" f
  for f in "$dir"/*.yaml; do
    sed -e "s#__IMAGE__#unused#g" "$f" | kubectl delete -n "$NAMESPACE" --ignore-not-found -f - || true
  done
}

# Phase 2 / 3: Helm -----------------------------------------------------------
# helm_deploy <release> <image> [extra helm args...]
helm_deploy() {
  local release="$1" image="$2"; shift 2
  require_tools helm
  local repo="${image%:*}" tag="${image##*:}"
  say "helm upgrade --install $release (chart zero2ai-app, image tag $tag)"
  helm upgrade --install "$release" "$CHART_DIR" \
    --namespace "$NAMESPACE" \
    --set image.repository="$repo" \
    --set image.tag="$tag" \
    --wait --timeout 10m \
    "$@"
  helm history "$release" -n "$NAMESPACE" --max 5
}

# values_args <dir>...: fills the VALUES_ARGS array with "-f <dir>/values.yaml"
# and "-f <dir>/values-<env>.yaml" for each dir that has them. Later files win.
values_args() {
  VALUES_ARGS=()
  local d
  for d in "$@"; do
    if [ -f "$d/values.yaml" ]; then VALUES_ARGS+=(-f "$d/values.yaml"); fi
    if [ -f "$d/values-$ENV.yaml" ]; then VALUES_ARGS+=(-f "$d/values-$ENV.yaml"); fi
  done
  return 0
}

helm_uninstall() {
  helm uninstall "$1" -n "$NAMESPACE" --wait 2>/dev/null || true
}

# Testing ---------------------------------------------------------------------
# with_port_forward <service> <local-port> <remote-port> <command...>
# Opens the same tunnel you used on your laptop, runs the command, closes it.
with_port_forward() {
  local svc="$1" lport="$2" rport="$3"; shift 3
  kubectl -n "$NAMESPACE" port-forward "svc/$svc" "$lport:$rport" >/dev/null 2>&1 &
  local pf=$! rc=0 _
  for _ in $(seq 1 40); do
    if (echo >"/dev/tcp/127.0.0.1/$lport") >/dev/null 2>&1; then break; fi
    sleep 0.5
  done
  "$@" || rc=$?
  kill "$pf" 2>/dev/null || true
  wait "$pf" 2>/dev/null || true
  return "$rc"
}

http_get() {
  echo "GET $1"
  curl -fsS --max-time 20 "$1" || die "GET $1 failed"
  echo
}

http_post() {
  echo "POST $1  $2"
  curl -fsS --max-time 90 -X POST "$1" -H 'Content-Type: application/json' -d "$2" || die "POST $1 failed"
  echo
}

# ingress_port <ingress-name>: the ALB listener port the Helm chart asked for
# (ingress.port, e.g. 8010). Read back from the Ingress so the test always uses
# what is really deployed.
ingress_port() {
  kubectl -n "$NAMESPACE" get ingress "$1" \
    -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/listen-ports}' 2>/dev/null \
    | grep -o '[0-9][0-9]*' | head -1
}

# wait_for_ingress <ingress-name> [path]: prints "host" or "host:port" once
# the app answers through the ALB, ready to use as  http://$(wait_for_ingress x)
wait_for_ingress() {
  local name="$1" host="" path="${2:-/health}" port addr
  say "Waiting for the AWS load balancer for ingress/$name (first time: 2-4 minutes)"
  for _ in $(seq 1 60); do
    host=$(kubectl -n "$NAMESPACE" get ingress "$name" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
    [ -n "$host" ] && break
    sleep 5
  done
  [ -n "$host" ] || die "No load balancer address yet. Check: kubectl -n $NAMESPACE describe ingress $name"
  port=$(ingress_port "$name")
  addr="$host"
  if [ -n "$port" ] && [ "$port" != "80" ]; then addr="$host:$port"; fi
  for _ in $(seq 1 72); do
    curl -fsS --max-time 5 "http://$addr$path" >/dev/null 2>&1 && { echo "$addr"; return 0; }
    sleep 5
  done
  die "Load balancer $addr is not answering on $path yet. DNS can take a few more minutes; retry the test script."
}

# platform_alb: DNS name of the shared platform ALB (built by eks-addons).
platform_alb() {
  kubectl -n kube-system get ingress zero2ai-platform \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true
}

# my_public_cidr: this computer's public IP as a /32 (asks AWS's checkip service).
my_public_cidr() {
  local ip
  ip=$(curl -fsS --max-time 10 https://checkip.amazonaws.com 2>/dev/null | tr -d '[:space:]') || true
  case "$ip" in *.*.*.*) echo "$ip/32" ;; *) echo "" ;; esac
}

# wait_for_lb_service <service-name>: same, for a Service of type LoadBalancer (Phase 1).
wait_for_lb_service() {
  local name="$1" host="" path="${2:-/health}"
  say "Waiting for the AWS load balancer for service/$name (first time: 2-4 minutes)"
  for _ in $(seq 1 60); do
    host=$(kubectl -n "$NAMESPACE" get svc "$name" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
    [ -n "$host" ] && break
    sleep 5
  done
  [ -n "$host" ] || die "No load balancer address yet. Check: kubectl -n $NAMESPACE describe svc $name"
  for _ in $(seq 1 72); do
    curl -fsS --max-time 5 "http://$host$path" >/dev/null 2>&1 && { echo "$host"; return 0; }
    sleep 5
  done
  die "Load balancer $host is not answering on $path yet. DNS can take a few more minutes; retry the test script."
}

# LLM keys (Chapters 16-18, Phases 1-2): a Kubernetes Secret built from the
# keys in YOUR shell's environment. Never written to a file or to git.
create_llm_secret_from_env() {
  local args=() k
  for k in ANTHROPIC_API_KEY OPENAI_API_KEY GEMINI_API_KEY; do
    [ -n "${!k:-}" ] && args+=("--from-literal=$k=${!k}")
  done
  [ ${#args[@]} -gt 0 ] || die "Set at least one key first, e.g.  export ANTHROPIC_API_KEY=sk-ant-...  (see Chapter 16)"
  kubectl -n "$NAMESPACE" create secret generic llm-api-keys "${args[@]}" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  ok "Secret llm-api-keys is ready (keys: $(for a in "${args[@]}"; do a=${a#--from-literal=}; printf '%s ' "${a%%=*}"; done))"
}

usage_phase() {
  echo "Usage: $0 <build|1|2|3>   (ENV=${ENV}, region ${AWS_REGION})"
  echo "  build  build the image and push it to ECR"
  echo "  1      Phase 1: plain Kubernetes YAML, same as your laptop"
  echo "  2      Phase 2: Helm chart + values, tested with port-forward and helm test"
  echo "  3      Phase 3: production values (load balancer, autoscaling, hardening)"
  exit 1
}
