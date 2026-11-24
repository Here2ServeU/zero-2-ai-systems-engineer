# Chapter 18 — Phase 2: Promote it to the cloud (AWS EKS)

> In Phase 1 you ran the production LLM service on your laptop and packed it in a container.
> Now you move the **same container** to a real cloud cluster in two small steps: **2A** with
> plain Kubernetes YAML, then **2B** with the shared Helm chart, so Prometheus collects its
> metrics. Phase 3 ([PRODUCTION.md](PRODUCTION.md)) makes it production-grade.

**Labels:** Needs an account that may cost money · Needs the internet · Easier with a helper the first time

---

## Before you start

1. **Finish Phase 1** ([../README.md](../README.md)), including Step 9 (the container).
2. **Build the shared cloud platform once:**
   [../../chapter-10-kubernetes/PLATFORM.md](../../chapter-10-kubernetes/PLATFORM.md). It
   creates the EKS cluster, your image shelf (ECR), Prometheus and Grafana, and takes about 20
   minutes.
3. **Costs money.** The cluster costs money every hour it exists, and each robot question costs
   a fraction of a cent. Get permission if the accounts aren't yours, and **tear everything down
   when you finish** (see "Clean up").
4. **Set your API key in this terminal** (same as Phase 1):

```bash
export ANTHROPIC_API_KEY='paste-your-key-here'
```

**Run every command on this page from this folder:**

```bash
cd chapter-18-prodllm/cloud
```

## What changes from your laptop to the cloud

| On your laptop (Phase 1) | In the cloud (Phase 2) | Why |
|---|---|---|
| Image built on your laptop | Image pushed to **ECR**, your private image shelf in AWS | Cloud servers can't see your laptop |
| `docker run -e ANTHROPIC_API_KEY` | A Kubernetes **Secret** called `llm-api-keys`, made from your terminal's key | The key reaches the pod without ever being written to a file or to git |
| `curl localhost:5000` and `localhost:8000` | A **port-forward** tunnel to the Service's two doors (80 for `/llm`, 8000 for `/metrics`) | Phase 2 stays private: no public address yet |
| You read `/metrics` by hand | 2B: a **ServiceMonitor** tells the cluster's Prometheus to read it every 15 seconds | Numbers you can graph and alert on (Chapters 11 and 15) |
| No size limits | Each copy asks for 50m CPU and 128Mi memory, and may use at most 256Mi | So the cluster can pick a server with room |
| Plain YAML (2A) | The shared **Helm chart** with this chapter's values (2B) | One command installs, upgrades and rolls back |

## New words

- **Secret** — A Kubernetes object that holds private values (like API keys) and hands them to
  pods as environment variables.
- **port-forward** — A tunnel from a port on your laptop to a Service inside the cluster.
- **ServiceMonitor** — Tells Prometheus which Service to collect metrics from, and how often.
- **Release** — One installed copy of a Helm chart (here: `prod-llm`).

## Step 0 — Build the image and push it to ECR

```bash
bash deploy.sh build
```

This logs in to ECR, builds `../Dockerfile` for `linux/amd64` (the kind of computer EKS uses,
even on an Apple Silicon Mac), tags it with your git commit and pushes it.

**What you should see:** Docker build steps, then `[OK] Pushed ...zero2ai-dev/prod-llm:<tag>`.

---

## Phase 2A — Plain YAML

Open [`phase2a-yaml/deployment.yaml`](phase2a-yaml/deployment.yaml). It is one Deployment
named `prod-llm-p1` that runs your image with:

- `envFrom: secretRef: llm-api-keys` — every key in the Secret becomes an environment variable,
  exactly like `-e ANTHROPIC_API_KEY` on your laptop.
- two ports: `5000` (`/llm`, `/health`) and `8000` (`/metrics`).
- a `readinessProbe` on `/health`, so traffic only arrives once the copy is ready.

[`phase2a-yaml/service.yaml`](phase2a-yaml/service.yaml) is the front desk: port `80` goes to
`5000`, and port `8000` goes to `8000`.

```bash
bash deploy.sh 2a
bash test.sh 2a
```

**What you should see:**

- `deploy.sh 2a` prints `[OK] Secret llm-api-keys is ready (keys: ANTHROPIC_API_KEY )`, applies
  the two files, waits for `deployment "prod-llm-p1" successfully rolled out`, and ends with
  `[OK] Phase 2A deployed. Test it: bash test.sh 2a`.
- `test.sh 2a` opens a tunnel and checks each grown-up feature from Phase 1:
  1. `GET .../health` → `{"status":"healthy"}`
  2. **A real question** ("In one sentence, what is KYC?") → an answer with `"cached":false`
  3. **The same question again** → `"cached":true` (free, from the memory box)
  4. **The safety filter** (`my ssn: ...`) → `[OK] Blocked (HTTP 422)`
  5. The `llm_calls_total` and `llm_tokens_total` counters, through a second tunnel to port 8000
- It ends with `[OK] Phase 2A checks passed`.

What `test.sh 2a` does, by hand (two terminals):

```bash
kubectl -n zero2ai port-forward service/prod-llm-p1 8080:80 8000:8000      # terminal 1: the tunnel
curl -s http://localhost:8080/health                                       # terminal 2
curl -s -X POST http://localhost:8080/llm -H 'Content-Type: application/json' \
  -d '{"user_id":"alice","prompt":"My SSN: 123-45-6789"}'
curl -s http://localhost:8000/metrics | grep -E '^llm_(calls|tokens)_total'
```

Explore it:

