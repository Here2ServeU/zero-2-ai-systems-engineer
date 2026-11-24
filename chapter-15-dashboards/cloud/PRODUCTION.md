# Chapter 15 — Phase 3: Run it like a Fortune 500 company

> Phase 1 (laptop): [../README.md](../README.md) · Phase 2 (cloud): [README.md](README.md).
> You need Phase 2 working first, and the shared platform from
> [../../chapter-10-kubernetes/PLATFORM.md](../../chapter-10-kubernetes/PLATFORM.md).

**Labels:** Needs an AWS account that costs money · Needs the internet

---

## The big idea (in plain words)

A dashboard only helps if someone is looking at it. Nobody stares at charts at 3am. So big
companies add **alerts**: rules that watch the numbers all the time and raise their hand when
something is wrong. **Dashboards are for humans; alerts wake humans up.**

In Phase 3 you keep the same app and the same dashboard, and add:

- three **alert rules** that watch the golden signals,
- the production safety nets every course app gets (autoscaling, disruption budget, zone
  spreading, network rules, a public address),
- a **runbook**: the page an on-call engineer opens when an alert fires.

## Deploy and test

Every command runs from `chapter-15-dashboards/cloud`. Step 0 (`bash deploy.sh build`) from
Phase 2 must have run at least once.

```bash
bash deploy.sh 3
```

**What you should see:** Helm output with `STATUS: deployed`, a `helm history` table where the
newest revision says `Upgrade complete`, then `[OK] Phase 3 deployed. Test it: bash test.sh 3`.
If anything fails to become healthy within 10 minutes, `--atomic` rolls the release back
automatically and you see an error instead.

```bash
bash test.sh 3
```

This does everything `test.sh 2b` did, then waits for the public load balancer, sends a payment
through it, and lists the alert rules Prometheus now knows.

**What you should see** (addresses shortened):

```
[OK] Prometheus has the app's numbers
[OK] helm test monitored-api
"title":"Zero2AI Fraud API (Chapter 15)"
[OK] Grafana loaded the dashboard
==> Waiting for the AWS load balancer for ingress/monitored-api (first time: 2-4 minutes)
==> Public: http://k8s-zero2ai-....elb.amazonaws.com:8015
POST http://k8s-zero2ai-....elb.amazonaws.com:8015/predict  {"amount":950,"hour":3}
{"label":"fraud","prediction":1}
FraudShareHigh
ModelLatencyHigh
MonitoredApiDown
[OK] Phase 3 checks passed
```

## What changes in production and why

All of this comes from [`phase3-production/values.yaml`](phase3-production/values.yaml), added on
top of [`phase2b-helm/values.yaml`](phase2b-helm/values.yaml), plus two settings that
[`deploy.sh`](deploy.sh) adds for Phase 3.

| What | Setting | Why |
|---|---|---|
| **Alert rules** (PrometheusRule) | `prometheusRule.enabled: true` with 3 rules | Prometheus checks them every few seconds, day and night, so humans don't have to watch |
| `FraudShareHigh` | more than 20% of payments flagged as fraud for 10 minutes | A sudden jump means an attack, or the model has drifted (Chapter 13) |
| `ModelLatencyHigh` | p95 model time above 50 ms for 5 minutes | The app is getting slow for real customers |
| `MonitoredApiDown` | no copy reachable (`up == 0`) for 2 minutes | The app is completely down. Severity `critical` |
| **Autoscaling** (HPA) | `autoscaling: 2 to 5 copies`, target 70% CPU (chart default) | Busy? Add copies. Quiet? Remove them (after 5 calm minutes) to save money |
| **Bigger CPU request** | `resources.requests.cpu: 100m` | The HPA measures CPU as a percentage of the request, so the request must be realistic |
| **Disruption budget** (PDB) | `pdb.enabled: true`, at least 1 copy always up | When AWS replaces a node, Kubernetes never takes all copies down at once |
| **Zone spreading** | `topologySpread.enabled: true` | Copies are spread across availability zones and nodes, so one broken data center doesn't take the app down |
| **Network rules** (NetworkPolicy) | `networkPolicy.enabled: true`, plus `allowCidrs[0]` = the VPC range (set by `deploy.sh`) | Only pods in the same namespace, Prometheus (on the metrics port only) and the load balancer may connect. Everything else is blocked |
| **Public address** | `ingress.enabled: true`, `port: 8015` | The app gets its own port on the shared platform ALB: `http://<platform-alb>:8015` |
| **Auto-rollback** | `--atomic` (set by `deploy.sh 3`) | If the new version doesn't become healthy, Helm puts the old one back |
| **Locked-down container** (already on since 2B) | chart defaults: non-root user 1000, read-only file system, all Linux capabilities dropped | If someone breaks in, they can do very little |

Grafana itself stays where the platform put it. Putting Grafana on the open internet needs single
sign-on first; that's a good stretch goal.

