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
> | Platform ALB (shared by Grafana + every Phase 3 app) | ~$0.025/hour | One per environment, while the platform exists |
> | Phase 1 NLB | ~$0.025/hour | Only while a chapter's Phase 1 is running |
> | NAT gateway (qa/prod only) | ~$0.045/hour | dev has none |
>
> A 3-hour dev session costs about **$0.50–$1**. A forgotten prod platform costs **$250+/month**.
> **Always finish with `platform-down.sh`.** Get permission first if the account isn't yours.

## The big idea (in plain words)

On your laptop, Kubernetes was a toy kitchen. In the cloud it's a real restaurant. Three tools
build and run it:

- **Terraform** builds the building: the network, the Kubernetes cluster (**EKS**), the image
  shelves (**ECR**), and the permissions. You learned it in Chapters 07–08. Chapter 10 uses the same
  layout and `dev` / `qa` / `prod` files, with its **own** state bucket, so it needs nothing from Chapter 08.
- **EKS** (Elastic Kubernetes Service) is Kubernetes that AWS runs for you. Same `kubectl`
  commands as your laptop.
- **An ALB** (Application Load Balancer) is the platform's **front door**: one public address
  that reaches Grafana, Prometheus and every chapter's app, from your browser or with `curl`.
- **Helm** is Kubernetes' **package manager**. A **chart** is a folder of YAML **templates** with
  blanks; a **values** file fills in the blanks. One command installs, upgrades, or rolls back
  an app.

Every chapter from 10 to 18 then teaches its topic in **three phases**:

| Phase | What you do | Tested how |
|---|---|---|
| **1 — Lift and shift** | `kubectl apply` plain YAML, same as your laptop. Image comes from ECR. | port-forward + curl (like local), then the public load balancer |
| **2 — Package with Helm** | `helm upgrade --install` the shared chart with the chapter's `phase2/values.yaml`. | port-forward + curl + `helm test` |
| **3 — Production** | Same release, plus `phase3/values.yaml`: autoscaling, disruption budget, zone spreading, network policy, hardened security, a port on the platform ALB, monitoring/alerts, managed secrets. | platform ALB + `helm test` + checking each safety net |

## What's where

Chapter 10 is **self-contained**: everything the platform needs is in this folder. Chapters
11–18 only add their own `cloud/` files and reuse what's here.

```text
chapter-10-kubernetes/
├── PLATFORM.md          # this guide
├── terraform/
│   ├── backend/         # Chapter 10's OWN S3 state bucket + DynamoDB lock (no Chapter 08 needed)
│   ├── modules/
│   │   ├── vpc/         # the same network brick as Chapter 08 (+ optional private subnets & NAT)
│   │   ├── eks/         # cluster, node group, core add-ons, admin access
│   │   ├── ecr/         # one image registry per chapter app
│   │   └── pod-identity-role/  # AWS permissions for one pod, no access keys
│   ├── eks/             # stack: network + cluster + ECR + IAM   (environments/dev|qa|prod)
│   └── eks-addons/      # stack: Helm-installed cluster software + the platform ALB (platform-alb.tf)
├── helm/zero2ai-app/    # ONE chart every chapter installs with its own values
├── scripts/
│   ├── platform-up.sh / platform-down.sh   # build / destroy the whole platform
│   ├── urls.sh / status.sh                 # every ALB address / what's running
│   ├── check-tools.sh / put-llm-secret.sh / validate-chart.sh
│   ├── lib.sh                              # shared helpers every chapter's cloud/*.sh sources
│   └── local-up.sh / local-test.sh / local-down.sh   # Chapter 10 on your laptop (minikube/kind)
└── cloud/               # Chapter 10's own phases (below)

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
bash chapter-10-kubernetes/scripts/check-tools.sh
```

> **Windows:** run every script in **Git Bash**. **Apple Silicon Mac:** nothing special — the
> scripts build images for `linux/amd64`, which is what the EKS nodes run.