```bash
kubectl -n zero2ai get pods -l app=prod-llm-p1                 # one copy, Running
kubectl -n zero2ai logs deployment/prod-llm-p1 --tail=20       # the same log lines as Terminal 1 on your laptop
kubectl -n zero2ai get secret llm-api-keys                     # the Secret exists (the value stays hidden)
```

---

## Phase 2B — The shared Helm chart, scraped by Prometheus

Same app, packaged with the shared chart
[`../../chapter-10-kubernetes/helm/zero2ai-app`](../../chapter-10-kubernetes/helm/zero2ai-app)
and this chapter's answers in [`phase2b-helm/values.yaml`](phase2b-helm/values.yaml):

- `containerPort: 5000` and `metricsPort: 8000` — the two doors.
- `envFromSecrets: ["llm-api-keys"]` — the same Secret as 2A.
- `serviceMonitor.enabled: true`, `interval: 15s` — Prometheus collects `/metrics` every 15
  seconds.
- The chart's safe defaults add a startup, readiness and liveness check on `/health`, and run
  the container as a normal user with a read-only disk.

```bash
bash deploy.sh 2b
bash test.sh 2b
```

**What you should see:** `deploy.sh 2b` removes the 2A objects, refreshes the Secret, runs
`helm upgrade --install prod-llm ...`, prints the release history and ends with
`[OK] Phase 2B deployed. Test it: bash test.sh 2b`. `test.sh 2b` prints `[OK] helm test prod-llm`
(a tiny pod *inside* the cluster called `/health`), repeats the five feature checks from 2A, and
ends with `[OK] Phase 2B checks passed`.

### See your metrics in Prometheus

Run from the top of the repo (`cd ../..` first) to list the platform's addresses:

```bash
bash chapter-10-kubernetes/scripts/urls.sh
```

Open the **prometheus** address (`http://<alb>:9090`, open to your own IP only) in your
browser. If it times out, use a tunnel instead and open `http://localhost:9090`:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Run these queries in the search box:

- `llm_calls_total{service="prod-llm"}` — calls by status: success, cache_hit, blocked...
- `sum(increase(llm_tokens_total{service="prod-llm"}[1h]))` — tokens used in the last hour:
  your cost meter.

If nothing shows yet, wait 30 seconds (two scrapes) after running `bash test.sh 2b`.

### Helm commands to explore

From `chapter-18-prodllm/cloud`:

```bash
helm list -n zero2ai                                  # what's installed
helm get values prod-llm -n zero2ai                   # the answers this release used
kubectl -n zero2ai get servicemonitor prod-llm        # the "please scrape me" note for Prometheus
helm history prod-llm -n zero2ai                      # numbered revisions
helm rollback prod-llm 1 -n zero2ai                   # back to revision 1
```

## Try it yourself

- In `phase2b-helm/values.yaml`, change `replicaCount: 1` to `2` and run `bash deploy.sh 2b`
  again. Now run `bash test.sh 2b` a few times. Sometimes the second identical question says
  `"cached":false`: each copy has **its own** memory box. Phase 3 explains the real fix.
- Run `kubectl -n zero2ai delete pod -l app.kubernetes.io/instance=prod-llm` and ask the same
  question again. The replacement copy starts with an empty cache and empty budgets.
- Put `replicaCount` back to `1` when you're done.

## If something breaks

- **`[ERROR] Set at least one key first, e.g. export ANTHROPIC_API_KEY=...`** → The key isn't
  set in this terminal. `export` it (see "Before you start") and run the deploy again.
- **`Cluster zero2ai-eks-dev not found`** → Build the platform first:
  [PLATFORM.md](../../chapter-10-kubernetes/PLATFORM.md).
- **`No image recorded for 'prod-llm'`** → Run Step 0 first: `bash deploy.sh build`.
- **`Cannot connect to the Docker daemon`** during `build` → Start Docker Desktop.
- **`[ERROR] POST http://localhost:8080/llm failed`** on the "real question" → The robot call
  failed (HTTP 503). Read the reason: `kubectl -n zero2ai logs deployment/prod-llm --tail=20`
  (use `prod-llm-p1` in 2A). `401`/`AuthenticationError` = wrong key: export the right one and
  deploy again (deploy refreshes the Secret). `404`/`NotFoundError` = model not available to
  your account (see Phase 1, Step 4). `429` = rate or spending limit: wait and retry.
- **Pods stuck in `CreateContainerConfigError`** → The `llm-api-keys` Secret is missing. Run the
  deploy step again with the key exported.
- **`ImagePullBackOff`** → The cluster can't find the image. Run `bash deploy.sh build`, then
  deploy again.
- **`Error: UPGRADE FAILED: ... has no deployed releases`** → A failed first install. Run
  `helm uninstall prod-llm -n zero2ai`, then `bash deploy.sh 2b` again.
- **`bash deploy.sh` prints `Usage: deploy.sh <build|2a|2b|3>`** → You typed an old or
  misspelled phase. Use `build`, `2a`, `2b` or `3`.

## Clean up

```bash
bash down.sh                                                   # remove this chapter's app (the cluster stays)
bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev  # delete the whole platform when you're done for the day
```

**What you should see:** `[OK] Chapter 18 removed. Finished the course? bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev`,
then later the platform destroy finishing without errors. `down.sh` also deletes the
`llm-api-keys` Secret, so your key no longer sits in the cluster.

## Next: Phase 3

Your service runs in the cloud. Now run it the way big companies do, with autoscaling, keys
from a vault, a public address and alerts on errors, latency and spend:
**[PRODUCTION.md](PRODUCTION.md)**.