### See the alerts

Open a tunnel to Prometheus. From anywhere:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Then open http://localhost:9090/alerts.

**What you should see:** a group called `monitored-api.rules` with the three alerts, all green
(**Inactive**). Press Ctrl+C to close the tunnel when you're done.

### Try it: make an alert fire

`load.sh` sends random payments, and only about 1 in 9 is fraud, so `FraudShareHigh` stays quiet.
Pretend there's an attack: send only fraud for 12 minutes. From `chapter-15-dashboards/cloud`:

```bash
HOST=$(kubectl -n zero2ai get ingress monitored-api -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
for i in $(seq 1 720); do curl -s -o /dev/null -X POST "http://$HOST:8015/predict" -H "Content-Type: application/json" -d '{"amount": 999, "hour": 3}'; sleep 1; done
```

**What you should see:** nothing in the terminal (it's quietly sending one payment a second).
Watch http://localhost:9090/alerts in the tunnel from above: after a few minutes
`FraudShareHigh` turns yellow (**Pending**: the rule is true, but not yet for 10 minutes), then
red (**Firing**). The "Fraud share" panel on the dashboard goes red too. Press Ctrl+C to stop
the loop; the alert goes back to Inactive after about 10 minutes.

---

## How big companies run this

### 1. Golden signals, SLIs and SLOs

SRE teams at Google-sized companies start every dashboard with the four **golden signals**:

| Golden signal | Plain words | In this chapter |
|---|---|---|
| **Traffic** | How busy is it? | "Predictions per second" panel (`rate(fraud_predictions_total[1m])`) |
| **Latency** | How slow is it? | "Model latency p50 / p95" panel and the `ModelLatencyHigh` alert |
| **Errors** | How often does it fail? | Only the "everything is down" case: `MonitoredApiDown` and the "Healthy copies" panel. The app doesn't count failed requests yet |
| **Saturation** | How full is it? | "Requests in progress" and "CPU used per copy" panels, and the HPA |

Then they turn the most important numbers into promises:

- An **SLI** (service level *indicator*) is a measurement, like "the share of predictions that
  took under 50 ms."
- An **SLO** (service level *objective*) is the goal for it, like "99.9% of predictions take
  under 50 ms, measured over 30 days."
- The **error budget** is the 0.1% you're allowed to miss. Over 30 days that's about 43 minutes
  of slowness. While budget is left, the team can ship new features quickly. When it's used up,
  they slow down and fix reliability first.

**What this chapter implements:** the golden-signal panels and simple threshold alerts.
**How you'd extend it at work:** add an error counter to the app (for example
`fraud_errors_total`), write the SLO down, and alert on **burn rate** ("we're using the error
budget 10 times faster than allowed") instead of raw thresholds. That gives fewer, more
meaningful pages.

### 2. Alerting that people trust

- **Every alert must need a human.** If nobody needs to do anything, it's a dashboard panel, not
  an alert. Too many alerts and people start ignoring them ("alert fatigue").
- **`for:` durations** stop flapping. Each rule here must be true for 2-10 minutes before it
  fires.
- **Severities** decide who gets woken: `critical` pages the on-call engineer now; `warning`
  becomes a ticket for working hours. This chapter labels them; that's the hook a routing system
  uses.
- **Routing.** Alertmanager (part of the platform) receives every firing alert. In this course it
  has no receivers, so alerts show up only in the Prometheus and Alertmanager pages.
  **At work** you'd route `critical` to PagerDuty or Opsgenie and `warning` to a Slack channel.
- **Every alert links to a runbook.** Here is a short one.

### 3. Runbook

| Alert | What it means | First 3 commands | How to fix |
|---|---|---|---|
| `MonitoredApiDown` (critical) | Prometheus can't reach any copy of the app for 2 minutes. Customers get errors | `kubectl -n zero2ai get pods -l app.kubernetes.io/instance=monitored-api`<br>`kubectl -n zero2ai describe pod <pod-name>`<br>`kubectl -n zero2ai logs deploy/monitored-api --tail=50` | Pods `CrashLoopBackOff`: read the logs and roll back with `helm rollback monitored-api -n zero2ai`. Pods `Pending`: the cluster is full; wait for the autoscaler or check nodes with `kubectl get nodes`. Pods running but still "down": check the ServiceMonitor with `kubectl -n zero2ai get servicemonitor monitored-api` |
| `ModelLatencyHigh` (warning) | The slowest 5% of predictions take over 50 ms | `kubectl -n zero2ai top pods`<br>`kubectl -n zero2ai get hpa monitored-api`<br>`helm history monitored-api -n zero2ai` | CPU at the limit and HPA at 5 copies: raise `autoscaling.maxReplicas`. Started right after a release: `helm rollback monitored-api -n zero2ai` |
| `FraudShareHigh` (warning) | Over 20% of payments look like fraud for 10 minutes | Open the dashboard: is traffic up too, or only the fraud share?<br>`kubectl -n zero2ai logs deploy/monitored-api --tail=50`<br>`helm history monitored-api -n zero2ai` | Traffic spike from a few sources: tell the security / fraud team (possible attack). No traffic change but a new release: roll back. Slow creep over weeks: the model may have drifted; retrain (Chapter 13) |

After every real incident, teams write a short **blameless post-mortem**: what happened, how they
found it, and what they'll change so it doesn't happen again.

### 4. Dashboards as code, for real

- **What this chapter implements:** the dashboard is [`dashboard.json`](dashboard.json) in git,
  installed by Helm. Change the file, redeploy, done.
- **How you'd extend it at work:** changes go through a pull request with a reviewer; one
  dashboard template serves every service (using Grafana variables); dashboards for different
  teams live in Grafana folders with permissions; and Grafana uses single sign-on instead of one
  shared `admin` password.

### 5. Reliability and safe change

- **Implemented:** at least 2 copies, HPA up to 5, PDB, zone spreading, readiness and liveness
  probes, `--atomic` rollback, and Chapter 14's safe-release habits.
- **At work you'd add:** a canary that checks the golden signals before sending everyone to the
  new version, and alerts on the monitoring system itself ("is Prometheus still scraping?").

### 6. Security

- **Implemented:** non-root container, read-only file system, all capabilities dropped,
  NetworkPolicy, the service account gets no Kubernetes API token, Grafana's password is
  generated by Terraform (not in git), Prometheus on the ALB is limited to your IP.
- **At work you'd add:** single sign-on for Grafana with read-only roles for most people, HTTPS
  on the public address (`ingress.certificateArn`), and `ingress.allowedCidrs` so only your
  company can reach the app.

### 7. Cost (FinOps)

Metrics cost money too: every extra label value makes a new time series that Prometheus must
store. **Implemented:** dev keeps only 2 days of metrics with no disk (prod: 15 days on 20 GB),
and the HPA removes copies when it's quiet. **At work:** keep label values few (never a user ID
as a label), and set retention per environment.

