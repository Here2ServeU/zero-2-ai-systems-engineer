# Chapter 10 — Cloud track: run many copies on AWS EKS

> You ran the fraud API on your laptop's Kubernetes. Now run the **same app** on a real cloud
> cluster, in three phases. Build the platform first: [platform/README.md](../../platform/README.md).

**Labels:** 💳 Needs an account that may cost money · 🌐 Needs the internet · 🧑‍🤝‍🧑 Easier with a helper the first time

---

## New words

- **EKS** — Kubernetes that AWS runs for you. `kubectl` works exactly the same.
- **ECR** — Your private image shelf in AWS. The cluster pulls your lunchbox recipe from here.
- **LoadBalancer Service** — Asks AWS for a real load balancer with a public address.
- **Helm chart** — A folder of YAML **templates** with blanks.
- **Values file** — The answers that fill in the blanks. Same chart + different values = a
  different app or environment.
- **Release** — One installed copy of a chart (here: `fraud-api`). Each upgrade is a numbered
  **revision** you can roll back to.
- **Ingress** — The public entrance; on EKS it becomes an **Application Load Balancer (ALB)**.
- **HPA (HorizontalPodAutoscaler)** — Adds copies when they're busy, removes them when quiet.
- **PDB (PodDisruptionBudget)** — "Never take down more than this many copies at once."

## Step 0 — Point at the cluster and push your image

From this folder (`chapter-10-kubernetes/cloud`):

```bash
bash deploy.sh build
```

This logs in to ECR, builds `chapter-06-docker` for `linux/amd64`, tags it with your git commit
(e.g. `3f9c2ab`), and pushes it. **What you should see:** `✔ Pushed ...zero2ai-dev/fraud-api:3f9c2ab`.

---

## Phase 1 — Lift and shift (same YAML as your laptop)

Open [`phase1/deployment.yaml`](phase1/deployment.yaml) next to your laptop's
[`../deployment.yaml`](../deployment.yaml). Only two things changed: the **image** now comes from
ECR, and each copy declares how much CPU/memory it needs (**resources**) so the cloud scheduler
can place it.

[`phase1/service.yaml`](phase1/service.yaml) keeps the same name and ports, but `NodePort`
becomes `LoadBalancer`: in the cloud you don't knock on a node's door, you get a real AWS
**Network Load Balancer** with a public address.

```bash
bash deploy.sh 1
bash test.sh 1
```

`test.sh 1` does exactly what you did locally, **then** goes through the public load balancer:

```bash
kubectl -n zero2ai port-forward service/zero2ai-fraud-svc 8080:80   # same tunnel as your laptop
curl http://localhost:8080/health
curl http://<the-nlb-address>/health                                # the public way
```

Try the laptop tricks — they work the same in the cloud:

```bash
kubectl -n zero2ai get pods -o wide                     # see which node and zone each copy is on
kubectl -n zero2ai delete pod <pod-name>                # self-healing, in the cloud
kubectl -n zero2ai scale deployment zero2ai-fraud-api --replicas=4
```

---

## Phase 2 — Package it with Helm

Copying YAML files around doesn't scale to 9 chapters × 3 environments. Helm fixes that:
**one chart**, [`platform/helm/zero2ai-app`](../../platform/helm/zero2ai-app), used by every
chapter. Look inside:

- `templates/deployment.yaml` — the Deployment you know, with blanks like
  `replicas: {{ .Values.replicaCount }}` and `image: {{ include "app.image" . }}`.
- `values.yaml` — the default answers.
- [`phase2/values.yaml`](phase2/values.yaml) — **this chapter's** answers (2 copies, port 5000,
  health path `/health`, inside-only `ClusterIP` service).

```bash
bash deploy.sh 2
bash test.sh 2
```

`deploy.sh 2` removes Phase 1 (and its load balancer), then runs:

```bash
helm upgrade --install fraud-api platform/helm/zero2ai-app -n zero2ai \
  -f phase2/values.yaml --set image.repository=... --set image.tag=... --wait
```

`test.sh 2` tests it **like on your laptop** — port-forward + curl — and then runs
`helm test fraud-api`, which starts a tiny pod *inside* the cluster that calls `/health` through
the Service.

Helm superpowers to try:

```bash
helm list -n zero2ai                                   # what's installed
helm get values fraud-api -n zero2ai                   # the answers used
helm template fraud-api ../../platform/helm/zero2ai-app -f phase2/values.yaml \
  --set image.repository=demo --set image.tag=v1      # see the YAML Helm generates, offline
helm upgrade fraud-api ../../platform/helm/zero2ai-app -n zero2ai --reuse-values --set replicaCount=3
helm history fraud-api -n zero2ai                      # numbered revisions
helm rollback fraud-api 1 -n zero2ai                   # back to revision 1
```

