# The Cloud Platform (Chapters 10–18): Terraform → EKS → Helm

> Shared by every chapter from Chapter 10 on. Build it **once** per environment, run any
> chapter's cloud track on it, then **destroy it** when you stop for the day.

**Labels:** 💳 Needs an account that may cost money · 🌐 Needs the internet · 🧑‍🤝‍🧑 Easier with a helper the first time

---

> ### ⚠️ Money first
>
> While the platform exists you pay for it, even when nothing is happening:
>
> | Piece | Roughly | Notes |
> |---|---|---|
> | EKS control plane | $0.10/hour (~$73/month) | One per environment |
> | 2 × t3.medium nodes (dev, Spot) | ~$0.03/hour | prod uses 3 × t3.large On-Demand |
> | Load balancer (Phase 1 NLB / Phase 3 ALB) | ~$0.025/hour each | Only while a chapter's app is exposed |
> | NAT gateway (qa/prod only) | ~$0.045/hour | dev has none |
>
> A 3-hour dev session costs about **$0.50–$1**. A forgotten prod platform costs **$250+/month**.
> **Always finish with `platform-down.sh`.** Get permission first if the account isn't yours.

## The big idea (in plain words)

On your laptop, Kubernetes was a toy kitchen. In the cloud it's a real restaurant. Three tools
build and run it:

- **Terraform** builds the building: the network, the Kubernetes cluster (**EKS**), the image
  shelves (**ECR**), and the permissions. You learned it in Chapters 07–08; this reuses the same
  layout, state bucket, and `dev` / `qa` / `prod` files.
- **EKS** (Elastic Kubernetes Service) is Kubernetes that AWS runs for you. Same `kubectl`
  commands as your laptop.
- **Helm** is Kubernetes' **package manager**. A **chart** is a folder of YAML **templates** with
  blanks; a **values** file fills in the blanks. One command installs, upgrades, or rolls back
  an app.

Every chapter from 10 to 18 then teaches its topic in **three phases**:

| Phase | What you do | Tested how |
|---|---|---|
| **1 — Lift and shift** | `kubectl apply` plain YAML, same as your laptop. Image comes from ECR. | port-forward + curl (like local), then the public load balancer |
| **2 — Package with Helm** | `helm upgrade --install` the shared chart with the chapter's `phase2/values.yaml`. | port-forward + curl + `helm test` |
| **3 — Production** | Same release, plus `phase3/values.yaml`: autoscaling, disruption budget, zone spreading, network policy, hardened security, ALB ingress, monitoring/alerts, managed secrets. | public ALB + `helm test` + checking each safety net |

## What's where

```text
chapter-08-cloud/terraform/
├── backend/            # S3 state bucket + DynamoDB lock (from Chapter 08, reused)
├── modules/
│   ├── vpc/            # same brick as Chapter 08 (+ optional private subnets & NAT)
│   ├── eks/            # NEW: cluster, node group, core add-ons, admin access
│   ├── ecr/            # NEW: one image registry per chapter app
│   └── pod-identity-role/  # NEW: AWS permissions for one pod, no access keys
├── ec2/                # Chapter 08's stack
├── eks/                # NEW stack: network + cluster + ECR + IAM   (environments/dev|qa|prod)
└── eks-addons/         # NEW stack: Helm-installed cluster software (environments/dev|qa|prod)

platform/
├── helm/zero2ai-app/   # ONE chart every chapter installs with its own values
└── scripts/            # platform-up / platform-down / check-tools / status / put-llm-secret / lib

chapter-NN-*/cloud/
├── phase1/*.yaml       # plain Kubernetes YAML
├── phase2/values.yaml  # Helm values
├── phase3/values.yaml  # production values (+ values-prod.yaml for ENV=prod)
├── deploy.sh           # build | 1 | 2 | 3
├── test.sh             # 1 | 2 | 3
└── down.sh
```

### dev vs qa vs prod (same code, different settings files)

| Setting | dev | qa | prod |
|---|---|---|---|
| Nodes | 2 × t3.medium **Spot**, public subnets | 2 × t3.medium Spot, **private** subnets + NAT | 3 × t3.large **On-Demand**, private, **3 AZs** |
| Control-plane logs | off | api, audit, authenticator (7 days) | all (30 days) |
| Secrets encrypted with KMS | no | yes | yes |
| ECR tags | can be overwritten | can be overwritten | **immutable** |
| Prometheus | 2 days, no disk | 3 days | 15 days on a 20 GB disk |
| Load balancer controller / Alertmanager | 1 copy | 1 copy | 2 copies |

## Step 1 — Tools (once)

You need: **AWS CLI** (logged in, Chapter 07), **Terraform**, **kubectl**, **Helm 3**, **Docker**,
**git**, **curl**. Check them all at once from the top of the repo:

```bash
bash platform/scripts/check-tools.sh
```

> **Windows:** run every script in **Git Bash**. **Apple Silicon Mac:** nothing special — the
> scripts build images for `linux/amd64`, which is what the EKS nodes run.

## Step 2 — Build the platform (~20 minutes)

```bash
bash platform/scripts/platform-up.sh dev
```

It runs, in order:

1. Checks the Chapter 08 **state backend** exists (creates it if not).
2. `terraform apply` in `chapter-08-cloud/terraform/eks` with `environments/dev.tfvars`
   → VPC, EKS cluster, node group, ECR repositories, IAM roles, MLflow bucket, LLM secret envelope.
3. `terraform apply` in `chapter-08-cloud/terraform/eks-addons`
   → Helm installs the AWS Load Balancer Controller, metrics-server, Cluster Autoscaler,
   External Secrets, and Prometheus + Grafana.
4. Points `kubectl` at the cluster.

Terraform shows each plan and waits for you to type `yes` (set `AUTO_APPROVE=1` to skip that).

**What you should see at the end:** `kubectl get nodes` lists 2 nodes `Ready`.

Prefer doing it by hand? It's the Chapter 08 routine, twice:

```bash
cd chapter-08-cloud/terraform/eks
terraform init -reconfigure -backend-config=environments/dev.tfbackend \
  -backend-config="bucket=$(terraform -chdir=../backend output -raw state_bucket)"
terraform plan  -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
$(terraform output -raw configure_kubectl)
cd ../eks-addons
# same init / plan / apply with this folder's environments/dev.* files
```

## Step 3 — Do the chapters

| Chapter | Cloud track | Image | What Phase 3 adds |
|---|---|---|---|
| 10 Kubernetes | [cloud/](../chapter-10-kubernetes/cloud/README.md) | fraud-api | gunicorn, HPA, PDB, zone spread, NetworkPolicy, ALB |
| 11 Monitoring | [cloud/](../chapter-11-monitoring/cloud/README.md) | metrics-api | ServiceMonitor + alert rules in Prometheus |
| 12 AIOps | [cloud/](../chapter-12-aiops/cloud/README.md) | aiops | watcher reads real Prometheus metrics and scales the app (RBAC-limited) |
| 13 Retraining | [cloud/](../chapter-13-retraining/cloud/README.md) | retrain, mlflow | MLflow server on EKS, artifacts in S3 via Pod Identity, weekly CronJob |
| 14 Safe releases | [cloud/](../chapter-14-deployment/cloud/README.md) | fraud-api | blue/green with Helm, ALB weighted canary, `--atomic` auto-rollback |
| 15 Dashboards | [cloud/](../chapter-15-dashboards/cloud/README.md) | monitored-api | Grafana dashboard as code + alerts |
| 16 LLM | [cloud/](../chapter-16-llm/cloud/README.md) | llm-api | keys from AWS Secrets Manager (External Secrets) |
| 17 RAG | [cloud/](../chapter-17-rag/cloud/README.md) | rag-api | index built per pod by an init container, model baked into the image |
| 18 Production LLM | [cloud/](../chapter-18-prodllm/cloud/README.md) | prod-llm | everything above: ALB, HPA, PDB, secrets, metrics, cost/error alerts |

Each chapter's routine is the same:

```bash
cd chapter-10-kubernetes/cloud
bash deploy.sh build    # build the image, push to ECR
bash deploy.sh 1 && bash test.sh 1
bash deploy.sh 2 && bash test.sh 2
bash deploy.sh 3 && bash test.sh 3
bash down.sh            # remove this chapter's app (keeps the cluster)
```

Use another environment by prefixing `ENV=qa` or `ENV=prod`, e.g. `ENV=prod bash deploy.sh 3`.

## Step 4 — Look around

```bash
bash platform/scripts/status.sh                    # nodes, releases, apps, load balancers
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
terraform -chdir=chapter-08-cloud/terraform/eks-addons output -raw grafana_admin_password
```

## Step 5 — Destroy (every time you stop)

```bash
bash platform/scripts/platform-down.sh dev
```

It removes every app first (so AWS deletes the load balancers), then destroys the add-ons, then
the cluster and network. The tiny state backend stays for next time.

## If something breaks

- **`Cluster zero2ai-eks-dev not found`** → Run `platform-up.sh dev` first, or set the same `ENV`
  you built.
- **`No image recorded for 'fraud-api'`** → Run `bash deploy.sh build` in that chapter first.
- **`docker push` says `denied` / `no basic auth credentials`** → Your ECR login expired (12
  hours). `deploy.sh build` logs in again; just rerun it.
- **Pods `ImagePullBackOff` with `exec format error` in logs** → The image was built for ARM.
  Use `deploy.sh build`; it always builds `linux/amd64`.
- **Ingress has no address after 5 minutes** → `kubectl -n zero2ai describe ingress <name>` and
  `kubectl -n kube-system logs deploy/aws-load-balancer-controller`. Usually a missing subnet tag
  or IAM permission; both come from Terraform, so re-run `platform-up.sh`.
- **`terraform destroy` hangs on the VPC or subnets** → A load balancer still exists. Run
  `platform-down.sh` (it deletes apps first), or delete `k8s-*` load balancers in the EC2 console.
- **`Error: Kubernetes cluster unreachable` in eks-addons** → Your AWS login expired or kubectl
  isn't configured. `aws sts get-caller-identity`, then re-run.

## Where to next

Start with [Chapter 10's cloud track](../chapter-10-kubernetes/cloud/README.md).
