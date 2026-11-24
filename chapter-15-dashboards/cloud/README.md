# Chapter 15 — Phase 2: Promote it to the cloud (dashboards as code on EKS)

> Phase 1 (your laptop) is in [../README.md](../README.md). Phase 3 (production) is in
> [PRODUCTION.md](PRODUCTION.md).
> Build the shared platform first: [../../chapter-10-kubernetes/PLATFORM.md](../../chapter-10-kubernetes/PLATFORM.md).

**Labels:** Needs an AWS account that costs money · Needs the internet · Easier with a helper the first time

---

> **Money first.** The shared platform costs roughly $0.15-0.30 per hour while it exists (see
> PLATFORM.md). This chapter adds almost nothing on top in Phase 2 (two small pods). Always
> finish with the clean-up steps at the bottom. Get permission first if the AWS account isn't
> yours.

## What changes from your laptop to the cloud, and why

| On your laptop (Phase 1) | On EKS (Phase 2) | Why |
|---|---|---|
| `docker compose` started the app, Prometheus **and** Grafana | Only the app is new. Prometheus and Grafana already run on the cluster for every chapter | One shared monitoring system is cheaper and gives one place to look |
| `prometheus.yml` listed the app's address by hand | A **ServiceMonitor** tells Prometheus "collect from every copy behind this Service" | In the cloud, copies come and go and change addresses. The ServiceMonitor finds them automatically |
| You built the dashboard by clicking, and lost it on `docker compose down` | The dashboard is a file, [`dashboard.json`](dashboard.json), installed with the app | **Dashboards as code**: reviewed, versioned in git, rebuilt automatically |
| Grafana password `zero2ai123` in a file | A random password made by Terraform and kept in a Kubernetes Secret | Real passwords never go in git |
| One copy of the app | Two copies | If one copy dies, the other keeps answering |

## New words

- **ServiceMonitor** — a small Kubernetes file that tells Prometheus which Service to collect
  metrics from, and on which port. It replaces `scrape_configs` in `prometheus.yml`.
- **Dashboard as code** — the dashboard saved as a JSON file in git
  ([`dashboard.json`](dashboard.json)), so it's reviewed, versioned and recreated automatically.
- **ConfigMap** — a Kubernetes object that holds a small file or settings.
- **Grafana sidecar** — a helper container next to Grafana that watches for any ConfigMap with
  the label `grafana_dashboard: "1"` and loads it as a dashboard within seconds.
- **port-forward** — a private tunnel from your laptop to something inside the cluster, so
  `http://localhost:9090` reaches the cluster's Prometheus.

## Before you start

1. The platform is up: `bash chapter-10-kubernetes/scripts/platform-up.sh dev` from the top of
   the repo ([PLATFORM.md](../../chapter-10-kubernetes/PLATFORM.md), about 20 minutes).
2. Your tools work: `bash chapter-10-kubernetes/scripts/check-tools.sh` from the top of the repo.
3. You did Phase 1, so you know what the app should answer.

Every command below runs from **this folder**: `chapter-15-dashboards/cloud`.

```bash
cd chapter-15-dashboards/cloud
```

---

## Step 0 — Build the image and push it to the cloud

From `chapter-15-dashboards/cloud`:

```bash
bash deploy.sh build
```

This logs in to **ECR** (your private image shelf in AWS), builds the same `Dockerfile` you used
in Phase 1 for `linux/amd64` (the kind of computer EKS runs), tags it with your git commit, and
pushes it.

**What you should see:** build and push lines, ending with
`[OK] Pushed <account>.dkr.ecr.us-east-1.amazonaws.com/zero2ai-dev/monitored-api:<tag>`.

---

## Phase 2A — Plain YAML (the app + a ServiceMonitor)

Three small files in [`phase2a-yaml/`](phase2a-yaml):

- [`deployment.yaml`](phase2a-yaml/deployment.yaml) — run 2 copies of the image. Each copy opens
  door 5000 (the app) and door 8000 (the numbers), like on your laptop. It also says how much
  CPU and memory each copy needs, and has a **readiness probe**: Kubernetes calls `/health` and
  only sends traffic to copies that answer.