---

## Phase 3 — Production platform

Same release, one more values file on top:
[`phase3/values.yaml`](phase3/values.yaml) (+ [`values-prod.yaml`](phase3/values-prod.yaml) when
`ENV=prod`).

| Setting | What it does | Why production needs it |
|---|---|---|
| `command: gunicorn ...` | A real web server: 2 processes × 4 threads per copy | Flask's built-in server is for development only |
| `autoscaling` | HPA: 2–6 copies, target 70% CPU | Handles busy hours without paying for idle copies |
| `pdb.minAvailable: 1` | PodDisruptionBudget | Node upgrades never take every copy down |
| `topologySpread` | Spread copies across zones and nodes | One data-center outage doesn't take the app down |
| `networkPolicy` | Only the load balancer and this namespace may connect | Limits damage if something else is compromised |
| `securityContext` (chart default) | Non-root, read-only disk, no Linux capabilities | Hardening; passes Pod Security "restricted" |
| `ingress` | Joins the **platform ALB** on port 8010, with health checks; HTTPS when you add a certificate | One stable public address, no extra load balancer to pay for |
| `--atomic` (in deploy.sh) | If the upgrade fails, Helm rolls back by itself | No half-broken releases |

```bash
bash deploy.sh 3
bash test.sh 3
```

**What you should see:** `helm test` passes, then `/health`, `/info`, `/predict` answer through
the **shared platform ALB on port 8010**, `http://k8s-zero2ai-....elb.amazonaws.com:8010`, then the
HPA, PDB and NetworkPolicy are listed. Open the same address in your browser
(`.../health`), or run `bash ../../platform/scripts/urls.sh` to list every address.

Watch autoscaling work (second terminal: `kubectl -n zero2ai get hpa fraud-api -w`):

```bash
kubectl -n zero2ai run load --rm -it --image=curlimages/curl --restart=Never -- \
  sh -c 'while true; do curl -s -o /dev/null -X POST http://fraud-api/predict \
  -H "Content-Type: application/json" \
  -d "{\"amount\":950,\"hour\":3,\"is_weekend\":0,\"amount_vs_avg\":2.8,\"is_large_txn\":1,\"is_late_night\":1,\"merch_txn_ct\":4}"; done'
```

Press Ctrl+C to stop; about 5 minutes later the extra copies are removed.

Roll back to Phase 2 with one command — that's the point of Helm:

```bash
helm history fraud-api -n zero2ai
helm rollback fraud-api <phase-2-revision> -n zero2ai
```

### The same thing in qa and prod

```bash
bash ../../platform/scripts/platform-up.sh prod     # once (costs more: see platform README)
ENV=prod bash deploy.sh build
ENV=prod bash deploy.sh 3
ENV=prod bash test.sh 3
```

Same chart, same values, plus `values-prod.yaml` (3–10 copies, `minAvailable: 2`). The prod
registry has **immutable** tags, so the image you tested is exactly the image that runs.

---

## Try it yourself

- In `phase2/values.yaml` change `replicaCount` to `3`, run `bash deploy.sh 2`, then
  `helm history fraud-api -n zero2ai`. Roll back to the previous revision.
- Run `helm template` (above) for Phase 2 and Phase 3 and compare the output. Which Kubernetes
  objects only exist in Phase 3?
- Delete a node's worth of pods: `kubectl -n zero2ai delete pod -l app.kubernetes.io/instance=fraud-api`.
  How long until `/health` answers again through the ALB? (With the PDB and 2+ copies, a node
  *drain* would never take them all at once.)

## If something breaks

- **`test.sh 1` port-forward works but the NLB never answers** → New load balancers take 2–4
  minutes plus DNS time. Rerun `bash test.sh 1`.
- **`Error: UPGRADE FAILED: ... has no deployed releases`** → A failed first install. Run
  `helm uninstall fraud-api -n zero2ai`, then `bash deploy.sh 2` again.
- **Phase 3 pods `CreateContainerConfigError: container has runAsNonRoot and image has
  non-numeric user`** → The chart sets `runAsUser: 1000` to avoid this; make sure you're using
  this repo's chart, not an older copy.
- **HPA shows `<unknown>/70%`** → metrics-server needs ~1 minute after pods start.
  `kubectl top pods -n zero2ai` should show numbers first.

## Clean up

```bash
bash down.sh                                            # remove this chapter's app
bash ../../platform/scripts/platform-down.sh dev        # when you're done for the day
```

## Where to next

[Chapter 11's cloud track](../../chapter-11-monitoring/cloud/README.md): your app's metrics,
collected by Prometheus on the cluster.
