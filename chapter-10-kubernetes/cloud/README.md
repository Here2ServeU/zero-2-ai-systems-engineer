# Chapter 10 — Phase 2: Promote it to the cloud (AWS EKS)

> In Phase 1 you ran 2 self-healing copies of the fraud API on your laptop. Now you move the
> **same app** to a real cloud cluster, in two small steps: **2A** with the same plain YAML,
> then **2B** packaged with Helm. Phase 3 ([PRODUCTION.md](PRODUCTION.md)) hardens it for
> production.

**Labels:** Needs an account that may cost money · Needs the internet · Easier with a helper the first time

---

## Before you start

1. **Finish Phase 1** ([../README.md](../README.md)). Everything here builds on it.
2. **Build the shared cloud platform once:** [../PLATFORM.md](../PLATFORM.md). It creates the EKS
   cluster, your private image shelf (ECR) and the add-ons, and takes about 20 minutes.
3. **Costs money.** An EKS cluster costs roughly **$0.10/hour** plus servers and load
   balancers. Get permission if the AWS account isn't yours, and **tear everything down when
   you finish** (see "Clean up" at the bottom).

**Run every command on this page from this folder:**

```bash
cd chapter-10-kubernetes/cloud
```

## What changes from your laptop to the cloud

| On your laptop (Phase 1) | In the cloud (Phase 2) | Why |
|---|---|---|
| Image built on your laptop | Image pushed to **ECR**, your private image shelf in AWS | Cloud servers can't see your laptop |
| `NodePort` front desk on door 30080 | `LoadBalancer` front desk: AWS gives you a public address | Cloud servers are not your laptop |
| No size limits | Each copy says how much CPU and memory it needs (**resources**) | So the cloud can pick a server with room |
| Plain YAML files (2A) | A **Helm chart** with values (2B) | One command installs, upgrades and rolls back |

## New words

- **EKS** — Kubernetes that AWS runs for you. `kubectl` works exactly the same.
- **ECR** — Your private image shelf in AWS. The cluster pulls your app's image from here.
- **LoadBalancer Service** — Asks AWS for a real load balancer with a public address.
- **Helm chart** — A folder of YAML **templates** with blanks.
- **Values file** — The answers that fill in the blanks. Same chart + different values = a
  different app or environment.
- **Release** — One installed copy of a chart (here: `fraud-api`). Each upgrade is a numbered
  **revision** you can roll back to.

## Step 0 — Build the image and push it to ECR

```bash
bash deploy.sh build
```

This logs in to ECR, builds this chapter's app ([`../fraud-api`](../fraud-api)) for
`linux/amd64` (the kind of computer EKS uses, even if your laptop is a newer Mac), tags it with
your git commit (for example `3f9c2ab`), and pushes it.

**What you should see:** `[OK] Pushed ...zero2ai-dev/fraud-api:3f9c2ab`.

---

## Phase 2A — Same YAML as your laptop

Open [`phase2a-yaml/deployment.yaml`](phase2a-yaml/deployment.yaml) next to your laptop's
[`../deployment.yaml`](../deployment.yaml). Only two things changed: the **image** now comes
from ECR, and each copy declares its **resources**.

[`phase2a-yaml/service.yaml`](phase2a-yaml/service.yaml) keeps the same name and ports, but
`NodePort` becomes `LoadBalancer`: you get a real AWS **Network Load Balancer** with a public
address.

```bash
bash deploy.sh 2a
bash test.sh 2a
```

**What you should see:** `deploy.sh 2a` ends with two pods `Running` and
`[OK] Phase 2A deployed`. `test.sh 2a` calls `/health`, `/info` and `/predict` through a tunnel
(exactly like your laptop), then through the public load balancer, and ends with
`[OK] Phase 2A checks passed`. A brand-new load balancer can take 2 to 4 minutes to answer;
the script waits for it.

What `test.sh 2a` does, by hand:

```bash
kubectl -n zero2ai port-forward service/zero2ai-fraud-svc 8080:80   # same tunnel as your laptop
curl http://localhost:8080/health                                   # in a second terminal
kubectl -n zero2ai get service zero2ai-fraud-svc                    # EXTERNAL-IP = the public address
curl http://<that-address>/health
```