- [`service.yaml`](phase2a-yaml/service.yaml) — one stable name (`monitored-api-p1`) in front of
  both copies, with an `http` port and a `metrics` port.
- [`servicemonitor.yaml`](phase2a-yaml/servicemonitor.yaml) — "Prometheus, collect from the
  `metrics` port of this Service every 15 seconds." This is your old `prometheus.yml`, cloud
  style.

From `chapter-15-dashboards/cloud`:

```bash
bash deploy.sh 2a
```

**What you should see:** `kubectl apply` lines (`deployment.apps/monitored-api-p1 created`,
`service/monitored-api-p1 created`, `servicemonitor.monitoring.coreos.com/monitored-api-p1 created`),
then `deployment "monitored-api-p1" successfully rolled out`, then
`[OK] Phase 2A deployed. Test it: bash test.sh 2a`.

```bash
bash test.sh 2a
```

`test.sh 2a` starts a tiny helper pod that sends random payments to the app from **inside** the
cluster for 45 seconds, then opens a tunnel to the cluster's Prometheus and checks it has the
app's `fraud_predictions_total` numbers (it retries for up to a minute, because Prometheus
collects every 15 seconds).

**What you should see:** `[OK] Done. Look at the dashboard.`, then a line of JSON from
Prometheus containing `"value"`, then `[OK] Prometheus has the app's numbers` and finally
`[OK] Phase 2A checks passed`.

In Phase 2A there is no dashboard yet. You could click one together in the cluster's Grafana,
exactly like Phase 1. Phase 2B does it properly.

---

## Phase 2B — Helm, with the dashboard included

Instead of separate YAML files, you install the course's shared Helm chart
([`chapter-10-kubernetes/helm/zero2ai-app`](../../chapter-10-kubernetes/helm/zero2ai-app)) with
this chapter's settings in [`phase2b-helm/values.yaml`](phase2b-helm/values.yaml):

- `containerPort: 5000` and `metricsPort: 8000` — the app's two doors.
- `replicaCount: 2` — two copies.
- `serviceMonitor.enabled: true` — the chart makes the ServiceMonitor for you.
- `grafanaDashboard.enabled: true` — the chart turns `dashboard.json` into a ConfigMap labelled
  `grafana_dashboard: "1"`, and Grafana's sidecar loads it.

`deploy.sh 2b` removes the Phase 2A objects, then runs
`helm upgrade --install monitored-api ... --set-file grafanaDashboard.json=dashboard.json`.
The chart also adds safety settings: the app runs as a non-root user with a read-only file
system.

From `chapter-15-dashboards/cloud`:

```bash
bash deploy.sh 2b
```

**What you should see:** Helm output with `STATUS: deployed`, a short `helm history` table, and
`[OK] Phase 2B deployed. Test it: bash test.sh 2b`.

```bash
bash test.sh 2b
```

This sends traffic, checks Prometheus, runs `helm test` (a tiny pod that calls `/health`), and
asks Grafana's API whether it loaded the dashboard.

**What you should see:** `[OK] Prometheus has the app's numbers`, `[OK] helm test monitored-api`,
a line `"title":"Zero2AI Fraud API (Chapter 15)"`, `[OK] Grafana loaded the dashboard` and
`[OK] Phase 2B checks passed`.

### Watch the dashboard

Send 5 minutes of traffic, then open Grafana. From `chapter-15-dashboards/cloud`:

```bash
bash load.sh 300
```

**What you should see:** `==> Sending traffic to monitored-api for 300 seconds`, then (after 5
minutes) `[OK] Done. Look at the dashboard.` Open a second terminal for the next commands while
it runs.

Find Grafana's address and password. From `chapter-15-dashboards/cloud`:

```bash
bash ../../chapter-10-kubernetes/scripts/urls.sh
terraform -chdir=../../chapter-10-kubernetes/terraform/eks-addons output -raw grafana_admin_password
```

