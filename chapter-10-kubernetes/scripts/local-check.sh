#!/usr/bin/env bash
# local-check.sh: "is my laptop ready for Chapter 10?"
# Checks Docker, kubectl and your local Kubernetes cluster, and tells you in
# plain words what to fix. Changes nothing. Safe to run as often as you like.
#
#   bash scripts/local-check.sh        (from the chapter-10-kubernetes folder)
set -uo pipefail

pass() { printf '  \033[32m[OK]\033[0m %s\n' "$*"; }
problem() { printf '  \033[31m[ERROR]\033[0m %s\n      \033[33m→ %s\033[0m\n' "$1" "$2"; PROBLEMS=$((PROBLEMS + 1)); }
PROBLEMS=0

echo "Checking your laptop for Chapter 10..."

# 1. Docker: builds the app image.
if ! command -v docker >/dev/null 2>&1; then
  problem "Docker is not installed" "Install Docker Desktop (Chapter 06): https://www.docker.com/products/docker-desktop/"
elif ! docker info >/dev/null 2>&1; then
  problem "Docker is installed but not running" "Open Docker Desktop and wait until it says 'Engine running', then run this again"
else
  pass "Docker is running"
fi

# 2. kubectl: how you talk to Kubernetes.
if ! command -v kubectl >/dev/null 2>&1; then
  problem "kubectl is not installed" "Docker Desktop includes it once Kubernetes is enabled (Settings → Kubernetes). Or: https://kubernetes.io/docs/tasks/tools/"
  echo; echo "Fix the [ERROR] items above, then run this again."; exit 1
fi
pass "kubectl is installed"

# 3. Which cluster is kubectl pointed at?
CTX="$(kubectl config current-context 2>/dev/null || true)"
if [ -z "$CTX" ]; then
  problem "No Kubernetes cluster is set up yet" "Docker Desktop → Settings → Kubernetes → Enable Kubernetes (pick 'kubeadm'), or run: minikube start"
  echo; echo "Fix the [ERROR] items above, then run this again."; exit 1
fi
case "$CTX" in
  arn:aws:eks:*|*eks*)
    problem "kubectl is pointed at a CLOUD cluster ($CTX)" "This chapter runs on your laptop. Switch back: kubectl config use-context docker-desktop   (or minikube / kind-<name>; list them with: kubectl config get-contexts)"
    echo; echo "Fix the [ERROR] items above, then run this again."; exit 1 ;;
esac
pass "kubectl is pointed at: $CTX"

# 4. Is the cluster awake, with a Ready node?
if ! kubectl get nodes --request-timeout=10s >/dev/null 2>&1; then
  case "$CTX" in
    minikube*)      hint="Start it: minikube start" ;;
    kind-*)         hint="Start Docker Desktop; if the cluster was deleted: kind create cluster" ;;
    docker-desktop) hint="Docker Desktop → Settings → Kubernetes: make sure it is enabled and shows green" ;;
    *)              hint="Start your local cluster, then run this again" ;;
  esac
  problem "The cluster '$CTX' is not answering" "$hint"
else
  READY=$(kubectl get nodes --no-headers 2>/dev/null | awk '$2=="Ready"' | wc -l | tr -d ' ')
  if [ "$READY" -ge 1 ]; then
    pass "Cluster is awake: $READY node(s) Ready"
  else
    problem "The cluster has no Ready node yet" "Wait a minute and run this again (kubectl get nodes)"
  fi
fi

echo
if [ "$PROBLEMS" -eq 0 ]; then
  if [ -n "${CALLED_FROM_LOCAL_UP:-}" ]; then echo "All good."; else echo "All good. Next:  bash scripts/local-up.sh"; fi
else
  echo "Fix the [ERROR] items above, then run this again."
  exit 1
fi
