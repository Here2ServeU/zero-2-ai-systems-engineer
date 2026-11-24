# Chapter 12 — Phase 3: Run it like a Fortune 500 company

> In Phase 2 the guard only *reported*. In Phase 3 it is allowed to **act**: when it predicts
> trouble, it adds a copy of Chapter 11's `metrics-api`. Automation that can change production is
> powerful and dangerous, so this phase is mostly about **guardrails**: what it may touch, how far
> it may go, and who watches it.
> Phase 1: [../README.md](../README.md) · Phase 2: [README.md](README.md)

**Labels:** Needs an account that may cost money · Needs the internet · Easier with a helper the first time

---

> **Money first.** Phase 3 runs on the shared platform from
> [chapter-10-kubernetes/PLATFORM.md](../../chapter-10-kubernetes/PLATFORM.md). Every copy the
> guard adds uses more of the cluster. Destroy the platform when you stop (see [Clean up](#clean-up)).

## Deploy and test

You need the image from Phase 2's Step 0 (`bash deploy.sh build`). From the top of the course repo:

```bash
cd chapter-12-aiops/cloud
bash deploy.sh 3
```

`deploy.sh 3` removes the Phase 2A Job, makes sure `metrics-api` (Chapter 11) is running, then
upgrades the **same** `aiops` Helm release with [`phase2b-helm/values.yaml`](phase2b-helm/values.yaml)
and [`phase3-production/values.yaml`](phase3-production/values.yaml) stacked (later wins), with
`--atomic`.

**What you should see:** `[OK] Watching deployment/metrics-api`, `STATUS: deployed`, then
`[OK] Phase 3 deployed (may scale metrics-api, every 2 min). Test it: bash test.sh 3`.

```bash
bash test.sh 3 --load
```

This makes `metrics-api` busy for 4 minutes, runs the guard once right away, and shows what the
guard is allowed to do. (Without `--load`, a quiet app is usually `STABLE` and nothing changes.)

**What you should see** (your numbers will differ):

```text
NAME          READY   UP-TO-DATE   AVAILABLE   AGE
metrics-api   2/2     2            2           ...
==> Running the guard right now (job aiops-now-1764000000)
AIOps watcher: target=zero2ai/metrics-api allow_scale=True
CPU % of request (last 15 min): [3.9, 4.0, ..., 61.5, 88.2]
Memory % of limit (last 15 min): [...]
Status: WARNING
  WARNING: CPU trend up: 9.8%/reading
Action: Scale up now
Triggering automated response:
  - Scaled deployment metrics-api 2 -> 3 copies
==> After the guard ran
metrics-api   2/3     3            2           ...
==> What the guard may do (RBAC)
PolicyRule:
  Resources                             Non-Resource URLs  Resource Names  Verbs
  ---------                             -----------------  --------------  -----
  horizontalpodautoscalers.autoscaling  []                 [metrics-api]   [get patch]
  deployments.apps/scale                []                 [metrics-api]   [get patch]
[OK] Phase 3 checks passed
```

If you ran Chapter 11's **Phase 3**, `metrics-api` has an autoscaler (HPA). Then the guard does
not fight it; instead you see `- Raised HPA metrics-api minReplicas 2 -> 3`. The guard predicts
("CPU is climbing, get ready") and the HPA reacts ("CPU is high now"): two kinds of scaling
working together.

Prove the permission slip works. The guard runs as the Kubernetes identity
`system:serviceaccount:zero2ai:aiops`; ask Kubernetes what that identity may do:

```bash
SA=system:serviceaccount:zero2ai:aiops
kubectl -n zero2ai auth can-i patch deployments/metrics-api --subresource=scale --as=$SA
kubectl -n zero2ai auth can-i patch deployments/fraud-api --subresource=scale --as=$SA
kubectl -n zero2ai auth can-i delete pods --as=$SA
kubectl -n zero2ai auth can-i get secrets --as=$SA
```

**What you should see:** `yes`, then `no`, `no`, `no`. It may resize exactly one app and nothing else.

## What changes in production and why

Everything below really exists in this chapter's files (`phase3-production/values.yaml`, the
`3)` branch of `deploy.sh`, `aiops_watcher.py`, and the shared chart's defaults).

| Setting | Where | What it does | Why production needs it |
|---|---|---|---|
| `ALLOW_SCALE: "true"` | `phase3-production/values.yaml` | The guard may act on a `WARNING` | Phase 2B proved its decisions first; now it is trusted to act |
| `MAX_REPLICAS: "5"` | same | Never scales `metrics-api` above 5 copies (and never above the HPA's own maximum) | A bug or bad data can never run up a huge bill |
| `SCALE_STEP: "1"` | same | Adds one copy per run | Small, safe steps; the next run sees the effect before doing more |
| `schedule: "*/2 * * * *"` | same | Runs every 2 minutes instead of 5 | Reacts faster once it is allowed to act |
| `serviceAccount.automount: true` | same | The guard's pod gets a Kubernetes API token | It needs one to ask Kubernetes for more copies |
| `rbac` Role + RoleBinding | same | Only `get` and `patch`, only on `deployments/scale` and the HPA, only for `metrics-api`, only in `zero2ai` | **Least privilege**: if the guard misbehaves or is broken into, the damage is tiny |
| `prometheusRule`: `AIOpsWatcherFailing` | same | Alert when any `aiops-...` Job has failed runs, for 10 minutes | Who watches the watcher? Prometheus does. A silent, broken guard is worse than none |
| HPA-aware scaling | `aiops_watcher.py` | If an HPA exists, raise its `minReplicas` instead of setting copies directly | Two robots must not fight over the same number |
| `--atomic` | `deploy.sh 3` | A failed upgrade rolls back by itself | No half-broken releases |
| `concurrencyPolicy: Forbid` | Chart default | A new run never starts while the last one is still going | Two guards acting at once could double-scale |
| `backoffLimit: 1`, keep last 3 good and 3 failed Jobs, delete Jobs after 1 day | Chart defaults | Limited retries and a short history of runs to read | You can read recent decisions, and old Jobs do not pile up |
| Non-root, read-only disk, no Linux capabilities, small resources (50m CPU, 128 MiB limit) | Chart defaults + `phase2b-helm/values.yaml` | The guard's container is locked down and small | Hardening and cost |

## How big companies run this

Each item is marked **[In this chapter]** if you just deployed it, or **[At work]** if it is how
you would extend it in a real job. Nothing marked "At work" is in this repo.

### Start in report-only mode, then let it act

**[In this chapter]** Phase 2B ran the guard with `ALLOW_SCALE: "false"`: it decided and
reported, but changed nothing. Phase 3 flips that one setting. **[At work]** teams leave new
automation in this "shadow mode" for days or weeks and compare its decisions with what humans
did, before letting it act. Many keep a "kill switch" setting to turn acting off in one command.

You can do that here: set `ALLOW_SCALE: "false"` in `phase3-production/values.yaml` and run
`bash deploy.sh 3`.

### SLOs: what the guard is protecting

The guard exists to protect Chapter 11's service level objectives (SLOs), such as "95% of
predictions take under 0.5 s". **[In this chapter]** it uses a simple early-warning signal
(CPU climbing as a % of what each copy asked for) and Chapter 11's alerts still tell humans when
the SLO is in danger. **[At work]** AIOps systems also learn daily and weekly patterns (Monday
morning is always busy), combine many signals, and group related alerts into one incident so
people are not flooded.

### Alerting, and a short runbook

**[In this chapter]** `AIOpsWatcherFailing` fires if any `aiops-...` Job has failed runs for 10
minutes. You see it in Prometheus (**Alerts**) and Alertmanager (port 9093 on the platform ALB,
your IP only). **[At work]** it would page the on-call engineer; the platform's Alertmanager has
no receivers set up, so here alerts are shown but not sent.

**Runbook: `AIOpsWatcherFailing` (warning)**

1. **What it means:** at least one run of the guard crashed. While it is broken, nobody is
   watching `metrics-api` for early trouble (Chapter 11's alerts still work).
2. **First 3 commands** (from `chapter-12-aiops/cloud`):

   ```bash
   kubectl -n zero2ai get cronjob aiops
   kubectl -n zero2ai get jobs
   kubectl -n zero2ai logs job/<a-job-with-0/1-completions>
   ```

3. **How to fix**, by what the log says:
   - `urlopen error` / `Connection refused` → Prometheus is down or moved. Check
     `kubectl -n monitoring get pods`.
   - `HTTP 403` / `check RBAC` → The permission slip is missing or wrong.
     `kubectl -n zero2ai describe role aiops`; restore it with `bash deploy.sh 3`.
   - `ImagePullBackOff` (in `kubectl -n zero2ai get pods`) → `bash deploy.sh build`, then
     `bash deploy.sh 3`.
   - A Python error after you changed the code → roll back: `helm history aiops -n zero2ai`,
     then `helm rollback aiops <revision> -n zero2ai`.
4. **Clear it:** failed Jobs are kept for a while, so the alert stays until they are gone. After
   the fix, delete them: `kubectl -n zero2ai delete job <failed-job-name>`. Then check
   `bash test.sh 3` passes.

**Runbook: "metrics-api has too many copies"** (the guard only ever scales *up*)

1. **What it means:** the guard added copies during a busy time, and nothing in this chapter
   scales them back down.
2. **First 3 commands:**

   ```bash
   kubectl -n zero2ai get deployment metrics-api
   kubectl -n zero2ai get hpa metrics-api
   kubectl -n zero2ai top pods
   ```

3. **How to fix:** if it is quiet now, put it back to 2 copies. Without an HPA:
   `kubectl -n zero2ai scale deployment metrics-api --replicas=2`. With Chapter 11's Phase 3 HPA:
   `bash ../../chapter-11-monitoring/cloud/deploy.sh 3` (puts `minReplicas` back to 2).

### Security

- **[In this chapter]** **Least privilege with RBAC:** a Role that lists exactly two resources,
  one resource name, two verbs, one namespace. You proved it with `kubectl auth can-i`.
- **[In this chapter]** Only the guard gets an API token; Chapter 11's Helm-installed app does
  not (the chart sets `automountServiceAccountToken: false` unless a values file asks for it). The container runs as a non-root user with a
  read-only disk and no Linux capabilities.
- **[In this chapter]** No passwords or keys anywhere: the token comes from Kubernetes and the
  guard only reads Prometheus inside the cluster.
- **[At work]** add a NetworkPolicy so the guard may only *call out* to Prometheus and the
  Kubernetes API (this chapter limits who can reach apps, not where the guard can connect), and
  have security review every new permission before it is granted.

### Reliability: guardrails for automation

- **[In this chapter]** a hard cap (`MAX_REPLICAS`), small steps (`SCALE_STEP`), one run at a time
  (`concurrencyPolicy: Forbid`), cooperation with the HPA, and an alert on the guard itself.
- **[In this chapter]** if Prometheus has too little data (fewer than 3 readings), the guard says
  `STABLE by default` and does nothing. When unsure, do no harm.
- **[At work]** add a **cool-down** (after acting, wait before acting again), **scale-down** when
  it is quiet, a limit on actions per hour, and human approval for risky actions such as restarts
  or rollbacks.

### Safe change

- **[In this chapter]** `helm upgrade --atomic` and numbered Helm revisions for the guard's own
  settings; the decision code is the same `predict_failure()` you tested on your laptop.
- **[At work]** test the guard's logic against recorded past incidents ("would it have caught
  last month's outage?") before every change, and roll new versions out to dev and qa first.

### Cost and FinOps

- **[In this chapter]** `MAX_REPLICAS: "5"` puts a ceiling on what the guard can spend, and the
  guard measures CPU against what each copy *asked for*, the same number the bill is based on.
- **[At work]** scaling up costs money every minute, so teams also scale down when quiet, pick
  cheaper machine types for spare copies, and show a weekly "what did automation cost and save?" report.
- **[In this chapter]** the biggest saving is still `bash down.sh` and `platform-down.sh` when
  you stop.

### Audit and compliance

- **[In this chapter]** every decision is written to the Job's log (the numbers it saw, the
  warnings, and the exact change, such as `Scaled deployment metrics-api 2 -> 3 copies`). The last
  3 good and 3 failed runs are kept, for up to a day. The guard's settings are code in git, and
  `helm history aiops -n zero2ai` shows every change to them.
- **[In this chapter]** in `qa` and `prod` the platform turns on EKS audit logs, which record
  every change the guard's identity makes through the Kubernetes API (see PLATFORM.md).
- **[At work]** send every automated action to a permanent log and the team's chat channel, and
  open a real incident ticket. On your laptop, `automated_response.py` only *printed* "Alert sent
  to Slack" and "Incident ticket opened"; the cloud guard does not send those.

## Production readiness checklist

Run each command from `chapter-12-aiops/cloud` after `bash deploy.sh 3`.

- [ ] Tests pass: `bash test.sh 3 --load` ends with `[OK] Phase 3 checks passed` and the log shows
      a `Scaled deployment ...` or `Raised HPA ...` line.
- [ ] Runs on schedule: `kubectl -n zero2ai get cronjob aiops` shows `*/2 * * * *`.
- [ ] Least privilege: `kubectl -n zero2ai auth can-i patch deployments/metrics-api --subresource=scale --as=system:serviceaccount:zero2ai:aiops`
      says `yes`, and `kubectl -n zero2ai auth can-i delete pods --as=system:serviceaccount:zero2ai:aiops` says `no`.
- [ ] Hard cap: `kubectl -n zero2ai get cronjob aiops -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].env}'`
      includes `MAX_REPLICAS` with value `5`.
- [ ] One run at a time: `kubectl -n zero2ai get cronjob aiops -o jsonpath='{.spec.concurrencyPolicy}'` prints `Forbid`.
- [ ] Not root: `kubectl -n zero2ai get cronjob aiops -o jsonpath='{.spec.jobTemplate.spec.template.spec.securityContext.runAsNonRoot}'` prints `true`.
- [ ] The watcher is watched: `kubectl -n zero2ai get prometheusrule aiops` lists it, and
      Prometheus **Alerts** shows `AIOpsWatcherFailing`.
- [ ] Rollback is possible: `helm history aiops -n zero2ai` lists more than one revision.
- [ ] You can switch acting off: you know which setting (`ALLOW_SCALE`) and command (`bash deploy.sh 3`) do it.
- [ ] After testing, `metrics-api` is back to 2 copies: `kubectl -n zero2ai get deployment metrics-api`.
- [ ] You know how to stop paying: `bash down.sh` and `platform-down.sh` (below).

## Career corner

You just built the core of what **Site Reliability Engineers**, **AIOps Engineers**, **Platform
Engineers** and **MLOps Engineers** build: automation that keeps services healthy without a human
in the loop for simple problems. Questions you can now answer in an interview:

1. *What is the difference between reactive and predictive scaling?* (An HPA reacts to CPU that
   is high now; the guard predicts from a rising trend and prepares early. Here they work
   together: the guard raises the HPA's minimum instead of fighting it.)
2. *How do you make it safe to let automation change production?* (Report-only first, least
   privilege, a hard cap, small steps, one run at a time, an alert on the automation itself, and
   a kill switch.)
3. *What is least privilege, and how did you prove it?* (Give only the permissions needed; a
   Role limited to `get`/`patch` on one app's scale, checked with `kubectl auth can-i`.)
4. *How does a z-score find a spike, and when can it miss one?* (It measures distance from the
   average in "spreads"; two big outliers can stretch the spread and hide each other.)
5. *Your automation stopped working at 2 a.m. How would you know?* (An alert on its failed runs,
   `AIOpsWatcherFailing`, plus logs for every run.)

## Clean up

Remove the guard (keeps the cluster and `metrics-api`):

```bash
bash down.sh
```

**What you should see:** `[OK] Chapter 12 guard removed (metrics-api from Chapter 11 is left running: ...)`.
Remove `metrics-api` too:

```bash
bash ../../chapter-11-monitoring/cloud/down.sh
```

When you are done for the day, destroy the platform (from this folder):

```bash
bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev
```

## Where to next

[Chapter 13 — Notice when the world changes (Drift and retraining)](../../chapter-13-retraining/README.md):
your platform can watch and heal its machines; next it learns to notice when the *data* changes,
and retrains the model by itself.