## Step 2 — Build the platform (~20 minutes)

```bash
bash chapter-10-kubernetes/scripts/platform-up.sh dev
```

It runs, in order:

1. Checks Chapter 10's **state backend** (`terraform/backend`) exists, and creates it the first time
   (bucket `zero2ai-eks-tfstate-<account>`, lock table `zero2ai-eks-terraform-locks`).
2. `terraform apply` in `chapter-10-kubernetes/terraform/eks` with `environments/dev.tfvars`
   → VPC, EKS cluster, node group, ECR repositories, IAM roles, MLflow bucket, LLM secret envelope.
3. `terraform apply` in `chapter-10-kubernetes/terraform/eks-addons`
   → Helm installs the AWS Load Balancer Controller, metrics-server, Cluster Autoscaler,
   External Secrets, and Prometheus + Grafana. Then it builds the **platform ALB** (see below).
4. Points `kubectl` at the cluster and prints every URL (`urls.sh`).

Terraform shows each plan and waits for you to type `yes` (set `AUTO_APPROVE=1` to skip that).

**What you should see at the end:** `kubectl get nodes` lists 2 nodes `Ready`, then a list of
addresses starting with `http://k8s-zero2ai-....us-east-1.elb.amazonaws.com`.

Prefer doing it by hand? It's the Chapter 08 routine (backend once, then each stack):

```bash
cd chapter-10-kubernetes/terraform/eks
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
| 10 Kubernetes | [cloud/](cloud/README.md) | fraud-api | gunicorn, HPA, PDB, zone spread, NetworkPolicy, ALB |
| 11 Monitoring | [cloud/](../chapter-11-monitoring/cloud/README.md) | metrics-api | ServiceMonitor + alert rules in Prometheus |
| 12 AIOps | [cloud/](../chapter-12-aiops/cloud/README.md) | aiops | watcher reads real Prometheus metrics and scales the app (RBAC-limited) |
| 13 Retraining | [cloud/](../chapter-13-retraining/cloud/README.md) | retrain, mlflow | MLflow server on EKS, artifacts in S3 via Pod Identity, weekly CronJob |
| 14 Safe releases | [cloud/](../chapter-14-deployment/cloud/README.md) | fraud-api | blue/green with Helm, ALB weighted canary, `--atomic` auto-rollback |
| 15 Dashboards | [cloud/](../chapter-15-dashboards/cloud/README.md) | monitored-api | Grafana dashboard as code + alerts |
| 16 LLM | [cloud/](../chapter-16-llm/cloud/README.md) | llm-api | keys from AWS Secrets Manager (External Secrets) |
| 17 RAG | [cloud/](../chapter-17-rag/cloud/README.md) | rag-api | index built per pod by an init container, model baked into the image |
| 18 Production LLM | [cloud/](../chapter-18-prodllm/cloud/README.md) | prod-llm | everything above: ALB, HPA, PDB, secrets, metrics, cost/error alerts |

Each Phase 3 app gets its own port on the platform ALB (Step 4): Chapter **NN** answers at
`http://<platform-alb>:80NN` (10 → `:8010`, 14 → `:8014`, 18 → `:8018`).

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

## Step 4 — Reach the cluster: the platform ALB

The add-ons stack builds **one** internet-facing **Application Load Balancer** for the whole
cluster ([`eks-addons/platform-alb.tf`](terraform/eks-addons/platform-alb.tf)).
Every service gets its own **port** on it, so you never need `port-forward` to look around:

| Address | What's there | Who can open it |
|---|---|---|
| `http://<alb>/` | Landing page with a link to everything below | `alb_allowed_cidrs` (default: anyone) |
| `http://<alb>:3000` | Grafana (user `admin`) | `alb_allowed_cidrs` |
| `http://<alb>:9090` | Prometheus | **your IP only** (no login, so `platform-up.sh` locks it to you) |
| `http://<alb>:9093` | Alertmanager | your IP only |
| `http://<alb>:8010` … `:8018` | Chapter 10 … 18's app, once you run its `deploy.sh 3` | anyone (set `ingress.allowedCidrs` to limit) |