**What you should see:** a list of addresses including one ending in `:3000` (Grafana), then the
Grafana password on one line. Open `http://<platform-alb>:3000` in your browser, log in as
`admin` with that password, and open **Dashboards -> Zero2AI Fraud API (Chapter 15)**.

No load balancer address yet? Use a tunnel instead:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Then open http://localhost:3000. Press Ctrl+C to close the tunnel when you're done.

**What you should see on the dashboard:** six panels: predictions per second (fraud vs legit),
model latency p50/p95, fraud share, requests in progress, healthy copies, and CPU used per copy.
They fill in as `load.sh` sends traffic.

---

## Explore with kubectl and helm

From anywhere (these talk to the cluster, not to files):

```bash
kubectl -n zero2ai get pods -l app.kubernetes.io/instance=monitored-api -o wide   # your copies and their nodes
kubectl -n zero2ai get servicemonitor                                             # what Prometheus is told to collect
kubectl -n zero2ai get configmap monitored-api-dashboard                          # the dashboard, stored in the cluster
kubectl -n zero2ai logs deploy/monitored-api --tail=20                            # the app's latest log lines
helm list -n zero2ai                                                              # installed releases
helm history monitored-api -n zero2ai                                             # every upgrade, numbered
helm get values monitored-api -n zero2ai                                          # the settings Helm used
```

**What you should see:** two `Running` pods; a ServiceMonitor named `monitored-api`; a ConfigMap
named `monitored-api-dashboard`; Flask log lines like `"POST /predict HTTP/1.1" 200`; and your
release with `STATUS deployed`.

Try **dashboards as code** for real: change a panel title in [`dashboard.json`](dashboard.json),
run `bash deploy.sh 2b` again, and reload Grafana. The new title appears without any clicking.

---

## If something breaks

- **`Cluster zero2ai-eks-dev not found`** -> Build the platform first:
  `bash chapter-10-kubernetes/scripts/platform-up.sh dev` from the top of the repo.
- **`No image recorded for 'monitored-api'`** -> Run `bash deploy.sh build` first.
- **`docker push` says `denied` or `no basic auth credentials`** -> The ECR login expired. Run
  `bash deploy.sh build` again; it logs in again.
- **`Usage: deploy.sh <build|2a|2b|3>`** -> You typed a phase that doesn't exist (the old `1`,
  `2`, `3` numbering is gone). Use `build`, `2a`, `2b` or `3`.
- **Pods stuck in `Pending`** -> The cluster is out of room. `kubectl -n zero2ai describe pod <name>`
  shows why. The Cluster Autoscaler adds a node within a few minutes.
- **`Prometheus has no fraud_predictions_total yet`** -> Prometheus collects every 15 seconds and
  needs a moment to notice a new ServiceMonitor. Wait a minute and run `bash test.sh 2a` (or
  `2b`) again. Still nothing? Check the pods are `Running`:
  `kubectl -n zero2ai get pods`.
- **Grafana has no "Zero2AI Fraud API" dashboard** -> Check the ConfigMap exists:
  `kubectl -n zero2ai get configmap monitored-api-dashboard --show-labels` (the labels must
  include `grafana_dashboard=1`). Then wait 30 seconds for the sidecar and reload.
- **Dashboard panels say "No data"** -> Run `bash load.sh 120` and set the time range to **Last
  15 minutes**.
- **`port-forward` says `address already in use`** -> Something on your laptop already uses port
  3000 or 9090 (maybe the Phase 1 Compose stack). Run `docker compose down` in
  `chapter-15-dashboards`, or close the other program.

## Clean up

Remove this chapter's app (the cluster keeps running). From `chapter-15-dashboards/cloud`:

```bash
bash down.sh
```

**What you should see:** `[OK] Chapter 15 removed`.

Finished for the day? Destroy the whole platform so it stops costing money. From
`chapter-15-dashboards/cloud`:

```bash
bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev
```

**What you should see:** Terraform destroying resources, ending with a message that the platform
is gone. Check the AWS console the first few times to be sure.

## Next

Make it production-grade with alerts and safety nets: [PRODUCTION.md](PRODUCTION.md).
