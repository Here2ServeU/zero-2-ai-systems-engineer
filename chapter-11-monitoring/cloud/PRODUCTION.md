# Chapter 11 — Phase 3: Run it like a Fortune 500 company

> Phase 2 proved Prometheus can *see* your app. Phase 3 makes the app and its monitoring
> production-grade: alerts that raise the alarm, safety nets that keep it running, and a
> runbook that tells a tired human what to do at 3 a.m.
> Phase 1: [../README.md](../README.md) · Phase 2: [README.md](README.md)

**Labels:** Needs an account that may cost money · Needs the internet · Easier with a helper the first time

---

> **Money first.** Phase 3 runs on the shared platform from
> [chapter-10-kubernetes/PLATFORM.md](../../chapter-10-kubernetes/PLATFORM.md) and adds a
> listener (port 8011) to the platform ALB that already exists. Destroy the platform when you stop
> (see [Clean up](#clean-up)).

## Deploy and test

You need the image from Phase 2's Step 0 (`bash deploy.sh build`). From the top of the course repo:

```bash
cd chapter-11-monitoring/cloud
bash deploy.sh 3
```

`deploy.sh 3` removes any Phase 2A objects, then upgrades the **same** `metrics-api` Helm
release with two values files stacked: [`phase2b-helm/values.yaml`](phase2b-helm/values.yaml)
then [`phase3-production/values.yaml`](phase3-production/values.yaml) (later files win). It also
tells the network rules which IP range the load balancer uses (your VPC's range) and adds
`--atomic`, so a failed upgrade rolls itself back.

**What you should see:** `STATUS: deployed`, a `helm history` table with a new revision, then
`[OK] Phase 3 deployed. Test it: bash test.sh 3`.

```bash
bash test.sh 3
```

**What you should see** (the first time, waiting for the load balancer takes 2 to 4 minutes):

```text
Phase: Succeeded                          <- helm test
==> Waiting for the AWS load balancer for ingress/metrics-api (first time: 2-4 minutes)
==> Public address: http://k8s-zero2ai-....us-east-1.elb.amazonaws.com:8011
POST http://k8s-zero2ai-...:8011/predict  {"amount":120}
{"prediction":0}
POST ...  {"amount":990}
{"prediction":1}
POST ...  {"amount":1500}
{"prediction":1}
[OK] Prometheus is collecting metrics-api
==> Alert rules loaded into Prometheus
MetricsApiDown
MetricsApiCopyMissing
MetricsApiSlowPredictions
NAME            REFERENCE                TARGETS        MINPODS   MAXPODS   REPLICAS
metrics-api     Deployment/metrics-api   cpu: 2%/70%    2         5         2
NAME            MIN AVAILABLE   ...
metrics-api     1               ...
[OK] Phase 3 checks passed
```

Open `http://<that address>:8011/health` in your browser too. Anyone on the internet can reach
it (see the security section for how to limit that).

## What changes in production and why

Everything below really exists in this chapter's files (`phase3-production/values.yaml`, the
`3)` branch of `deploy.sh`, and the shared chart's defaults).

| Setting | Where | What it does | Why production needs it |
|---|---|---|---|
| `prometheusRule` with 3 alerts | `phase3-production/values.yaml` | `MetricsApiDown` (no healthy copy for 2 min, critical), `MetricsApiCopyMissing` (fewer than 2 healthy copies for 5 min, warning), `MetricsApiSlowPredictions` (95% of predictions slower than 0.5 s for 5 min, warning) | Numbers nobody looks at do not help. Alerts turn numbers into "a human should look now" |
| `for: 2m` / `for: 5m` on each alert | same | The problem must last that long before the alert fires | Stops one blip from waking someone up (fewer false alarms) |
| `autoscaling` | same | HPA: 2 to 5 copies, adds copies above 70% CPU | Handles busy hours without paying for idle copies all day |
| `pdb.enabled` | same | PodDisruptionBudget: at least 1 copy stays up during node upgrades | Planned maintenance never takes every copy down |
| `topologySpread` | same | Spreads copies across availability zones and computers | One data-center problem does not take the app down |
| `networkPolicy` | same + `deploy.sh` | Only pods in `zero2ai`, the load balancer (VPC range) and Prometheus (from `monitoring`, port 8000 only) may connect | Limits damage if something else in the cluster is broken into |
| `ingress` on port 8011 | same | Joins the shared platform ALB with a `/health` check | One stable public address without paying for another load balancer |
| `resources.requests.cpu: 100m` | same | Each copy reserves a tenth of a CPU | The HPA measures "70%" against this number, and the scheduler uses it to place copies |
| `--atomic` | `deploy.sh 3` | If the upgrade fails, Helm rolls back by itself | No half-broken releases |
| ServiceMonitor every 15 s | `phase2b-helm/values.yaml` (still on) | Prometheus keeps collecting | Alerts need fresh numbers |
| Non-root, read-only disk, no Linux capabilities, no Kubernetes API token | Chart defaults | The app cannot change its own files or talk to the Kubernetes API | Hardening: a broken-into app can do far less |
| Startup, readiness and liveness probes on `/health` | Chart defaults | Kubernetes only sends visitors to healthy copies and restarts stuck ones | Self-healing |
| `maxUnavailable: 0` rolling updates | Chart defaults | New copies start before old ones stop | Upgrades without downtime |

> **Why still one process per copy?** `start_http_server(8000)` runs inside the app. Several web
> server workers in one copy would each try to open port 8000 and fight. So this chapter scales
> with more *copies* instead. (Multi-process metrics are possible with the
> `PROMETHEUS_MULTIPROC_DIR` setting; that is beyond this chapter.)

## How big companies run this

Each item is marked **[In this chapter]** if you just deployed it, or **[At work]** if it is how
you would extend it in a real job. Nothing marked "At work" is in this repo.

### SLIs, SLOs and error budgets

- **SLI (Service Level Indicator)** — a measurement of how users experience the service, for
  example "the share of requests that succeed" or "how long 95% of predictions take" (the p95
  latency). **[In this chapter]** you measure both kinds of numbers: `up`, `api_requests_total`
  and the `api_request_duration_seconds` histogram.
- **SLO (Service Level Objective)** — the target for an SLI, for example "99.9% of requests
  succeed over 30 days" or "p95 latency under 0.5 s". **[In this chapter]** the 0.5 s line in
  `MetricsApiSlowPredictions` is that kind of target, written as an alert.
- **Error budget** — what the SLO allows to go wrong. 99.9% over 30 days leaves 0.1%, about 43
  minutes of failure a month. If the team uses it up, they pause new features and fix reliability
  first. **[At work]** teams write SLOs down, track the budget on a dashboard, and alert on how
  fast it is being used up ("burn-rate" alerts).
- **[At work]** this app labels every request `status="200"`, even if something went wrong, so a
  success-rate SLI would always look perfect. In a real service you would label the true status
  code (200, 400, 500) so errors can be counted.

### Alerting, and a short runbook

**[In this chapter]** the three alert rules are loaded into Prometheus. Firing alerts appear in
Prometheus (**Alerts** page) and in Alertmanager (port 9093 on the platform ALB, your IP only).
**[At work]** Alertmanager would also *send* them: page the on-call engineer through a paging
tool, or post to a team chat channel. The platform here installs Alertmanager but sets up no
receivers, so alerts are shown but not sent anywhere.

A **runbook** is a short "what to do when this alert fires" page, written *before* the bad day.
Every alert at a big company links to one.

**Runbook: `MetricsApiDown` (critical)**

1. **What it means:** for 2 minutes, Prometheus has not reached any healthy copy of `metrics-api`.
   Users are probably getting errors right now.
2. **First 3 commands** (from `chapter-11-monitoring/cloud`):

   ```bash
   kubectl -n zero2ai get pods -l app.kubernetes.io/instance=metrics-api
   kubectl -n zero2ai describe deployment metrics-api
   kubectl -n zero2ai logs deployment/metrics-api --tail=50
   ```

   Look for: pods missing (0 copies), `CrashLoopBackOff` (the app keeps crashing),
   `ImagePullBackOff` (bad image), or `0/1 READY` (failing `/health`).
3. **How to fix:**
   - A bad new version: roll back to the last good revision:
     `helm history metrics-api -n zero2ai`, then `helm rollback metrics-api <revision> -n zero2ai`.
   - Copies scaled to 0 or deleted: `kubectl -n zero2ai scale deployment metrics-api --replicas=2`,
     then `bash deploy.sh 3` to put every setting back.
   - Image cannot be pulled: `bash deploy.sh build`, then `bash deploy.sh 3`.
4. **Check it is fixed:** `bash test.sh 3` passes, and the alert leaves the Alerts page within a
   few minutes.

**Runbook: `MetricsApiSlowPredictions` (warning)** — 95% of predictions took over 0.5 s for 5
minutes. Check whether copies are overloaded (`kubectl -n zero2ai top pods`,
`kubectl -n zero2ai get hpa metrics-api`). If the HPA is already at 5 copies, raise
`maxReplicas` in `phase3-production/values.yaml` and run `bash deploy.sh 3`. If it began right
after a deploy, roll back as above.

**Practice: make `MetricsApiDown` fire on purpose.** The HPA would fight you (it keeps at least
2 copies), so remove it first, then scale to zero:

```bash
kubectl -n zero2ai delete hpa metrics-api
kubectl -n zero2ai scale deployment metrics-api --replicas=0
```

Open Prometheus (see [README.md](README.md#explore-it-yourself)) -> **Alerts**. Within about a
minute `MetricsApiDown` turns **Pending** (the problem is seen, waiting out its `for: 2m`), then
**Firing**. Now follow the runbook to fix it:

```bash
kubectl -n zero2ai scale deployment metrics-api --replicas=2
bash deploy.sh 3
```

**What you should see:** the pods come back, `deploy.sh 3` re-creates the HPA, and a few minutes
later the alert is gone.

### Security

- **[In this chapter]** **Least privilege:** the app's pod gets no Kubernetes API token
  (`automountServiceAccountToken: false`), runs as user 1000 (not root), cannot gain more
  permissions, has every Linux capability dropped, and its disk is read-only (only `/tmp` is writable).
- **[In this chapter]** **NetworkPolicy:** only the namespace, the load balancer's IP range and
  Prometheus (on port 8000 only) may connect.
- **[In this chapter]** Prometheus and Alertmanager have no login, so the platform only opens
  them on the ALB to your own IP.
- **[At work]** limit who can reach the app with `ingress.allowedCidrs` (for example the office
  or VPN range), use HTTPS with your own domain (`ingress.host` and `ingress.certificateArn` in
  the chart), and put Prometheus behind single sign-on. This app has no secrets; Chapter 16 shows
  how secrets come from AWS Secrets Manager.

### Reliability

- **[In this chapter]** HPA (2 to 5 copies), PDB (at least 1 copy always up), spreading across
  zones, probes, zero-downtime rolling updates.
- **[At work]** run Prometheus itself with two copies and long-term storage, and add a "dead man's
  switch" alert that proves the alerting pipeline works. (The platform keeps 15 days of history
  on a disk in `ENV=prod`, and 2 days without a disk in dev; see PLATFORM.md.)

### Safe change

- **[In this chapter]** `helm upgrade --atomic` rolls back a failed upgrade by itself, and every
  change is a numbered revision you can `helm rollback` to.
- **[At work]** changes go through a pull request, CI renders and checks the chart (this repo has
  `chapter-10-kubernetes/scripts/validate-chart.sh` for that), and teams roll out to dev, then
  qa, then prod. Chapter 14 adds blue/green and canary releases.

### Cost and FinOps

**FinOps** means treating cloud cost as an engineering number you watch, like latency.

- **[In this chapter]** every copy asks for only what it needs (100m CPU, 128 MiB memory, limit
  256 MiB), the HPA removes extra copies when it is quiet, and Phase 3 shares the existing
  platform ALB instead of creating a new load balancer.
- **[In this chapter]** the biggest saving: `bash down.sh` and `platform-down.sh` when you stop.
- **[At work]** **right-size** from real numbers: use the memory query from Phase 2 and
  `kubectl -n zero2ai top pods` for a week, then set requests close to what is really used. Keep
  less metric history for less important apps, and drop labels that create too many separate series.

### Audit and compliance

- **[In this chapter]** `helm history metrics-api -n zero2ai` shows every revision of the app and
  when it was deployed. The alert rules are code in git, so you can see who changed a threshold and why.
- **[In this chapter]** the platform turns on EKS control-plane audit logs in `qa` and `prod` (not
  in `dev`), which record who changed what in the cluster (see PLATFORM.md).
- **[At work]** keep alert history and incident notes, and write a short blameless **postmortem**
  after each real outage: what happened, why, and what you changed so it cannot happen again.

## Production readiness checklist

Run each command from `chapter-11-monitoring/cloud` after `bash deploy.sh 3`.

- [ ] Tests pass: `bash test.sh 3` ends with `[OK] Phase 3 checks passed`.
- [ ] Prometheus is collecting it: `kubectl -n zero2ai get servicemonitor metrics-api` lists it,
      and Prometheus **Status -> Targets** shows 2 or more targets `UP`.
- [ ] Alerts are loaded: `kubectl -n zero2ai get prometheusrule metrics-api` lists it, and
      Prometheus **Alerts** shows the 3 rules.
- [ ] Autoscaling: `kubectl -n zero2ai get hpa metrics-api` shows `MINPODS 2` and `MAXPODS 5`.
- [ ] Disruption budget: `kubectl -n zero2ai get pdb metrics-api` shows `MIN AVAILABLE 1`.
- [ ] Network rules: `kubectl -n zero2ai get networkpolicy metrics-api` lists it.
- [ ] Copies are spread: `kubectl -n zero2ai get pods -l app.kubernetes.io/instance=metrics-api -o wide`
      shows the copies on different nodes.
- [ ] Not root: `kubectl -n zero2ai get deployment metrics-api -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}'`
      prints `true`.
- [ ] Rollback is possible: `helm history metrics-api -n zero2ai` lists more than one revision.
- [ ] You made `MetricsApiDown` fire and fixed it with the runbook.
- [ ] You know how to stop paying: `bash down.sh` and `platform-down.sh` (below).

## Career corner

The work you just did is the daily work of a **Site Reliability Engineer (SRE)**, a **Platform
Engineer**, an **Observability Engineer** or a **DevOps Engineer**. Questions you can now answer
in an interview:

1. *What is the difference between a counter and a histogram, and when would you use each?*
   (A counter only goes up, for "how many"; a histogram buckets measurements, for "how long",
   so you can work out p95 latency.)
2. *How does Prometheus find a new app on Kubernetes?* (A ServiceMonitor selects a Service by
   its labels and names the metrics port; Prometheus then scrapes every copy behind it.)
3. *What is an SLO, and what is an error budget?* (A target for a user-facing measurement, and
   how much failure that target still allows, for example about 43 minutes a month at 99.9%.)
4. *Why do alert rules have a `for:` duration?* (So a short blip does not page anyone; the
   problem must last before the alert fires.)
5. *Your alert says every copy is down. What are your first three commands?* (Get the pods,
   describe the deployment, read the logs; then roll back with Helm if a new version caused it.)

## Clean up

Remove this chapter's app (keeps the cluster):

```bash
bash down.sh
```

**What you should see:** `[OK] Chapter 11 app removed`. (Going on to Chapter 12 now? You can
leave it running: Chapter 12's guard watches it.)

When you are done for the day, destroy the platform (from this folder):

```bash
bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev
```

## Where to next

[Chapter 12](../../chapter-12-aiops/README.md) builds a robot guard that reads these numbers and
acts on them by itself. Its production phase is
[chapter-12-aiops/cloud/PRODUCTION.md](../../chapter-12-aiops/cloud/PRODUCTION.md).
