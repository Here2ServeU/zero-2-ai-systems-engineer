# Chapter 12 — Cloud track: the AIOps guard on a real cluster

> On your laptop the guard looked at made-up numbers. On EKS it reads **real** CPU and memory
> numbers from Prometheus and — in Phase 3 — **adds copies by itself**, within strict limits.
> Platform first: [chapter-10-kubernetes/PLATFORM.md](../../chapter-10-kubernetes/PLATFORM.md).

**Labels:** 💳 Needs an account that may cost money · 🌐 Needs the internet

---

## New words

- **Job** — "Run this to the end, then stop."
- **CronJob** — A Job on a timetable, e.g. every 5 minutes (`*/5 * * * *`).
- **RBAC (Role-Based Access Control)** — Kubernetes' permission slips. A **Role** lists what's
  allowed; a **RoleBinding** gives it to one service account.
- **Service account** — The identity a pod uses when it talks to Kubernetes.

## Step 0 — Build and push

The image holds your three files: `aiops_engine.py`, `automated_response.py`, and the new
[`aiops_watcher.py`](../aiops_watcher.py), which feeds **real** numbers into the same
`predict_failure()` you wrote.

```bash
cd chapter-12-aiops/cloud
bash deploy.sh build
```

## Phase 1 — The laptop demo, as a Job

```bash
bash deploy.sh 1
bash test.sh 1     # prints the same WARNING report you saw on your laptop
```

## Phase 2 — A guard on a schedule, watching a real app (report only)

The guard needs a patient: Chapter 11's `metrics-api`. `deploy.sh 2` deploys it if it isn't
running. [`phase2/values.yaml`](phase2/values.yaml) turns the chart into a **CronJob** (no web
server) running `aiops_watcher.py` every 5 minutes with `ALLOW_SCALE: "false"`.

```bash
bash deploy.sh 2
bash test.sh 2          # runs the guard right now and prints its report
bash test.sh 2 --load   # first makes metrics-api busy for 4 minutes -> expect WARNING
```

The watcher asks Prometheus for CPU used **as a % of what each copy asked for**, over the last
15 minutes, one reading per minute — the same kind of list as `cpu = [45, 47, ...]` on your laptop.

## Phase 3 — Let the guard act (safely)

[`phase3/values.yaml`](phase3/values.yaml):

- `ALLOW_SCALE: "true"`, `MAX_REPLICAS: "5"`, `SCALE_STEP: "1"` — it may add one copy per run,
  never past 5.
- A **Role** that allows *only* `get`/`patch` on *only* `deployments/scale` and the HPA named
  `metrics-api`, in this namespace. It cannot touch anything else.
- If the app has an **HPA**, the guard raises the HPA's *minimum* instead of fighting it:
  predictive (AIOps) + reactive (HPA) scaling working together.
- An alert `AIOpsWatcherFailing` if the guard's own runs fail. (Who watches the watcher? Prometheus.)

```bash
bash deploy.sh 3
bash test.sh 3 --load   # WARNING -> "Scaled deployment metrics-api 2 -> 3 copies"
```

Prove the permission slip works:

```bash
SA=system:serviceaccount:zero2ai:aiops
kubectl -n zero2ai auth can-i patch deployments/metrics-api --subresource=scale --as=$SA   # yes
kubectl -n zero2ai auth can-i patch deployments/fraud-api --subresource=scale --as=$SA     # no: not on the list
kubectl -n zero2ai auth can-i delete pods --as=$SA                                         # no
```

## If something breaks

- **`Not enough data yet`** → Prometheus needs 3+ minutes of history for the app. Wait, rerun.
- **`Cannot read deployment metrics-api (HTTP 403)`** → RBAC. Check
  `kubectl -n zero2ai describe role aiops`. (Phase 2 has no Role on purpose: report only.)
- **Always STABLE even with `--load`** → The trend must rise more than 1.5 %/minute. Lower the
  app's CPU request in Chapter 11's values, or run `--load` twice.

## Clean up / next

`bash down.sh` · Next: [Chapter 13's cloud track](../../chapter-13-retraining/cloud/README.md).