`-n zero2ai` means "in the `zero2ai` namespace", the folder on the cluster where every chapter's
app lives.

Try the laptop tricks. They work the same in the cloud:

```bash
kubectl -n zero2ai get pods -o wide                     # see which server and zone each copy is on
kubectl -n zero2ai delete pod <pod-name>                # self-healing, in the cloud
kubectl -n zero2ai scale deployment zero2ai-fraud-api --replicas=4
```

---

## Phase 2B — Package it with Helm

Copying YAML files around doesn't scale to 9 chapters and 3 environments. Helm fixes that:
**one chart**, [`../helm/zero2ai-app`](../helm/zero2ai-app), used by every chapter. Look inside:

- `templates/deployment.yaml` — the Deployment you know, with blanks like
  `replicas: {{ .Values.replicaCount }}`.
- `values.yaml` — the default answers.
- [`phase2b-helm/values.yaml`](phase2b-helm/values.yaml) — **this chapter's** answers (2 copies,
  port 5000, health path `/health`, an inside-only `ClusterIP` front desk).

```bash
bash deploy.sh 2b
bash test.sh 2b
```

`deploy.sh 2b` removes Phase 2A (and its load balancer, so you stop paying for it), then runs:

```bash
helm upgrade --install fraud-api ../helm/zero2ai-app -n zero2ai \
  -f phase2b-helm/values.yaml --set image.repository=... --set image.tag=... --wait
```

**What you should see:** `[OK] Phase 2B deployed`, then `test.sh 2b` tests it **like on your
laptop** (port-forward + curl) and runs `helm test fraud-api`, which starts a tiny pod *inside*
the cluster that calls `/health`. It ends with `[OK] Phase 2B checks passed`.

Helm superpowers to try:

```bash
helm list -n zero2ai                                   # what's installed
helm get values fraud-api -n zero2ai                   # the answers used
helm template fraud-api ../helm/zero2ai-app -f phase2b-helm/values.yaml \
  --set image.repository=demo --set image.tag=v1      # see the YAML Helm makes, offline
helm upgrade fraud-api ../helm/zero2ai-app -n zero2ai --reuse-values --set replicaCount=3
helm history fraud-api -n zero2ai                      # numbered revisions
helm rollback fraud-api 1 -n zero2ai                   # back to revision 1
```

## Try it yourself

- In `phase2b-helm/values.yaml` change `replicaCount` to `3`, run `bash deploy.sh 2b`, then
  `helm history fraud-api -n zero2ai`. Roll back to the previous revision.
- Run the `helm template` command above and find the `replicas:` line in its output.

## If something breaks

- **`Cluster zero2ai-eks-dev not found`** → Build the platform first: [../PLATFORM.md](../PLATFORM.md).
- **`No image recorded for 'fraud-api'`** → Run Step 0 first: `bash deploy.sh build`.
- **`Cannot connect to the Docker daemon`** during `build` → Open Docker Desktop and wait for
  *Engine running*.
- **`test.sh 2a`: the tunnel works but the load balancer never answers** → New load balancers take
  2 to 4 minutes plus DNS time. Run `bash test.sh 2a` again.
- **`Error: UPGRADE FAILED: ... has no deployed releases`** → A failed first install. Run
  `helm uninstall fraud-api -n zero2ai`, then `bash deploy.sh 2b` again.
- **Pods `ImagePullBackOff` in the cloud** → The cluster can't find the image in ECR. Run
  `bash deploy.sh build` again, then the deploy step.

## Clean up

```bash
bash down.sh                                          # remove this chapter's app (the cluster stays)
bash ../scripts/platform-down.sh dev                  # delete the whole platform when you're done for the day
```

**What you should see:** `[OK] Chapter 10 app removed`, and later the platform destroy finishing
with no errors. After `platform-down.sh`, nothing from this course is costing you money.

## Next: Phase 3

Your app runs in the cloud. Now make it production-grade, the way large companies run it:
**[PRODUCTION.md](PRODUCTION.md)**.
