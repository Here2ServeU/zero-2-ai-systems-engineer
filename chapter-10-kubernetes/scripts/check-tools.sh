#!/usr/bin/env bash
# check-tools.sh: confirms every tool the cloud track needs is installed.
set -uo pipefail
fail=0
check() {
  local name="$1" cmd="$2" hint="$3"
  if command -v "$name" >/dev/null 2>&1; then
    printf '  \033[32m✔\033[0m %-10s %s\n' "$name" "$($cmd 2>&1 | head -1)"
  else
    printf '  \033[31m✘\033[0m %-10s missing: %s\n' "$name" "$hint"; fail=1
  fi
}
echo "Tools for the EKS cloud track:"
check aws       "aws --version"                   "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
check terraform "terraform version"               "https://developer.hashicorp.com/terraform/install"
check kubectl   "kubectl version --client"        "https://kubernetes.io/docs/tasks/tools/"
check helm      "helm version --short"            "https://helm.sh/docs/intro/install/"
check docker    "docker --version"                "Docker Desktop (Chapter 06)"
check git       "git --version"                   "https://git-scm.com/downloads"
check curl      "curl --version"                  "comes with Git Bash / macOS / Linux"
echo
if aws sts get-caller-identity >/dev/null 2>&1; then
  echo "AWS login: $(aws sts get-caller-identity --query Arn --output text)"
else
  echo "AWS login: NOT logged in. Run: aws configure   (Chapter 07)"; fail=1
fi
exit $fail
