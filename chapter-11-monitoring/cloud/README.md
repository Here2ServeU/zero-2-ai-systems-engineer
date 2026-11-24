# Chapter 11 — Phase 2: Promote it to the cloud

> Your metrics app moves from your laptop to the AWS EKS cluster from Chapter 10, and the
> cluster's Prometheus starts collecting its numbers by itself.
> Phase 1 (laptop) is in [../README.md](../README.md). Phase 3 is in [PRODUCTION.md](PRODUCTION.md).

**Labels:** Needs an account that may cost money · Needs the internet · Easier with a helper the first time

---

> **Money first.** Everything here runs on the shared platform from
> [chapter-10-kubernetes/PLATFORM.md](../../chapter-10-kubernetes/PLATFORM.md). Build it once
> (`bash chapter-10-kubernetes/scripts/platform-up.sh dev`, about 20 minutes). It costs money
> every hour it exists, even when idle. A 3-hour dev session is roughly $0.50 to $1. **Destroy it
> when you stop** (see [Clean up](#clean-up)). Get permission first if the AWS account is not yours.

## What changes from laptop to cloud, and why

| On your laptop (Phase 1) | In the cloud (Phase 2) | Why |
|---|---|---|
| You ran one copy with `python` or `docker run` | Kubernetes runs **2 copies** of the same container | If one copy crashes, the other keeps answering |
| The image lived only on your laptop | The image is pushed to **ECR**, AWS's private image shelf | The cluster's computers must be able to download it |
| *You* typed `curl http://localhost:8000` to read the numbers | **Prometheus** reads every copy's port 8000 every 15 seconds | Nobody can watch numbers by hand all night |
| The numbers disappeared when you pressed Ctrl+C | Prometheus keeps the **history** (2 days in dev) | So you can ask "what happened at 3 a.m.?" |
| No pictures | **Grafana** can draw graphs from Prometheus | People spot problems faster in a picture |

## New words

- **ServiceMonitor** — A small wish-list file that tells Prometheus: "collect the numbers from
  the copies behind this Service, on its port named `metrics`, every 15 seconds". It is how
  Kubernetes apps sign up to be watched.
- **Target** — One copy Prometheus collects from. In Prometheus, the metric `up` is `1` if the
  target answered and `0` if it did not.
- **PromQL** — Prometheus's question language. `up{service="metrics-api"}` means "show `up` for
  the targets whose `service` label is `metrics-api`".
- **Port-forward** — A private tunnel from your laptop to something inside the cluster, so
  `localhost` reaches it. The test scripts open and close these for you.
- **Release** — One installed copy of a Helm chart. Each upgrade is a numbered **revision**.

## What is in this folder

```text
chapter-11-monitoring/cloud/
├── deploy.sh                 # build | 2a | 2b | 3
├── test.sh                   # 2a | 2b | 3
├── down.sh                   # remove this chapter's app (keeps the cluster)
├── phase2a-yaml/             # Phase 2A: plain Kubernetes YAML
│   ├── deployment.yaml
│   ├── service.yaml
│   └── servicemonitor.yaml
├── phase2b-helm/values.yaml  # Phase 2B: answers for the shared Helm chart
├── phase3-production/values.yaml   # Phase 3: see PRODUCTION.md
└── PRODUCTION.md
```

Run every command below **from this folder**. From the top of the course repo:

```bash
cd chapter-11-monitoring/cloud
```

## Step 0 — Build and push the image

```bash
bash deploy.sh build
```

This connects `kubectl` to the cluster, logs in to ECR, builds the **same Dockerfile you used in
Phase 1** (for `linux/amd64`, which is what the EKS computers run, even if your laptop is an
Apple Silicon Mac), and pushes it. The image tag is your git commit, for example `3f9c2ab`.

**What you should see:** lines starting with `==>` for each stage, then
`[OK] Pushed <account>.dkr.ecr.us-east-1.amazonaws.com/zero2ai-dev/metrics-api:<tag>`.

---

## Phase 2A — Plain YAML, plus a ServiceMonitor

Open the three files in [`phase2a-yaml/`](phase2a-yaml):

- [`deployment.yaml`](phase2a-yaml/deployment.yaml) — 2 copies of your container. Each copy
  opens the same two doors as on your laptop: `5000` (named `http`) and `8000` (named
  `metrics`). It also says how much CPU and memory each copy needs (**resources**), and uses
  `/health` to check each copy is alive (**probes**).
- [`service.yaml`](phase2a-yaml/service.yaml) — one stable name, `metrics-api-p1`, in front of
  both copies. Port 80 goes to the app's 5000; port 8000 goes to the metrics door.
- [`servicemonitor.yaml`](phase2a-yaml/servicemonitor.yaml) — the new piece: "Prometheus,
  please collect from the Service labelled `app: metrics-api-p1`, port `metrics`, every 15 seconds."

The names end in `-p1` so they never clash with the Helm version in Phase 2B.

```bash
bash deploy.sh 2a
```

`deploy.sh 2a` removes the Phase 2B/3 Helm release if it exists, puts your image name into the
YAML (the files say `__IMAGE__`) and runs `kubectl apply`, then waits for the copies to be ready.

**What you should see:**

```text
deployment.apps/metrics-api-p1 created
service/metrics-api-p1 created
servicemonitor.monitoring.coreos.com/metrics-api-p1 created
deployment "metrics-api-p1" successfully rolled out
[OK] Phase 2A deployed. Test it: bash test.sh 2a
```

(On a second run, `created` becomes `configured` or `unchanged`.)

```bash
bash test.sh 2a
```

`test.sh 2a` does what you did on your laptop, through port-forward tunnels: knocks on
`/health`, sends five `/predict` requests, and reads the metrics door. Then it asks the cluster's
Prometheus: "are you collecting `metrics-api-p1`?" (Prometheus needs up to a minute to find a new
target, so the script retries.)

**What you should see:**

```text
GET http://localhost:8080/health
{"status":"healthy"}
GET http://localhost:8000/metrics (api_ lines only)
api_requests_total{endpoint="/health",method="GET",status="200"} ...
api_requests_total{endpoint="/predict",method="POST",status="200"} ...
...
==> Asking Prometheus: is it scraping metrics-api-p1? (can take up to 1 minute after deploy)
{"status":"success","data":{"resultType":"vector","result":[{"metric":{"__name__":"up",...,"service":"metrics-api-p1"},"value":[...,"1"]}, ...]}}
[OK] Prometheus is collecting metrics-api-p1
[OK] Phase 2A checks passed
```

The `"1"` at the end of each result means "this copy answered". There is one result per copy.

> The metrics door answers on any path, so `/metrics` (what Prometheus asks for) and `/` (what
> you typed on your laptop) show the same numbers.

---

## Phase 2B — The same app, packaged with Helm

Copying YAML files around does not scale to many apps and environments. Helm fixes that: the
**one shared chart** from Chapter 10,
[`chapter-10-kubernetes/helm/zero2ai-app`](../../chapter-10-kubernetes/helm/zero2ai-app), plus
this chapter's short answers file, [`phase2b-helm/values.yaml`](phase2b-helm/values.yaml):

- `command: ["python", "app_with_metrics.py"]` and `containerPort: 5000` — run your app.
- `metricsPort: 8000` — the chart adds the `metrics` door to each copy and to the Service.
- `serviceMonitor.enabled: true` — the chart writes the ServiceMonitor for you.

The chart also adds safety settings you did not have to write in 2A: the app runs as a non-root
user with a read-only disk, and Kubernetes waits for a copy to pass `/health` before sending it
visitors.

```bash
bash deploy.sh 2b
```

`deploy.sh 2b` deletes the Phase 2A objects, then runs `helm upgrade --install metrics-api ...`
with your image and waits until the copies are ready.

**What you should see:** `Release "metrics-api" does not exist. Installing it now.` (first time
only), `STATUS: deployed`, a short revision table from `helm history`, then
`[OK] Phase 2B deployed. Test it: bash test.sh 2b`.

```bash
bash test.sh 2b
```

Same checks as 2A, plus `helm test`, which starts a tiny pod inside the cluster that calls
`/health` through the Service.

**What you should see:** the same `GET` lines and `api_` metric lines as 2A, then
`Phase: Succeeded` and `{"status":"healthy"}` from the test pod, then
`[OK] Prometheus is collecting metrics-api` and `[OK] Phase 2B checks passed`.

---

## Explore it yourself

All from this folder, after Phase 2B. Open a **second terminal** for each port-forward and leave
it running; press Ctrl+C in it when you are done.

```bash
kubectl -n zero2ai get pods,svc,servicemonitor -l app.kubernetes.io/instance=metrics-api
```

**What you should see:** 2 pods `Running` with `READY 1/1`, a Service `metrics-api` with ports
`80/TCP,8000/TCP`, and a ServiceMonitor `metrics-api`. You may also see a pod
`metrics-api-test` marked `Completed`: that is the finished `helm test` pod.

Read one copy's numbers yourself, like on your laptop:

```bash
kubectl -n zero2ai port-forward svc/metrics-api 8080:80 8000:8000
```

Then, in another terminal:

```bash
for i in 1 2 3 4 5 6 7 8 9 10; do curl -s -X POST http://localhost:8080/predict -H "Content-Type: application/json" -d '{"amount": 900}'; echo; done
curl -s http://localhost:8000 | grep api_requests_total
```

**What you should see:** ten `{"prediction":1}` lines, then counter lines. (A Service sends each
visit to either copy, and the numbers door you reach belongs to one copy, so its count may be
lower than 10. Prometheus adds all copies together for you.)

Look inside Prometheus:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Open `http://localhost:9090` in your browser. (Or use the platform ALB address on port 9090 from
`bash ../../chapter-10-kubernetes/scripts/urls.sh`; that one only opens from your own IP.)

- **Status -> Targets** (in newer versions **Status -> Target health**): find
  `serviceMonitor/zero2ai/metrics-api/0` with 2 targets `UP`.
- **Query** page (called **Graph** in older versions), try these PromQL questions one at a time:

  | Question | PromQL |
  |---|---|
  | Is each copy answering? | `up{service="metrics-api"}` |
  | Visits per second, by door | `sum by (endpoint) (rate(api_requests_total{service="metrics-api"}[1m]))` |
  | How long do 95% of predictions take? | `histogram_quantile(0.95, sum by (le) (rate(api_request_duration_seconds_bucket{service="metrics-api"}[5m])))` |
  | How much memory does each copy use? | `container_memory_working_set_bytes{namespace="zero2ai", pod=~"metrics-api-.*", container="app"}` |

  `rate(...[1m])` means "how fast did this counter grow, per second, over the last minute". Run
  the `curl` loop above again so there is something to see.

The same question from the command line (no browser):

```bash
curl -sG http://localhost:9090/api/v1/query --data-urlencode 'query=up{service="metrics-api"}'
```

**What you should see:** JSON with two results, each ending in `"1"`.

Draw it in Grafana:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Open `http://localhost:3000`, user `admin`. The password is (run from the top of the course repo):

```bash
terraform -chdir=chapter-10-kubernetes/terraform/eks-addons output -raw grafana_admin_password
```

Go to **Explore**, pick the **Prometheus** data source, paste a query from the table, and click
**Run query**. Chapter 15 turns these into a saved dashboard.

Helm commands to try:

```bash
helm list -n zero2ai                              # what is installed
helm get values metrics-api -n zero2ai            # the answers Helm used
helm history metrics-api -n zero2ai               # numbered revisions
helm template metrics-api ../../chapter-10-kubernetes/helm/zero2ai-app -f phase2b-helm/values.yaml \
  --set image.repository=demo --set image.tag=v1  # see the YAML Helm makes, offline
```

## If something breaks

- **`[ERROR] Cluster zero2ai-eks-dev not found`** → Build the platform first:
  `bash ../../chapter-10-kubernetes/scripts/platform-up.sh dev` (from this folder), or use the
  same `ENV` you built.
- **`[ERROR] No image recorded for 'metrics-api' in dev`** → Run `bash deploy.sh build` first.
- **`Usage: deploy.sh <build|2a|2b|3>`** → You typed an old or wrong phase name. Use `build`,
  `2a`, `2b` or `3` (not `1` or `2`).
- **`bash: deploy.sh: No such file or directory`** → You are not in `chapter-11-monitoring/cloud`.
- **`docker push` says `denied` or `no basic auth credentials`** → Your ECR login expired. Run
  `bash deploy.sh build` again; it logs in each time.
- **Pods stay in `ImagePullBackOff`** → The image is missing or for the wrong computer type.
  Rebuild with `bash deploy.sh build` (it always builds `linux/amd64`), then rerun the deploy step.
  Details: `kubectl -n zero2ai describe pod <pod-name>`.
- **Pods in `CrashLoopBackOff`** → Read the app's last words:
  `kubectl -n zero2ai logs deployment/metrics-api` (2A: `deployment/metrics-api-p1`).
- **`[ERROR] Prometheus has no 'up' series for metrics-api yet`** → Wait one minute and rerun
  `bash test.sh 2b`. If it still fails, open Prometheus **Status -> Targets**. If the target is
  missing, check that the ServiceMonitor and Service exist and have matching labels:
  `kubectl -n zero2ai get servicemonitor,svc --show-labels`. If Prometheus itself is missing,
  check `kubectl -n monitoring get pods` (the platform add-ons install it).
- **`no matches for kind "ServiceMonitor"`** during `deploy.sh 2a` → The platform add-ons (and so
  Prometheus) are not installed. Rerun `platform-up.sh dev`.
- **Port-forward says `address already in use`** → Something on your laptop already uses 8080,
  8000 or 9090: often your Phase 1 app or container. Stop it (Ctrl+C, or
  `docker rm -f metrics-api`) and try again.
- **`Error: UPGRADE FAILED: ... has no deployed releases`** → A first install failed half-way. Run
  `helm uninstall metrics-api -n zero2ai`, then `bash deploy.sh 2b` again.
- **Grafana login fails** → Copy the password again with the `terraform ... output` command above
  (no spaces). The user name is `admin`.

## Clean up

Remove this chapter's app (keeps the cluster):

```bash
bash down.sh
```

**What you should see:** `[OK] Chapter 11 app removed`.

Going straight on to Phase 3 or Chapter 12? You can skip `down.sh`: Chapter 12's guard watches
this same `metrics-api` app.

When you are done for the day, destroy the whole platform (from this folder):

```bash
bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev
```

## Where to next

[PRODUCTION.md](PRODUCTION.md) — Phase 3: alert rules, autoscaling, network rules, a public
address and a runbook, the way large companies run monitoring.
