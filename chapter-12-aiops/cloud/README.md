# Chapter 12 — Phase 2: Promote it to the cloud

> The robot guard moves from your laptop to the AWS EKS cluster from Chapter 10. First it runs
> the laptop demo once (2A). Then it wakes up every 5 minutes, reads **real** CPU and memory
> numbers for Chapter 11's `metrics-api` from Prometheus, and reports what it sees (2B).
> Phase 1 (laptop) is in [../README.md](../README.md). Phase 3 is in [PRODUCTION.md](PRODUCTION.md).

**Labels:** Needs an account that may cost money · Needs the internet · Easier with a helper the first time

---

> **Money first.** Everything here runs on the shared platform from
> [chapter-10-kubernetes/PLATFORM.md](../../chapter-10-kubernetes/PLATFORM.md). Build it once
> (`bash chapter-10-kubernetes/scripts/platform-up.sh dev`, about 20 minutes). It costs money
> every hour it exists, even when idle. **Destroy it when you stop** (see [Clean up](#clean-up)).
> Get permission first if the AWS account is not yours.

## What changes from laptop to cloud, and why

| On your laptop (Phase 1) | In the cloud (Phase 2) | Why |
|---|---|---|
| Made-up lists like `cpu = [45, 47, ...]` | Real numbers from Prometheus: CPU used as a % of what each copy asked for, and memory used as a % of its limit, one reading per minute for the last 15 minutes | A guard that only reads pretend numbers protects nothing |
| *You* ran `python automated_response.py` | Kubernetes runs it: once as a **Job** (2A), then every 5 minutes as a **CronJob** (2B) | Nobody can run a script by hand every 5 minutes, all night |
| It *printed* "Kubernetes pods scaled up" | 2B is **report only** (`ALLOW_SCALE: "false"`); Phase 3 really scales | New automation first runs in "watch and tell" mode, so people can trust it before it acts |
| Nothing to watch | It watches Chapter 11's `metrics-api` | The guard needs a real "patient" |

The same `predict_failure()` you typed in Phase 1 makes every decision. The new file
[`../aiops_watcher.py`](../aiops_watcher.py) only fetches the real numbers, hands them to
`predict_failure()`, and (in Phase 3) acts on the answer.

## New words

- **Job** — "Run this container to the end, then stop." (A Deployment means "keep it running forever".)
- **CronJob** — A Job on a timetable. `*/5 * * * *` means "every 5 minutes". The five spots are
  minute, hour, day of month, month, day of week; `*` means "any".
- **Environment variable** — A setting handed to a program from outside, like a note taped to the
  box. The watcher reads `TARGET_DEPLOYMENT`, `PROMETHEUS_URL` and `ALLOW_SCALE` this way.
- **Report-only mode** (also "dry run" or "shadow mode") — The automation decides what it *would*
  do and says so, but changes nothing.
- **`kubectl top`** — Shows how much CPU and memory each pod is using right now.

## What is in this folder

```text
chapter-12-aiops/cloud/
├── deploy.sh                 # build | 2a | 2b | 3
├── test.sh                   # 2a | 2b | 3   (2b and 3 also take --load)
├── down.sh                   # remove the guard (keeps the cluster and metrics-api)
├── phase2a-yaml/job.yaml     # Phase 2A: the laptop demo as a one-time Job
├── phase2b-helm/values.yaml  # Phase 2B: the guard as a CronJob, report only
├── phase3-production/values.yaml   # Phase 3: see PRODUCTION.md
└── PRODUCTION.md
```

Run every command below **from this folder**. From the top of the course repo:

```bash
cd chapter-12-aiops/cloud
```

## Step 0 — Build and push the image

```bash
bash deploy.sh build
```

This builds the **same Dockerfile you used in Phase 1** for `linux/amd64` and pushes it to ECR.
The image holds `aiops_engine.py`, `automated_response.py` and `aiops_watcher.py`.

**What you should see:** lines starting with `==>`, then
`[OK] Pushed <account>.dkr.ecr.us-east-1.amazonaws.com/zero2ai-dev/aiops:<tag>`.

---

## Phase 2A — The laptop demo, as a Job

[`phase2a-yaml/job.yaml`](phase2a-yaml/job.yaml) is a Job that runs `python
automated_response.py`, exactly what `docker run --rm aiops:local` did on your laptop.
`backoffLimit: 1` means "if it fails, try once more, then give up", and
`ttlSecondsAfterFinished: 3600` cleans the finished Job away after an hour.

```bash
bash deploy.sh 2a
```

**What you should see:** `job.batch/aiops-demo created`, then
`[OK] Phase 2A job started. See its report: bash test.sh 2a`.

```bash
bash test.sh 2a
```

`test.sh 2a` waits for the Job to finish, then prints its logs.

**What you should see:** `job.batch/aiops-demo condition met`, then the same 12 lines you saw on
your laptop (`Status: WARNING` ... `- Incident ticket opened`), then `[OK] Phase 2A checks passed`.
Same box, same answer, different computer.

---

## Phase 2B — A guard on a schedule, watching a real app (report only)

The guard needs a patient: Chapter 11's `metrics-api`. `deploy.sh 2b` checks it is running. If it
is not, the script deploys Chapter 11's Phase 2B for you (and builds Chapter 11's image first if
needed). That version has no autoscaler, which makes the guard's actions easy to see later.

[`phase2b-helm/values.yaml`](phase2b-helm/values.yaml) turns the shared Helm chart into a
**CronJob** (no web server, no Service):

- `cronJob.schedule: "*/5 * * * *"` and `command: ["python", "aiops_watcher.py"]`
- `PROMETHEUS_URL` — the platform's Prometheus inside the cluster
- `TARGET_DEPLOYMENT: metrics-api`, `TARGET_NAMESPACE: zero2ai` — who to watch
- `ALLOW_SCALE: "false"` — report only

```bash
bash deploy.sh 2b
```

**What you should see:** `[OK] Watching deployment/metrics-api` (after a warning and a Chapter 11
deploy, the first time), then Helm's `STATUS: deployed`, then
`[OK] Phase 2B deployed (report-only, every 5 min). Test it: bash test.sh 2b`.

```bash
bash test.sh 2b
```

`test.sh 2b` does not wait 5 minutes: it starts a Job from the CronJob right now and prints its report.

**What you should see:**

```text
NAME          READY   UP-TO-DATE   AVAILABLE   AGE
metrics-api   2/2     2            2           ...
==> Running the guard right now (job aiops-now-1764000000)
AIOps watcher: target=zero2ai/metrics-api allow_scale=False
CPU % of request (last 15 min): [4.1, 3.9, 4.0, ...]
Memory % of limit (last 15 min): [17.2, 17.2, 17.3, ...]
Status: STABLE
Action: No action needed
==> After the guard ran
metrics-api   2/2     2            2           ...
[OK] Phase 2B checks passed
```

Your numbers will differ. A quiet app is usually `STABLE`. If `metrics-api` was only just
deployed, you see `Not enough data yet (need 3+ minutes of metrics). STABLE by default.` instead:
wait 3 minutes and run it again.

Now make the patient busy, so the guard has something to notice:

```bash
bash test.sh 2b --load
```

This starts a small pod that sends `/predict` requests to `metrics-api` as fast as it can for 4
minutes, then runs the guard.

**What you should see:** after about 4 minutes, rising CPU numbers, then something like:

```text
Status: WARNING
  WARNING: CPU trend up: 9.8%/reading
Action: Scale up now
Report-only mode (ALLOW_SCALE is not "true"): no changes made.
```

and `metrics-api` still has 2 copies. The guard saw the danger and *said* so, but did not touch
anything. Phase 3 lets it act.

---

## Explore it yourself

All from this folder, after Phase 2B.

```bash
kubectl -n zero2ai get cronjob aiops
kubectl -n zero2ai get jobs
```

**What you should see:** the CronJob `aiops` with `SCHEDULE */5 * * * *`, and a list of Jobs:
`aiops-<number>` ones started by the schedule and `aiops-now-<number>` ones started by `test.sh`.

```bash
kubectl -n zero2ai logs job/<a-job-name-from-the-list>
```

**What you should see:** that run's report, starting `AIOps watcher: target=zero2ai/metrics-api`.

Start a run yourself, the same way `test.sh` does:

```bash
kubectl -n zero2ai create job aiops-manual --from=cronjob/aiops
kubectl -n zero2ai wait --for=condition=complete job/aiops-manual --timeout=3m
kubectl -n zero2ai logs job/aiops-manual
kubectl -n zero2ai delete job aiops-manual
```

See what the guard sees, right now:

```bash
kubectl -n zero2ai top pods
```

**What you should see:** CPU (in `m`, thousandths of a CPU) and memory for each pod. During
`--load`, the `metrics-api` pods climb.

Ask Prometheus the guard's question yourself. Open a second terminal and run:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Open `http://localhost:9090`, go to the **Query** page (called **Graph** in older versions), and
paste:

```text
100 * sum(rate(container_cpu_usage_seconds_total{namespace="zero2ai",pod=~"metrics-api-[a-z0-9]+-[a-z0-9]+",container!=""}[2m])) / sum(kube_pod_container_resource_requests{namespace="zero2ai",pod=~"metrics-api-[a-z0-9]+-[a-z0-9]+",resource="cpu"})
```

Switch to the **Graph** tab and set the range to 15 minutes. That line is exactly the list the
guard reads: CPU used as a % of what the copies asked for.

## If something breaks

- **`[ERROR] Cluster zero2ai-eks-dev not found`** → Build the platform first:
  `bash ../../chapter-10-kubernetes/scripts/platform-up.sh dev` (from this folder).
- **`[ERROR] No image recorded for 'aiops' in dev`** → Run `bash deploy.sh build` first.
- **`Usage: deploy.sh <build|2a|2b|3>`** → You typed an old or wrong phase name. Use `build`,
  `2a`, `2b` or `3`.
- **`bash: deploy.sh: No such file or directory`** → You are not in `chapter-12-aiops/cloud`.
- **`test.sh 2a` times out with `timed out waiting for the condition`** → The Job did not finish.
  Look at it: `kubectl -n zero2ai describe job aiops-demo` and `kubectl -n zero2ai logs job/aiops-demo`.
  `ImagePullBackOff` in `kubectl -n zero2ai get pods` means rebuild with `bash deploy.sh build`,
  then `bash deploy.sh 2a` again.
- **`Not enough data yet (need 3+ minutes of metrics)`** → Prometheus needs a few minutes of
  history for a new app. Wait 3 minutes and rerun `bash test.sh 2b`.
- **`[ERROR] The guard's run failed`** with `urlopen error` or `Connection refused` → The guard
  cannot reach Prometheus. Check `kubectl -n monitoring get pods`: the `prometheus-...` pod must be
  `Running` (the platform add-ons install it).
- **Always `STABLE`, even with `--load`** → The CPU trend must climb more than 1.5 points per
  minute. Run `bash test.sh 2b --load` again (the first run warms up), or check the load pod
  started: `kubectl -n zero2ai get pod aiops-load`.
- **`error: failed to create job: jobs.batch "aiops-manual" already exists`** → Delete the old one:
  `kubectl -n zero2ai delete job aiops-manual`.
- **`deploy.sh 2b` fails while deploying `metrics-api`** → Deploy Chapter 11 yourself and read its
  error: `bash ../../chapter-11-monitoring/cloud/deploy.sh build`, then
  `bash ../../chapter-11-monitoring/cloud/deploy.sh 2b`.

## Clean up

Remove the guard (keeps the cluster and Chapter 11's `metrics-api`):

```bash
bash down.sh
```

**What you should see:** `[OK] Chapter 12 guard removed (metrics-api from Chapter 11 is left running: ...)`.
To remove `metrics-api` too:

```bash
bash ../../chapter-11-monitoring/cloud/down.sh
```

When you are done for the day, destroy the whole platform (from this folder):

```bash
bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev
```

## Where to next

[PRODUCTION.md](PRODUCTION.md) — Phase 3: let the guard really scale `metrics-api`, with a
permission slip for exactly one app, a hard cap, and an alert that watches the watcher.