**In the browser:** open the landing page and click.

**From the command line:**

```bash
bash chapter-10-kubernetes/scripts/urls.sh                       # every address, plus ready-made curl commands
ALB=$(terraform -chdir=chapter-10-kubernetes/terraform/eks-addons output -raw platform_alb_hostname)
curl -i http://$ALB/                                # landing page (HTTP 200)
curl -s http://$ALB:3000/api/health                 # Grafana
curl -s http://$ALB:8010/health                     # Chapter 10, after its Phase 3
terraform -chdir=chapter-10-kubernetes/terraform/eks-addons output -raw grafana_admin_password
kubectl get nodes                                   # the cluster's own API (not through the ALB)
bash chapter-10-kubernetes/scripts/status.sh                     # nodes, releases, apps, load balancers
```

**How it works.** Every Ingress with the annotation `alb.ingress.kubernetes.io/group.name: zero2ai`
is merged by the AWS Load Balancer Controller into the **same** ALB. The Helm chart does this by
default (`ingress.groupName: zero2ai`), and each chapter's `phase3/values.yaml` picks its port with
`ingress.port: 80NN`. One ALB instead of one per chapter: cheaper, and one address to remember.

**Settings** (in `eks-addons/environments/<env>.tfvars`):

- `alb_allowed_cidrs` — who may open the landing page and Grafana. In prod, use your office/VPN ranges.
- `alb_admin_cidrs` — who may open Prometheus/Alertmanager. `platform-up.sh` sets it to your
  current public IP; if your IP changes, rerun `platform-up.sh`. Empty = not exposed.
- Want HTTPS? With your own domain and an ACM certificate, set `ingress.host` and
  `ingress.certificateArn` in a chapter's values (host-based routing on 443).

Port-forward still works exactly like on your laptop if you prefer it:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80   # http://localhost:3000
```

## Step 5 — Destroy (every time you stop)

```bash
bash chapter-10-kubernetes/scripts/platform-down.sh dev
```

It removes every app first, then destroys the add-ons (which deletes the platform ALB; the script
waits until AWS confirms it's gone), then the cluster and network. The tiny state backend stays for next time.

## If something breaks

- **`Cluster zero2ai-eks-dev not found`** → Run `platform-up.sh dev` first, or set the same `ENV`
  you built.
- **`No image recorded for 'fraud-api'`** → Run `bash deploy.sh build` in that chapter first.
- **`docker push` says `denied` / `no basic auth credentials`** → Your ECR login expired (12
  hours). `deploy.sh build` logs in again; just rerun it.
- **Pods `ImagePullBackOff` with `exec format error` in logs** → The image was built for ARM.
  Use `deploy.sh build`; it always builds `linux/amd64`.
- **Browser says "can't reach" right after `platform-up.sh`** → A new ALB needs 1–3 minutes
  before its DNS name works. Wait and reload; `nslookup <alb-hostname>` should return addresses.
- **Prometheus on `:9090` times out but Grafana works** → Your public IP changed since
  `platform-up.sh`. Rerun it (it updates `alb_admin_cidrs`), or use port-forward.
- **Ingress has no address after 5 minutes** → `kubectl -n zero2ai describe ingress <name>` and
  `kubectl -n kube-system logs deploy/aws-load-balancer-controller`. Usually a missing subnet tag
  or IAM permission; both come from Terraform, so re-run `platform-up.sh`.
- **`terraform destroy` hangs on the VPC or subnets** → A load balancer still exists. Run
  `platform-down.sh` (it deletes apps first), or delete `k8s-*` load balancers in the EC2 console.
- **`Error: Kubernetes cluster unreachable` in eks-addons** → Your AWS login expired or kubectl
  isn't configured. `aws sts get-caller-identity`, then re-run.

## Where to next

Start with [Chapter 10's cloud track](cloud/README.md).