---

## Production readiness checklist

Run each command from `chapter-15-dashboards/cloud` after `bash deploy.sh 3`.

- [ ] All tests pass: `bash test.sh 3` ends with `[OK] Phase 3 checks passed`
- [ ] At least 2 copies are running: `kubectl -n zero2ai get pods -l app.kubernetes.io/instance=monitored-api`
- [ ] Autoscaling is on (2 to 5): `kubectl -n zero2ai get hpa monitored-api`
- [ ] A disruption budget exists: `kubectl -n zero2ai get pdb monitored-api`
- [ ] Network rules exist: `kubectl -n zero2ai get networkpolicy monitored-api`
- [ ] Prometheus is told to scrape the app: `kubectl -n zero2ai get servicemonitor monitored-api`
- [ ] The three alert rules are loaded: `kubectl -n zero2ai get prometheusrule monitored-api -o jsonpath='{.spec.groups[*].rules[*].alert}'`
- [ ] The dashboard ships as code: `kubectl -n zero2ai get configmap monitored-api-dashboard --show-labels` shows `grafana_dashboard=1`
- [ ] The container runs as non-root: `kubectl -n zero2ai get deploy monitored-api -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}'` prints `true`
- [ ] The public address answers: `curl http://$(kubectl -n zero2ai get ingress monitored-api -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):8015/health` prints `{"status":"healthy"}`
- [ ] You can roll back: `helm history monitored-api -n zero2ai` shows more than one revision

## Career corner

**Roles that do this work:** Site Reliability Engineer (SRE), Observability Engineer, Platform
Engineer, DevOps Engineer, Production / Infrastructure Engineer.

Practice questions you might hear in an interview:

1. What are the four golden signals, and which panel on your dashboard shows each one?
2. What is the difference between an SLI, an SLO and an error budget? Give an example for a
   fraud-checking API.
3. Why does a good alert have a `for:` duration, and what is alert fatigue?
4. Why keep dashboards as code instead of building them by clicking?
5. Your `MonitoredApiDown` alert fires at 3am. Walk me through your first five minutes.

## Clean up

From `chapter-15-dashboards/cloud`:

```bash
bash down.sh
```

**What you should see:** `[OK] Chapter 15 removed`. This also removes the dashboard and the
alert rules.

Done for the day? Destroy the platform so it stops costing money. From
`chapter-15-dashboards/cloud`:

```bash
bash ../../chapter-10-kubernetes/scripts/platform-down.sh dev
```

**What you should see:** Terraform destroying everything, ending with
`[OK] Everything for dev is destroyed.`

## Where to next

[Chapter 16 — Talk to a smart writing robot (LLM)](../../chapter-16-llm/README.md). You'll put a
large language model behind your own API, and in its Phase 3 keep the API keys in AWS Secrets
Manager.
